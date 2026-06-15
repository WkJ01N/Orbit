import 'dart:convert';

import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:shared_preferences/shared_preferences.dart';

const reminderAlarmRegistryKey = 'orbit_reminder_alarm_registry_v1';

/// Persists alarm payloads so background isolates can show notifications
/// without the UI process.
class ReminderAlarmRegistry {
  ReminderAlarmRegistry._();

  static Future<Map<int, ReminderAlarmSpec>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(reminderAlarmRegistryKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        int.parse(key),
        ReminderAlarmSpec.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  static Future<ReminderAlarmSpec?> loadEntry(int alarmId) async {
    final all = await loadAll();
    return all[alarmId];
  }

  static Future<void> saveBatch(List<ReminderAlarmSpec> specs) async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      for (final spec in specs) '${spec.alarmId}': spec.toJson(),
    };
    await prefs.setString(reminderAlarmRegistryKey, jsonEncode(map));
  }

  static Future<void> upsert(ReminderAlarmSpec spec) async {
    final all = await loadAll();
    all[spec.alarmId] = spec;
    await saveBatch(all.values.toList());
  }

  static Future<void> removeByAlarmId(int alarmId) async {
    final all = await loadAll();
    if (all.remove(alarmId) == null) {
      return;
    }
    await _writeMap(all);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(reminderAlarmRegistryKey);
  }

  static Future<int> count() async {
    final all = await loadAll();
    return all.length;
  }

  static Future<void> _writeMap(Map<int, ReminderAlarmSpec> all) async {
    final prefs = await SharedPreferences.getInstance();
    if (all.isEmpty) {
      await prefs.remove(reminderAlarmRegistryKey);
      return;
    }
    final map = {
      for (final entry in all.entries) '${entry.key}': entry.value.toJson(),
    };
    await prefs.setString(reminderAlarmRegistryKey, jsonEncode(map));
  }
}
