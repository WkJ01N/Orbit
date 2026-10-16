import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/statistics.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CourseSession lesson(String id, DateTime start) => CourseSession(
  id: id,
  classType: '',
  room: 'A1',
  date: start,
  weekday: start.weekday,
  courseName: 'Math',
  courseCode: 'M',
  section: '1',
  startAt: start,
  endAt: start.add(const Duration(minutes: 90)),
  teachers: const [],
  faculty: '',
  semester: '2026',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppDatabase db;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('orbit_statistics_');
    db = await AppDatabase.open(dir.path);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<OrbitStatistics> stats() async =>
      OrbitStatistics(records: await db.statisticsRecords());
  test(
    'activity dates deduplicate, first date does not invent activity',
    () async {
      await db.refreshStatistics(
        now: DateTime(2026, 1, 2),
        recordActivity: true,
      );
      await db.refreshStatistics(
        now: DateTime(2026, 1, 2, 23),
        recordActivity: true,
      );
      await db.refreshStatistics(
        now: DateTime(2026, 1, 3),
        recordActivity: true,
      );
      await db.setFirstUsedDate(DateTime(2020, 1, 1));
      expect((await stats()).activeDays, 2);
      expect((await stats()).firstUsedDate, '2020-01-01');
    },
  );
  test(
    'first-use date is stored separately and converges across devices',
    () async {
      await db.setActiveSyncAccount(
        const SyncAccount(uid: 'one', email: 'a@b.c'),
      );
      await db.refreshStatistics(
        now: DateTime(2026, 3, 1),
        recordActivity: true,
      );
      expect(
        (await db.statisticsRecords()).where((r) => r['kind'] == 'profile'),
        hasLength(1),
      );
      await db.applyRemoteEntities([
        SyncEntity(
          type: SyncEntityType.statistic,
          id: 'profile',
          payload: {
            'kind': 'profile',
            'firstUsedDate': '2026-01-01',
            'firstUsedDateAutomatic': true,
            'updatedAt': '2026-02-01T00:00:00Z',
          },
        ),
      ]);
      expect((await stats()).firstUsedDate, '2026-01-01');
      expect((await stats()).activeDays, 1);
      await db.setFirstUsedDate(DateTime(2026, 2, 1));
      await db.applyRemoteEntities([
        SyncEntity(
          type: SyncEntityType.statistic,
          id: 'profile',
          payload: {
            'kind': 'profile',
            'firstUsedDate': '2025-01-01',
            'firstUsedDateAutomatic': true,
            'updatedAt': '2099-02-01T00:00:00Z',
          },
        ),
      ]);
      expect((await stats()).firstUsedDate, '2026-02-01');
    },
  );
  test(
    'restored edited courses publish their stable statistics source',
    () async {
      await db.setActiveSyncAccount(
        const SyncAccount(uid: 'one', email: 'a@b.c'),
      );
      await db.restoreUserBackup(
        sessions: [lesson('edited', DateTime(2025, 1, 1, 9))],
        aliases: {'edited': 'original'},
        replace: true,
      );
      final course = (await db.pendingSyncMutations()).firstWhere(
        (m) => m.entity.type == SyncEntityType.courseSession,
      );
      expect(course.entity.payload['statisticsSourceId'], 'original');
      await db.refreshStatistics();
      expect(
        (await db.statisticsRecords())
            .where((r) => r['kind'] == 'course')
            .single['id'],
        'course|original',
      );
    },
  );
  test(
    'editing an ended lesson before reconciliation preserves its completion',
    () async {
      final original = lesson('original', DateTime(2025, 1, 1, 9));
      await db.upsertSessions([original]);
      await db.updateSessionWithIdChange(
        'original',
        lesson('edited', DateTime(2099, 1, 1, 9)),
      );
      await db.refreshStatistics();
      expect((await stats()).attendedSessions, 1);
      expect((await stats()).classMinutes, 90);
    },
  );
  test('legacy remote deletion retires pending course statistics', () async {
    await db.setActiveSyncAccount(
      const SyncAccount(uid: 'one', email: 'a@b.c'),
    );
    await db.upsertSessions([
      lesson('past', DateTime(2025, 1, 1, 9)),
      lesson('future', DateTime(2099, 1, 1, 9)),
    ]);
    await db.refreshStatistics();
    expect((await stats()).learnedCourses, isEmpty);
    await db.applyRemoteEntities([
      const SyncEntity(
        type: SyncEntityType.courseSession,
        id: 'future',
        deleted: true,
        payload: {},
        revision: 1,
      ),
    ]);
    await db.refreshStatistics();
    expect((await stats()).learnedCourses, hasLength(1));
    expect((await stats()).attendedSessions, 1);
  });
  test('backfill, future lessons and stable edited identities', () async {
    final past = lesson('old', DateTime(2025, 1, 1, 9));
    await db.upsertSessions([past]);
    await db.refreshStatistics();
    await db.refreshStatistics();
    expect((await stats()).attendedSessions, 1);
    expect((await stats()).classMinutes, 90);
    expect((await stats()).learnedCourses, hasLength(1));
    await db.updateSessionWithIdChange(
      'old',
      past.copyWith(id: 'changed', room: 'A2'),
    );
    await db.refreshStatistics();
    expect((await stats()).attendedSessions, 1);
    await db.upsertSessions([lesson('future', DateTime(2099, 1, 1, 9))]);
    await db.refreshStatistics();
    expect((await stats()).learnedCourses, isEmpty);
    await db.deleteSessionById('future');
    await db.refreshStatistics();
    expect((await stats()).learnedCourses, hasLength(1));
  });
  test(
    'delete keeps statistics by default, exclusion restores with course',
    () async {
      await db.upsertSessions([lesson('a', DateTime(2025, 1, 1, 9))]);
      await db.deleteSessionById('a');
      expect((await stats()).attendedSessions, 1);
      await db.restoreDeletedSessionIds(['a']);
      await db.deleteSessionById('a', deleteStatistics: true);
      expect((await stats()).attendedSessions, 0);
      await db.refreshStatistics();
      expect((await stats()).attendedSessions, 0);
      await db.restoreDeletedSessionIds(['a']);
      expect((await stats()).attendedSessions, 1);
      await db.deleteSessionById('a', deleteStatistics: true);
      await db.purgeAllDeleted();
      expect((await stats()).attendedSessions, 0);
    },
  );
  test(
    'excluded DDLs never count; reopening and completing only count once',
    () async {
      final d = Deadline(
        id: 'a',
        subject: 'Math',
        title: 'Work',
        dueAt: DateTime(2025),
        leadMinutes: const [60],
        completedAt: DateTime(2025),
      );
      final excluded = Deadline(
        id: 'b',
        subject: 'Math',
        title: 'Copy',
        dueAt: DateTime(2025),
        leadMinutes: const [60],
        completedAt: DateTime(2025),
        countsTowardStatistics: false,
      );
      await db.saveDeadlines([d, excluded]);
      await db.refreshStatistics();
      expect((await stats()).completedDeadlines, 1);
      await db.saveDeadline(d.copyWith(clearCompleted: true));
      // Completion must be recorded without waiting for lifecycle reconciliation.
      expect((await stats()).completedDeadlines, 1);
      await db.refreshStatistics();
      expect((await stats()).completedDeadlines, 1);
      await db.saveDeadline(d.copyWith(completedAt: DateTime(2026)));
      await db.refreshStatistics();
      expect((await stats()).completedDeadlines, 1);
      expect(
        Deadline.fromSyncPayload(
          excluded.toSyncPayload(),
        ).countsTowardStatistics,
        isFalse,
      );
    },
  );
  test(
    'guest merge is explicit and account statistics remain isolated',
    () async {
      await db.refreshStatistics(
        now: DateTime(2025, 1, 1),
        recordActivity: true,
      );
      await db.setActiveSyncAccount(
        const SyncAccount(uid: 'one', email: 'a@b.c'),
      );
      expect((await stats()).activeDays, 0);
      await db.mergeGuestStatistics('one');
      expect((await stats()).activeDays, 1);
      await db.refreshStatistics(
        now: DateTime(2025, 1, 2),
        recordActivity: true,
      );
      await db.setActiveSyncAccount(
        const SyncAccount(uid: 'two', email: 'b@b.c'),
        resetState: true,
      );
      expect((await stats()).activeDays, 0);
      await db.refreshStatistics(
        now: DateTime(2025, 1, 3),
        recordActivity: true,
      );
      await db.setActiveSyncAccount(
        const SyncAccount(uid: 'one', email: 'a@b.c'),
        resetState: true,
      );
      expect((await stats()).activeDays, 2);
      await db.setActiveSyncAccount(null);
      expect((await stats()).activeDays, 0);
    },
  );
  test(
    'remote duplicate days union and older changes cannot undo exclusion',
    () async {
      await db.setActiveSyncAccount(
        const SyncAccount(uid: 'one', email: 'a@b.c'),
      );
      final day = SyncEntity(
        type: SyncEntityType.statistic,
        id: 'day|2025-01-01',
        payload: {
          'kind': 'day',
          'date': '2025-01-01',
          'updatedAt': '2025-01-01T00:00:00Z',
        },
      );
      await db.applyRemoteEntities([day, day]);
      expect((await stats()).activeDays, 1);
      final record = {
        'kind': 'course',
        'name': 'Math',
        'semester': '2026',
        'courseKey': 'M',
        'minutes': 90,
        'counted': true,
        'excluded': true,
        'updatedAt': '2026-01-02T00:00:00Z',
      };
      await db.applyRemoteEntities([
        SyncEntity(
          type: SyncEntityType.statistic,
          id: 'course|a',
          payload: record,
        ),
      ]);
      await db.applyRemoteEntities([
        SyncEntity(
          type: SyncEntityType.statistic,
          id: 'course|a',
          payload: {...record, 'updatedAt': '2026-01-04T00:00:00Z'},
        ),
      ]);
      await db.applyRemoteEntities([
        SyncEntity(
          type: SyncEntityType.statistic,
          id: 'course|a',
          payload: {
            ...record,
            'excluded': false,
            'updatedAt': '2026-01-03T00:00:00Z',
          },
        ),
      ]);
      expect((await stats()).attendedSessions, 0);
    },
  );
  test(
    'current backup round trip includes trash and statistics; repeated restore is idempotent',
    () async {
      await db.upsertSessions([lesson('a', DateTime(2025, 1, 1, 9))]);
      await db.deleteSessionById('a');
      final service = ScheduleBackupService();
      final backup = service.decodeBackup(
        service.encodeToJson(
          await db.getAllSessions(includeDeleted: true),
          statistics: await db.statisticsRecords(),
        ),
      );
      expect(backup.version, ScheduleBackupService.backupVersion);
      expect(backup.sessions.single.deletedAt, isNotNull);
      await db.restoreUserBackup(
        sessions: backup.sessions,
        statistics: backup.statistics,
      );
      await db.restoreUserBackup(
        sessions: backup.sessions,
        statistics: backup.statistics,
      );
      expect((await db.getDeletedSessions()), hasLength(1));
      expect((await stats()).attendedSessions, 1);
    },
  );
  test(
    'settings failure rolls back courses, DDLs, statistics and sync mutations',
    () async {
      await db.setActiveSyncAccount(
        const SyncAccount(uid: 'one', email: 'a@b.c'),
      );
      await db.upsertSessions([lesson('a', DateTime(2025, 1, 1, 9))]);
      await db.refreshStatistics();
      final pending = await db.pendingSyncMutationCount();
      await expectLater(
        db.restoreUserBackup(
          sessions: [lesson('b', DateTime(2025, 2, 1, 9))],
          statistics: const [],
          replace: true,
          deleteStatistics: true,
          restoreSettings: () async => throw StateError('test write failure'),
        ),
        throwsStateError,
      );
      expect((await db.getAllSessions()).single.id, 'a');
      expect((await stats()).attendedSessions, 1);
      expect(await db.pendingSyncMutationCount(), pending);
    },
  );
}
