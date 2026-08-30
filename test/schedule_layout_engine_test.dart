import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/schedule_layout.dart';
import 'package:orbit/services/schedule_layout_engine.dart';

CourseSession _session({
  required DateTime date,
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
  String code = 'TEST101',
}) {
  return CourseSession(
    id: '${date.toIso8601String()}|$code|01|$startHour:$startMinute',
    classType: 'class',
    room: 'A101',
    date: date,
    weekday: date.weekday,
    courseName: code,
    courseCode: code,
    section: '01',
    startAt: DateTime(date.year, date.month, date.day, startHour, startMinute),
    endAt: DateTime(date.year, date.month, date.day, endHour, endMinute),
    teachers: const ['Teacher'],
    faculty: 'Faculty',
    semester: '2026',
  );
}

void main() {
  test('宽度切换单日、多日与整周模式', () {
    expect(scheduleViewportModeForWidth(320), ScheduleViewportMode.singleDay);
    expect(scheduleViewportModeForWidth(360), ScheduleViewportMode.multiDay);
    expect(maxMultiDayCountForWidth(360), 3);
    expect(scheduleViewportModeForWidth(840), ScheduleViewportMode.fullWeek);
  });

  test('多日数量受宽度限制但不修改偏好值', () {
    final dates = visibleScheduleDates(
      anchor: DateTime(2026, 8, 24),
      mode: ScheduleViewportMode.multiDay,
      preferredMultiDayCount: 5,
      maxMultiDayCount: 3,
      showEmptyDays: true,
      sessions: const [],
    );
    expect(dates.length, 3);
    expect(dates.last, DateTime(2026, 8, 26));
  });

  test('隐藏无课日期后连续选择有课日期并可跨周', () {
    final sessions = [
      _session(
        date: DateTime(2026, 8, 24),
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      ),
      _session(
        date: DateTime(2026, 8, 28),
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
        code: 'TEST102',
      ),
      _session(
        date: DateTime(2026, 9, 1),
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
        code: 'TEST103',
      ),
    ];
    final dates = visibleScheduleDates(
      anchor: DateTime(2026, 8, 24),
      mode: ScheduleViewportMode.multiDay,
      preferredMultiDayCount: 3,
      maxMultiDayCount: 3,
      showEmptyDays: false,
      sessions: sessions,
    );
    expect(dates, [
      DateTime(2026, 8, 24),
      DateTime(2026, 8, 28),
      DateTime(2026, 9, 1),
    ]);
  });

  test('重叠课程分到不同通道，首尾相接不视为冲突', () {
    final date = DateTime(2026, 8, 24);
    final sessions = [
      _session(
        date: date,
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      ),
      _session(
        date: date,
        startHour: 9,
        startMinute: 30,
        endHour: 10,
        endMinute: 30,
        code: 'TEST102',
      ),
      _session(
        date: date,
        startHour: 10,
        startMinute: 30,
        endHour: 11,
        endMinute: 15,
        code: 'TEST103',
      ),
    ];
    final layout = const ScheduleLayoutEngine().build(
      dates: [date],
      sessions: sessions,
      mode: ScheduleViewportMode.singleDay,
    );
    expect(layout.days.single.events[0].laneCount, 2);
    expect(layout.days.single.events[1].laneCount, 2);
    expect(layout.days.single.events[2].laneCount, 1);
    expect(layout.days.single.events[2].durationMinutes, 45);
  });
}
