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

/// Which week the schedule grid opens to when the user has not picked a week.
enum GridDefaultWeekMode { smart, current, earliest }

DateTime? earliestWeekStartFromSessions(List<CourseSession> sessions) {
  if (sessions.isEmpty) {
    return null;
  }
  final earliest = sessions
      .map((session) => session.date)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return weekStartFor(earliest);
}

/// Resolves the week to display based on the user's [mode] preference.
/// Returns null when there are no sessions.
DateTime? resolveDefaultWeekStart(
  List<CourseSession> sessions,
  GridDefaultWeekMode mode,
) {
  if (sessions.isEmpty) {
    return null;
  }
  final thisWeek = weekStartFor(DateTime.now());
  switch (mode) {
    case GridDefaultWeekMode.current:
      return thisWeek;
    case GridDefaultWeekMode.earliest:
      return earliestWeekStartFromSessions(sessions);
    case GridDefaultWeekMode.smart:
      if (weekHasSessions(thisWeek, sessions)) {
        return thisWeek;
      }
      return _nearestWeekWithSessions(sessions, thisWeek) ??
          earliestWeekStartFromSessions(sessions);
  }
}

DateTime? _nearestWeekWithSessions(
  List<CourseSession> sessions,
  DateTime reference,
) {
  final weeks = sessions.map((s) => weekStartFor(s.date)).toSet();
  DateTime? best;
  int? bestDistance;
  for (final week in weeks) {
    final distance = week.difference(reference).inDays.abs();
    // On ties, prefer the upcoming week so users land on classes ahead of them.
    if (bestDistance == null ||
        distance < bestDistance ||
        (distance == bestDistance && week.isAfter(best!))) {
      best = week;
      bestDistance = distance;
    }
  }
  return best;
}
