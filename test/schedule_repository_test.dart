import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'xlsx_test_fixtures.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CourseSession _session({
  required String id,
  required DateTime date,
  required int weekday,
}) {
  final startAt = DateTime(date.year, date.month, date.day, 9, 0);
  final endAt = DateTime(date.year, date.month, date.day, 10, 0);
  return CourseSession(
    id: id,
    classType: '一般課堂',
    room: 'C508',
    date: date,
    weekday: weekday,
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
    tempDir = await Directory.systemTemp.createTemp('orbit_repo_');
    database = await AppDatabase.open(tempDir.path);
    repository = ScheduleRepository(database, XlsxParser());
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  group('importParsedSessions', () {
    test('寫入並可查詢課程', () async {
      final sessions = [
        _session(
          id: 'a',
          date: DateTime(2026, 6, 2),
          weekday: 2,
        ),
        _session(
          id: 'b',
          date: DateTime(2026, 6, 3),
          weekday: 3,
        ),
      ];

      await repository.importParsedSessions(sessions);

      final all = await repository.getAllSessions();
      expect(all.length, 2);
    });

    test('重複匯入以 id 去重覆蓋', () async {
      final original = _session(
        id: 'dup',
        date: DateTime(2026, 6, 2),
        weekday: 2,
      );
      await repository.importParsedSessions([original]);

      final updated = original.copyWith(room: 'D201');
      await repository.importParsedSessions([updated]);

      final all = await repository.getAllSessions();
      expect(all.length, 1);
      expect(all.first.room, 'D201');
    });
  });

  group('getEarliestWeekStart', () {
    test('返回最早課程所在週的週一', () async {
      await repository.importParsedSessions([
        _session(
          id: 'late',
          date: DateTime(2026, 6, 5),
          weekday: 5,
        ),
        _session(
          id: 'early',
          date: DateTime(2026, 5, 28),
          weekday: 4,
        ),
      ]);

      final earliest = await repository.getEarliestWeekStart();
      expect(earliest, weekStartFor(DateTime(2026, 5, 28)));
    });
  });

  group('importFromFiles', () {
    test('從 xlsx 測試資料匯入', () async {
      final bytes = weekOneFixture();
      final imported = await repository.importFromFiles([
        (bytes: bytes, fileName: 'week1.xlsx'),
      ]);

      expect(imported.length, 3);
      expect((await repository.getAllSessions()).length, 3);
    });
  });
}
