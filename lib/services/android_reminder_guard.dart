import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/reminder_background.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/settings_service.dart';

const _maintenanceAlarmId = 90400;
const _androidPackageName = 'com.must.orbit.orbit';

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

  Future<bool> isBatteryOptimizationAcknowledged() {
    return _settingsService.loadBatteryOptimizationAcknowledged();
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
      await _settingsService.saveBatteryOptimizationAcknowledged(true);
    } catch (_) {
      final fallback = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await fallback.launch();
      await _settingsService.saveBatteryOptimizationAcknowledged(true);
    }
  }
}
