import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orbit/core/timezone_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/reminder_permission_status.dart';
import 'package:orbit/models/reminder_schedule_report.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/android_alarm_delivery_service.dart';
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
  NotificationTapCallback? _notificationTapCallback;
  Future<void> _rescheduleChain = Future.value();
  DateTime? _lastSuccessfulRescheduleAt;
  DateTime? _lastScheduleDay;
  Duration? _lastTimezoneOffset;

  static const _foregroundResyncDebounce = Duration(hours: 6);
  static const _channelId = 'orbit_course_reminders';

  ReminderScheduleReport lastScheduleReport = ReminderScheduleReport.empty;

  int get lastScheduleFailureCount => lastScheduleReport.failed;
  int get lastExpectedCount => lastScheduleReport.expected;
  int get lastPendingCount => lastScheduleReport.pending;
  bool get lastScheduleVerificationFailed =>
      lastScheduleReport.verificationFailed;

  Future<void> ensurePluginInitialized() async {
    if (_initialized) return;
    await configureReminderTimezone();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      windows: WindowsInitializationSettings(
        appName: 'Orbit',
        appUserModelId: 'com.must.orbit',
        guid: '7f8d9c2a-4b1e-4f6a-9c3d-2e1f0a9b8c7d',
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  Future<void> initialize({required NotificationCopy copy}) async {
    await _prepare(copy);
    if (!Platform.isAndroid) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (!_permissionsRequested) {
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      _permissionsRequested = true;
    }
  }

  Future<void> _prepare(NotificationCopy copy) async {
    await ensurePluginInitialized();
    if (Platform.isAndroid) await _ensureAndroidChannel(copy);
  }

  void registerNotificationTapHandler(NotificationTapCallback? callback) {
    _notificationTapCallback = callback;
  }

  Future<String?> getLaunchNotificationPayload() async {
    await ensurePluginInitialized();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  void markRescheduleSuccess() {
    _lastSuccessfulRescheduleAt = DateTime.now();
    _lastScheduleDay = DateTime.now();
    _lastTimezoneOffset = DateTime.now().timeZoneOffset;
  }

  Future<bool> shouldResyncOnForeground() async {
    final last = _lastSuccessfulRescheduleAt;
    final now = DateTime.now();
    if (last == null || now.difference(last) >= _foregroundResyncDebounce) {
      return true;
    }
    final scheduleDay = _lastScheduleDay;
    if (scheduleDay == null ||
        scheduleDay.year != now.year ||
        scheduleDay.month != now.month ||
        scheduleDay.day != now.day ||
        _lastTimezoneOffset != now.timeZoneOffset) {
      return true;
    }
    if (Platform.isAndroid) {
      final permission = await queryPermissionStatus();
      if (!permission.notificationsEnabled) return true;
      final pending = await _pendingCourseReminderCount();
      return pending >= 0 && pending != lastScheduleReport.pending;
    }
    return false;
  }

  Future<ReminderPermissionStatus> queryPermissionStatus() async {
    if (!Platform.isAndroid) {
      return const ReminderPermissionStatus(
        notificationsEnabled: true,
        exactAlarmsEnabled: true,
      );
    }
    await ensurePluginInitialized();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return ReminderPermissionStatus.unknown;
    return ReminderPermissionStatus(
      notificationsEnabled: await android.areNotificationsEnabled() ?? false,
      exactAlarmsEnabled:
          await android.canScheduleExactNotifications() ?? false,
    );
  }

  Future<void> rescheduleAll({
    required List<CourseSession> upcomingSessions,
    required List<CourseSession> allSessions,
    required ReminderSettings settings,
    required NotificationCopy copy,
    bool requestPermissions = true,
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
            requestPermissions: requestPermissions,
          ),
        );
    return _rescheduleChain;
  }

  Future<void> _rescheduleAllImpl({
    required List<CourseSession> upcomingSessions,
    required List<CourseSession> allSessions,
    required ReminderSettings settings,
    required NotificationCopy copy,
    required bool requestPermissions,
  }) async {
    if (requestPermissions) {
      await initialize(copy: copy);
    } else {
      await _prepare(copy);
    }
    await cancelScheduledCourseReminders();

    final now = DateTime.now();
    final specs = <ReminderAlarmSpec>[
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

    var exactAlarmsEnabled = true;
    if (Platform.isAndroid) {
      final permission = await queryPermissionStatus();
      exactAlarmsEnabled = permission.exactAlarmsEnabled;
      if (!permission.notificationsEnabled) {
        lastScheduleReport = ReminderScheduleReport(
          expected: specs.length,
          scheduled: 0,
          pending: 0,
          failed: specs.length,
          blockReason: ReminderScheduleBlockReason.notificationsDenied,
        );
        return;
      }
    }

    var accepted = 0;
    var failed = 0;
    var usedFallback = false;
    for (final spec in specs) {
      final attempt = await _scheduleSpec(
        spec,
        copy,
        exactAlarmsEnabled: exactAlarmsEnabled,
      );
      if (attempt.scheduled) {
        accepted++;
      } else {
        failed++;
      }
      usedFallback = usedFallback || attempt.usedInexactFallback;
    }

    final pending = await _pendingCourseReminderCount();
    final verifiedScheduled = pending >= 0 ? pending : accepted;
    final missing = specs.length - verifiedScheduled;
    final verifiedFailed = pending >= 0 && missing > failed ? missing : failed;
    lastScheduleReport = ReminderScheduleReport(
      expected: specs.length,
      scheduled: verifiedScheduled,
      pending: pending,
      failed: verifiedFailed,
      usedInexactFallback: usedFallback,
    );
  }

  Future<ReminderTestResult> showImmediateTest({
    required String title,
    required String body,
    required NotificationCopy copy,
  }) async {
    await _prepare(copy);
    await _plugin.cancel(backgroundTestNotificationId);
    await AndroidAlarmDeliveryService.instance.cancel(
      backgroundTestNotificationId,
    );
    final permission = await queryPermissionStatus();
    if (!permission.notificationsEnabled) {
      return const ReminderTestResult.failure(
        ReminderTestFailure.notificationsDenied,
      );
    }
    try {
      await _plugin.cancel(immediateTestNotificationId);
      await _plugin.show(
        immediateTestNotificationId,
        title,
        body,
        _notificationDetails(copy),
        payload: 'test_immediate_reminder',
      );
      return const ReminderTestResult.success();
    } catch (error, stackTrace) {
      debugPrint('Immediate reminder test failed: $error');
      debugPrint('$stackTrace');
      return const ReminderTestResult.failure(
        ReminderTestFailure.schedulingFailed,
      );
    }
  }

  Future<ReminderTestResult> scheduleBackgroundTest({
    required String title,
    required String body,
    required NotificationCopy copy,
  }) async {
    await _prepare(copy);
    final permission = await queryPermissionStatus();
    if (!permission.notificationsEnabled) {
      return const ReminderTestResult.failure(
        ReminderTestFailure.notificationsDenied,
      );
    }
    if (!permission.exactAlarmsEnabled) {
      return const ReminderTestResult.failure(
        ReminderTestFailure.exactAlarmsDenied,
      );
    }

    final fireAt = DateTime.now().add(const Duration(minutes: 1));
    final attempt = await _scheduleSpec(
      ReminderAlarmSpec(
        alarmId: backgroundTestNotificationId,
        notificationId: backgroundTestNotificationId,
        title: title,
        body: body,
        payload: 'test_background_reminder',
        fireAt: fireAt,
      ),
      copy,
      allowInexactFallback: false,
      exactAlarmsEnabled: true,
      rescheduleOnReboot: false,
    );
    if (!attempt.scheduled) {
      return const ReminderTestResult.failure(
        ReminderTestFailure.schedulingFailed,
      );
    }
    final pending = await _plugin.pendingNotificationRequests();
    final queued =
        pending.any((item) => item.id == backgroundTestNotificationId) ||
        await AndroidAlarmDeliveryService.instance.contains(
          backgroundTestNotificationId,
        );
    return queued
        ? ReminderTestResult.success(fireAt: fireAt)
        : const ReminderTestResult.failure(
            ReminderTestFailure.schedulingFailed,
          );
  }

  Future<void> cancelScheduledCourseReminders() async {
    await ensurePluginInitialized();
    if (Platform.isAndroid) {
      await AndroidAlarmDeliveryService.instance.cancelCourseReminders();
    }
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (isCourseReminderNotificationId(request.id)) {
          await _plugin.cancel(request.id);
        }
      }
    } catch (error) {
      debugPrint('Failed to cancel scheduled course reminders: $error');
      for (
        var id = nextDaySummaryAlarmBase;
        id < nextDaySummaryAlarmLimit;
        id++
      ) {
        await _plugin.cancel(id);
      }
    }
  }

  Future<void> cancelAllReminders() => cancelScheduledCourseReminders();

  Future<_ScheduleAttempt> _scheduleSpec(
    ReminderAlarmSpec spec,
    NotificationCopy copy, {
    bool allowInexactFallback = true,
    bool exactAlarmsEnabled = true,
    bool rescheduleOnReboot = true,
  }) async {
    final when = reminderAtToTzDateTime(spec.fireAt);
    final details = _notificationDetails(copy, bigText: spec.bigText);
    if (Platform.isAndroid) {
      var pluginScheduled = false;
      var usedInexactFallback = false;
      try {
        await _plugin.zonedSchedule(
          spec.notificationId,
          spec.title,
          spec.body,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: spec.payload,
        );
        pluginScheduled = true;
      } catch (error, stackTrace) {
        debugPrint('Exact schedule failed for ${spec.notificationId}: $error');
        debugPrint('$stackTrace');
        if (allowInexactFallback) {
          try {
            await _plugin.zonedSchedule(
              spec.notificationId,
              spec.title,
              spec.body,
              when,
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: spec.payload,
            );
            pluginScheduled = true;
            usedInexactFallback = true;
          } catch (fallbackError, fallbackStack) {
            debugPrint('Inexact schedule failed: $fallbackError');
            debugPrint('$fallbackStack');
          }
        }
      }

      final alarmScheduled = await AndroidAlarmDeliveryService.instance
          .schedule(
            spec,
            exact: exactAlarmsEnabled,
            rescheduleOnReboot: rescheduleOnReboot,
          );
      return _ScheduleAttempt(
        scheduled: pluginScheduled || alarmScheduled,
        usedInexactFallback: usedInexactFallback || !exactAlarmsEnabled,
      );
    }

    try {
      await _plugin.zonedSchedule(
        spec.notificationId,
        spec.title,
        spec.body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: spec.payload,
      );
      return const _ScheduleAttempt(scheduled: true);
    } catch (error, stackTrace) {
      debugPrint('Reminder schedule failed: $error');
      debugPrint('$stackTrace');
      return const _ScheduleAttempt(scheduled: false);
    }
  }

  Future<int> _pendingCourseReminderCount() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final pluginCount = pending
          .where((item) => isCourseReminderNotificationId(item.id))
          .length;
      if (!Platform.isAndroid) return pluginCount;
      final alarmCount = await AndroidAlarmDeliveryService.instance
          .pendingCourseReminderCount();
      return math.max(pluginCount, alarmCount);
    } catch (error) {
      debugPrint('Failed to query pending notifications: $error');
      return -1;
    }
  }

  NotificationDetails _notificationDetails(
    NotificationCopy copy, {
    String? bigText,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        copy.channelName,
        channelDescription: copy.channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        styleInformation: bigText == null
            ? null
            : BigTextStyleInformation(bigText),
      ),
      windows: const WindowsNotificationDetails(),
    );
  }

  Future<void> _ensureAndroidChannel(NotificationCopy copy) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        copy.channelName,
        description: copy.channelDescription,
        importance: Importance.max,
      ),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    _notificationTapCallback?.call(response.payload);
  }
}

class _ScheduleAttempt {
  const _ScheduleAttempt({
    required this.scheduled,
    this.usedInexactFallback = false,
  });

  final bool scheduled;
  final bool usedInexactFallback;
}
