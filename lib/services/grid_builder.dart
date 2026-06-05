import 'package:intl/intl.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_models.dart';

class GridBuilder {
  static const weekdayLabels = {
    1: '週一',
    2: '週二',
    3: '週三',
    4: '週四',
    5: '週五',
    6: '週六',
    7: '週日',
  };

  WeekGrid buildWeekGrid({
    required DateTime weekStart,
    required List<CourseSession> sessions,
  }) {
    final normalizedStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEnd = normalizedStart.add(const Duration(days: 6));
    final weekSessions = sessions.where((session) {
      final date = DateTime(session.date.year, session.date.month, session.date.day);
      return !date.isBefore(normalizedStart) && !date.isAfter(weekEnd);
    }).toList();

    final timeLabels = <String>{};
    for (final session in weekSessions) {
      timeLabels.add(_timeLabel(session.startAt));
    }
    final sortedTimeLabels = timeLabels.toList()
      ..sort((a, b) => _compareTimeLabel(a, b));

    final cells = <String, List<CourseSession>>{};
    for (final session in weekSessions) {
      final key = '${session.weekday}|${_timeLabel(session.startAt)}';
      cells.putIfAbsent(key, () => []).add(session);
    }

    return WeekGrid(
      weekStart: normalizedStart,
      timeLabels: sortedTimeLabels,
      cells: cells,
    );
  }

  String formatWeekRange(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    final formatter = DateFormat('M/d');
    return '${formatter.format(weekStart)} - ${formatter.format(end)}';
  }

  String _timeLabel(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  int _compareTimeLabel(String a, String b) {
    final aParts = a.split(':').map(int.parse).toList();
    final bParts = b.split(':').map(int.parse).toList();
    final aMinutes = aParts[0] * 60 + aParts[1];
    final bMinutes = bParts[0] * 60 + bParts[1];
    return aMinutes.compareTo(bMinutes);
  }
}
