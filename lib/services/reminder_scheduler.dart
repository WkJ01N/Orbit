import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/services/custom_reminder_planner.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orbit/core/timezone_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/reminder_permission_status.dart';
import 'package:orbit/services/strong_reminder_resolver.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/reminder_schedule_report.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/android_native_reminder_service.dart';
import 'package:orbit/services/reminder_alarm_planner.dart';
import 'package:orbit/services/deadline_reminder_planner.dart';
import 'package:orbit/services/reminder_id_ranges.dart';
import 'package:orbit/services/windows_notification_worker.dart';

typedef NotificationTapCallback = void Function(String? payload);

class ReminderScheduler {
  ReminderScheduler._() : _windows = WindowsNotificationWorker();

  @visibleForTesting
  ReminderScheduler.forTesting({WindowsNotificationWorker? windows})
    : _windows = windows ?? WindowsNotificationWorker();

  static final ReminderScheduler shared = ReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;
  final WindowsNotificationWorker _windows;
  AppDatabase? database;
  bool _permissionsRequested = false;
  NotificationTapCallback? _notificationTapCallback;
  Future<void> _rescheduleChain = Future.value();
  String? _lastLiveWindowsPayload;
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
    return _initializing ??= _initializePlugin().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initializePlugin() async {
    if (Platform.isWindows) {
      _windows.onNotificationTap = (payload) {
        if (_notificationTapCallback != null) _lastLiveWindowsPayload = payload;
        _notificationTapCallback?.call(payload);
      };
      await _windows.initialize();
      _initialized = true;
      return;
    }
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
    AndroidNativeReminderService.instance.registerNotificationTapHandler(
      callback == null ? null : (payload) => callback(payload),
    );
  }

  Future<String?> getLaunchNotificationPayload() async {
    await ensurePluginInitialized();
    if (Platform.isWindows) {
      final payload = await _windows.launchPayload();
      return payload == _lastLiveWindowsPayload ? null : payload;
    }
    if (Platform.isAndroid) {
      final nativePayload = await AndroidNativeReminderService.instance
          .consumeLaunchPayload();
      if (nativePayload != null) return nativePayload;
    }
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

  Future<bool?> queryNotificationAuthorization() async {
    await ensurePluginInitialized();
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
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
    List<Deadline> deadlines = const [],
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
            deadlines: deadlines,
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
    required List<Deadline> deadlines,
    required ReminderSettings settings,
    required NotificationCopy copy,
    required bool requestPermissions,
  }) async {
    if (requestPermissions) {
      await initialize(copy: copy);
    } else {
      await _prepare(copy);
    }
    final retainedCatchUp = <ReminderAlarmSpec>[];
    if (Platform.isWindows && database != null) {
      final pending = await _windows.pendingIds();
      for (final row in await database!.reminderSchedules()) {
        final spec = ReminderAlarmSpec.fromJson(
          jsonDecode(row['spec'] as String) as Map<String, dynamic>,
        );
        if (spec.catchUp && pending.contains(spec.notificationId)) {
          retainedCatchUp.add(spec);
        }
      }
    }
    await cancelScheduledCourseReminders();

    final now = DateTime.now();
    final identityDb = database;
    final sessionAliases = identityDb == null
        ? <String, String>{}
        : await identityDb.reminderSessionAliases();
    final seriesMemberships = identityDb == null
        ? <String, List<String>>{}
        : await identityDb.reminderSeriesMemberships();
    final specs = <ReminderAlarmSpec>[
      ...buildReminderAlarmSpecs(
        upcomingSessions: upcomingSessions,
        settings: settings,
        now: now,
        copy: copy,
        sessionAliases: sessionAliases,
        seriesMemberships: seriesMemberships,
      ),
      ...buildNextDaySummaryAlarmSpecs(
        allSessions: allSessions,
        settings: settings,
        now: now,
        copy: copy,
        sessionAliases: sessionAliases,
        seriesMemberships: seriesMemberships,
      ),
      if (identityDb != null)
        ...buildDeadlineReminderSpecs(
          deadlines: deadlines,
          notificationIds: await identityDb.reserveDeadlineNotificationIds(
            deadlines,
          ),
          now: now,
          text: copy.deadlineText,
        ),
    ];
    final db = database;
    if (db != null) {
      if (Platform.isWindows) {
        try {
          final delivered =
              await const MethodChannel(
                    'com.must.orbit.orbit/windows_reminders',
                  )
                  .invokeListMethod<int>('deliveredIds')
                  .timeout(const Duration(seconds: 10)) ??
              [];
          for (final row in await db.reminderSchedules()) {
            if (delivered.contains(3000000 + (row['id'] as int))) {
              await db.markReminderProcessed(
                row['rule_id'] as String,
                row['session_id'] as String,
                row['send_index'] as int,
              );
            }
          }
        } catch (error) {
          debugPrint('Notification delivery verification unavailable: $error');
        }
      }
      if (Platform.isAndroid) {
        await AndroidNativeReminderService.instance.configureDatabase(
          db.path,
          copy,
        );
      }
      final custom = planCustomReminders(
        sessions: allSessions,
        rules: settings.customRules,
        strong: settings.strong,
        now: now,
        states: await db.reminderDeliveryStates(),
        sessionAliases: await db.reminderSessionAliases(),
        seriesMemberships: await db.reminderSeriesMemberships(),
        catchUpLabel: copy.catchUpLabel,
        catchUpNotice: copy.catchUpNotice,
        originalLabel: copy.originalLabel,
        deliveredLabel: copy.deliveredLabel,
        acknowledgeLabel: copy.acknowledgeLabel,
        stopLabel: copy.stopLabel,
        weekdayNames: copy.weekdayNames,
      );
      final aliases = await db.reminderSessionAliases();
      final currentIdentities = allSessions
          .map((s) => aliases[s.id] ?? s.id)
          .toSet();
      retainedCatchUp.removeWhere(
        (s) => !currentIdentities.contains(s.sessionId),
      );
      final keys = Platform.isWindows
          ? await db.storeWindowsBuiltinSchedules(specs)
          : <String>{};
      final groups = <String>{};
      for (final stored in await db.materializeReminderSchedules(custom)) {
        final spec = stored;
        final key = '${spec.ruleId}|${spec.sessionId}|${spec.sendIndex}';
        keys.add(key);
        final group = '${spec.ruleId}|${spec.sessionId}';
        if (!Platform.isAndroid || groups.add(group)) specs.add(stored);
      }
      for (final spec in retainedCatchUp) {
        if (settings.customRules.any((r) => r.id == spec.ruleId && r.enabled)) {
          keys.add('${spec.ruleId}|${spec.sessionId}|${spec.sendIndex}');
        }
      }
      await db.pruneReminderSchedules(keys);
      for (final spec in retainedCatchUp) {
        final rule = settings.customRules
            .where((r) => r.id == spec.ruleId && r.enabled)
            .firstOrNull;
        final states = await db.reminderDeliveryStates();
        final acknowledged = states.any(
          (s) =>
              s['rule_id'] == spec.ruleId &&
              s['session_id'] == spec.sessionId &&
              s['acknowledged'] == 1,
        );
        if (rule != null &&
            !acknowledged &&
            !specs.any((s) => s.notificationId == spec.notificationId)) {
          final updated = ReminderAlarmSpec.fromJson({
            ...spec.toJson(),
            'strong': resolveStrongReminder(
              global: settings.strong,
              type: StrongReminderType.custom,
              rule: rule,
              session: allSessions
                  .where((s) => (aliases[s.id] ?? s.id) == spec.sessionId)
                  .firstOrNull,
              aliases: aliases,
              memberships: seriesMemberships,
            ).toJson(),
            'fireAt':
                (spec.fireAt.isAfter(now)
                        ? spec.fireAt
                        : now.add(const Duration(seconds: 1)))
                    .toIso8601String(),
          });
          await db.updateReminderSchedule(
            spec.notificationId - 3000000,
            jsonEncode(updated.toJson()),
          );
          specs.add(updated);
        }
      }
    }
    specs.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    if (Platform.isWindows && specs.length > 3000) {
      specs.removeRange(3000, specs.length);
    }

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
    final queuedCustom = <int>{};
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
        queuedCustom.add(spec.notificationId);
        if (Platform.isWindows &&
            spec.catchUp &&
            spec.ruleId != null &&
            db != null) {
          await db.markCatchUpQueued(
            spec.ruleId!,
            spec.sessionId!,
            spec.sendIndex,
          );
        }
      } else {
        failed++;
      }
      usedFallback = usedFallback || attempt.usedInexactFallback;
    }

    if (db != null) await db.markQueuedReminders(queuedCustom);
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
    await _cancelNotification(backgroundTestNotificationId);
    await AndroidNativeReminderService.instance.cancel(
      backgroundTestNotificationId,
    );
    final permission = await queryPermissionStatus();
    if (!permission.notificationsEnabled) {
      return const ReminderTestResult.failure(
        ReminderTestFailure.notificationsDenied,
      );
    }
    try {
      await _cancelNotification(immediateTestNotificationId);
      if (Platform.isWindows) {
        await _windows.show(
          immediateTestNotificationId,
          title,
          body,
          'test_immediate_reminder',
        );
      } else {
        await _plugin.show(
          immediateTestNotificationId,
          title,
          body,
          _notificationDetails(copy),
          payload: 'test_immediate_reminder',
        );
      }
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
    final queued = await AndroidNativeReminderService.instance.contains(
      backgroundTestNotificationId,
    );
    return queued
        ? ReminderTestResult.success(fireAt: fireAt)
        : const ReminderTestResult.failure(
            ReminderTestFailure.schedulingFailed,
          );
  }

  Future<void> acknowledgeOccurrence(
    AppDatabase db,
    String ruleId,
    String sessionId,
  ) async {
    final rows = (await db.reminderSchedules())
        .where(
          (row) => row['rule_id'] == ruleId && row['session_id'] == sessionId,
        )
        .toList();
    await db.acknowledgeReminder(ruleId, sessionId);
    await ensurePluginInitialized();
    for (final row in rows) {
      final id = 3000000 + (row['id'] as int);
      if (Platform.isAndroid) {
        await AndroidNativeReminderService.instance.cancel(id);
      }
      await _cancelNotification(id);
    }
  }

  Future<void> cancelScheduledCourseReminders() async {
    await ensurePluginInitialized();
    if (Platform.isAndroid) {
      await AndroidNativeReminderService.instance.cancelCourseReminders();
    }
    try {
      final pending = await _pendingNotificationIds();
      for (final id in pending) {
        if (isCourseReminderNotificationId(id)) {
          await _cancelNotification(id);
        }
      }
    } catch (error) {
      debugPrint('Failed to cancel scheduled course reminders: $error');
      // A failed Windows query must not trigger thousands of synchronous RPCs
      // or replace reminders while their previous IDs are unknown.
      if (Platform.isWindows) rethrow;
      for (
        var id = nextDaySummaryAlarmBase;
        id < nextDaySummaryAlarmLimit;
        id++
      ) {
        await _cancelNotification(id);
      }
    }
  }

  Future<void> cancelAllReminders() => cancelScheduledCourseReminders();

  Future<void> _cancelNotification(int id) =>
      Platform.isWindows ? _windows.cancel(id) : _plugin.cancel(id);

  Future<List<int>> _pendingNotificationIds() async => Platform.isWindows
      ? await _windows.pendingIds()
      : (await _plugin.pendingNotificationRequests()).map((n) => n.id).toList();

  Future<_ScheduleAttempt> _scheduleSpec(
    ReminderAlarmSpec spec,
    NotificationCopy copy, {
    bool allowInexactFallback = true,
    bool exactAlarmsEnabled = true,
    bool rescheduleOnReboot = true,
  }) async {
    if (Platform.isAndroid) {
      final result = await AndroidNativeReminderService.instance.schedule(
        spec,
        copy: copy,
        exactPreferred: exactAlarmsEnabled,
        allowInexactFallback: allowInexactFallback,
        restoreOnReboot: rescheduleOnReboot,
      );
      return _ScheduleAttempt(
        scheduled: result.scheduled,
        usedInexactFallback: result.usedInexactFallback,
      );
    }

    try {
      if (Platform.isWindows) {
        await _windows.schedule(spec);
        return const _ScheduleAttempt(scheduled: true);
      }
      await _plugin.zonedSchedule(
        spec.notificationId,
        spec.title,
        spec.body,
        reminderAtToTzDateTime(spec.fireAt),
        _notificationDetails(copy, bigText: spec.bigText),
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
      final pending = await _pendingNotificationIds();
      final pluginCount = pending.where(isCourseReminderNotificationId).length;
      if (!Platform.isAndroid) return pluginCount;
      return AndroidNativeReminderService.instance.pendingCourseReminderCount();
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
