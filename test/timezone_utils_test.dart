import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('configureReminderTimezone does not throw', () async {
    await expectLater(configureReminderTimezone(), completes);
    expect(tz.local, isNotNull);
  });

  test('reminderAtToTzDateTime matches wall clock fields', () {
    final when = reminderAtToTzDateTime(DateTime(2026, 1, 2, 8, 15));
    expect(when.hour, 8);
    expect(when.minute, 15);
  });
}
