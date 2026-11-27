import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/services/calendar_export_service.dart';

CourseSession _session({
  String id = 'course-1',
  String courseName = '高等数学',
  String section = 'A',
  String room = '一教 301',
  List<String> teachers = const ['张老师'],
  DateTime? startAt,
  DateTime? endAt,
  String? note,
  DateTime? deletedAt,
}) {
  final start = startAt ?? DateTime(2026, 3, 2, 9);
  return CourseSession(
    id: id,
    classType: '理论',
    room: room,
    date: start,
    weekday: start.weekday,
    courseName: courseName,
    courseCode: 'MATH101',
    section: section,
    startAt: start,
    endAt: endAt ?? start.add(const Duration(minutes: 90)),
    teachers: teachers,
    faculty: '理学院',
    semester: '2025-2026 春',
    note: note,
    deletedAt: deletedAt,
  );
}

void main() {
  const service = CalendarExportService();

  test('writes a single calendar with one event per session', () {
    final ics = service.build([
      _session(),
      _session(id: 'course-2', courseName: '线性代数'),
    ], stamp: DateTime.utc(2026, 3, 1, 12, 30, 45));

    expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
    expect(ics, endsWith('END:VCALENDAR\r\n'));
    expect('BEGIN:VEVENT'.allMatches(ics), hasLength(2));
    expect(ics, contains('DTSTAMP:20260301T123045Z\r\n'));
    expect(ics, contains('UID:course-1@orbit\r\n'));
    expect(ics, contains('UID:course-2@orbit\r\n'));
  });

  test('every line break is CRLF as the format requires', () {
    final ics = service.build([_session()]);
    final withoutFolds = ics.replaceAll('\r\n ', '').replaceAll('\r\n\t', '');
    expect(withoutFolds.replaceAll('\r\n', '').contains('\n'), isFalse);
    expect(ics.split('\r\n').every((line) => !line.contains('\r')), isTrue);
  });

  test('writes times in UTC so no time zone block is needed', () {
    final start = DateTime(2026, 3, 2, 9);
    final ics = service.build([_session(startAt: start)]);

    final utc = start.toUtc();
    final expected =
        '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}'
        'T${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}Z';
    expect(ics, contains('DTSTART:$expected\r\n'));
    expect(ics, isNot(contains('TZID')));
  });

  test('escapes separators, backslashes and newlines in text fields', () {
    final ics = service.build([
      _session(courseName: r'数学; 分析, 二\\三', note: '第一行\n第二行'),
    ]);

    expect(ics, contains(r'SUMMARY:数学\; 分析\, 二\\\\三'));
    expect(ics, contains(r'第一行\n第二行'));
  });

  test('skips deleted sessions', () {
    final ics = service.build([
      _session(),
      _session(id: 'gone', deletedAt: DateTime(2026, 3, 3)),
    ]);

    expect('BEGIN:VEVENT'.allMatches(ics), hasLength(1));
    expect(ics, isNot(contains('UID:gone@orbit')));
  });

  test('folds long lines at 75 octets without splitting characters', () {
    final longName = '超长课程名称' * 12;
    final ics = service.build([_session(courseName: longName)]);
    final lines = ics.split('\r\n')..removeWhere((line) => line.isEmpty);

    for (final line in lines) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
    }
    final unfolded = ics.replaceAll('\r\n ', '');
    expect(unfolded, contains('SUMMARY:$longName'));
  });

  test('an empty timetable still produces a valid calendar', () {
    final ics = service.build(const []);

    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('END:VCALENDAR'));
    expect(ics, isNot(contains('BEGIN:VEVENT')));
  });

  test('alarms are added only when a lead time is supplied', () {
    expect(service.build([_session()]), isNot(contains('VALARM')));
    expect(
      service.build([_session()], defaultLeadMinutes: 0),
      isNot(contains('VALARM')),
    );
    final ics = service.build([_session()], defaultLeadMinutes: 15);
    expect(ics, contains('BEGIN:VALARM\r\nACTION:DISPLAY\r\n'));
    expect(ics, contains('TRIGGER:-PT15M\r\n'));
  });

  test('exams use their own lead time and respect a disabled reminder', () {
    final exam = _session(
      id: 'exam|one',
    ).copyWith(kind: SessionKind.exam, examLeadMinutes: 45);
    final silent = _session(
      id: 'exam|two',
    ).copyWith(kind: SessionKind.exam, examReminderEnabled: false);
    final ics = service.build([exam, silent], defaultLeadMinutes: 15);
    expect(ics, contains('TRIGGER:-PT45M\r\n'));
    expect(ics, isNot(contains('TRIGGER:-PT15M')));
    expect('BEGIN:VALARM'.allMatches(ics), hasLength(1));
  });

  test('open deadlines export as events with their enabled alarms', () {
    final open = Deadline(
      id: 'd1',
      subject: 'Math',
      title: 'Homework',
      dueAt: DateTime.utc(2026, 4, 1, 12),
      leadMinutes: const [60, 1440],
      disabledReminderLeadMinutes: const [1440],
    );
    final done = Deadline(
      id: 'd3',
      subject: 'Math',
      title: 'Finished',
      dueAt: DateTime.utc(2026, 4, 3, 12),
      leadMinutes: const [60],
      completedAt: DateTime.utc(2026, 3, 30),
    );
    final removed = Deadline(
      id: 'd2',
      subject: 'Math',
      title: 'Removed',
      dueAt: DateTime.utc(2026, 4, 2, 12),
      leadMinutes: const [60],
      deletedAt: DateTime.utc(2026, 3, 1),
    );
    final ics = service.build(const [], deadlines: [open, done, removed]);

    expect('BEGIN:VEVENT'.allMatches(ics), hasLength(1));
    expect(ics, contains('UID:ddl-d1@orbit\r\n'));
    expect(ics, contains('SUMMARY:[DDL] Homework\r\n'));
    expect(ics, contains('DTSTART:20260401T120000Z\r\n'));
    expect(ics, contains('TRIGGER:-PT60M\r\n'));
    expect(ics, isNot(contains('TRIGGER:-PT1440M')));
  });
}
