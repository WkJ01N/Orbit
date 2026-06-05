import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/grid/session_range_utils.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CourseSession _session({
  required String id,
  required DateTime startAt,
  required DateTime endAt,
}) {
  return CourseSession(
    id: id,
    classType: '一般課堂',
    room: 'C508',
    date: DateTime(startAt.year, startAt.month, startAt.day),
    weekday: startAt.weekday,
    courseName: '物理II',
    courseCode: 'PHYS102',
    section: 'EX1',
    startAt: startAt,
    endAt: endAt,
    teachers: const ['Teacher'],
    faculty: 'FIE',
    semester: '2602',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase database;
  late ScheduleRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('orbit_batch_delete_');
    database = await AppDatabase.open(tempDir.path);
    repository = ScheduleRepository(database, XlsxParser());
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  group('isSessionFullyInRange', () {
    final rangeStart = DateTime(2026, 6, 2, 8, 0);
    final rangeEnd = DateTime(2026, 6, 8, 18, 0);
    final session = _session(
      id: 'inside',
      startAt: DateTime(2026, 6, 3, 9, 0),
      endAt: DateTime(2026, 6, 3, 10, 0),
    );

    test('returns true when session is fully inside range', () {
      expect(
        isSessionFullyInRange(session, rangeStart, rangeEnd),
        isTrue,
      );
    });

    test('returns false when session partially overlaps start', () {
      final partial = _session(
        id: 'partial-start',
        startAt: DateTime(2026, 6, 1, 9, 0),
        endAt: DateTime(2026, 6, 3, 10, 0),
      );
      expect(
        isSessionFullyInRange(partial, rangeStart, rangeEnd),
        isFalse,
      );
    });

    test('returns false when session partially overlaps end', () {
      final partial = _session(
        id: 'partial-end',
        startAt: DateTime(2026, 6, 8, 17, 0),
        endAt: DateTime(2026, 6, 9, 10, 0),
      );
      expect(
        isSessionFullyInRange(partial, rangeStart, rangeEnd),
        isFalse,
      );
    });

    test('returns false when session is completely outside', () {
      final outside = _session(
        id: 'outside',
        startAt: DateTime(2026, 6, 10, 9, 0),
        endAt: DateTime(2026, 6, 10, 10, 0),
      );
      expect(
        isSessionFullyInRange(outside, rangeStart, rangeEnd),
        isFalse,
      );
    });
  });

  group('weeksOverlappingMonth', () {
    test('includes weeks crossing month start and end', () {
      final weeks = weeksOverlappingMonth(2026, 6);
      expect(weeks, isNotEmpty);
      expect(weeks.first, weekStartFor(DateTime(2026, 6, 1)));
      expect(weeks.last.weekday, DateTime.monday);
      expect(
        !weekEndDate(weeks.last).isBefore(DateTime(2026, 6, 1)),
        isTrue,
      );
    });

    test('handles January with prior-year overlap week', () {
      final weeks = weeksOverlappingMonth(2026, 1);
      expect(weeks.first, weekStartFor(DateTime(2026, 1, 1)));
    });
  });

  group('weekHasSessions', () {
    test('detects sessions within week boundaries', () {
      final weekStart = weekStartFor(DateTime(2026, 6, 3));
      final sessions = [
        _session(
          id: 'in-week',
          startAt: DateTime(2026, 6, 4, 9, 0),
          endAt: DateTime(2026, 6, 4, 10, 0),
        ),
      ];
      expect(weekHasSessions(weekStart, sessions), isTrue);
    });

    test('returns false when no sessions in week', () {
      final weekStart = weekStartFor(DateTime(2026, 6, 3));
      final sessions = [
        _session(
          id: 'other-week',
          startAt: DateTime(2026, 6, 12, 9, 0),
          endAt: DateTime(2026, 6, 12, 10, 0),
        ),
      ];
      expect(weekHasSessions(weekStart, sessions), isFalse);
    });
  });

  group('defaultBatchDeleteRange', () {
    test('spans Monday 00:00 to Sunday 23:59', () {
      final weekStart = weekStartFor(DateTime(2026, 6, 4));
      final range = defaultBatchDeleteRange(weekStart);
      expect(range.start, DateTime(2026, 6, 1));
      expect(range.end, DateTime(2026, 6, 7, 23, 59));
    });
  });

  test('deleteSessionsFullyInRange removes only fully contained sessions', () async {
    final rangeStart = DateTime(2026, 6, 2, 8, 0);
    final rangeEnd = DateTime(2026, 6, 8, 18, 0);
    await database.upsertSessions([
      _session(
        id: 'inside',
        startAt: DateTime(2026, 6, 3, 9, 0),
        endAt: DateTime(2026, 6, 3, 10, 0),
      ),
      _session(
        id: 'partial',
        startAt: DateTime(2026, 6, 1, 9, 0),
        endAt: DateTime(2026, 6, 3, 10, 0),
      ),
      _session(
        id: 'outside',
        startAt: DateTime(2026, 6, 10, 9, 0),
        endAt: DateTime(2026, 6, 10, 10, 0),
      ),
    ]);

    expect(await repository.countSessionsFullyInRange(rangeStart, rangeEnd), 1);

    final deleted =
        await repository.deleteSessionsFullyInRange(rangeStart, rangeEnd);
    expect(deleted, 1);

    final remaining = await repository.getAllSessions();
    expect(remaining.map((s) => s.id).toSet(), {'partial', 'outside'});
  });
}
