import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orbit/core/timezone_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/reminder_permission_status.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/android_reminder_guard.dart';
import 'package:orbit/services/class_notification_builder.dart';
import 'package:orbit/services/next_day_summary_builder.dart';
import 'package:orbit/services/reminder_alarm_planner.dart';
import 'package:orbit/services/reminder_id_ranges.dart';

typedef NotificationTapCallback = void Function(String? payload);

class ReminderScheduler {
  ReminderScheduler._();

  static final ReminderScheduler shared = ReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionsRequested = false;
  int lastScheduleFailureCount = 0;

  /// Number of notifications we intended to schedule in the last reschedule
  /// (those that passed the time filters), before any system-level failures.
  int lastExpectedCount = 0;

  /// Number of notifications actually pending in the system after the last
  /// reschedule, as reported by the OS. -1 means the platform does not support
  /// querying (e.g. Windows) so verification is skipped.
  int lastPendingCount = -1;

  /// Number of Android AlarmManager one-shots registered in the last reschedule.
  int lastRegisteredAlarmCount = 0;

  NotificationTapCallback? _notificationTapCallback;
  Future<void> _rescheduleChain = Future.value();
  DateTime? _lastSuccessfulRescheduleAt;
  final List<Timer> _nearTermTimers = [];

  /// When a reminder fires within this window, also register an in-process
  /// [Timer] that calls [FlutterLocalNotificationsPlugin.show] as a fallback
  /// when OEM builds silently drop scheduled alarms.
  static const _nearTermHorizon = Duration(hours: 2);

  /// True when we expected to schedule reminders but the OS reports none were
  /// actually queued. This catches OEM (e.g. OriginOS/iQOO) silently dropping
  /// exact alarms even though the plugin call did not throw.
  bool get lastScheduleVerificationFailed =>
      Platform.isAndroid && lastExpectedCount > 0 && lastPendingCount == 0;

  static const _foregroundResyncDebounce = Duration(hours: 6);

  static const _channelId = 'orbit_course_reminders';
  static const _classLeadBase = classLeadAlarmBase;
  static const _checkInBase = checkInAlarmBase;
  static const _nextDaySummaryBase = nextDaySummaryAlarmBase;

  Future<void> ensurePluginInitialized() async {
    if (_initialized) {
      return;
    }

    await configureReminderTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Orbit',
      appUserModelId: 'com.must.orbit',
      guid: '7f8d9c2a-4b1e-4f6a-9c3d-2e1f0a9b8c7d',
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  Future<void> initialize({required NotificationCopy copy}) async {
    await ensurePluginInitialized();

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (!_permissionsRequested) {
        await androidPlugin?.requestNotificationsPermission();
        await androidPlugin?.requestExactAlarmsPermission();
        _permissionsRequested = true;
      }
      await _ensureAndroidChannel(copy);
    }
  }

  void registerNotificationTapHandler(NotificationTapCallback? callback) {
    _notificationTapCallback = callback;
  }

  Future<String?> getLaunchNotificationPayload() async {
    await ensurePluginInitialized();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) {
      return null;
    }
    return details?.notificationResponse?.payload;
  }

  void markRescheduleSuccess() {
    _lastSuccessfulRescheduleAt = DateTime.now();
  }

  bool shouldResyncOnForeground() {
    final last = _lastSuccessfulRescheduleAt;
    if (last == null) {
      return true;
    }
    return DateTime.now().difference(last) >= _foregroundResyncDebounce;
  }

  Future<ReminderPermissionStatus> queryPermissionStatus() async {
    if (!Platform.isAndroid) {
      return const ReminderPermissionStatus(
        notificationsEnabled: true,
        exactAlarmsEnabled: true,
      );
    }

    await ensurePluginInitialized();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) {
      return ReminderPermissionStatus.unknown;
    }

    final notifications = await androidPlugin.areNotificationsEnabled() ?? false;
    final exactAlarms =
        await androidPlugin.canScheduleExactNotifications() ?? false;
    return ReminderPermissionStatus(
      notificationsEnabled: notifications,
      exactAlarmsEnabled: exactAlarms,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    _notificationTapCallback?.call(response.payload);
  }

  Future<void> _ensureAndroidChannel(NotificationCopy copy) async {
    if (!Platform.isAndroid) {
      return;
    }
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        copy.channelName,
        description: copy.channelDescription,
        importance: Importance.max,
      ),
    );
  }

  Future<void> rescheduleAll({
    required List<CourseSession> upcomingSessions,
    required List<CourseSession> allSessions,
    required ReminderSettings settings,
    required NotificationCopy copy,
  }) {
    _rescheduleChain = _rescheduleChain
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Reschedule chain error: $error');
          debugPrint('$stackTrace');
        })
        .then(
          (_) => _rescheduleAllImpl(
            upcomingSessions: upcomingSessions,
            allSessions: allSessions,
            settings: settings,
            copy: copy,
          ),
        );
    return _rescheduleChain;
  }

  Future<void> _rescheduleAllImpl({
    required List<CourseSession> upcomingSessions,
    required List<CourseSession> allSessions,
    required ReminderSettings settings,
    required NotificationCopy copy,
  }) async {
    await initialize(copy: copy);
    await cancelAll();
    if (Platform.isAndroid) {
      await AndroidReminderGuard.instance.cancelAllReminderAlarms();
    }
    _cancelNearTermTimers();
    lastScheduleFailureCount = 0;
    lastExpectedCount = 0;
    lastPendingCount = -1;
    lastRegisteredAlarmCount = 0;

    final now = DateTime.now();
    var classLeadId = _classLeadBase;
    var checkInId = _checkInBase;
    var expected = 0;
    final scheduleTasks = <Future<void>>[];

    if (settings.enabled) {
      for (final session in upcomingSessions) {
        final reminderAt = session.startAt
            .subtract(Duration(minutes: settings.leadMinutes));
        if (!reminderAt.isAfter(now)) {
          continue;
        }

        final id = classLeadId++;
        expected++;
        scheduleTasks.add(
          _scheduleClassLead(
            id: id,
            session: session,
            reminderAt: reminderAt,
            leadMinutes: settings.leadMinutes,
            settings: settings,
            copy: copy,
            now: now,
          ),
        );
        if (classLeadId >= _checkInBase) {
          break;
        }
      }
    }

    if (settings.checkInReminderEnabled) {
      for (final session in upcomingSessions) {
        if (!session.startAt.isAfter(now)) {
          continue;
        }

        final id = checkInId++;
        expected++;
        scheduleTasks.add(
          _scheduleCheckIn(
            id: id,
            session: session,
            reminderAt: session.startAt,
            settings: settings,
            copy: copy,
            now: now,
          ),
        );
        if (checkInId >= _nextDaySummaryBase) {
          break;
        }
      }
    }

    if (settings.nextDaySummaryEnabled) {
      expected += countNextDaySummarySlots(
        allSessions: allSessions,
        settings: settings,
        now: now,
      );
      scheduleTasks.add(
        _scheduleNextDaySummaries(
          allSessions: allSessions,
          settings: settings,
          copy: copy,
          now: now,
        ),
      );
    }

    await Future.wait(scheduleTasks);

    lastExpectedCount = expected;
    if (Platform.isAndroid) {
      final alarmSpecs = [
        ...buildReminderAlarmSpecs(
          upcomingSessions: upcomingSessions,
          settings: settings,
          now: now,
          copy: copy,
        ),
        ...buildNextDaySummaryAlarmSpecs(
          allSessions: allSessions,
          settings: settings,
          now: now,
          copy: copy,
        ),
      ];
      final alarmResult =
          await AndroidReminderGuard.instance.scheduleReminderAlarms(alarmSpecs);
      lastRegisteredAlarmCount = alarmResult.scheduled;
      lastScheduleFailureCount += alarmResult.failed;
      for (final spec in alarmResult.failedSpecs) {
        _registerNearTermReminderFromSpec(
          spec: spec,
          now: now,
          copy: copy,
        );
      }
    }
    await _verifyPendingCount();
  }

  void _cancelNearTermTimers() {
    for (final timer in _nearTermTimers) {
      timer.cancel();
    }
    _nearTermTimers.clear();
  }

  void _registerNearTermReminderFromSpec({
    required ReminderAlarmSpec spec,
    required DateTime now,
    required NotificationCopy copy,
  }) {
    final details = NotificationDetails(
      android: _androidAlarmDetails(
        copy: copy,
        bigText: spec.bigText,
      ),
      windows: const WindowsNotificationDetails(),
    );
    _registerNearTermReminder(
      reminderAt: spec.fireAt,
      now: now,
      id: spec.notificationId,
      title: spec.title,
      body: spec.body,
      details: details,
      payload: spec.payload,
    );
  }

  void _registerNearTermReminder({
    required DateTime reminderAt,
    required DateTime now,
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
    required String payload,
  }) {
    if (!isWithinNearTermHorizon(reminderAt, now, _nearTermHorizon)) {
      return;
    }
    final delay = reminderAt.difference(now);
    final timer = Timer(delay, () async {
      try {
        await _plugin.show(
          id,
          title,
          body,
          details,
          payload: payload,
        );
      } catch (error, stackTrace) {
        debugPrint('Near-term show failed for $id: $error');
        debugPrint('$stackTrace');
      }
    });
    _nearTermTimers.add(timer);
  }

  /// On Android, query the OS for the number of pending notifications so we can
  /// detect when alarms were silently dropped (no exception thrown) by the OEM.
  Future<void> _verifyPendingCount() async {
    if (!Platform.isAndroid) {
      lastPendingCount = -1;
      return;
    }
    try {
      final pending = await _plugin.pendingNotificationRequests();
      lastPendingCount = pending.length;
    } catch (error) {
      debugPrint('Failed to query pending notifications: $error');
      lastPendingCount = -1;
    }
  }

  Future<void> _scheduleNextDaySummaries({
    required List<CourseSession> allSessions,
    required ReminderSettings settings,
    required NotificationCopy copy,
    required DateTime now,
  }) async {
    final slots = buildNextDaySummarySlots(
      allSessions: allSessions,
      settings: settings,
      now: now,
      copy: copy,
    );
    await Future.wait(
      slots.map(
        (slot) => _scheduleNextDayNotification(
          id: slot.notificationId,
          title: slot.title,
          body: slot.body,
          reminderAt: slot.fireAt,
          copy: copy,
          payload: slot.payload,
        ),
      ),
    );
  }

  Future<void> _scheduleNextDayNotification({
    required int id,
    required String title,
    required String body,
    required DateTime reminderAt,
    required NotificationCopy copy,
    required String payload,
  }) async {
    final details = NotificationDetails(
      android: _androidAlarmDetails(copy: copy),
      windows: const WindowsNotificationDetails(),
    );

    await _zonedSchedule(
      id: id,
      title: title,
      body: body,
      reminderAt: reminderAt,
      details: details,
      payload: payload,
      preferAlarmClock: true,
    );
  }

  Future<void> cancelAll() async {
    await ensurePluginInitialized();
    await _plugin.cancelAll();
  }

  Future<void> cancelAllReminders() async {
    _cancelNearTermTimers();
    await cancelAll();
    if (Platform.isAndroid) {
      await AndroidReminderGuard.instance.cancelAllReminderAlarms();
    }
  }

  Future<void> _scheduleClassLead({
    required int id,
    required CourseSession session,
    required DateTime reminderAt,
    required int leadMinutes,
    required ReminderSettings settings,
    required NotificationCopy copy,
    required DateTime now,
  }) async {
    final text = buildClassLeadNotificationText(
      session: session,
      settings: settings,
      copy: copy,
      leadMinutes: leadMinutes,
    );

    final details = NotificationDetails(
      android: _androidAlarmDetails(
        copy: copy,
        bigText: text.bigText,
      ),
      windows: const WindowsNotificationDetails(),
    );

    await _zonedSchedule(
      id: id,
      title: text.title,
      body: text.body,
      reminderAt: reminderAt,
      details: details,
      payload: session.id,
      preferAlarmClock: true,
    );
    if (!Platform.isAndroid) {
      _registerNearTermReminder(
        reminderAt: reminderAt,
        now: now,
        id: id,
        title: text.title,
        body: text.body,
        details: details,
        payload: session.id,
      );
    }
  }

  Future<void> _scheduleCheckIn({
    required int id,
    required CourseSession session,
    required DateTime reminderAt,
    required ReminderSettings settings,
    required NotificationCopy copy,
    required DateTime now,
  }) async {
    final text = buildCheckInNotificationText(
      session: session,
      settings: settings,
      copy: copy,
    );

    final details = NotificationDetails(
      android: _androidAlarmDetails(copy: copy),
      windows: const WindowsNotificationDetails(),
    );

    await _zonedSchedule(
      id: id,
      title: text.title,
      body: text.body,
      reminderAt: reminderAt,
      details: details,
      payload: 'checkin_${session.id}',
      preferAlarmClock: true,
    );
    if (!Platform.isAndroid) {
      _registerNearTermReminder(
        reminderAt: reminderAt,
        now: now,
        id: id,
        title: text.title,
        body: text.body,
        details: details,
        payload: 'checkin_${session.id}',
      );
    }
  }

  AndroidNotificationDetails _androidAlarmDetails({
    required NotificationCopy copy,
    String? bigText,
  }) {
    return AndroidNotificationDetails(
      _channelId,
      copy.channelName,
      channelDescription: copy.channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      styleInformation:
          bigText == null ? null : BigTextStyleInformation(bigText),
    );
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime reminderAt,
    required NotificationDetails details,
    required String payload,
    bool preferAlarmClock = false,
  }) async {
    final when = reminderAtToTzDateTime(reminderAt);

    if (Platform.isAndroid && preferAlarmClock) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          payload: payload,
        );
        return;
      } catch (error, stackTrace) {
        debugPrint('AlarmClock schedule failed for $id: $error');
        debugPrint('$stackTrace');
      }
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (error, stackTrace) {
      debugPrint('Exact schedule failed for $id: $error');
      debugPrint('$stackTrace');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (fallbackError, fallbackStack) {
        lastScheduleFailureCount++;
        debugPrint('Inexact schedule also failed for $id: $fallbackError');
        debugPrint('$fallbackStack');
      }
    }
  }
}
