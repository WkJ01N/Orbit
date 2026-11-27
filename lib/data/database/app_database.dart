import 'package:orbit/services/semester_service.dart';
import 'package:orbit/data/database/row_decoders.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/account_sync.dart';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

part 'app_database_statistics.dart';
part 'app_database_backup.dart';
part 'app_database_deadlines.dart';
part 'app_database_reminders.dart';
part 'app_database_sync.dart';

abstract class _AppDatabaseBase {
  _AppDatabaseBase(this._db);

  final Database _db;
  final StreamController<void> _syncChanges = StreamController.broadcast();

  AppDatabase get _self => this as AppDatabase;

  Future<Map<String, int>> _syncRevisionMap();
  Future<Map<String, String>> reminderSessionAliases();
  Future<List<Map<String, Object?>>> reminderSchedules();
}

class AppDatabase extends _AppDatabaseBase
    with
        _AppDatabaseDeadlinesMixin,
        _AppDatabaseRemindersMixin,
        _AppDatabaseSyncMixin {
  AppDatabase(super._db);

  static const _uuid = Uuid();

  Stream<void> get syncChanges => _syncChanges.stream;

  static const _tableName = 'course_sessions';

  static Future<AppDatabase> open(String databasePath) async {
    final db = await openDatabase(
      p.join(databasePath, 'orbit.db'),
      version: 13,
      onConfigure: (database) async {
        await database.rawQuery('PRAGMA busy_timeout = 5000');
        try {
          await database.rawQuery('PRAGMA journal_mode = WAL');
        } catch (_) {
          // Some environments (e.g. read-only or in-memory DBs) keep default mode.
        }
      },
      onCreate: (database, version) async {
        await _createSchema(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            'ALTER TABLE $_tableName ADD COLUMN note TEXT',
          );
        }
        if (oldVersion < 3) {
          await database.execute(
            'ALTER TABLE $_tableName ADD COLUMN deleted_at TEXT',
          );
          await _createActiveIndexes(database);
        }
        if (oldVersion < 4) {
          await database.execute(
            'ALTER TABLE $_tableName ADD COLUMN recurrence_series_id TEXT',
          );
          await database.execute(
            'ALTER TABLE $_tableName ADD COLUMN recurrence_meeting_id TEXT',
          );
        }
        if (oldVersion < 5) await _createReminderSchema(database);
        if (oldVersion < 6) await _createSyncSchema(database);
        if (oldVersion < 7) await _createDeadlineSchema(database);
        if (oldVersion < 8) await _createArchiveSchema(database);
        if (oldVersion < 9) await _createStrongSchema(database);
        if (oldVersion < 10) await _createStatisticsSchema(database);
        if (oldVersion < 11) await _createDeadlineStrongSchema(database);
        if (oldVersion < 12) await _createExamSchema(database);
        if (oldVersion < 13) {
          // Reconcile any v12 databases upgraded before sync_conflict_history or
          // partial v12 tables once during migration instead of on every open.
          await _createActiveIndexes(database);
          await _createReminderSchema(database);
          await _createSyncSchema(database);
          await _createDeadlineSchema(database);
          await _createArchiveSchema(database);
          await _createStrongSchema(database);
          await _createStatisticsSchema(database);
          await _createDeadlineStrongSchema(database);
          await _createExamSchema(database);
        }
      },
    );
    return AppDatabase(db);
  }

  static Future<void> _createSchema(Database database) async {
    await database.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        class_type TEXT NOT NULL,
        room TEXT NOT NULL,
        date TEXT NOT NULL,
        weekday INTEGER NOT NULL,
        course_name TEXT NOT NULL,
        course_code TEXT NOT NULL,
        section TEXT NOT NULL,
        start_at TEXT NOT NULL,
        end_at TEXT NOT NULL,
        teachers TEXT NOT NULL,
        faculty TEXT NOT NULL,
        semester TEXT NOT NULL,
        source_file TEXT,
        note TEXT,
        deleted_at TEXT,
        recurrence_series_id TEXT,
        recurrence_meeting_id TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_course_sessions_start_at ON $_tableName(start_at)',
    );
    await database.execute(
      'CREATE INDEX idx_course_sessions_date ON $_tableName(date)',
    );
    await _createActiveIndexes(database);
    await _createReminderSchema(database);
    await _createSyncSchema(database);
    await _createDeadlineSchema(database);
    await _createArchiveSchema(database);
    await _createStrongSchema(database);
    await _createStatisticsSchema(database);
    await _createDeadlineStrongSchema(database);
    await _createExamSchema(database);
  }

  static Future<void> _createExamSchema(Database database) async {
    final names = (await database.rawQuery(
      'PRAGMA table_info(course_sessions)',
    )).map((r) => r['name']).toSet();
    for (final entry in {
      'kind': "TEXT NOT NULL DEFAULT 'course'",
      'semester_id': 'TEXT',
      'exam_reminder_enabled': 'INTEGER NOT NULL DEFAULT 1',
      'exam_strong_reminder': 'INTEGER NOT NULL DEFAULT 1',
      'exam_lead_minutes': 'INTEGER NOT NULL DEFAULT 30',
    }.entries) {
      if (!names.contains(entry.key)) {
        await database.execute(
          'ALTER TABLE course_sessions ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
  }

  String get path => _db.path;

  static Future<void> _createArchiveSchema(Database database) async {
    for (final table in ['course_sessions', 'deadlines']) {
      final columns = await database.rawQuery('PRAGMA table_info($table)');
      final names = columns.map((c) => c['name']).toSet();
      final additions = {
        'archived_at': 'TEXT',
        'archive_hidden': 'INTEGER NOT NULL DEFAULT 0',
        'auto_archive_paused': 'INTEGER NOT NULL DEFAULT 0',
        if (table == 'course_sessions') ...{
          'linked_course_key': 'TEXT',
          'start_period': 'INTEGER',
          'period_time_plan_id': 'TEXT',
        },
      };
      for (final entry in additions.entries) {
        if (!names.contains(entry.key)) {
          await database.execute(
            'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
      }
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_${table}_archive ON $table(archived_at) WHERE deleted_at IS NULL',
      );
    }
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_course_sessions_unarchived_end '
      'ON course_sessions(end_at) WHERE deleted_at IS NULL AND archived_at IS NULL',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_deadlines_auto_archive '
      'ON deadlines(completed_at) WHERE deleted_at IS NULL AND archived_at IS NULL AND auto_archive_paused = 0',
    );
  }

  /// Archive changes and their sync mutations commit together.
  Future<int> updateArchive({
    List<String> sessionIds = const [],
    List<String> deadlineIds = const [],
    required ArchiveMutation action,
    bool hide = true,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final changed = await _db.transaction((txn) async {
      var count = 0;
      for (final id in sessionIds.toSet()) {
        final rows = await txn.query(
          _tableName,
          where: 'id=? AND deleted_at IS NULL',
          whereArgs: [id],
        );
        if (rows.isEmpty) continue;
        final value = CourseSession.fromMap(rows.first);
        if (action == ArchiveMutation.archive &&
            (value.archived || value.endAt.isAfter(now))) {
          continue;
        }
        if (action != ArchiveMutation.archive && !value.archived) continue;
        final next = value.copyWith(
          archivedAt: action == ArchiveMutation.archive ? now : null,
          clearArchived: action == ArchiveMutation.restore,
          archiveHidden: action == ArchiveMutation.hide
              ? true
              : action == ArchiveMutation.show
              ? false
              : hide,
          autoArchivePaused: action == ArchiveMutation.restore ? true : null,
        );
        await txn.update(
          _tableName,
          next.toMap(),
          where: 'id=?',
          whereArgs: [id],
        );
        await _queueSyncEntity(
          txn,
          SyncEntity(
            type: SyncEntityType.courseSession,
            id: next.id,
            payload: courseSessionSyncPayload(next),
          ),
          SyncOperation.upsert,
        );
        count++;
      }
      for (final id in deadlineIds.toSet()) {
        final rows = await txn.query(
          'deadlines',
          where: 'id=? AND deleted_at IS NULL',
          whereArgs: [id],
        );
        if (rows.isEmpty) continue;
        final value = Deadline.fromMap(rows.first);
        if (action == ArchiveMutation.archive &&
            (value.archived || !value.completed)) {
          continue;
        }
        if (action != ArchiveMutation.archive && !value.archived) continue;
        final next = value.copyWith(
          archivedAt: action == ArchiveMutation.archive ? now : null,
          clearArchived: action == ArchiveMutation.restore,
          archiveHidden: action == ArchiveMutation.hide
              ? true
              : action == ArchiveMutation.show
              ? false
              : hide,
          autoArchivePaused: action == ArchiveMutation.restore ? true : null,
        );
        await txn.update(
          'deadlines',
          next.toMap(),
          where: 'id=?',
          whereArgs: [id],
        );
        await _queueSyncEntity(
          txn,
          _deadlineEntity(next),
          SyncOperation.upsert,
        );
        count++;
      }
      return count;
    });
    if (changed > 0) _syncChanges.add(null);
    return changed;
  }

  static SyncEntity _deadlineEntity(Deadline value, {int revision = 0}) =>
      _buildDeadlineEntity(value, revision: revision);

  static Future<void> _createActiveIndexes(Database database) async {
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_course_sessions_active_date '
      'ON $_tableName(date) WHERE deleted_at IS NULL',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_course_sessions_active_start '
      'ON $_tableName(start_at) WHERE deleted_at IS NULL',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_course_sessions_active_end '
      'ON $_tableName(end_at) WHERE deleted_at IS NULL',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_course_sessions_active_semester '
      'ON $_tableName(semester, start_at) WHERE deleted_at IS NULL',
    );
  }

  Future<List<CourseSession>> getUnarchivedEndedSessions(
    DateTime before, {
    bool excludeAutoArchivePaused = false,
  }) async {
    final rows = await _db.query(
      _tableName,
      where:
          'deleted_at IS NULL AND archived_at IS NULL AND end_at <= ?'
          '${excludeAutoArchivePaused ? ' AND auto_archive_paused = 0' : ''}',
      whereArgs: [before.toIso8601String()],
      orderBy: 'start_at ASC',
    );
    return decodeCourseRows(rows);
  }

  Future<List<String>> getUnarchivedEndedSessionIds(
    DateTime before, {
    bool excludeAutoArchivePaused = false,
  }) async {
    final rows = await _db.query(
      _tableName,
      columns: ['id'],
      where:
          'deleted_at IS NULL AND archived_at IS NULL AND end_at <= ?'
          '${excludeAutoArchivePaused ? ' AND auto_archive_paused = 0' : ''}',
      whereArgs: [before.toIso8601String()],
    );
    return [for (final row in rows) row['id'] as String];
  }

  Future<List<CourseSession>> getSessionsBySemester(
    String semester, {
    DateTime? startFrom,
  }) async {
    final rows = await _db.query(
      _tableName,
      where:
          'deleted_at IS NULL AND semester = ?'
          '${startFrom != null ? ' AND start_at >= ?' : ''}',
      whereArgs: [semester, if (startFrom != null) startFrom.toIso8601String()],
      orderBy: 'start_at ASC',
    );
    return decodeCourseRows(rows);
  }

  Future<List<DateTime>> getActiveSessionDates() async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT date FROM $_tableName WHERE deleted_at IS NULL',
    );
    return [for (final row in rows) DateTime.parse(row['date'] as String)];
  }

  Future<void> upsertSessions(List<CourseSession> sessions) async {
    await _db.transaction((txn) async {
      for (final session in sessions) {
        await txn.insert(
          _tableName,
          session.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _queueCourseMutation(txn, session, SyncOperation.upsert);
        if (session.semesterId != null) {
          await _assignSemesterInTransaction(
            txn,
            [session.id],
            session.semesterId!,
            session.semester,
          );
        }
      }
    });
    _syncChanges.add(null);
  }

  Future<void> updateSession(CourseSession session) async {
    await refreshStatistics();
    await _db.transaction((txn) async {
      await txn.insert(
        _tableName,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _queueCourseMutation(txn, session, SyncOperation.upsert);
      if (session.semesterId != null) {
        await _assignSemesterInTransaction(
          txn,
          [session.id],
          session.semesterId!,
          session.semester,
        );
      }
    });
    await refreshStatistics();
    _syncChanges.add(null);
  }

  /// Transactionally deletes [deleteIds] then upserts [upsert]. Used for
  /// conflict-overwrite saves and strategy-based imports so that removing the
  /// old rows and writing the new ones cannot leave the table half-updated.
  Future<void> replaceSessions({
    required List<String> deleteIds,
    required List<CourseSession> upsert,
    Map<String, String> identityChanges = const {},
    bool deleteStatistics = false,
  }) async {
    await refreshStatistics();
    await _db.transaction((txn) async {
      if (deleteStatistics) {
        await _setCourseStatisticsExcluded(
          txn,
          deleteIds.where(
            (id) =>
                !identityChanges.containsKey(id) &&
                !upsert.any((s) => s.id == id),
          ),
          true,
        );
      }
      await _withdrawPendingStatistics(
        txn,
        deleteIds.where(
          (id) =>
              !identityChanges.containsKey(id) &&
              !upsert.any((s) => s.id == id),
        ),
      );
      for (final change in identityChanges.entries) {
        final updated = upsert.where((s) => s.id == change.value).firstOrNull;
        if (updated != null) {
          await _rememberReminderIdentity(txn, change.key, updated);
        }
      }
      if (deleteIds.isNotEmpty) {
        final placeholders = List.filled(deleteIds.length, '?').join(',');
        final deleted = await txn.rawQuery(
          'SELECT * FROM $_tableName WHERE id IN ($placeholders) '
          'AND deleted_at IS NULL',
          deleteIds,
        );
        await txn.rawUpdate(
          'UPDATE $_tableName SET deleted_at = ? '
          'WHERE id IN ($placeholders) AND deleted_at IS NULL',
          [DateTime.now().toIso8601String(), ...deleteIds],
        );
        for (final row in deleted) {
          await _queueCourseMutation(
            txn,
            CourseSession.fromMap(row),
            SyncOperation.delete,
          );
        }
      }
      for (final session in upsert) {
        await txn.insert(
          _tableName,
          session.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _queueCourseMutation(txn, session, SyncOperation.upsert);
        if (session.semesterId != null) {
          await _assignSemesterInTransaction(
            txn,
            [session.id],
            session.semesterId!,
            session.semester,
          );
        }
      }
    });
    _syncChanges.add(null);
  }

  Future<void> updateSessionWithIdChange(
    String oldId,
    CourseSession session,
  ) async {
    await refreshStatistics();
    await _db.transaction((txn) async {
      final oldRows = await txn.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [oldId],
      );
      await _rememberReminderIdentity(txn, oldId, session);
      await txn.delete(_tableName, where: 'id = ?', whereArgs: [oldId]);
      if (oldRows.isNotEmpty) {
        await _queueCourseMutation(
          txn,
          CourseSession.fromMap(oldRows.first),
          SyncOperation.delete,
        );
      }
      await txn.insert(
        _tableName,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _queueCourseMutation(txn, session, SyncOperation.upsert);
    });
    await refreshStatistics();
    _syncChanges.add(null);
  }

  Future<DateTime?> getEarliestSessionDate() async {
    final result = await _db.rawQuery(
      'SELECT MIN(date) AS min_date FROM $_tableName '
      'WHERE deleted_at IS NULL',
    );
    final value = result.first['min_date'] as String?;
    if (value == null) {
      return null;
    }
    final parts = value.split('-');
    if (parts.length != 3) {
      return null;
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static Future<void> _rememberReminderIdentity(
    Transaction txn,
    String oldId,
    CourseSession session,
  ) => _rememberReminderIdentityImpl(txn, oldId, session);

  Future<List<CourseSession>> getAllSessions({
    bool includeDeleted = false,
  }) async {
    final rows = await _db.query(
      _tableName,
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'start_at ASC',
    );
    return decodeCourseRows(rows);
  }

  Future<CourseSession?> getSessionById(String id) async {
    final rows = await _db.query(
      _tableName,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return CourseSession.fromMap(rows.first);
  }

  Future<List<CourseSession>> searchSessions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }
    final pattern = '%$trimmed%';
    final rows = await _db.query(
      _tableName,
      where:
          'deleted_at IS NULL AND '
          '(course_name LIKE ? OR course_code LIKE ? OR room LIKE ? OR teachers LIKE ?)',
      whereArgs: [pattern, pattern, pattern, pattern],
      orderBy: 'start_at ASC',
      limit: 100,
    );
    return decodeCourseRows(rows);
  }

  Future<List<CourseSession>> getUpcomingSessions(DateTime from) async {
    final rows = await _db.query(
      _tableName,
      where:
          'end_at > ? AND deleted_at IS NULL AND (archived_at IS NULL OR archive_hidden=0)',
      whereArgs: [from.toIso8601String()],
      orderBy: 'start_at ASC',
    );
    return decodeCourseRows(rows);
  }

  Future<List<CourseSession>> getSessionsBetween(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final rows = await _db.query(
      _tableName,
      where: 'date >= ? AND date <= ? AND deleted_at IS NULL',
      whereArgs: [_dateKey(startInclusive), _dateKey(endInclusive)],
      orderBy: 'start_at ASC',
    );
    return decodeCourseRows(rows);
  }

  Future<int> clearAllSessions({bool deleteStatistics = false}) =>
      _softDeleteWhere(
        'deleted_at IS NULL',
        const [],
        deleteStatistics: deleteStatistics,
      );
  Future<int> deleteSessionById(String id, {bool deleteStatistics = false}) =>
      _softDeleteWhere('id = ? AND deleted_at IS NULL', [
        id,
      ], deleteStatistics: deleteStatistics);

  Future<int> countEndedSessions(DateTime before) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_tableName '
      'WHERE end_at <= ? AND deleted_at IS NULL',
      [before.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteEndedSessions(
    DateTime before, {
    bool deleteStatistics = false,
  }) async {
    return _softDeleteWhere('end_at <= ? AND deleted_at IS NULL', [
      before.toIso8601String(),
    ], deleteStatistics: deleteStatistics);
  }

  Future<int> countSessionsFullyInRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_tableName '
      'WHERE start_at >= ? AND end_at <= ? AND deleted_at IS NULL',
      [startInclusive.toIso8601String(), endInclusive.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteSessionsFullyInRange(
    DateTime startInclusive,
    DateTime endInclusive, {
    bool deleteStatistics = false,
  }) async {
    return _softDeleteWhere(
      'start_at >= ? AND end_at <= ? AND deleted_at IS NULL',
      [startInclusive.toIso8601String(), endInclusive.toIso8601String()],
      deleteStatistics: deleteStatistics,
    );
  }

  Future<void> replaceAllActiveSessions(
    List<CourseSession> sessions, {
    bool deleteStatistics = false,
  }) async {
    await refreshStatistics();
    await _db.transaction((txn) async {
      final existing = await txn.query(_tableName, where: 'deleted_at IS NULL');
      final retained = sessions.map((session) => session.id).toSet();
      final removed = existing
          .map((row) => row['id'] as String)
          .where((id) => !retained.contains(id))
          .toList();
      await _withdrawPendingStatistics(txn, removed);
      if (deleteStatistics) {
        await _setCourseStatisticsExcluded(txn, removed, true);
      }
      await txn.update(_tableName, {
        'deleted_at': DateTime.now().toIso8601String(),
      }, where: 'deleted_at IS NULL');
      for (final row in existing) {
        await _queueCourseMutation(
          txn,
          CourseSession.fromMap(row),
          SyncOperation.delete,
        );
      }
      for (final session in sessions) {
        await txn.insert(
          _tableName,
          session.copyWith(clearDeletedAt: true).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _queueCourseMutation(txn, session, SyncOperation.upsert);
      }
    });
    await refreshStatistics();
    _syncChanges.add(null);
  }

  Future<List<CourseSession>> getDeletedSessions() async {
    final rows = await _db.query(
      _tableName,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC, start_at ASC',
    );
    return decodeCourseRows(rows);
  }

  Future<int> restoreDeletedSessionIds(List<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return 0;
    final count = await _db.transaction((txn) async {
      var total = 0;
      for (var offset = 0; offset < unique.length; offset += 400) {
        final chunk = unique.sublist(
          offset,
          offset + 400 < unique.length ? offset + 400 : unique.length,
        );
        final where =
            'id IN (${List.filled(chunk.length, '?').join(',')}) AND deleted_at IS NOT NULL';
        final rows = await txn.query(
          _tableName,
          where: where,
          whereArgs: chunk,
        );
        total += await txn.update(
          _tableName,
          {'deleted_at': null},
          where: where,
          whereArgs: chunk,
        );
        await _setCourseStatisticsExcluded(
          txn,
          rows.map((r) => r['id'] as String),
          false,
        );
        for (final row in rows) {
          await _queueCourseMutation(
            txn,
            CourseSession.fromMap({...row, 'deleted_at': null}),
            SyncOperation.upsert,
          );
        }
      }
      return total;
    });
    _syncChanges.add(null);
    return count;
  }

  Future<int> purgeDeletedBefore(DateTime cutoff) {
    return _db.delete(
      _tableName,
      where: 'deleted_at IS NOT NULL AND deleted_at <= ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  Future<int> purgeAllDeleted({bool deleteStatistics = false}) async {
    final count = await _db.transaction((txn) async {
      final rows = await txn.query(_tableName, where: 'deleted_at IS NOT NULL');
      if (deleteStatistics) {
        await _setCourseStatisticsExcluded(
          txn,
          rows.map((r) => r['id'] as String),
          true,
        );
      }
      return txn.delete(_tableName, where: 'deleted_at IS NOT NULL');
    });
    _syncChanges.add(null);
    return count;
  }

  Future<int> softDeleteSessionIds(
    List<String> ids, {
    bool deleteStatistics = false,
  }) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return 0;
    await refreshStatistics();
    final count = await _db.transaction((txn) async {
      var total = 0;
      final deletedAt = DateTime.now().toIso8601String();
      for (var offset = 0; offset < unique.length; offset += 400) {
        final chunk = unique.sublist(
          offset,
          offset + 400 < unique.length ? offset + 400 : unique.length,
        );
        final where =
            'id IN (${List.filled(chunk.length, '?').join(',')}) AND deleted_at IS NULL';
        final rows = await txn.query(
          _tableName,
          where: where,
          whereArgs: chunk,
        );
        total += await txn.update(
          _tableName,
          {'deleted_at': deletedAt},
          where: where,
          whereArgs: chunk,
        );
        if (deleteStatistics) {
          await _setCourseStatisticsExcluded(
            txn,
            rows.map((r) => r['id'] as String),
            true,
          );
        }
        await _withdrawPendingStatistics(
          txn,
          rows.map((r) => r['id'] as String),
        );
        for (final row in rows) {
          await _queueCourseMutation(
            txn,
            CourseSession.fromMap(row),
            SyncOperation.delete,
          );
        }
      }
      return total;
    });
    _syncChanges.add(null);
    return count;
  }

  Future<int> _softDeleteWhere(
    String where,
    List<Object?> whereArgs, {
    bool deleteStatistics = false,
  }) async {
    await refreshStatistics();
    final count = await _db.transaction((txn) async {
      final rows = await txn.query(
        _tableName,
        where: where,
        whereArgs: whereArgs,
      );
      if (deleteStatistics) {
        await _setCourseStatisticsExcluded(
          txn,
          rows.map((r) => r['id'] as String),
          true,
        );
      }
      await _withdrawPendingStatistics(txn, rows.map((r) => r['id'] as String));
      final count = await txn.update(
        _tableName,
        {'deleted_at': DateTime.now().toIso8601String()},
        where: where,
        whereArgs: whereArgs,
      );
      for (final row in rows) {
        await _queueCourseMutation(
          txn,
          CourseSession.fromMap(row),
          SyncOperation.delete,
        );
      }
      return count;
    });
    _syncChanges.add(null);
    return count;
  }

  static Future<void> _queueCourseMutation(
    Transaction txn,
    CourseSession session,
    SyncOperation operation,
  ) => _queueCourseMutationImpl(txn, session, operation);

  static Future<void> _queueSyncEntity(
    DatabaseExecutor txn,
    SyncEntity entity,
    SyncOperation operation, {
    int? baseRevision,
  }) =>
      _queueSyncEntityImpl(txn, entity, operation, baseRevision: baseRevision);

  Future<void> close() async {
    await _syncChanges.close();
    await _db.close();
  }

  static String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
