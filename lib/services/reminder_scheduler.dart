import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orbit/core/timezone_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_permission_status.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/schedule_summary_service.dart';
import 'package:timezone/timezone.dart' as tz;

typedef NotificationTapCallback = void Function(String? payload);

class ReminderScheduler {
  ReminderScheduler._();

  static final ReminderScheduler shared = ReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionsRequested = false;
  int lastScheduleFailureCount = 0;
  NotificationTapCallback? _notificationTapCallback;
  Future<void> _rescheduleChain = Future.value();
  DateTime? _lastSuccessfulRescheduleAt;

  static const _foregroundResyncDebounce = Duration(hours: 6);

  static const _channelId = 'orbit_course_reminders';
  static const _classLeadBase = 1;
  static const _checkInBase = 500000;
  static const _nextDaySummaryBase = 1000000;
  static const _nextDaySummaryDays = 30;

  Future<void> ensurePluginInitialized() async {
    if (_initialized) {
      return;
    }

    configureReminderTimezone();

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

  void registerNotificationTapHandler(NotificationTapCallback callback) {
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
        importance: Importance.high,
      ),
    );
  }

  Future<void> rescheduleAll({
    required List<CourseSession> upcomingSessions,
    required List<CourseSession> allSessions,
    required ReminderSettings settings,
    required NotificationCopy copy,
  }) {
    _rescheduleChain = _rescheduleChain.then(
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
    lastScheduleFailureCount = 0;

    final now = DateTime.now();
    var classLeadId = _classLeadBase;
    var checkInId = _checkInBase;
    final scheduleTasks = <Future<void>>[];

    if (settings.enabled) {
      for (final session in upcomingSessions) {
        final reminderAt = session.startAt
            .subtract(Duration(minutes: settings.leadMinutes));
        if (!reminderAt.isAfter(now)) {
          continue;
        }

        final id = classLeadId++;
        scheduleTasks.add(
          _scheduleClassLead(
            id: id,
            session: session,
            reminderAt: reminderAt,
            leadMinutes: settings.leadMinutes,
            copy: copy,
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
        scheduleTasks.add(
          _scheduleCheckIn(
            id: id,
            session: session,
            reminderAt: session.startAt,
            copy: copy,
          ),
        );
        if (checkInId >= _nextDaySummaryBase) {
          break;
        }
      }
    }

    if (settings.nextDaySummaryEnabled) {
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
  }

  Future<void> _scheduleNextDaySummaries({
    required List<CourseSession> allSessions,
    required ReminderSettings settings,
    required NotificationCopy copy,
    required DateTime now,
  }) async {
    final today = DateTime(now.year, now.month, now.day);
    final sessionsByDate = groupSessionsByDate(allSessions);
    final summaryTasks = <Future<void>>[];

    for (var offset = 0; offset < _nextDaySummaryDays; offset++) {
      final targetDay = today.add(Duration(days: offset + 1));
      final notifyDay = targetDay.subtract(const Duration(days: 1));
      final notifyAt = DateTime(
        notifyDay.year,
        notifyDay.month,
        notifyDay.day,
        settings.nextDaySummaryHour,
        settings.nextDaySummaryMinute,
      );
      if (!notifyAt.isAfter(now)) {
        continue;
      }

      final summary = summarizeDayFromGrouped(sessionsByDate, targetDay);
      final notificationId = _nextDaySummaryBase + offset;

      if (summary.hasClasses) {
        final firstTime = formatTimeOfDay(summary.firstSessionStart!);
        summaryTasks.add(
          _schedulePlainNotification(
            id: notificationId,
            title: copy.nextDaySummaryTitle,
            body: copy.nextDaySummaryBody(summary.sessionCount, firstTime),
            reminderAt: notifyAt,
            copy: copy,
            payload: 'next_day_${_dateKey(targetDay)}',
          ),
        );
      } else {
        summaryTasks.add(
          _schedulePlainNotification(
            id: notificationId,
            title: copy.nextDayNoClassTitle,
            body: copy.nextDayNoClassBody,
            reminderAt: notifyAt,
            copy: copy,
            payload: 'next_day_empty_${_dateKey(targetDay)}',
          ),
        );
      }
    }

    await Future.wait(summaryTasks);
  }

  Future<void> cancelAll() async {
    if (!_initialized) {
      return;
    }
    await _plugin.cancelAll();
  }

  Future<void> _scheduleClassLead({
    required int id,
    required CourseSession session,
    required DateTime reminderAt,
    required int leadMinutes,
    required NotificationCopy copy,
  }) async {
    final teachers = session.teachers.isEmpty
        ? copy.teachersNotProvided
        : session.teachers.join('、');
    final timeLabel = formatTimeOfDay(session.startAt);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        copy.channelName,
        channelDescription: copy.channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          copy.bigTextFor(
            course: session.courseName,
            time: timeLabel,
            room: session.room,
            teachers: teachers,
          ),
        ),
      ),
      windows: const WindowsNotificationDetails(),
    );

    await _zonedSchedule(
      id: id,
      title: copy.titleFor(leadMinutes),
      body: copy.bodyFor(session.courseName, session.room),
      reminderAt: reminderAt,
      details: details,
      payload: session.id,
    );
  }

  Future<void> _scheduleCheckIn({
    required int id,
    required CourseSession session,
    required DateTime reminderAt,
    required NotificationCopy copy,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        copy.channelName,
        channelDescription: copy.channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      windows: const WindowsNotificationDetails(),
    );

    await _zonedSchedule(
      id: id,
      title: copy.checkInTitle(session.courseName, session.room),
      body: copy.checkInBody(session.courseName),
      reminderAt: reminderAt,
      details: details,
      payload: 'checkin_${session.id}',
    );
  }

  Future<void> _schedulePlainNotification({
    required int id,
    required String title,
    required String body,
    required DateTime reminderAt,
    required NotificationCopy copy,
    required String payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        copy.channelName,
        channelDescription: copy.channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      windows: const WindowsNotificationDetails(),
    );

    await _zonedSchedule(
      id: id,
      title: title,
      body: body,
      reminderAt: reminderAt,
      details: details,
      payload: payload,
    );
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime reminderAt,
    required NotificationDetails details,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(reminderAt, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (error, stackTrace) {
      lastScheduleFailureCount++;
      debugPrint('Failed to schedule notification $id: $error');
      debugPrint('$stackTrace');
    }
  }

  static String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
