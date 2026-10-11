import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/deadline_recurrence.dart';

void main() {
  test('daily interval uses calendar dates and respects count', () {
    final r = DeadlineRecurrence(
      start: DateTime(2026, 1, 30, 23, 59),
      frequency: DeadlineFrequency.daily,
      interval: 2,
      count: 3,
    ).generate();
    expect(r.dates, [
      DateTime(2026, 1, 30, 23, 59),
      DateTime(2026, 2, 1, 23, 59),
      DateTime(2026, 2, 3, 23, 59),
    ]);
  });
  test(
    'weekly multiple weekdays skip dates before start and preserve interval',
    () {
      final r = DeadlineRecurrence(
        start: DateTime(2026, 10, 7, 12),
        frequency: DeadlineFrequency.weekly,
        interval: 2,
        weekdays: {1, 5},
        count: 3,
      ).generate();
      expect(r.dates, [
        DateTime(2026, 10, 9, 12),
        DateTime(2026, 10, 19, 12),
        DateTime(2026, 10, 23, 12),
      ]);
    },
  );
  test('monthly requires explicit missing-month dates and does not drift', () {
    final r = DeadlineRecurrence(
      start: DateTime(2026, 1, 31, 12),
      frequency: DeadlineFrequency.monthly,
      count: 4,
    ).generate();
    expect(r.missingMonths, [DateTime(2026, 2), DateTime(2026, 4)]);
    final resolved = DeadlineRecurrence(
      start: DateTime(2026, 1, 31, 12),
      frequency: DeadlineFrequency.monthly,
      count: 4,
      monthDates: {'2026-02': 20, '2026-04': 30},
    ).generate();
    expect(resolved.missingMonths, isEmpty);
    expect(resolved.dates, [
      DateTime(2026, 1, 31, 12),
      DateTime(2026, 2, 20, 12),
      DateTime(2026, 3, 31, 12),
      DateTime(2026, 4, 30, 12),
    ]);
  });
  test('leap years, inclusive end date and batch limits', () {
    expect(
      DeadlineRecurrence(
        start: DateTime(2028, 1, 29, 9),
        frequency: DeadlineFrequency.monthly,
        until: DateTime(2028, 3, 29),
      ).generate().dates,
      hasLength(3),
    );
    expect(
      () => DeadlineRecurrence(
        start: DateTime(2026),
        frequency: DeadlineFrequency.daily,
        count: 1001,
      ).generate(),
      throwsArgumentError,
    );
    expect(
      () => DeadlineRecurrence(
        start: DateTime(2026),
        frequency: DeadlineFrequency.daily,
        interval: 0,
        count: 3,
      ).generate(),
      throwsArgumentError,
    );
  });
}
