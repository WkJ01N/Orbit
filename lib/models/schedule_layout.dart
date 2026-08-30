import 'package:orbit/models/course_session.dart';

enum ScheduleViewportMode { singleDay, multiDay, fullWeek }

class ScheduleEventLayout {
  const ScheduleEventLayout({
    required this.session,
    required this.startMinute,
    required this.endMinute,
    required this.lane,
    required this.laneCount,
  });

  final CourseSession session;
  final int startMinute;
  final int endMinute;
  final int lane;
  final int laneCount;

  int get durationMinutes => endMinute - startMinute;
}

class ScheduleDayLayout {
  const ScheduleDayLayout({required this.date, required this.events});

  final DateTime date;
  final List<ScheduleEventLayout> events;
}

class ScheduleTimelineLayout {
  const ScheduleTimelineLayout({
    required this.mode,
    required this.days,
    required this.startMinute,
    required this.endMinute,
  });

  final ScheduleViewportMode mode;
  final List<ScheduleDayLayout> days;
  final int startMinute;
  final int endMinute;
}
