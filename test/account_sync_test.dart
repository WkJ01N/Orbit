import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/services/account_sync_service.dart';
import 'package:orbit/services/schedule_sync_coordinator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CourseSession _session({String id = 'course-1', String room = 'A101'}) {
  final date = DateTime(2026, 9, 21);
  return CourseSession(
    id: id,
    classType: 'Lecture',
    room: room,
    date: date,
    weekday: date.weekday,
    courseName: 'Mathematics',
    courseCode: 'MATH101',
    section: 'A',
    startAt: DateTime(2026, 9, 21, 8),
    endAt: DateTime(2026, 9, 21, 9, 40),
    teachers: const ['Teacher'],
    faculty: 'Science',
    semester: '2026',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late AppDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbit_sync_');
    database = await AppDatabase.open(directory.path);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('password and display name rules match the account forms', () {
    expect(isValidOrbitPassword('orbit123'), isTrue);
    expect(isValidOrbitPassword('12345678'), isFalse);
    expect(isValidOrbitPassword('abcdefgh'), isFalse);
    expect(isValidOrbitPassword('a1short'), isFalse);
    expect(isValidOrbitPassword('a12345678901234567890'), isFalse);
    expect(isValidOrbitUsername(''), isTrue);
    expect(isValidOrbitUsername('星'), isTrue);
    expect(isValidOrbitUsername('Orbit user'), isTrue);
    expect(isValidOrbitUsername('line\nbreak'), isFalse);
  });

  test('account profile metadata persists with the active account', () async {
    const account = SyncAccount(
      uid: 'user-1',
      email: 'one@example.com',
      username: 'Orbit user',
      avatarFileId: 'cloud://avatar-file',
    );

    await database.setActiveSyncAccount(account);

    final restored = await database.activeSyncAccount();
    expect(restored?.uid, account.uid);
    expect(restored?.email, account.email);
    expect(restored?.username, account.username);
    expect(restored?.avatarFileId, account.avatarFileId);
  });

  test('local writes queue and coalesce only while signed in', () async {
    await database.upsertSessions([_session()]);
    expect(await database.pendingSyncMutationCount(), 0);

    await database.setActiveSyncAccount(
      const SyncAccount(uid: 'user-1', email: 'one@example.com'),
    );
    await database.updateSession(_session(room: 'A102'));
    await database.updateSession(_session(room: 'A103'));

    var pending = await database.pendingSyncMutations();
    expect(pending, hasLength(1));
    expect(pending.single.baseRevision, 0);
    expect(pending.single.entity.payload['room'], 'A103');

    await database.deleteSessionById('course-1');
    pending = await database.pendingSyncMutations();
    expect(pending, hasLength(1));
    expect(pending.single.operation, SyncOperation.delete);
  });

  test(
    'remote changes do not echo and next edit uses cloud revision',
    () async {
      await database.setActiveSyncAccount(
        const SyncAccount(uid: 'user-1', email: 'one@example.com'),
      );
      await database.applyRemoteEntities([
        SyncEntity(
          type: SyncEntityType.courseSession,
          id: 'course-1',
          payload: courseSessionSyncPayload(_session(room: 'Cloud')),
          revision: 7,
        ),
      ]);
      expect(await database.pendingSyncMutationCount(), 0);
      expect((await database.getSessionById('course-1'))!.room, 'Cloud');

      await database.updateSession(_session(room: 'Local'));
      final pending = await database.pendingSyncMutations();
      expect(pending.single.baseRevision, 7);
    },
  );

  test(
    'an edit made during upload advances to the accepted revision',
    () async {
      await database.setActiveSyncAccount(
        const SyncAccount(uid: 'user-1', email: 'one@example.com'),
      );
      await database.applyRemoteEntities([
        SyncEntity(
          type: SyncEntityType.courseSession,
          id: 'course-1',
          payload: courseSessionSyncPayload(_session(room: 'Cloud')),
          revision: 7,
        ),
      ]);

      await database.updateSession(_session(room: 'First edit'));
      final sent = await database.pendingSyncMutations();
      await database.updateSession(_session(room: 'Second edit'));
      await database.acknowledgeSyncMutations({
        sent.single.mutationId: 8,
      }, sent: sent);

      final pending = await database.pendingSyncMutations();
      expect(pending, hasLength(1));
      expect(pending.single.entity.payload['room'], 'Second edit');
      expect(pending.single.baseRevision, 8);
    },
  );

  test('a server conflict leaves only the conflict record', () async {
    await database.setActiveSyncAccount(
      const SyncAccount(uid: 'user-1', email: 'one@example.com'),
    );
    await database.upsertSessions([_session()]);
    final mutation = (await database.pendingSyncMutations()).single;

    await database.storeSyncConflicts([
      SyncConflict(
        id: 'conflict-1',
        local: mutation,
        remote: SyncEntity(
          type: SyncEntityType.courseSession,
          id: 'course-1',
          payload: courseSessionSyncPayload(_session(room: 'Cloud')),
          revision: 3,
        ),
        createdAt: DateTime.utc(2026, 9, 18),
      ),
    ]);

    expect(await database.pendingSyncMutationCount(), 0);
    expect(await database.syncConflictCount(), 1);
  });

  test(
    'switching accounts cannot upload the previous account outbox',
    () async {
      await database.setActiveSyncAccount(
        const SyncAccount(uid: 'user-1', email: 'one@example.com'),
      );
      await database.upsertSessions([_session()]);
      expect(await database.pendingSyncMutationCount(), 1);

      await database.setActiveSyncAccount(null);
      await database.setActiveSyncAccount(
        const SyncAccount(uid: 'user-2', email: 'two@example.com'),
      );
      expect(await database.pendingSyncMutationCount(), 0);
    },
  );

  test('sync pulls from the old cursor after pushing local changes', () async {
    await database.setActiveSyncAccount(
      const SyncAccount(uid: 'user-1', email: 'one@example.com'),
    );
    await database.upsertSessions([_session()]);
    final backend = _MemoryBackend(
      pulled: SyncEntity(
        type: SyncEntityType.courseSession,
        id: 'remote-course',
        payload: courseSessionSyncPayload(_session(id: 'remote-course')),
        revision: 1,
      ),
    );
    var refreshes = 0;
    final coordinator = ScheduleSyncCoordinator(
      database: database,
      backend: backend,
      loadConfiguration: () async => const ImportConfiguration(),
      saveConfiguration: (_) async {},
      onCoursesChanged: () async => refreshes++,
    );

    final status = await coordinator.synchronize();

    expect(backend.pullCursors, [0]);
    expect(status.pendingCount, 0);
    expect(await database.getSessionById('remote-course'), isNotNull);
    expect(refreshes, 1);
  });

  test('sync drains more than one server-sized upload batch', () async {
    await database.setActiveSyncAccount(
      const SyncAccount(uid: 'user-1', email: 'one@example.com'),
    );
    await database.upsertSessions([
      for (var index = 0; index < 101; index++) _session(id: 'course-$index'),
    ]);
    final backend = _MemoryBackend();
    final coordinator = ScheduleSyncCoordinator(
      database: database,
      backend: backend,
      loadConfiguration: () async => const ImportConfiguration(),
      saveConfiguration: (_) async {},
      onCoursesChanged: () async {},
    );

    final status = await coordinator.synchronize();

    expect(backend.pushBatchSizes, [100, 1]);
    expect(status.pendingCount, 0);
  });

  test('optimized sync exchanges upload and download in one call', () async {
    await database.setActiveSyncAccount(
      const SyncAccount(uid: 'user-1', email: 'one@example.com'),
    );
    await database.upsertSessions([_session()]);
    final backend = _OptimizedMemoryBackend(
      pulled: SyncEntity(
        type: SyncEntityType.courseSession,
        id: 'remote-course',
        payload: courseSessionSyncPayload(_session(id: 'remote-course')),
        revision: 1,
      ),
    );
    final coordinator = ScheduleSyncCoordinator(
      database: database,
      backend: backend,
      loadConfiguration: () async => const ImportConfiguration(),
      saveConfiguration: (_) async {},
      onCoursesChanged: () async {},
    );

    final status = await coordinator.synchronize();

    expect(backend.exchangeCursors, [0]);
    expect(backend.pullCursors, isEmpty);
    expect(status.pendingCount, 0);
    expect(await database.getSessionById('remote-course'), isNotNull);
  });

  test('initial merge discards a stale pre-logout upload', () async {
    final local = _session(room: 'Same');
    await database.setActiveSyncAccount(
      const SyncAccount(uid: 'user-1', email: 'one@example.com'),
    );
    await database.upsertSessions([local]);
    await database.setActiveSyncAccount(null);
    expect(await database.pendingSyncMutationCount(), 1);
    final backend = _MemoryBackend(
      snapshotValues: [
        SyncEntity(
          type: SyncEntityType.courseSession,
          id: local.id,
          payload: courseSessionSyncPayload(local),
          revision: 5,
        ),
      ],
    );
    final coordinator = ScheduleSyncCoordinator(
      database: database,
      backend: backend,
      loadConfiguration: () async => const ImportConfiguration(),
      saveConfiguration: (_) async {},
      onCoursesChanged: () async {},
    );
    const account = SyncAccount(uid: 'user-1', email: 'one@example.com');

    final preview = await coordinator.previewInitialMerge(account);
    expect(preview.identical, hasLength(1));
    await coordinator.confirmInitialMerge(
      account: account,
      preview: preview,
      useLocalForConflict: const {},
    );

    expect(backend.pushBatchSizes, isEmpty);
    expect(await database.pendingSyncMutationCount(), 0);
  });

  test(
    'an offline deletion after sign-out becomes an explicit conflict',
    () async {
      final cloud = _session(room: 'Cloud');
      await database.setActiveSyncAccount(
        const SyncAccount(uid: 'user-1', email: 'one@example.com'),
      );
      await database.applyRemoteEntities([
        SyncEntity(
          type: SyncEntityType.courseSession,
          id: cloud.id,
          payload: courseSessionSyncPayload(cloud),
          revision: 3,
        ),
      ]);
      await database.setActiveSyncAccount(null);
      await database.deleteSessionById(cloud.id);
      expect(
        (await database.pendingSyncMutations()).single.operation,
        SyncOperation.delete,
      );
      final backend = _MemoryBackend(
        snapshotValues: [
          SyncEntity(
            type: SyncEntityType.courseSession,
            id: cloud.id,
            payload: courseSessionSyncPayload(cloud),
            revision: 3,
          ),
        ],
      );
      final coordinator = ScheduleSyncCoordinator(
        database: database,
        backend: backend,
        loadConfiguration: () async => const ImportConfiguration(),
        saveConfiguration: (_) async {},
        onCoursesChanged: () async {},
      );
      const account = SyncAccount(uid: 'user-1', email: 'one@example.com');

      final preview = await coordinator.previewInitialMerge(account);

      expect(preview.conflicts, hasLength(1));
      expect(preview.conflicts.single.local.operation, SyncOperation.delete);
      await coordinator.confirmInitialMerge(
        account: account,
        preview: preview,
        useLocalForConflict: {preview.conflicts.single.id: true},
      );
      expect(backend.pushedOperations, contains(SyncOperation.delete));
      expect(await database.getSessionById(cloud.id), isNull);
    },
  );

  test(
    'deleting an account binding stops tracking its local changes',
    () async {
      await database.setActiveSyncAccount(
        const SyncAccount(uid: 'user-1', email: 'one@example.com'),
      );
      await database.setActiveSyncAccount(null, clearBinding: true);

      await database.upsertSessions([_session()]);

      expect(await database.boundSyncAccountUid(), isNull);
      expect(await database.pendingSyncMutationCount(), 0);
    },
  );

  test('initial merge rejects unresolved choices', () async {
    final coordinator = ScheduleSyncCoordinator(
      database: database,
      backend: _MemoryBackend(),
      loadConfiguration: () async => const ImportConfiguration(),
      saveConfiguration: (_) async {},
      onCoursesChanged: () async {},
    );
    final local = SyncEntity(
      type: SyncEntityType.courseSession,
      id: 'course-1',
      payload: courseSessionSyncPayload(_session()),
    );
    final conflict = SyncConflict(
      id: 'choice-1',
      local: SyncMutation(
        mutationId: 'mutation-1',
        entity: local,
        operation: SyncOperation.upsert,
        baseRevision: 2,
      ),
      remote: SyncEntity(
        type: SyncEntityType.courseSession,
        id: 'course-1',
        payload: courseSessionSyncPayload(_session(room: 'Cloud')),
        revision: 2,
      ),
      createdAt: DateTime.utc(2026, 9, 18),
    );

    expect(
      () => coordinator.confirmInitialMerge(
        account: const SyncAccount(uid: 'user-1', email: 'one@example.com'),
        preview: InitialSyncPreview(conflicts: [conflict]),
        useLocalForConflict: const {},
      ),
      throwsA(
        isA<AccountSyncException>().having(
          (error) => error.code,
          'code',
          'unresolved_conflicts',
        ),
      ),
    );
  });

  test('import configuration changes enter the sync queue', () async {
    await database.setActiveSyncAccount(
      const SyncAccount(uid: 'user-1', email: 'one@example.com'),
    );
    final coordinator = ScheduleSyncCoordinator(
      database: database,
      backend: _MemoryBackend(),
      loadConfiguration: () async => const ImportConfiguration(),
      saveConfiguration: (_) async {},
      onCoursesChanged: () async {},
    );
    final after = ImportConfiguration(
      semesters: [
        SemesterPlan(
          id: 'semester-1',
          name: 'Autumn',
          firstWeekMonday: DateTime(2026, 9, 7),
        ),
      ],
    );

    await coordinator.enqueueConfigurationChange(
      const ImportConfiguration(),
      after,
    );

    final pending = await database.pendingSyncMutations();
    expect(pending, hasLength(1));
    expect(pending.single.entity.type, SyncEntityType.semesterPlan);
    expect(pending.single.entity.payload['name'], 'Autumn');
  });

  test(
    'initial merge requires a choice for edit versus cloud deletion',
    () async {
      await database.upsertSessions([_session()]);
      final backend = _MemoryBackend(
        snapshotValues: [
          const SyncEntity(
            type: SyncEntityType.courseSession,
            id: 'course-1',
            payload: {},
            revision: 4,
            deleted: true,
          ),
        ],
      );
      final coordinator = ScheduleSyncCoordinator(
        database: database,
        backend: backend,
        loadConfiguration: () async => const ImportConfiguration(),
        saveConfiguration: (_) async {},
        onCoursesChanged: () async {},
      );

      final preview = await coordinator.previewInitialMerge(
        const SyncAccount(uid: 'user-1', email: 'one@example.com'),
      );

      expect(preview.localOnly, isEmpty);
      expect(preview.conflicts, hasLength(1));
      expect(preview.conflicts.single.remote.deleted, isTrue);
    },
  );
}

class _MemoryBackend implements SyncBackend {
  _MemoryBackend({this.pulled, this.snapshotValues = const []});

  final SyncEntity? pulled;
  final List<SyncEntity> snapshotValues;
  final List<int> pullCursors = [];
  final List<int> pushBatchSizes = [];
  final List<SyncOperation> pushedOperations = [];
  bool _returned = false;

  @override
  bool get configured => true;

  @override
  Future<void> deleteAccountData() async {}

  @override
  Future<SyncPullResult> pull(int cursor, {int limit = 200}) async {
    pullCursors.add(cursor);
    if (_returned || pulled == null) {
      return SyncPullResult(cursor: cursor);
    }
    _returned = true;
    return SyncPullResult(entities: [pulled!], cursor: 1);
  }

  @override
  Future<SyncPushResult> push(List<SyncMutation> mutations, int cursor) async {
    pushBatchSizes.add(mutations.length);
    pushedOperations.addAll(mutations.map((mutation) => mutation.operation));
    return SyncPushResult(
      accepted: {for (final mutation in mutations) mutation.mutationId: 10},
      cursor: 10,
    );
  }

  @override
  Future<List<SyncEntity>> snapshot() async => snapshotValues;
}

class _OptimizedMemoryBackend extends _MemoryBackend
    implements OptimizedSyncBackend {
  _OptimizedMemoryBackend({required super.pulled});

  final List<int> exchangeCursors = [];

  @override
  Future<SyncExchangeResult> exchange(
    List<SyncMutation> mutations,
    int cursor, {
    int limit = 200,
  }) async {
    exchangeCursors.add(cursor);
    pushBatchSizes.add(mutations.length);
    return SyncExchangeResult(
      push: SyncPushResult(
        accepted: {for (final mutation in mutations) mutation.mutationId: 10},
        cursor: 10,
      ),
      pull: SyncPullResult(entities: [pulled!], cursor: 10),
    );
  }
}
