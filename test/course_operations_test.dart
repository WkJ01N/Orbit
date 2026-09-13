import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/batch_course.dart';
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
  String? recurrenceSeriesId,
  String? recurrenceMeetingId,
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
    recurrenceSeriesId: recurrenceSeriesId,
    recurrenceMeetingId: recurrenceMeetingId,
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

  test('batch save can skip or overwrite existing time conflicts', () async {
    final date = DateTime(2026, 9, 7);
    final existing = _session(id: 'existing', date: date, code: 'OLD');
    final conflict = _session(
      id: 'new-conflict',
      date: date,
      code: 'NEW',
      recurrenceSeriesId: 'series',
      recurrenceMeetingId: 'monday',
    );
    final free = _session(
      id: 'new-free',
      date: date,
      code: 'NEW',
      startHour: 11,
      endHour: 12,
      recurrenceSeriesId: 'series',
      recurrenceMeetingId: 'monday-late',
    );
    await database.upsertSessions([existing]);

    final preview = await repository.previewBatchCreate([conflict, free]);
    expect(preview.generatedCount, 2);
    expect(preview.conflictCount, 1);

    final skipped = await repository.saveBatchSessions([
      conflict,
      free,
    ], strategy: BatchConflictStrategy.skip);
    expect(skipped.createdCount, 1);
    expect(skipped.skippedCount, 1);
    expect((await repository.getAllSessions()).map((item) => item.id), [
      'existing',
      'new-free',
    ]);

    final overwritten = await repository.saveBatchSessions([
      conflict,
    ], strategy: BatchConflictStrategy.overwrite);
    expect(overwritten.createdCount, 1);
    expect(overwritten.overwrittenCount, 1);
    expect(
      (await repository.getAllSessions()).map((item) => item.id),
      containsAll(['new-conflict', 'new-free']),
    );
    expect(
      (await repository.getDeletedSessions()).map((item) => item.id),
      contains('existing'),
    );
  });

  test(
    'recurring edit changes one meeting without flattening other days',
    () async {
      final monday1 = _session(
        id: 'm1',
        date: DateTime(2026, 9, 7),
        recurrenceSeriesId: 'series',
        recurrenceMeetingId: 'monday',
      );
      final monday2 = _session(
        id: 'm2',
        date: DateTime(2026, 9, 14),
        recurrenceSeriesId: 'series',
        recurrenceMeetingId: 'monday',
      );
      final wednesday = _session(
        id: 'w1',
        date: DateTime(2026, 9, 9),
        room: 'W-room',
        startHour: 14,
        endHour: 16,
        recurrenceSeriesId: 'series',
        recurrenceMeetingId: 'wednesday',
      );
      await database.upsertSessions([monday1, monday2, wednesday]);

      final changes = monday1.copyWith(
        room: 'M-new',
        startAt: DateTime(2026, 9, 7, 10),
        endAt: DateTime(2026, 9, 7, 11),
      );
      final result = await repository.updateRecurringCourse(
        selected: monday1,
        changes: changes,
        scope: RecurringCourseEditScope.meetingAll,
      );

      expect(result.affectedCount, 2);
      final active = await repository.getAllSessions();
      final mondaySessions = active
          .where((item) => item.recurrenceMeetingId == 'monday')
          .toList();
      expect(mondaySessions.every((item) => item.room == 'M-new'), isTrue);
      expect(mondaySessions.every((item) => item.startAt.hour == 10), isTrue);
      final untouched = active.singleWhere(
        (item) => item.recurrenceMeetingId == 'wednesday',
      );
      expect(untouched.room, 'W-room');
      expect(untouched.startAt.hour, 14);
    },
  );

  test('recurring common edit preserves every meeting room and time', () async {
    final monday = _session(
      id: 'm1',
      date: DateTime(2026, 9, 7),
      recurrenceSeriesId: 'series',
      recurrenceMeetingId: 'monday',
    );
    final wednesday = _session(
      id: 'w1',
      date: DateTime(2026, 9, 9),
      room: 'W-room',
      startHour: 14,
      endHour: 16,
      recurrenceSeriesId: 'series',
      recurrenceMeetingId: 'wednesday',
    );
    await database.upsertSessions([monday, wednesday]);

    final changes = monday.copyWith(
      courseName: 'Advanced Algorithms',
      courseCode: 'CS201',
      section: 'B',
      room: 'ignored-room',
      startAt: DateTime(2026, 9, 7, 18),
      endAt: DateTime(2026, 9, 7, 20),
    );
    final result = await repository.updateRecurringCourse(
      selected: monday,
      changes: changes,
      scope: RecurringCourseEditScope.courseCommon,
    );

    expect(result.affectedCount, 2);
    final active = await repository.getAllSessions();
    expect(
      active.every((item) => item.courseName == 'Advanced Algorithms'),
      isTrue,
    );
    expect(active.every((item) => item.courseCode == 'CS201'), isTrue);
    expect(active.every((item) => item.section == 'B'), isTrue);
    final updatedMonday = active.singleWhere(
      (item) => item.recurrenceMeetingId == 'monday',
    );
    expect(updatedMonday.room, 'R1');
    expect(updatedMonday.startAt.hour, 9);
    final updatedWednesday = active.singleWhere(
      (item) => item.recurrenceMeetingId == 'wednesday',
    );
    expect(updatedWednesday.room, 'W-room');
    expect(updatedWednesday.startAt.hour, 14);
  });
}
