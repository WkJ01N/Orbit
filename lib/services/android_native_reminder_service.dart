import 'dart:io';
import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/reminder_alarm_registry.dart';
import 'package:orbit/services/reminder_id_ranges.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef NativeNotificationTapCallback = void Function(String payload);

class NativeReminderScheduleResult {
  const NativeReminderScheduleResult({
    required this.scheduled,
    this.usedInexactFallback = false,
  });

  final bool scheduled;
  final bool usedInexactFallback;
}

class ReminderDiagnosticEvent {
  const ReminderDiagnosticEvent({
    required this.timestamp,
    required this.stage,
    this.alarmId,
    this.reason,
  });

  final DateTime timestamp;
  final String stage;
  final int? alarmId;
  final String? reason;

  factory ReminderDiagnosticEvent.fromMap(Map<dynamic, dynamic> value) =>
      ReminderDiagnosticEvent(
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (value['timestamp'] as num).toInt(),
        ),
        stage: value['stage'] as String,
        alarmId: (value['alarmId'] as num?)?.toInt(),
        reason: value['reason'] as String?,
      );
}

class ReminderReliabilityStatus {
  const ReminderReliabilityStatus({
    this.enhancedMode = false,
    this.storedReminderCount = 0,
    this.registeredReminderCount = 0,
    this.forcedStopDetected = false,
    this.exitTimestamp,
    this.exitDescription,
    this.events = const [],
  });

  final bool enhancedMode;
  final int storedReminderCount;
  final int registeredReminderCount;
  final bool forcedStopDetected;
  final DateTime? exitTimestamp;
  final String? exitDescription;
  final List<ReminderDiagnosticEvent> events;

  factory ReminderReliabilityStatus.fromMap(Map<dynamic, dynamic> value) =>
      ReminderReliabilityStatus(
        enhancedMode: value['enhancedMode'] == true,
        storedReminderCount:
            (value['storedReminderCount'] as num?)?.toInt() ?? 0,
        registeredReminderCount:
            (value['registeredReminderCount'] as num?)?.toInt() ?? 0,
        forcedStopDetected: value['forcedStopDetected'] == true,
        exitTimestamp: value['exitTimestamp'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (value['exitTimestamp'] as num).toInt(),
              ),
        exitDescription: value['exitDescription'] as String?,
        events: (value['events'] as List? ?? const [])
            .map((item) => ReminderDiagnosticEvent.fromMap(item as Map))
            .toList(growable: false),
      );
}

/// Bridges Orbit's platform-neutral reminder specs to the Android receiver
/// that posts notifications without starting Flutter in the background.
class AndroidNativeReminderService {
  AndroidNativeReminderService._();

  static final instance = AndroidNativeReminderService._();
  static const MethodChannel _channel = MethodChannel(
    'com.must.orbit.orbit/reminders',
  );
  static const _legacyMigrationKey = 'native_reminder_migration_v1';

  bool _initialized = false;
  NativeNotificationTapCallback? _notificationTapCallback;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    _channel.setMethodCallHandler(_handleNativeCall);
    await _migrateLegacyAlarmManagerEntries();
    await _channel.invokeMethod<void>('initialize');
    _initialized = true;
  }

  Future<void> configureDatabase(String path, NotificationCopy copy) async {
    await initialize();
    await _channel.invokeMethod<void>('configureDatabase', {
      'path': path,
      'catchup_label': copy.catchUpLabel,
      'catchup_notice': copy.catchUpNotice,
      'original_label': copy.originalLabel,
      'delivered_label': copy.deliveredLabel,
      'channel_name': copy.channelName,
      'channel_description': copy.channelDescription,
    });
  }

  Future<String?> runtimeStatus() async {
    if (!Platform.isAndroid) return null;
    await initialize();
    return _channel.invokeMethod<String>('runtimeStatus');
  }

  Future<ReminderReliabilityStatus> reliabilityStatus() async {
    if (!Platform.isAndroid) return const ReminderReliabilityStatus();
    await initialize();
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'reminderReliabilityStatus',
    );
    return ReminderReliabilityStatus.fromMap(raw ?? const {});
  }

  Future<void> setEnhancedReminderMode({
    required bool enabled,
    required String channel,
    required String title,
    required String body,
    required String disable,
  }) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _channel.invokeMethod<void>('setEnhancedReminderMode', {
      'enabled': enabled,
      'channel': channel,
      'title': title,
      'body': body,
      'disable': disable,
    });
  }

  Future<bool> openAutostartSettings() async {
    if (!Platform.isAndroid) return false;
    await initialize();
    return await _channel.invokeMethod<bool>('openAutostartSettings') ?? false;
  }

  void registerNotificationTapHandler(NativeNotificationTapCallback? callback) {
    _notificationTapCallback = callback;
  }

  Future<NativeReminderScheduleResult> schedule(
    ReminderAlarmSpec spec, {
    required NotificationCopy copy,
    required bool exactPreferred,
    required bool allowInexactFallback,
    required bool restoreOnReboot,
  }) async {
    if (!Platform.isAndroid) {
      return const NativeReminderScheduleResult(scheduled: false);
    }
    await initialize();
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'scheduleReminder',
        buildScheduleArguments(
          spec,
          copy: copy,
          exactPreferred: exactPreferred,
          allowInexactFallback: allowInexactFallback,
          restoreOnReboot: restoreOnReboot,
        ),
      );
      return NativeReminderScheduleResult(
        scheduled: raw?['scheduled'] == true,
        usedInexactFallback: raw?['usedInexactFallback'] == true,
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Native reminder schedule failed: $error');
      debugPrint('$stackTrace');
      return const NativeReminderScheduleResult(scheduled: false);
    }
  }

  Map<String, dynamic> buildScheduleArguments(
    ReminderAlarmSpec spec, {
    required NotificationCopy copy,
    required bool exactPreferred,
    required bool allowInexactFallback,
    required bool restoreOnReboot,
  }) {
    return {
      'alarmId': spec.alarmId,
      'notificationId': spec.notificationId,
      'fireAtMillis': spec.fireAt.millisecondsSinceEpoch,
      'title': spec.title,
      'body': spec.body,
      'bigText': spec.bigText,
      'payload': spec.payload,
      'channelName': copy.channelName,
      'channelDescription': copy.channelDescription,
      'exactPreferred': exactPreferred,
      'allowInexactFallback': allowInexactFallback,
      'restoreOnReboot': restoreOnReboot,
      'metadata': jsonEncode(spec.toJson()),
    };
  }

  Future<void> cancel(int alarmId) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _channel.invokeMethod<void>('cancelReminder', {'alarmId': alarmId});
  }

  Future<void> cancelCourseReminders() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _channel.invokeMethod<void>('cancelCourseReminders');
  }

  Future<int> pendingCourseReminderCount() async {
    if (!Platform.isAndroid) return 0;
    await initialize();
    return await _channel.invokeMethod<int>('pendingCourseReminderCount') ?? 0;
  }

  Future<bool> contains(int alarmId) async {
    if (!Platform.isAndroid) return false;
    await initialize();
    return await _channel.invokeMethod<bool>('containsReminder', {
          'alarmId': alarmId,
        }) ??
        false;
  }

  Future<String?> consumeLaunchPayload() async {
    if (!Platform.isAndroid) return null;
    await initialize();
    return _channel.invokeMethod<String>('consumeLaunchPayload');
  }

  Future<void> ensureMaintenanceAlarm() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _channel.invokeMethod<void>('ensureMaintenanceAlarm');
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'notificationTap') return;
    final payload = call.arguments as String?;
    if (payload != null) _notificationTapCallback?.call(payload);
  }

  Future<void> _migrateLegacyAlarmManagerEntries() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_legacyMigrationKey) == true) return;
    try {
      await AndroidAlarmManager.initialize();
      final entries = await ReminderAlarmRegistry.loadAll();
      for (final alarmId in entries.keys) {
        await AndroidAlarmManager.cancel(alarmId);
      }
      await AndroidAlarmManager.cancel(backgroundTestNotificationId);
      await AndroidAlarmManager.cancel(maintenanceAlarmId);
      await ReminderAlarmRegistry.clearAll();
      await preferences.setBool(_legacyMigrationKey, true);
    } catch (error, stackTrace) {
      debugPrint('Legacy reminder migration failed: $error');
      debugPrint('$stackTrace');
    }
  }
}
