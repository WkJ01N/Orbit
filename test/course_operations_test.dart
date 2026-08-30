import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CourseSession _session({
  required String id,
  required DateTime date,
  String code = 'CS101',
  String section = 'A',
  String name = 'Algorithms',
  String room = 'R1',
  int startHour = 9,
  int endHour = 10,
  String? note,
  DateTime? deletedAt,
}) {
  return CourseSession(
    id: id,
    classType: 'Lecture',
    room: room,
    date: date,
    weekday: date.weekday,
    courseName: name,
    courseCode: code,
    section: section,
    startAt: DateTime(date.year, date.month, date.day, startHour),
    endAt: DateTime(date.year, date.month, date.day, endHour),
    teachers: const ['Teacher'],
    faculty: 'FIE',
    semester: '2608',
    note: note,
    deletedAt: deletedAt,
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
    tempDir = await Directory.systemTemp.createTemp('orbit_operations_');
    database = await AppDatabase.open(tempDir.path);
    repository = ScheduleRepository(database, XlsxParser());
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'upcoming query includes an ongoing class and excludes ended class',
    () async {
      final date = DateTime(2026, 8, 30);
      await database.upsertSessions([
        _session(id: 'ended', date: date, startHour: 8, endHour: 9),
        _session(id: 'ongoing', date: date, startHour: 10, endHour: 12),
        _session(id: 'future', date: date, startHour: 13, endHour: 14),
      ]);

      final result = await repository.getUpcomingSessions(
        from: DateTime(2026, 8, 30, 11),
      );

      expect(result.map((session) => session.id), ['ongoing', 'future']);
    },
  );

  test('course series uses code and section, with manual-name fallback', () {
    final date = DateTime(2026, 8, 30);
    final imported = _session(id: 'a', date: date, code: ' CS101 ');
    final same = _session(id: 'b', date: date, code: 'cs101');
    final manual = _session(
      id: 'c',
      date: date,
      code: 'MANUAL|abc',
      name: ' Algorithms ',
    );
    final manualAgain = _session(
      id: 'd',
      date: date,
      code: 'MANUAL|def',
      name: 'algorithms',
    );

    expect(
      CourseSeriesKey.fromSession(imported),
      CourseSeriesKey.fromSession(same),
    );
    expect(
      CourseSeriesKey.fromSession(manual),
      CourseSeriesKey.fromSession(manualAgain),
    );
  });

  test(
    'fromSelected updates future matching classes and soft deletes conflicts',
    () async {
      final first = _session(
        id: 'first',
        date: DateTime(2026, 8, 3),
        note: 'keep first',
      );
      final selected = _session(
        id: 'selected',
        date: DateTime(2026, 8, 10),
        note: 'keep selected',
      );
      final last = _session(
        id: 'last',
        date: DateTime(2026, 8, 17),
        note: 'keep last',
      );
      final conflict = _session(
        id: 'conflict',
        date: DateTime(2026, 8, 17),
        code: 'OTHER',
        startHour: 11,
        endHour: 12,
      );
      await database.upsertSessions([first, selected, last, conflict]);
      final changes = selected.copyWith(
        room: 'R9',
        startAt: DateTime(2026, 8, 10, 11),
        endAt: DateTime(2026, 8, 10, 12),
      );

      final preview = await repository.previewCourseSeriesUpdate(
        selected: selected,
        changes: changes,
        scope: CourseOperationScope.fromSelected,
      );
      expect(preview.targetCount, 2);
      expect(preview.conflictCount, 1);

      final result = await repository.updateCourseSeries(
        selected: selected,
        changes: changes,
        scope: CourseOperationScope.fromSelected,
      );
      expect(result.affectedCount, 2);
      expect(result.conflictCount, 1);

      final active = await repository.getAllSessions();
      final untouched = active.singleWhere((session) => session.id == 'first');
      expect(untouched.room, 'R1');
      final updated = active.where((session) => session.room == 'R9').toList();
      expect(updated, hasLength(2));
      expect(
        updated.map((session) => session.note),
        containsAll(['keep selected', 'keep last']),
      );
      expect(updated.every((session) => session.startAt.hour == 11), isTrue);
      expect(
        (await repository.getDeletedSessions()).map((session) => session.id),
        contains('conflict'),
      );
    },
  );

  test('trash restore skips an active time conflict', () async {
    final deleted = _session(id: 'deleted', date: DateTime(2026, 8, 30));
    await database.upsertSessions([deleted]);
    await repository.deleteSession(deleted.id);
    await database.upsertSessions([
      _session(id: 'replacement', date: deleted.date, code: 'OTHER'),
    ]);

    final result = await repository.restoreDeletedSessions([deleted.id]);

    expect(result.restored, 0);
    expect(result.skipped, 1);
    expect(await repository.getDeletedSessions(), hasLength(1));
  });

  test('trash entries older than seven days are purged', () async {
    final now = DateTime(2026, 8, 30, 12);
    await database.upsertSessions([
      _session(
        id: 'old',
        date: DateTime(2026, 8, 1),
        deletedAt: now.subtract(const Duration(days: 8)),
      ),
      _session(
        id: 'recent',
        date: DateTime(2026, 8, 2),
        deletedAt: now.subtract(const Duration(days: 2)),
      ),
    ]);

    expect(await repository.purgeExpiredDeletedSessions(now: now), 1);
    expect((await repository.getDeletedSessions()).single.id, 'recent');
  });
}
