import 'package:orbit/models/course_session.dart';

class GridCell {
  const GridCell({
    required this.weekday,
    required this.timeLabel,
    required this.sessions,
  });

  final int weekday;
  final String timeLabel;
  final List<CourseSession> sessions;
}

class WeekGrid {
  const WeekGrid({
    required this.weekStart,
    required this.timeLabels,
    required this.cells,
  });

  final DateTime weekStart;
  final List<String> timeLabels;
  final Map<String, List<CourseSession>> cells;

  List<CourseSession> sessionsFor(int weekday, String timeLabel) {
    return cells['$weekday|$timeLabel'] ?? const [];
  }
}
