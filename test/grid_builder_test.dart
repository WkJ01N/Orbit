import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/grid_builder.dart';

CourseSession _session({
  required DateTime date,
  required int weekday,
  required int startHour,
  int startMinute = 0,
  int endHour = 10,
  String courseCode = 'PHYS102',
}) {
  final startAt = DateTime(date.year, date.month, date.day, startHour, startMinute);
  final endAt = DateTime(date.year, date.month, date.day, endHour, startMinute);
  return CourseSession(
    id: '${date.toIso8601String()}|$courseCode|EX1|$startHour:$startMinute',
    classType: '一般課堂',
    room: 'C508',
    date: date,
    weekday: weekday,
    courseName: '物理II',
    courseCode: courseCode,
    section: 'EX1',
    startAt: startAt,
    endAt: endAt,
    teachers: const ['Teacher'],
    faculty: 'FIE',
    semester: '2602',
  );
}

void main() {
  late GridBuilder builder;

  setUp(() {
    builder = GridBuilder();
  });

  test('buildWeekGrid 按星期與時間分組課程', () {
    final weekStart = DateTime(2026, 6, 1);
    final sessions = [
      _session(date: DateTime(2026, 6, 2), weekday: 2, startHour: 9),
      _session(date: DateTime(2026, 6, 2), weekday: 2, startHour: 14),
      _session(date: DateTime(2026, 6, 3), weekday: 3, startHour: 9),
    ];

    final grid = builder.buildWeekGrid(weekStart: weekStart, sessions: sessions);

    expect(grid.weekStart, DateTime(2026, 6, 1));
    expect(grid.timeLabels, ['09:00', '14:00']);
    expect(grid.cells['2|09:00']!.length, 1);
    expect(grid.cells['2|14:00']!.length, 1);
    expect(grid.cells['3|09:00']!.length, 1);
  });

  test('buildWeekGrid 包含週日課程', () {
    final weekStart = DateTime(2026, 6, 1);
    final sundaySession = _session(
      date: DateTime(2026, 6, 7),
      weekday: 7,
      startHour: 10,
    );

    final grid = builder.buildWeekGrid(
      weekStart: weekStart,
      sessions: [sundaySession],
    );

    expect(grid.cells['7|10:00'], isNotNull);
    expect(grid.sessionsFor(7, '10:00').first.courseCode, 'PHYS102');
  });

  test('buildWeekGrid 忽略週外課程', () {
    final weekStart = DateTime(2026, 6, 1);
    final outside = _session(
      date: DateTime(2026, 6, 8),
      weekday: 1,
      startHour: 9,
    );

    final grid = builder.buildWeekGrid(
      weekStart: weekStart,
      sessions: [outside],
    );

    expect(grid.timeLabels, isEmpty);
    expect(grid.cells, isEmpty);
  });
}
