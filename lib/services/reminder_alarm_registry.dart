import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/reminder_id_ranges.dart';
import 'package:shared_preferences/shared_preferences.dart';

const reminderAlarmRegistryKey = 'orbit_reminder_alarm_registry_v2';

/// Stores payloads needed by AlarmManager's background isolate. The isolate
/// reloads preferences before every read so it can see updates made by the UI
/// process immediately before an alarm was registered.
class ReminderAlarmRegistry {
  ReminderAlarmRegistry._();

  static Future<Map<int, ReminderAlarmSpec>> loadAll({
    bool reload = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    final raw = prefs.getString(reminderAlarmRegistryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          int.parse(key),
          ReminderAlarmSpec.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (error) {
      debugPrint('Reminder alarm registry is invalid: $error');
      await prefs.remove(reminderAlarmRegistryKey);
      return {};
    }
  }

  static Future<ReminderAlarmSpec?> loadEntry(int alarmId) async {
    final all = await loadAll(reload: true);
    return all[alarmId];
  }

  static Future<void> upsert(ReminderAlarmSpec spec) async {
    final all = await loadAll()
      ..[spec.alarmId] = spec;
    await _write(all);
  }

  static Future<void> removeByAlarmId(int alarmId) async {
    final all = await loadAll();
    if (all.remove(alarmId) != null) await _write(all);
  }

  static Future<void> removeCourseReminders() async {
    final all = await loadAll()
      ..removeWhere((id, _) => isCourseReminderNotificationId(id));
    await _write(all);
  }

  static Future<int> courseReminderCount() async {
    final all = await loadAll(reload: true);
    return all.keys.where(isCourseReminderNotificationId).length;
  }

  static Future<bool> contains(int alarmId) async {
    final all = await loadAll(reload: true);
    return all.containsKey(alarmId);
  }

  static Future<void> _write(Map<int, ReminderAlarmSpec> all) async {
    final prefs = await SharedPreferences.getInstance();
    if (all.isEmpty) {
      await prefs.remove(reminderAlarmRegistryKey);
      return;
    }
    await prefs.setString(
      reminderAlarmRegistryKey,
      jsonEncode({
        for (final entry in all.entries) '${entry.key}': entry.value,
      }),
    );
  }
}
