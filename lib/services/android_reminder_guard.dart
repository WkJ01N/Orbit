import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/reminder_permission_status.dart';
import 'package:orbit/services/reminder_alarm_callbacks.dart';
import 'package:orbit/services/reminder_alarm_registry.dart';
import 'package:orbit/services/reminder_background.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/settings_service.dart';

const maintenanceAlarmId = 90400;
const _androidPackageName = 'com.must.orbit.orbit';
const _batteryChannel = MethodChannel('com.must.orbit.orbit/battery');
const _maintenanceInterval = Duration(hours: 6);

class AndroidReminderGuard {
  AndroidReminderGuard._();

  static final AndroidReminderGuard instance = AndroidReminderGuard._();

  final ReminderScheduler _scheduler = ReminderScheduler.shared;
  final SettingsService _settingsService = SettingsService();
  bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) {
      return;
    }
    await AndroidAlarmManager.initialize();
    _initialized = true;
  }

  Future<void> scheduleMaintenanceAlarm() async {
    if (!Platform.isAndroid || !_initialized) {
      return;
    }

    await AndroidAlarmManager.cancel(maintenanceAlarmId);
    await AndroidAlarmManager.periodic(
      _maintenanceInterval,
      maintenanceAlarmId,
      reminderMaintenanceCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );
  }

  /// Registers one-shot AlarmManager alarms for each [spec]. Returns the count
  /// successfully scheduled with the OS.
  Future<int> scheduleReminderAlarms(List<ReminderAlarmSpec> specs) async {
    if (!Platform.isAndroid || !_initialized) {
      return 0;
    }

    await ReminderAlarmRegistry.saveBatch(specs);
    var scheduled = 0;
    for (final spec in specs) {
      final ok = await AndroidAlarmManager.oneShotAt(
        spec.fireAt,
        spec.alarmId,
        fireReminderAlarm,
        alarmClock: true,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
      );
      if (ok) {
        scheduled++;
      }
    }
    return scheduled;
  }

  Future<void> cancelAllReminderAlarms() async {
    if (!Platform.isAndroid || !_initialized) {
      await ReminderAlarmRegistry.clearAll();
      return;
    }

    final entries = await ReminderAlarmRegistry.loadAll();
    for (final alarmId in entries.keys) {
      await AndroidAlarmManager.cancel(alarmId);
    }
    await AndroidAlarmManager.cancel(backgroundTestAlarmId);
    await ReminderAlarmRegistry.clearAll();
  }

  /// Schedules a test notification one minute from now via AlarmManager.
  Future<bool> scheduleBackgroundTestReminder({
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid || !_initialized) {
      return false;
    }

    await AndroidAlarmManager.cancel(backgroundTestAlarmId);
    final fireAt = DateTime.now().add(const Duration(minutes: 1));
    final spec = ReminderAlarmSpec(
      alarmId: backgroundTestAlarmId,
      notificationId: backgroundTestAlarmId,
      title: title,
      body: body,
      payload: 'test_background_reminder',
      fireAt: fireAt,
    );
    await ReminderAlarmRegistry.upsert(spec);
    return AndroidAlarmManager.oneShotAt(
      fireAt,
      backgroundTestAlarmId,
      fireReminderAlarm,
      alarmClock: true,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: false,
    );
  }

  Future<void> ensureReminderPermissions() async {
    if (!Platform.isAndroid) {
      return;
    }
    final locale = await _settingsService.loadLocale();
    final copy = NotificationCopy.fromL10n(
      lookupL10n(locale),
    );
    await _scheduler.initialize(copy: copy);
  }

  Future<ReminderPermissionStatus> queryPermissionStatus() {
    return _scheduler.queryPermissionStatus();
  }

  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) {
      return;
    }

    final status = await queryPermissionStatus();
    if (!status.exactAlarmsEnabled) {
      try {
        final exactAlarmIntent = AndroidIntent(
          action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
          data: 'package:$_androidPackageName',
        );
        await exactAlarmIntent.launch();
        return;
      } catch (_) {
        // Fall through to general notification settings.
      }
    }

    final intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: {
        'android.provider.extra.APP_PACKAGE': _androidPackageName,
      },
    );
    try {
      await intent.launch();
    } catch (_) {
      await openAppBatterySettings();
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final result = await _batteryChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:$_androidPackageName',
      );
      await intent.launch();
    } catch (_) {
      final fallback = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await fallback.launch();
    }
  }

  Future<void> openAppBatterySettings() async {
    if (!Platform.isAndroid) {
      return;
    }

    final intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:$_androidPackageName',
    );
    await intent.launch();
  }
}
