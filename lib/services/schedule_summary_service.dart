import 'package:orbit/models/course_session.dart';

class DayScheduleSummary {
  const DayScheduleSummary({
    required this.date,
    required this.sessionCount,
    this.firstSessionStart,
    this.firstCourseName,
  });

  final DateTime date;
  final int sessionCount;
  final DateTime? firstSessionStart;
  final String? firstCourseName;

  bool get hasClasses => sessionCount > 0;
}

String sessionDateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

Map<String, List<CourseSession>> groupSessionsByDate(
  List<CourseSession> sessions,
) {
  final grouped = <String, List<CourseSession>>{};
  for (final session in sessions) {
    final key = sessionDateKey(session.date);
    grouped.putIfAbsent(key, () => []).add(session);
  }
  for (final daySessions in grouped.values) {
    daySessions.sort((a, b) => a.startAt.compareTo(b.startAt));
  }
  return grouped;
}

DayScheduleSummary summarizeDayFromGrouped(
  Map<String, List<CourseSession>> sessionsByDate,
  DateTime day,
) {
  final normalized = DateTime(day.year, day.month, day.day);
  final daySessions = sessionsByDate[sessionDateKey(normalized)] ?? const [];

  if (daySessions.isEmpty) {
    return DayScheduleSummary(date: normalized, sessionCount: 0);
  }

  final first = daySessions.first;
  return DayScheduleSummary(
    date: normalized,
    sessionCount: daySessions.length,
    firstSessionStart: first.startAt,
    firstCourseName: first.courseName,
  );
}

/// 按日期聚合课表，用于次日确认通知与一键闹钟。
DayScheduleSummary summarizeDay(
  List<CourseSession> sessions,
  DateTime day,
) {
  final normalized = DateTime(day.year, day.month, day.day);
  final daySessions = sessions.where((session) {
    final sessionDate = DateTime(
      session.date.year,
      session.date.month,
      session.date.day,
    );
    return sessionDate == normalized;
  }).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));

  if (daySessions.isEmpty) {
    return DayScheduleSummary(date: normalized, sessionCount: 0);
  }

  final first = daySessions.first;
  return DayScheduleSummary(
    date: normalized,
    sessionCount: daySessions.length,
    firstSessionStart: first.startAt,
    firstCourseName: first.courseName,
  );
}

List<DayScheduleSummary> summarizeUpcomingDays(
  List<CourseSession> sessions, {
  int days = 30,
  DateTime? from,
}) {
  final start = from ?? DateTime.now();
  final base = DateTime(start.year, start.month, start.day);
  return [
    for (var i = 0; i < days; i++)
      summarizeDay(sessions, base.add(Duration(days: i))),
  ];
}

String formatTimeOfDay(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
