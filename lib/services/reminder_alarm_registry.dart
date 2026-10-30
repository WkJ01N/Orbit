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
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      // The blob is unreadable. Keep it so the next upsert can still rewrite a
      // healthy map: deleting it here would also erase every payload that the
      // pending AlarmManager entries are waiting for.
      debugPrint('Reminder alarm registry is unreadable: $error');
      return {};
    }
    if (decoded is! Map) {
      debugPrint('Reminder alarm registry has an unexpected shape');
      return {};
    }

    // Decode entry by entry: one damaged record must not silence the rest.
    final specs = <int, ReminderAlarmSpec>{};
    decoded.forEach((key, dynamic value) {
      final alarmId = key is int ? key : int.tryParse('$key');
      if (alarmId == null || value is! Map<String, dynamic>) {
        debugPrint('Dropping malformed reminder entry $key');
        return;
      }
      try {
        specs[alarmId] = ReminderAlarmSpec.fromJson(value);
      } catch (error) {
        debugPrint('Dropping unreadable reminder $alarmId: $error');
      }
    });
    return specs;
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

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(reminderAlarmRegistryKey);
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
