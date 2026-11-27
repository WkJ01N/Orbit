import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CourseSession _lesson(
  String id,
  DateTime start, {
  String code = 'M',
  String semester = '2026',
}) => CourseSession(
  id: id,
  classType: '',
  room: 'A1',
  date: DateTime(start.year, start.month, start.day),
  weekday: start.weekday,
  courseName: 'Math',
  courseCode: code,
  section: '1',
  startAt: start,
  endAt: start.add(const Duration(minutes: 90)),
  teachers: const [],
  faculty: '',
  semester: semester,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppDatabase db;
  late ScheduleRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('orbit_pushdown_');
    db = await AppDatabase.open(dir.path);
    repository = ScheduleRepository(db, XlsxParser());
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'ended-session queries skip unfinished, deleted and archived rows',
    () async {
      await db.upsertSessions([
        _lesson('ended', DateTime(2025, 1, 1, 9)),
        _lesson('future', DateTime(2099, 1, 1, 9)),
        _lesson('gone', DateTime(2025, 1, 2, 9)),
        _lesson('paused', DateTime(2025, 1, 3, 9)),
      ]);
      await db.deleteSessionById('gone');
      final now = DateTime(2026, 1, 1);
      expect(
        await db.getUnarchivedEndedSessionIds(now),
        unorderedEquals(['ended', 'paused']),
      );

      await repository.archiveEndedSessions(sessionIds: ['ended'], at: now);
      expect(await db.getUnarchivedEndedSessionIds(now), ['paused']);
      expect(
        (await repository.getUnarchivedEndedSessions(at: now)).map((s) => s.id),
        ['paused'],
      );
    },
  );

  test(
    'auto archive honours course delay and the UTC deadline boundary',
    () async {
      await db.upsertSessions([
        _lesson('old', DateTime(2025, 1, 1, 9)),
        _lesson('recent', DateTime(2025, 12, 31, 20)),
      ]);
      final done = DateTime.utc(2025, 12, 1);
      await db.saveDeadlines([
        Deadline(
          id: 'old-ddl',
          subject: 'Math',
          title: 'Old',
          dueAt: DateTime.utc(2025, 11, 30),
          leadMinutes: const [60],
          completedAt: done,
        ),
        Deadline(
          id: 'new-ddl',
          subject: 'Math',
          title: 'New',
          dueAt: DateTime.utc(2025, 12, 30),
          leadMinutes: const [60],
          completedAt: DateTime.utc(2025, 12, 30),
        ),
      ]);
      final now = DateTime(2026, 1, 1, 12);
      expect(
        await db.getAutoArchivableDeadlineIds(
          now.subtract(const Duration(days: 7)),
        ),
        ['old-ddl'],
      );

      final changed = await repository.runAutoArchive(
        const ArchiveSettings(
          autoCourses: true,
          autoDeadlines: true,
          courseDelayDays: 1,
          deadlineDelayDays: 7,
        ),
        at: now,
      );
      expect(changed, 2);
      final sessions = {for (final s in await db.getAllSessions()) s.id: s};
      expect(sessions['old']!.archived, isTrue);
      expect(sessions['recent']!.archived, isFalse);
      expect(
        (await db.getDeadlines()).where((d) => d.archived).map((d) => d.id),
        ['old-ddl'],
      );
    },
  );

  test('series and semester lookups filter inside SQLite', () async {
    final first = _lesson('a', DateTime(2026, 3, 2, 9));
    await db.upsertSessions([
      first,
      _lesson('b', DateTime(2026, 3, 9, 9)),
      _lesson('c', DateTime(2026, 3, 16, 9), semester: '2027'),
      _lesson('d', DateTime(2026, 3, 9, 9), code: 'OTHER'),
    ]);

    expect(
      (await db.getSessionsBySemester('2026')).map((s) => s.id),
      unorderedEquals(['a', 'b', 'd']),
    );
    expect(
      (await repository.getCourseSeries(
        first,
        CourseOperationScope.all,
      )).map((s) => s.id),
      unorderedEquals(['a', 'b']),
    );
    expect(
      (await repository.getCourseSeries(
        _lesson('b', DateTime(2026, 3, 9, 9)),
        CourseOperationScope.fromSelected,
      )).map((s) => s.id),
      ['b'],
    );
    expect(
      await repository.findOverlappingWeeks([
        _lesson('x', DateTime(2026, 3, 3, 9)),
      ]),
      isNotEmpty,
    );
    expect(
      await repository.findOverlappingWeeks([
        _lesson('y', DateTime(2030, 3, 3, 9)),
      ]),
      isEmpty,
    );
  });

  test(
    'archiving one lesson skips the full scan but still validates it',
    () async {
      final ended = _lesson('ended', DateTime(2025, 1, 1, 9));
      final future = _lesson('future', DateTime(2099, 1, 1, 9));
      await db.upsertSessions([ended, future]);
      final now = DateTime(2026, 1, 1);
      expect(
        await repository.archiveCourse(future, wholeCourse: false, at: now),
        0,
      );
      expect(
        await repository.archiveCourse(ended, wholeCourse: false, at: now),
        1,
      );
    },
  );

  test(
    'deadline refresh reloads deadlines without reloading sessions',
    () async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await db.upsertSessions([_lesson('a', DateTime(2099, 1, 1, 9))]);
      final sessionsBefore = await container.read(sessionsProvider.future);
      expect(await container.read(deadlinesProvider.future), isEmpty);

      await db.saveDeadline(
        Deadline(
          id: 'd',
          subject: 'Math',
          title: 'Work',
          dueAt: DateTime.utc(2099, 1, 2),
          leadMinutes: const [60],
        ),
      );
      container.read(deadlinesRefreshProvider.notifier).state++;
      expect(await container.read(deadlinesProvider.future), hasLength(1));
      expect(
        identical(
          await container.read(sessionsProvider.future),
          sessionsBefore,
        ),
        isTrue,
      );
    },
  );
}
