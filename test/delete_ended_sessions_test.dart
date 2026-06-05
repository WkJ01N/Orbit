import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
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
    tempDir = await Directory.systemTemp.createTemp('orbit_delete_ended_');
    database = await AppDatabase.open(tempDir.path);
    repository = ScheduleRepository(database, XlsxParser());
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test('countEndedSessions counts only sessions with end_at <= before', () async {
    final now = DateTime(2026, 6, 5, 12, 0);
    await database.upsertSessions([
      _session(
        id: 'past',
        startAt: DateTime(2026, 6, 5, 8, 0),
        endAt: DateTime(2026, 6, 5, 9, 0),
      ),
      _session(
        id: 'future',
        startAt: DateTime(2026, 6, 5, 14, 0),
        endAt: DateTime(2026, 6, 5, 15, 0),
      ),
    ]);

    expect(await repository.countEndedSessions(before: now), 1);
  });

  test('deleteEndedSessions removes only ended sessions', () async {
    final now = DateTime(2026, 6, 5, 12, 0);
    await database.upsertSessions([
      _session(
        id: 'past',
        startAt: DateTime(2026, 6, 5, 8, 0),
        endAt: DateTime(2026, 6, 5, 9, 0),
      ),
      _session(
        id: 'future',
        startAt: DateTime(2026, 6, 5, 14, 0),
        endAt: DateTime(2026, 6, 5, 15, 0),
      ),
    ]);

    final deleted = await repository.deleteEndedSessions(before: now);
    expect(deleted, 1);

    final remaining = await repository.getAllSessions();
    expect(remaining.length, 1);
    expect(remaining.single.id, 'future');
  });
}
