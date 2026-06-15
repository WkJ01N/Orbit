import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/session/current_time_indicator.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/grid_builder.dart';

CourseSession _session({
  required DateTime date,
  required int weekday,
  required int startHour,
  required int endHour,
  int startMinute = 0,
  int endMinute = 0,
}) {
  final startAt = DateTime(date.year, date.month, date.day, startHour, startMinute);
  final endAt = DateTime(date.year, date.month, date.day, endHour, endMinute);
  return CourseSession(
    id: '${date.toIso8601String()}|C|1|$startHour:$startMinute',
    classType: '一般課堂',
    room: 'C508',
    date: date,
    weekday: weekday,
    courseName: '物理II',
    courseCode: 'PHYS102',
    section: '1',
    startAt: startAt,
    endAt: endAt,
    teachers: const ['Teacher'],
    faculty: 'FIE',
    semester: '2602',
  );
}

void main() {
  const rowHeight = 64.0;
  // 2026-06-01 is a Monday.
  final weekStart = DateTime(2026, 6, 1);
  final grid = GridBuilder().buildWeekGrid(
    weekStart: weekStart,
    sessions: [
      // Slots at 09:00 (ends 10:30) and 11:00 (ends 12:00) on Monday.
      _session(date: weekStart, weekday: 1, startHour: 9, endHour: 10, endMinute: 30),
      _session(date: weekStart, weekday: 1, startHour: 11, endHour: 12),
    ],
  );

  double? offsetAt(
    DateTime now, {
    bool isCurrentWeek = true,
    List<int>? visibleWeekdays,
  }) {
    return currentTimeLineOffset(
      grid: grid,
      isCurrentWeek: isCurrentWeek,
      now: now,
      rowHeight: rowHeight,
      headerHeight: 0,
      visibleWeekdays: visibleWeekdays,
    );
  }

  test('hidden before the first slot', () {
    expect(offsetAt(DateTime(2026, 6, 1, 8, 30)), isNull);
  });

  test('hidden at or after the latest class end', () {
    expect(offsetAt(DateTime(2026, 6, 1, 12, 0)), isNull);
    expect(offsetAt(DateTime(2026, 6, 1, 13, 0)), isNull);
  });

  test('hidden when not the current week', () {
    expect(
      offsetAt(DateTime(2026, 6, 1, 9, 30), isCurrentWeek: false),
      isNull,
    );
  });

  test('hidden when today is outside the displayed week', () {
    // 2026-06-10 is outside the week starting 2026-06-01.
    expect(offsetAt(DateTime(2026, 6, 10, 9, 30)), isNull);
  });

  test('hidden when visible weekday does not include today', () {
    // Grid only has Monday; today is Wednesday.
    expect(
      offsetAt(
        DateTime(2026, 6, 3, 10, 0),
        visibleWeekdays: const [DateTime.monday],
      ),
      isNull,
    );
  });

  test('shown when visible weekday includes today', () {
    expect(
      offsetAt(
        DateTime(2026, 6, 1, 10, 0),
        visibleWeekdays: const [DateTime.monday],
      ),
      closeTo(32.0, 0.01),
    );
  });

  test('positions proportionally within the first row', () {
    // 09:00 slot spans to the next slot at 11:00 (120 minutes). At 10:00 the
    // line is halfway: row index 0, ratio 0.5 -> 32px.
    final offset = offsetAt(DateTime(2026, 6, 1, 10, 0));
    expect(offset, closeTo(32.0, 0.01));
  });

  test('positions within the last row using the class end as boundary', () {
    // Last row (index 1) spans 11:00..12:00 (60 minutes). At 11:30 ratio 0.5
    // -> 64 (row offset) + 32 = 96px.
    final offset = offsetAt(DateTime(2026, 6, 1, 11, 30));
    expect(offset, closeTo(96.0, 0.01));
  });

  test('at the exact first slot start the line is at the top', () {
    expect(offsetAt(DateTime(2026, 6, 1, 9, 0)), closeTo(0.0, 0.01));
  });
}
