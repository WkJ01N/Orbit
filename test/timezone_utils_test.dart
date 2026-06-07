import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('configureReminderTimezone does not throw', () {
    expect(configureReminderTimezone, returnsNormally);
    expect(tz.local, isNotNull);
  });
}
