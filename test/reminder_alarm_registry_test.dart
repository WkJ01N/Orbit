import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/reminder_alarm_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReminderAlarmSpec _spec(int alarmId) {
  return ReminderAlarmSpec(
    alarmId: alarmId,
    notificationId: alarmId,
    title: 'Physical $alarmId',
    body: 'Room A101',
    payload: 'session-$alarmId',
    fireAt: DateTime(2026, 6, 15, 6, 30),
  );
}

void _store(Map<String, Object?> entries) {
  SharedPreferences.setMockInitialValues({
    reminderAlarmRegistryKey: jsonEncode(entries),
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads every well formed entry', () async {
    _store({
      '1': _spec(1).toJson(),
      '2000000': _spec(2000000).toJson(),
    });

    final all = await ReminderAlarmRegistry.loadAll();

    expect(all.keys, unorderedEquals([1, 2000000]));
    expect(all[1]?.title, 'Physical 1');
  });

  test('one damaged entry does not discard the healthy ones', () async {
    _store({
      '1': _spec(1).toJson(),
      '2': <String, Object?>{'alarmId': 2, 'title': 'missing fields'},
      'not-a-number': _spec(3).toJson(),
      '2000000': _spec(2000000).toJson(),
    });

    final all = await ReminderAlarmRegistry.loadAll();

    expect(all.keys, unorderedEquals([1, 2000000]));
  });

  test('an unreadable blob keeps the stored value', () async {
    SharedPreferences.setMockInitialValues({
      reminderAlarmRegistryKey: '{"1": {"alarmId"',
    });

    expect(await ReminderAlarmRegistry.loadAll(), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(reminderAlarmRegistryKey), isNotNull);
  });

  test('upsert repairs a previously unreadable blob', () async {
    SharedPreferences.setMockInitialValues({
      reminderAlarmRegistryKey: 'not json at all',
    });

    await ReminderAlarmRegistry.upsert(_spec(7));

    final all = await ReminderAlarmRegistry.loadAll();
    expect(all.keys, [7]);
    expect(all[7]?.alarmId, 7);
  });

  test('upsert and remove keep the other entries intact', () async {
    await ReminderAlarmRegistry.upsert(_spec(1));
    await ReminderAlarmRegistry.upsert(_spec(2000000));
    await ReminderAlarmRegistry.removeByAlarmId(1);

    final all = await ReminderAlarmRegistry.loadAll();

    expect(all.keys, [2000000]);
  });
}