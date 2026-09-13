import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/schedule_display_settings.dart';
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
  test('narrow defaults to compact week and adaptive restores 1.3.2 modes', () {
    expect(scheduleViewportModeForWidth(320), ScheduleViewportMode.compactWeek);
    expect(scheduleViewportModeForWidth(360), ScheduleViewportMode.compactWeek);
    expect(scheduleViewportModeForWidth(839), ScheduleViewportMode.compactWeek);
    expect(
      scheduleViewportModeForWidth(
        320,
        narrowLayout: NarrowScheduleLayout.adaptive,
      ),
      ScheduleViewportMode.singleDay,
    );
    expect(
      scheduleViewportModeForWidth(
        360,
        narrowLayout: NarrowScheduleLayout.adaptive,
      ),
      ScheduleViewportMode.multiDay,
    );
    expect(maxMultiDayCountForWidth(360), 3);
    expect(scheduleViewportModeForWidth(840), ScheduleViewportMode.fullWeek);
  });

  test('compact week always returns all seven days', () {
    final dates = visibleScheduleDates(
      anchor: DateTime(2026, 8, 24),
      mode: ScheduleViewportMode.compactWeek,
      preferredMultiDayCount: 5,
      maxMultiDayCount: 3,
      showEmptyDays: true,
      sessions: const [],
    );
    expect(dates.length, 7);
    expect(dates.last, DateTime(2026, 8, 30));
  });

  test('adaptive mode skips empty dates with the 1.3.2 behavior', () {
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
      preferredMultiDayCount: 2,
      maxMultiDayCount: 3,
      showEmptyDays: false,
      sessions: sessions,
    );
    expect(dates, [DateTime(2026, 8, 24), DateTime(2026, 8, 28)]);
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
      mode: ScheduleViewportMode.compactWeek,
    );
    expect(layout.days.single.events[0].laneCount, 2);
    expect(layout.days.single.events[1].laneCount, 2);
    expect(layout.days.single.events[2].laneCount, 1);
    expect(layout.days.single.events[2].durationMinutes, 45);
  });
}
