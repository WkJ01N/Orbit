import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:orbit/models/reminder_permission_status.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/reminder_background.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/settings_service.dart';

const _maintenanceAlarmId = 90400;
const _androidPackageName = 'com.must.orbit.orbit';
const _batteryChannel = MethodChannel('com.must.orbit.orbit/battery');

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

    await AndroidAlarmManager.periodic(
      const Duration(hours: 24),
      _maintenanceAlarmId,
      reminderMaintenanceCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  Future<void> ensureReminderPermissions() async {
    if (!Platform.isAndroid) {
      return;
    }
    final locale = await _settingsService.loadLocale();
    final copy = notificationCopyFor(locale);
    await _scheduler.initialize(copy: copy);
  }

  Future<ReminderPermissionStatus> queryPermissionStatus() {
    return _scheduler.queryPermissionStatus();
  }

  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) {
      return;
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
