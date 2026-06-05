import 'package:orbit/models/course_session.dart';

DateTime weekStartFor(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final delta = normalized.weekday - DateTime.monday;
  return normalized.subtract(Duration(days: delta));
}

class BatchDeleteRange {
  const BatchDeleteRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

DateTime weekEndDate(DateTime weekStart) {
  final normalized = DateTime(weekStart.year, weekStart.month, weekStart.day);
  return normalized.add(const Duration(days: 6));
}

BatchDeleteRange defaultBatchDeleteRange(DateTime displayedWeekStart) {
  final start = DateTime(
    displayedWeekStart.year,
    displayedWeekStart.month,
    displayedWeekStart.day,
  );
  final endDay = weekEndDate(displayedWeekStart);
  final end = DateTime(endDay.year, endDay.month, endDay.day, 23, 59);
  return BatchDeleteRange(start: start, end: end);
}

List<DateTime> weeksOverlappingMonth(int year, int month) {
  final monthStart = DateTime(year, month, 1);
  final monthEnd = DateTime(year, month + 1, 0);
  var weekStart = weekStartFor(monthStart);
  if (weekEndDate(weekStart).isBefore(monthStart)) {
    weekStart = weekStart.add(const Duration(days: 7));
  }

  final weeks = <DateTime>[];
  while (!weekStart.isAfter(monthEnd)) {
    if (!weekEndDate(weekStart).isBefore(monthStart)) {
      weeks.add(weekStart);
    }
    weekStart = weekStart.add(const Duration(days: 7));
  }
  return weeks;
}

bool weekHasSessions(DateTime weekStart, List<CourseSession> sessions) {
  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final end = weekEndDate(weekStart);
  for (final session in sessions) {
    final date = DateTime(session.date.year, session.date.month, session.date.day);
    if (!date.isBefore(start) && !date.isAfter(end)) {
      return true;
    }
  }
  return false;
}
