import 'package:orbit/models/course_session.dart';

DateTime weekStartFor(DateTime date, {int startWeekday = DateTime.monday}) {
  final normalized = DateTime(date.year, date.month, date.day);
  final delta = (normalized.weekday - startWeekday + 7) % 7;
  return normalized.subtract(Duration(days: delta));
}

/// Returns weekdays 1–7 ordered from [startWeekday].
List<int> orderedWeekdays({int startWeekday = DateTime.monday}) {
  return [for (var i = 0; i < 7; i++) ((startWeekday - 1 + i) % 7) + 1];
}

class BatchDeleteRange {
  const BatchDeleteRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

DateTime weekEndDate(DateTime weekStart, {int startWeekday = DateTime.monday}) {
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

List<DateTime> weeksOverlappingMonth(
  int year,
  int month, {
  int startWeekday = DateTime.monday,
}) {
  final monthStart = DateTime(year, month, 1);
  final monthEnd = DateTime(year, month + 1, 0);
  var weekStart = weekStartFor(monthStart, startWeekday: startWeekday);
  if (weekEndDate(weekStart, startWeekday: startWeekday).isBefore(monthStart)) {
    weekStart = weekStart.add(const Duration(days: 7));
  }

  final weeks = <DateTime>[];
  while (!weekStart.isAfter(monthEnd)) {
    if (!weekEndDate(
      weekStart,
      startWeekday: startWeekday,
    ).isBefore(monthStart)) {
      weeks.add(weekStart);
    }
    weekStart = weekStart.add(const Duration(days: 7));
  }
  return weeks;
}

bool weekHasSessions(
  DateTime weekStart,
  List<CourseSession> sessions, {
  int startWeekday = DateTime.monday,
}) {
  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final end = weekEndDate(weekStart, startWeekday: startWeekday);
  for (final session in sessions) {
    final date = DateTime(
      session.date.year,
      session.date.month,
      session.date.day,
    );
    if (!date.isBefore(start) && !date.isAfter(end)) {
      return true;
    }
  }
  return false;
}

/// Which week the schedule grid opens to when the user has not picked a week.
enum GridDefaultWeekMode { smart, current, earliest }

DateTime? earliestWeekStartFromSessions(
  List<CourseSession> sessions, {
  int startWeekday = DateTime.monday,
}) {
  if (sessions.isEmpty) {
    return null;
  }
  final earliest = sessions
      .map((session) => session.date)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return weekStartFor(earliest, startWeekday: startWeekday);
}

/// Resolves the week to display based on the user's [mode] preference.
/// Returns null when there are no sessions.
DateTime? resolveDefaultWeekStart(
  List<CourseSession> sessions,
  GridDefaultWeekMode mode, {
  int startWeekday = DateTime.monday,
}) {
  if (sessions.isEmpty) {
    return null;
  }
  final thisWeek = weekStartFor(DateTime.now(), startWeekday: startWeekday);
  switch (mode) {
    case GridDefaultWeekMode.current:
      return thisWeek;
    case GridDefaultWeekMode.earliest:
      return earliestWeekStartFromSessions(
        sessions,
        startWeekday: startWeekday,
      );
    case GridDefaultWeekMode.smart:
      if (weekHasSessions(thisWeek, sessions, startWeekday: startWeekday)) {
        return thisWeek;
      }
      return _nearestWeekWithSessions(sessions, thisWeek, startWeekday) ??
          earliestWeekStartFromSessions(sessions, startWeekday: startWeekday);
  }
}

DateTime? _nearestWeekWithSessions(
  List<CourseSession> sessions,
  DateTime reference,
  int startWeekday,
) {
  final weeks = sessions
      .map((s) => weekStartFor(s.date, startWeekday: startWeekday))
      .toSet();
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
