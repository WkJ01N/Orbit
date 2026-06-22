import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/reminder_resync_status.dart';

void main() {
  test('reminderResyncBannerKind parses verify, partial, and error', () {
    expect(reminderResyncBannerKind(null), isNull);
    expect(
      reminderResyncBannerKind('verify'),
      ReminderResyncBannerKind.verify,
    );
    expect(
      reminderResyncBannerKind('partial:3'),
      ReminderResyncBannerKind.partial,
    );
    expect(
      reminderResyncBannerKind('SocketException'),
      ReminderResyncBannerKind.error,
    );
  });

  test('reminderPartialFailureCount extracts count from partial errors', () {
    expect(reminderPartialFailureCount(null), isNull);
    expect(reminderPartialFailureCount('verify'), isNull);
    expect(reminderPartialFailureCount('partial:2'), 2);
  });
}
