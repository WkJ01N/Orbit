import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/reminder_alarm_callbacks.dart';
import 'package:orbit/services/reminder_alarm_registry.dart';
import 'package:orbit/services/reminder_id_ranges.dart';

/// A process-independent Android delivery path used alongside scheduled local
/// notifications. Both paths post the same notification id, so a late second
/// delivery replaces the first instead of creating a duplicate notification.
class AndroidAlarmDeliveryService {
  AndroidAlarmDeliveryService._();

  static final instance = AndroidAlarmDeliveryService._();

  bool _initialized = false;
  static const _deliveryGracePeriod = Duration(seconds: 3);

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    await AndroidAlarmManager.initialize();
    _initialized = true;
  }

  Future<bool> schedule(
    ReminderAlarmSpec spec, {
    required bool exact,
    required bool rescheduleOnReboot,
  }) async {
    if (!Platform.isAndroid) return false;
    await initialize();
    await AndroidAlarmManager.cancel(spec.alarmId);
    await ReminderAlarmRegistry.upsert(spec);
    try {
      final scheduled = await AndroidAlarmManager.oneShotAt(
        spec.fireAt.add(_deliveryGracePeriod),
        spec.alarmId,
        fireReminderAlarm,
        alarmClock: exact,
        exact: exact,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: rescheduleOnReboot,
      );
      if (scheduled) return true;
    } catch (error) {
      debugPrint('Exact AlarmManager schedule failed: $error');
      // Register an inexact wake-up below when exact alarms are unavailable.
    }

    try {
      final scheduled = await AndroidAlarmManager.oneShotAt(
        spec.fireAt.add(_deliveryGracePeriod),
        spec.alarmId,
        fireReminderAlarm,
        exact: false,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: rescheduleOnReboot,
      );
      if (scheduled) return true;
    } catch (error) {
      debugPrint('Inexact AlarmManager schedule failed: $error');
      // The caller combines this result with the notification plugin result.
    }
    await ReminderAlarmRegistry.removeByAlarmId(spec.alarmId);
    return false;
  }

  Future<void> cancelCourseReminders() async {
    if (!Platform.isAndroid) return;
    await initialize();
    final entries = await ReminderAlarmRegistry.loadAll();
    for (final id in entries.keys.where(isCourseReminderNotificationId)) {
      await AndroidAlarmManager.cancel(id);
    }
    await ReminderAlarmRegistry.removeCourseReminders();
  }

  Future<void> cancel(int alarmId) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await AndroidAlarmManager.cancel(alarmId);
    await ReminderAlarmRegistry.removeByAlarmId(alarmId);
  }

  Future<int> pendingCourseReminderCount() {
    return ReminderAlarmRegistry.courseReminderCount();
  }

  Future<bool> contains(int alarmId) => ReminderAlarmRegistry.contains(alarmId);
}
