enum DeadlineFrequency { daily, weekly, monthly }

class DeadlineRecurrenceResult {
  const DeadlineRecurrenceResult(this.dates, this.missingMonths);
  final List<DateTime> dates;
  final List<DateTime> missingMonths;
}

class DeadlineRecurrence {
  const DeadlineRecurrence({
    required this.start,
    required this.frequency,
    this.interval = 1,
    this.weekdays = const {},
    this.count,
    this.until,
    this.monthDates = const {},
  });
  final DateTime start;
  final DeadlineFrequency frequency;
  final int interval;
  final Set<int> weekdays;
  final int? count;
  final DateTime? until;
  final Map<String, int> monthDates;
  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  DeadlineRecurrenceResult generate() {
    if (interval < 1 ||
        interval > 365 ||
        (count == null && until == null) ||
        (count != null && (count! < 1 || count! > 1000)) ||
        (until != null &&
            until!.isBefore(DateTime(start.year, start.month, start.day)))) {
      throw ArgumentError('Invalid recurrence');
    }
    final dates = <DateTime>[], missing = <DateTime>[];
    final end = until == null
        ? null
        : DateTime(until!.year, until!.month, until!.day, 23, 59, 59);
    var occurrences = 0;
    bool add(DateTime value) {
      if (value.isBefore(start)) return false;
      if (end != null && value.isAfter(end)) return true;
      dates.add(value);
      occurrences++;
      if (occurrences > 1000) {
        throw ArgumentError('At most 1000 tasks per batch');
      }
      return count != null && occurrences >= count!;
    }

    if (frequency == DeadlineFrequency.daily) {
      for (var n = 0; ; n++) {
        if (add(
          DateTime(
            start.year,
            start.month,
            start.day + n * interval,
            start.hour,
            start.minute,
          ),
        )) {
          break;
        }
      }
    } else if (frequency == DeadlineFrequency.weekly) {
      final days = (weekdays.isEmpty ? {start.weekday} : weekdays).toList()
        ..sort();
      if (days.any((d) => d < 1 || d > 7)) {
        throw ArgumentError('Invalid weekday');
      }
      final monday = DateTime(
        start.year,
        start.month,
        start.day - start.weekday + 1,
      );
      var finished = false;
      for (var week = 0; !finished; week += interval) {
        for (final day in days) {
          if (add(
            DateTime(
              monday.year,
              monday.month,
              monday.day + week * 7 + day - 1,
              start.hour,
              start.minute,
            ),
          )) {
            finished = true;
            break;
          }
        }
      }
    } else {
      for (var n = 0; ; n++) {
        final month = DateTime(start.year, start.month + n * interval);
        if (end != null && month.isAfter(end)) break;
        final last = DateTime(month.year, month.month + 1, 0).day;
        final override = monthDates[monthKey(month)];
        if (override != null && (override < 1 || override > last)) {
          throw ArgumentError('Invalid month date');
        }
        final day = override ?? start.day;
        if (day > last) {
          missing.add(month);
          occurrences++;
          if (occurrences > 1000) {
            throw ArgumentError('At most 1000 tasks per batch');
          }
          if (count != null && occurrences >= count!) break;
        } else if (add(
          DateTime(month.year, month.month, day, start.hour, start.minute),
        )) {
          break;
        }
      }
    }
    return DeadlineRecurrenceResult(dates, missing);
  }
}
