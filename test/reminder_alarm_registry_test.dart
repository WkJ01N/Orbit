import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/reminder_alarm_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveBatch and loadAll round-trip', () async {
    final fireAt = DateTime(2026, 6, 15, 10, 0);
    final specs = [
      ReminderAlarmSpec(
        alarmId: 1,
        notificationId: 1,
        title: 'Class soon',
        body: 'Physics · A101',
        payload: 'session-1',
        fireAt: fireAt,
        bigText: 'Physics at 10:00',
      ),
      ReminderAlarmSpec(
        alarmId: 500001,
        notificationId: 500001,
        title: 'Check in',
        body: 'Physics',
        payload: 'checkin_session-1',
        fireAt: fireAt.add(const Duration(minutes: 15)),
      ),
    ];

    await ReminderAlarmRegistry.saveBatch(specs);
    final loaded = await ReminderAlarmRegistry.loadAll();

    expect(loaded.length, 2);
    expect(loaded[1]?.title, 'Class soon');
    expect(loaded[500001]?.payload, 'checkin_session-1');
  });

  test('removeByAlarmId deletes one entry', () async {
    await ReminderAlarmRegistry.saveBatch([
      ReminderAlarmSpec(
        alarmId: 2,
        notificationId: 2,
        title: 'A',
        body: 'B',
        payload: 'p',
        fireAt: DateTime(2026, 6, 15, 11, 0),
      ),
    ]);

    await ReminderAlarmRegistry.removeByAlarmId(2);
    expect(await ReminderAlarmRegistry.count(), 0);
  });

  test('clearAll removes registry', () async {
    await ReminderAlarmRegistry.saveBatch([
      ReminderAlarmSpec(
        alarmId: 3,
        notificationId: 3,
        title: 'A',
        body: 'B',
        payload: 'p',
        fireAt: DateTime(2026, 6, 15, 12, 0),
      ),
    ]);

    await ReminderAlarmRegistry.clearAll();
    expect(await ReminderAlarmRegistry.count(), 0);
  });
}
