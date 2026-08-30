import 'dart:math' as math;

import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/schedule_layout.dart';

const double kScheduleTimeRailWidth = 54;
const double kScheduleSingleDayBreakpoint = 360;
const double kScheduleFullWeekBreakpoint = 840;
const double kScheduleMinimumDayWidth = 96;

ScheduleViewportMode scheduleViewportModeForWidth(double width) {
  if (width < kScheduleSingleDayBreakpoint) {
    return ScheduleViewportMode.singleDay;
  }
  if (width >= kScheduleFullWeekBreakpoint) {
    return ScheduleViewportMode.fullWeek;
  }
  return ScheduleViewportMode.multiDay;
}

int maxMultiDayCountForWidth(double width) {
  if (width < kScheduleSingleDayBreakpoint) {
    return 1;
  }
  final available = math.max(0, width - kScheduleTimeRailWidth);
  return (available / kScheduleMinimumDayWidth).floor().clamp(1, 6);
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSameScheduleDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<DateTime> courseDates(List<CourseSession> sessions) {
  final dates =
      sessions.map((session) => dateOnly(session.date)).toSet().toList()
        ..sort();
  return dates;
}

DateTime nearestCourseDate(DateTime anchor, List<CourseSession> sessions) {
  final dates = courseDates(sessions);
  if (dates.isEmpty) {
    return dateOnly(anchor);
  }
  final normalized = dateOnly(anchor);
  return dates.reduce((a, b) {
    final aDistance = a.difference(normalized).inDays.abs();
    final bDistance = b.difference(normalized).inDays.abs();
    if (aDistance == bDistance) {
      return b.isAfter(a) ? b : a;
    }
    return aDistance < bDistance ? a : b;
  });
}

List<DateTime> visibleScheduleDates({
  required DateTime anchor,
  required ScheduleViewportMode mode,
  required int preferredMultiDayCount,
  required int maxMultiDayCount,
  required bool showEmptyDays,
  required List<CourseSession> sessions,
  int weekStartDay = DateTime.monday,
}) {
  final normalizedAnchor = dateOnly(anchor);
  if (mode == ScheduleViewportMode.fullWeek) {
    final start = weekStartFor(normalizedAnchor, startWeekday: weekStartDay);
    final dates = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    if (showEmptyDays) {
      return dates;
    }
    final available = courseDates(sessions).toSet();
    return dates.where(available.contains).toList();
  }

  final count = mode == ScheduleViewportMode.singleDay
      ? 1
      : preferredMultiDayCount.clamp(1, maxMultiDayCount);
  if (showEmptyDays) {
    return [
      for (var i = 0; i < count; i++) normalizedAnchor.add(Duration(days: i)),
    ];
  }

  final dates = courseDates(sessions);
  if (dates.isEmpty) {
    return const [];
  }
  var startIndex = dates.indexWhere((date) => !date.isBefore(normalizedAnchor));
  if (startIndex < 0) {
    startIndex = math.max(0, dates.length - count);
  }
  return dates.skip(startIndex).take(count).toList();
}

DateTime navigateScheduleAnchor({
  required DateTime anchor,
  required int direction,
  required ScheduleViewportMode mode,
  required int visibleDayCount,
  required bool showEmptyDays,
  required List<CourseSession> sessions,
  int weekStartDay = DateTime.monday,
}) {
  final normalized = dateOnly(anchor);
  if (mode == ScheduleViewportMode.fullWeek) {
    return normalized.add(Duration(days: direction * 7));
  }
  if (showEmptyDays) {
    final step = mode == ScheduleViewportMode.singleDay
        ? 1
        : math.max(1, visibleDayCount);
    return normalized.add(Duration(days: direction * step));
  }

  final dates = courseDates(sessions);
  if (dates.isEmpty) {
    return normalized;
  }
  final currentIndex = direction > 0
      ? dates.indexWhere((date) => date.isAfter(normalized))
      : dates.lastIndexWhere((date) => date.isBefore(normalized));
  if (currentIndex < 0) {
    return normalized;
  }
  if (mode == ScheduleViewportMode.singleDay) {
    return dates[currentIndex];
  }
  final step = math.max(1, visibleDayCount);
  final target = (currentIndex + (direction > 0 ? step - 1 : -(step - 1)))
      .clamp(0, dates.length - 1);
  return dates[target];
}

class ScheduleLayoutEngine {
  const ScheduleLayoutEngine();

  ScheduleTimelineLayout build({
    required List<DateTime> dates,
    required List<CourseSession> sessions,
    required ScheduleViewportMode mode,
  }) {
    final normalizedDates = dates.map(dateOnly).toList();
    final dateSet = normalizedDates.toSet();
    final visibleSessions = sessions.where(
      (session) => dateSet.contains(dateOnly(session.date)),
    );
    final byDate = <DateTime, List<CourseSession>>{};
    for (final session in visibleSessions) {
      byDate.putIfAbsent(dateOnly(session.date), () => []).add(session);
    }

    final days = <ScheduleDayLayout>[];
    var earliest = 8 * 60;
    var latest = 18 * 60;
    var hasEvents = false;
    for (final date in normalizedDates) {
      final daySessions = byDate[date] ?? const <CourseSession>[];
      if (daySessions.isNotEmpty) {
        hasEvents = true;
        earliest = math.min(
          earliest,
          daySessions.map(_startMinute).reduce(math.min),
        );
        latest = math.max(latest, daySessions.map(_endMinute).reduce(math.max));
      }
      days.add(ScheduleDayLayout(date: date, events: _layoutDay(daySessions)));
    }

    if (hasEvents) {
      earliest = math.max(0, (earliest ~/ 60) * 60);
      latest = math.min(24 * 60, ((latest + 59) ~/ 60) * 60);
    }
    return ScheduleTimelineLayout(
      mode: mode,
      days: days,
      startMinute: earliest,
      endMinute: latest,
    );
  }

  List<ScheduleEventLayout> _layoutDay(List<CourseSession> sessions) {
    final sorted = [...sessions]
      ..sort((a, b) {
        final byStart = a.startAt.compareTo(b.startAt);
        return byStart != 0 ? byStart : b.endAt.compareTo(a.endAt);
      });
    final result = <ScheduleEventLayout>[];
    var groupStart = 0;
    while (groupStart < sorted.length) {
      var groupEnd = groupStart + 1;
      var latestEnd = _endMinute(sorted[groupStart]);
      while (groupEnd < sorted.length &&
          _startMinute(sorted[groupEnd]) < latestEnd) {
        latestEnd = math.max(latestEnd, _endMinute(sorted[groupEnd]));
        groupEnd++;
      }

      final laneEnds = <int>[];
      final assignments = <int>[];
      for (var i = groupStart; i < groupEnd; i++) {
        final start = _startMinute(sorted[i]);
        var lane = laneEnds.indexWhere((end) => end <= start);
        if (lane < 0) {
          lane = laneEnds.length;
          laneEnds.add(_endMinute(sorted[i]));
        } else {
          laneEnds[lane] = _endMinute(sorted[i]);
        }
        assignments.add(lane);
      }
      final laneCount = laneEnds.length;
      for (var i = groupStart; i < groupEnd; i++) {
        result.add(
          ScheduleEventLayout(
            session: sorted[i],
            startMinute: _startMinute(sorted[i]),
            endMinute: math.max(
              _startMinute(sorted[i]) + 1,
              _endMinute(sorted[i]),
            ),
            lane: assignments[i - groupStart],
            laneCount: laneCount,
          ),
        );
      }
      groupStart = groupEnd;
    }
    return result;
  }
}

int _startMinute(CourseSession session) =>
    session.startAt.hour * 60 + session.startAt.minute;

int _endMinute(CourseSession session) =>
    session.endAt.hour * 60 + session.endAt.minute;
