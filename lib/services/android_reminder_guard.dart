import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_permission_status.dart';
import 'package:orbit/services/android_native_reminder_service.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/settings_service.dart';

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
    await AndroidNativeReminderService.instance.initialize();
    _initialized = true;
  }

  Future<void> scheduleMaintenanceAlarm() async {
    if (!Platform.isAndroid || !_initialized) {
      return;
    }

    await AndroidNativeReminderService.instance.ensureMaintenanceAlarm();
  }

  Future<void> ensureReminderPermissions() async {
    if (!Platform.isAndroid) {
      return;
    }
    final locale = await _settingsService.loadLocale();
    final copy = NotificationCopy.fromL10n(lookupL10n(locale));
    await _scheduler.initialize(copy: copy);
    await scheduleMaintenanceAlarm();
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
      arguments: {'android.provider.extra.APP_PACKAGE': _androidPackageName},
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
