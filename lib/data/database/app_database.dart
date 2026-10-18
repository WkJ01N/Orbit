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

class AppDatabase {
  AppDatabase(this._db);

  final Database _db;
  static const _uuid = Uuid();
  final StreamController<void> _syncChanges = StreamController.broadcast();

  Stream<void> get syncChanges => _syncChanges.stream;

  static const _tableName = 'course_sessions';

  static Future<AppDatabase> open(String databasePath) async {
    final db = await openDatabase(
      p.join(databasePath, 'orbit.db'),
      version: 12,
      onCreate: (database, version) async {
        await _createSchema(database);
      },
      onOpen: (database) async {
        await _createReminderSchema(database);
        await _createSyncSchema(database);
        await _createDeadlineSchema(database);
        await _createStrongSchema(database);
        await _createStatisticsSchema(database);
        await _createDeadlineStrongSchema(database);
        await _createExamSchema(database);
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

  static Future<void> _createDeadlineStrongSchema(Database database) async {
    final columns = (await database.rawQuery(
      'PRAGMA table_info(deadlines)',
    )).map((row) => row['name']).toSet();
    for (final entry in {
      'strong_reminder_enabled': 'INTEGER NOT NULL DEFAULT 0',
      'strong_lead_minutes': 'TEXT',
      'disabled_reminder_lead_minutes': "TEXT NOT NULL DEFAULT '[]'",
    }.entries) {
      if (!columns.contains(entry.key)) {
        await database.execute(
          'ALTER TABLE deadlines ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
  }

  static Future<void> _createStrongSchema(Database database) async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS strong_reminder_sessions (id TEXT PRIMARY KEY, expires_at INTEGER NOT NULL, state TEXT NOT NULL)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_strong_session_expiry ON strong_reminder_sessions(expires_at)',
    );
  }

  Future<void> saveStrongSession(
    String id,
    int expiry,
    Map<String, dynamic> state,
  ) async {
    await _db.insert('strong_reminder_sessions', {
      'id': id,
      'expires_at': expiry,
      'state': jsonEncode(state),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> strongSessions() async =>
      (await _db.query('strong_reminder_sessions', orderBy: 'expires_at DESC'))
          .map(
            (row) => Map<String, dynamic>.from(
              jsonDecode(row['state'] as String) as Map,
            ),
          )
          .toList();
  Future<void> pruneStrongSessions(int before) async => _db.delete(
    'strong_reminder_sessions',
    where: 'expires_at < ?',
    whereArgs: [before],
  );

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

  static Future<void> _createDeadlineSchema(Database database) async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS deadlines ('
      'id TEXT PRIMARY KEY, subject TEXT NOT NULL, title TEXT NOT NULL, '
      'due_at TEXT NOT NULL, lead_minutes TEXT NOT NULL, course_key TEXT, '
      'completed_at TEXT, deleted_at TEXT)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_deadlines_due '
      'ON deadlines(due_at) WHERE deleted_at IS NULL',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS deadline_notification_ids ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, deadline_id TEXT NOT NULL, '
      'lead_minutes INTEGER NOT NULL, UNIQUE(deadline_id, lead_minutes))',
    );
  }

  Future<List<Deadline>> getDeadlines({bool includeDeleted = false}) async =>
      decodeDeadlineRows(
        await _db.query(
          'deadlines',
          where: includeDeleted ? null : 'deleted_at IS NULL',
          orderBy: 'due_at ASC',
        ),
      );

  Future<Deadline?> getDeadlineById(String id) async {
    final rows = await _db.query(
      'deadlines',
      where: 'id=? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Deadline.fromMap(rows.first);
  }

  Future<void> saveDeadline(Deadline value) => saveDeadlines([value]);

  Future<void> saveDeadlines(List<Deadline> values) async {
    await _db.transaction((txn) async {
      for (final value in values) {
        await txn.insert(
          'deadlines',
          value.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _queueSyncEntity(
          txn,
          _deadlineEntity(value),
          SyncOperation.upsert,
        );
        if (value.completed && value.countsTowardStatistics) {
          final owner = await _statisticsOwner(txn);
          final id = 'ddl|${value.id}';
          if (await _claimStatistic(txn, id, owner)) {
            final exists = await txn.query(
              'statistics_records',
              where: 'owner=? AND id=?',
              whereArgs: [owner, id],
            );
            if (exists.isEmpty) {
              await _writeStatistic(txn, owner, id, {
                'kind': 'ddl',
                'name': value.title,
                'completedAt': value.completedAt!.toUtc().toIso8601String(),
              });
            }
          }
        }
      }
    });
    _syncChanges.add(null);
  }

  /// Update only selected reminder slots using fresh rows in one transaction.
  Future<void> disableDeadlineReminders(
    Map<String, Set<int>> selections, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    await _db.transaction((txn) async {
      for (final entry in selections.entries) {
        final rows = await txn.query(
          'deadlines',
          where: 'id=? AND deleted_at IS NULL',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        final value = Deadline.fromMap(rows.first);
        if (value.completed || value.archived) continue;
        final disabled = value.disabledReminderLeadMinutes.toSet();
        disabled.addAll(
          value.leadMinutes.where(
            (m) =>
                entry.value.contains(m) &&
                value.dueAt.subtract(Duration(minutes: m)).isAfter(at),
          ),
        );
        final next = value.copyWith(
          disabledReminderLeadMinutes: disabled.toList()..sort(),
        );
        await txn.update(
          'deadlines',
          next.toMap(),
          where: 'id=?',
          whereArgs: [value.id],
        );
        await _queueSyncEntity(
          txn,
          _deadlineEntity(next),
          SyncOperation.upsert,
        );
      }
    });
    _syncChanges.add(null);
  }

  Future<void> deleteDeadline(Deadline value) async {
    final deleted = value.copyWith(deletedAt: DateTime.now());
    await _db.transaction((txn) async {
      await txn.insert(
        'deadlines',
        deleted.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _queueSyncEntity(
        txn,
        _deadlineEntity(deleted),
        SyncOperation.delete,
      );
    });
    _syncChanges.add(null);
  }

  Future<Map<String, int>> reserveDeadlineNotificationIds(
    List<Deadline> values,
  ) async {
    final result = <String, int>{};
    await _db.transaction((txn) async {
      for (final deadline in values) {
        for (final minutes in deadline.leadMinutes.toSet()) {
          await txn.insert(
            'deadline_notification_ids',
            {'deadline_id': deadline.id, 'lead_minutes': minutes},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          final rows = await txn.query(
            'deadline_notification_ids',
            columns: ['id'],
            where: 'deadline_id=? AND lead_minutes=?',
            whereArgs: [deadline.id, minutes],
            limit: 1,
          );
          result['${deadline.id}|$minutes'] =
              4000000 + (rows.first['id'] as int);
        }
      }
    });
    return result;
  }

  static SyncEntity _deadlineEntity(Deadline value, {int revision = 0}) =>
      SyncEntity(
        type: SyncEntityType.deadline,
        id: value.id,
        revision: revision,
        payload: value.toSyncPayload(),
        deleted: value.deleted,
      );

  Future<List<SyncEntity>> localDeadlineSyncEntities({
    bool includeDeleted = false,
  }) async {
    final revisions = await _syncRevisionMap();
    return [
      for (final value in await getDeadlines(includeDeleted: includeDeleted))
        _deadlineEntity(
          value,
          revision: revisions['deadline|${value.id}'] ?? 0,
        ),
    ];
  }

  String get path => _db.path;
  Future<Map<String, List<String>>> reminderSeriesMemberships() async {
    final result = <String, List<String>>{};
    for (final row in await _db.query('reminder_series_membership')) {
      result
          .putIfAbsent(row['session_id'] as String, () => [])
          .add(row['series_key'] as String);
    }
    return result;
  }

  Future<void> markCatchUpQueued(
    String ruleId,
    String sessionId,
    int index,
  ) async {
    await _db.rawInsert(
      'INSERT OR IGNORE INTO reminder_delivery(rule_id,session_id) VALUES(?,?)',
      [ruleId, sessionId],
    );
    await _db.rawUpdate(
      'UPDATE reminder_delivery SET catchup_index=MAX(catchup_index,?) WHERE rule_id=? AND session_id=?',
      [index, ruleId, sessionId],
    );
  }

  Future<Map<String, String>> reminderSessionAliases() async => {
    for (final row in await _db.query('reminder_session_alias'))
      row['session_id'] as String: row['stable_id'] as String,
  };
  Future<void> clearReminderHistory() async {
    await _db.delete('reminder_delivery');
    await _db.delete('reminder_schedule');
  }

  static Future<void> _createReminderSchema(Database database) async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS reminder_series_membership(session_id TEXT NOT NULL, series_key TEXT NOT NULL, PRIMARY KEY(session_id,series_key))',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS reminder_session_alias(session_id TEXT PRIMARY KEY, stable_id TEXT NOT NULL)',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS reminder_delivery ('
      'rule_id TEXT NOT NULL, session_id TEXT NOT NULL, acknowledged INTEGER NOT NULL DEFAULT 0, '
      'processed_index INTEGER NOT NULL DEFAULT 0, catchup_index INTEGER NOT NULL DEFAULT 0, '
      'PRIMARY KEY(rule_id, session_id))',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS reminder_schedule ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, delivery_key TEXT NOT NULL UNIQUE, '
      'rule_id TEXT NOT NULL, session_id TEXT NOT NULL, send_index INTEGER NOT NULL, '
      'fire_at INTEGER NOT NULL, spec TEXT NOT NULL, queued INTEGER NOT NULL DEFAULT 0)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminder_schedule_time ON reminder_schedule(fire_at)',
    );
  }

  static Future<void> _createSyncSchema(Database database) async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS sync_metadata ('
      'key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS sync_versions ('
      'entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, '
      'revision INTEGER NOT NULL DEFAULT 0, '
      'PRIMARY KEY(entity_type, entity_id))',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS sync_outbox ('
      'mutation_id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, '
      'entity_id TEXT NOT NULL, operation TEXT NOT NULL, '
      'base_revision INTEGER NOT NULL, schema_version INTEGER NOT NULL, '
      'payload TEXT NOT NULL, created_at TEXT NOT NULL, '
      'UNIQUE(entity_type, entity_id))',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS sync_conflicts ('
      'id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, '
      'local_mutation TEXT NOT NULL, remote_entity TEXT NOT NULL, '
      'created_at TEXT NOT NULL, '
      'UNIQUE(entity_type, entity_id))',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_created '
      'ON sync_outbox(created_at)',
    );
  }

  Future<List<Map<String, Object?>>> reminderDeliveryStates() =>
      _db.query('reminder_delivery');
  Future<void> acknowledgeReminder(String ruleId, String sessionId) async {
    await _db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR IGNORE INTO reminder_delivery(rule_id,session_id) VALUES(?,?)',
        [ruleId, sessionId],
      );
      await txn.rawUpdate(
        'UPDATE reminder_delivery SET acknowledged=1 WHERE rule_id=? AND session_id=?',
        [ruleId, sessionId],
      );
      await txn.delete(
        'reminder_schedule',
        where: 'rule_id=? AND session_id=?',
        whereArgs: [ruleId, sessionId],
      );
    });
  }

  Future<void> markReminderProcessed(
    String ruleId,
    String sessionId,
    int index, {
    bool catchUp = false,
  }) async {
    await _db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR IGNORE INTO reminder_delivery(rule_id,session_id) VALUES(?,?)',
        [ruleId, sessionId],
      );
      await txn.rawUpdate(
        'UPDATE reminder_delivery SET processed_index=MAX(processed_index,?),catchup_index=MAX(catchup_index,?) WHERE rule_id=? AND session_id=?',
        [index, catchUp ? index : 0, ruleId, sessionId],
      );
    });
  }

  Future<List<Map<String, Object?>>> reminderSchedules() =>
      _db.query('reminder_schedule', orderBy: 'fire_at');

  Future<Set<String>> storeWindowsBuiltinSchedules(
    List<ReminderAlarmSpec> specs,
  ) => _db.transaction((txn) async {
    final existing = {
      for (final row in await txn.query(
        'reminder_schedule',
        where: 'rule_id=?',
        whereArgs: ['@builtin'],
      ))
        row['delivery_key'] as String: row,
    };
    final keys = <String>{};
    final batch = txn.batch();
    for (final spec in specs) {
      final key = '@builtin|${spec.notificationId}';
      keys.add(key);
      final values = <String, Object?>{
        'delivery_key': key,
        'rule_id': '@builtin',
        'session_id': spec.payload,
        'send_index': 0,
        'fire_at': spec.fireAt.millisecondsSinceEpoch,
        'spec': jsonEncode(spec.toJson()),
      };
      if (existing.containsKey(key)) {
        batch.update(
          'reminder_schedule',
          values,
          where: 'delivery_key=?',
          whereArgs: [key],
        );
      } else {
        batch.insert('reminder_schedule', values);
      }
    }
    await batch.commit(noResult: true);
    return keys;
  });

  Future<void> markQueuedReminders(Set<int> ids) async {
    await _db.transaction((txn) async {
      await txn.update('reminder_schedule', {'queued': 0});
      final batch = txn.batch();
      for (final row in await txn.query(
        'reminder_schedule',
        where: 'rule_id=?',
        whereArgs: ['@builtin'],
      )) {
        final spec = ReminderAlarmSpec.fromJson(
          jsonDecode(row['spec'] as String) as Map<String, dynamic>,
        );
        if (ids.contains(spec.notificationId)) {
          batch.update(
            'reminder_schedule',
            {'queued': 1},
            where: 'id=?',
            whereArgs: [row['id']],
          );
        }
      }
      for (final id in ids) {
        if (id < 3000000) continue;
        batch.update(
          'reminder_schedule',
          {'queued': 1},
          where: 'id=?',
          whereArgs: [id - 3000000],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<ReminderAlarmSpec>> materializeReminderSchedules(
    List<ReminderAlarmSpec> specs,
  ) => _db.transaction((txn) async {
    final rows = {
      for (final row in await txn.query('reminder_schedule'))
        row['delivery_key'] as String: row,
    };
    final result = <ReminderAlarmSpec>[];
    final batch = txn.batch();
    for (final spec in specs) {
      final key = '${spec.ruleId}|${spec.sessionId}|${spec.sendIndex}';
      final old = rows[key];
      final rowId =
          old?['id'] as int? ??
          await txn.insert('reminder_schedule', {
            'delivery_key': key,
            'rule_id': spec.ruleId,
            'session_id': spec.sessionId,
            'send_index': spec.sendIndex,
            'fire_at': spec.fireAt.millisecondsSinceEpoch,
            'spec': jsonEncode(spec.toJson()),
          });
      final id = 3000000 + rowId;
      final stored = ReminderAlarmSpec.fromJson({
        ...spec.toJson(),
        'alarmId': id,
        'notificationId': id,
      });
      final json = jsonEncode(stored.toJson());
      if (old?['spec'] != json) {
        batch.update(
          'reminder_schedule',
          {'spec': json, 'fire_at': spec.fireAt.millisecondsSinceEpoch},
          where: 'id=?',
          whereArgs: [rowId],
        );
      }
      result.add(stored);
    }
    await batch.commit(noResult: true);
    return result;
  });
  Future<void> updateReminderSchedule(int id, String spec) async {
    await _db.update(
      'reminder_schedule',
      {'spec': spec},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<int> putReminderSchedule(Map<String, Object?> row) async {
    await _db.insert(
      'reminder_schedule',
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return (await _db.query(
          'reminder_schedule',
          columns: ['id'],
          where: 'delivery_key=?',
          whereArgs: [row['delivery_key']],
        )).first['id']
        as int;
  }

  Future<void> pruneReminderSchedules(Set<String> keys) async {
    final rows = await reminderSchedules();
    final batch = _db.batch();
    for (final row in rows) {
      if (!keys.contains(row['delivery_key'])) {
        batch.delete(
          'reminder_schedule',
          where: 'id=?',
          whereArgs: [row['id']],
        );
      }
    }
    await batch.commit(noResult: true);
  }

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
  ) async {
    final previous = await txn.query(
      'reminder_session_alias',
      where: 'session_id=?',
      whereArgs: [oldId],
    );
    final stable = previous.isEmpty
        ? oldId
        : previous.first['stable_id'] as String;
    await txn.insert('reminder_session_alias', {
      'session_id': session.id,
      'stable_id': stable,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final old = await txn.query(_tableName, where: 'id=?', whereArgs: [oldId]);
    final series = {
      CourseSeriesKey.fromSession(session).value,
      if (old.isNotEmpty)
        CourseSeriesKey.fromSession(CourseSession.fromMap(old.first)).value,
    };
    for (final key in series) {
      await txn.insert('reminder_series_membership', {
        'session_id': stable,
        'series_key': key,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

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
    await refreshStatistics();
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return 0;
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

  Future<void> setActiveSyncAccount(
    SyncAccount? account, {
    bool resetState = false,
    bool clearBinding = false,
  }) async {
    await _db.transaction((txn) async {
      if (account == null) {
        if (clearBinding) {
          await txn.delete('sync_metadata');
          await txn.delete('sync_outbox');
          await txn.delete('sync_conflicts');
          await txn.delete('sync_versions');
          return;
        }
        await txn.delete(
          'sync_metadata',
          where: 'key IN (?, ?, ?, ?)',
          whereArgs: [
            'active_account_uid',
            'active_account_email',
            'active_account_username',
            'active_account_avatar',
          ],
        );
        return;
      }
      final bound = await txn.query(
        'sync_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['bound_account_uid'],
        limit: 1,
      );
      final boundUid = bound.isEmpty ? null : bound.first['value'] as String;
      if (resetState || (boundUid != null && boundUid != account.uid)) {
        await txn.delete('sync_outbox');
        await txn.delete('sync_conflicts');
        await txn.delete('sync_versions');
      }
      await txn.insert('sync_metadata', {
        'key': 'bound_account_uid',
        'value': account.uid,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('sync_metadata', {
        'key': 'active_account_uid',
        'value': account.uid,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('sync_metadata', {
        'key': 'active_account_email',
        'value': account.email,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (account.username case final username?) {
        await txn.insert('sync_metadata', {
          'key': 'active_account_username',
          'value': username,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await txn.delete(
          'sync_metadata',
          where: 'key = ?',
          whereArgs: ['active_account_username'],
        );
      }
      if (account.avatarFileId case final avatar?) {
        await txn.insert('sync_metadata', {
          'key': 'active_account_avatar',
          'value': avatar,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await txn.delete(
          'sync_metadata',
          where: 'key = ?',
          whereArgs: ['active_account_avatar'],
        );
      }
    });
    _syncChanges.add(null);
  }

  Future<String?> boundSyncAccountUid() async {
    final rows = await _db.query(
      'sync_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['bound_account_uid'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<SyncAccount?> activeSyncAccount() async {
    final rows = await _db.query(
      'sync_metadata',
      where: 'key IN (?, ?, ?, ?)',
      whereArgs: [
        'active_account_uid',
        'active_account_email',
        'active_account_username',
        'active_account_avatar',
      ],
    );
    final values = {for (final row in rows) row['key']: row['value']};
    final uid = values['active_account_uid'] as String?;
    if (uid == null || uid.isEmpty) return null;
    return SyncAccount(
      uid: uid,
      email: values['active_account_email'] as String? ?? '',
      username: values['active_account_username'] as String?,
      avatarFileId: values['active_account_avatar'] as String?,
    );
  }

  Future<int> syncCursor(String uid) async {
    final rows = await _db.query(
      'sync_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['cursor:$uid'],
      limit: 1,
    );
    return rows.isEmpty ? 0 : int.tryParse(rows.first['value'] as String) ?? 0;
  }

  Future<void> setSyncCursor(String uid, int cursor) => _db.insert(
    'sync_metadata',
    {'key': 'cursor:$uid', 'value': '$cursor'},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<DateTime?> lastSyncAt(String uid) async {
    final rows = await _db.query(
      'sync_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['last_sync:$uid'],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : DateTime.tryParse(rows.first['value'] as String);
  }

  Future<void> setLastSyncAt(String uid, DateTime value) => _db.insert(
    'sync_metadata',
    {'key': 'last_sync:$uid', 'value': value.toUtc().toIso8601String()},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<List<SyncMutation>> pendingSyncMutations({
    int limit = 100,
    List<String>? entityTypes,
    List<String>? settingGroups,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (entityTypes != null || settingGroups != null) {
      if (entityTypes?.isNotEmpty == true) {
        clauses.add(
          'entity_type IN (${List.filled(entityTypes!.length, "?").join(",")})',
        );
        args.addAll(entityTypes);
      }
      if (settingGroups?.isNotEmpty == true) {
        clauses.add(
          '(entity_type=? AND entity_id IN (${List.filled(settingGroups!.length, "?").join(",")}))',
        );
        args.add(SyncEntityType.settingGroup.name);
        args.addAll(settingGroups);
      }
      if (clauses.isEmpty) return [];
    }
    final rows = await _db.query(
      'sync_outbox',
      where: clauses.isEmpty ? null : clauses.join(' OR '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(_mutationFromRow).toList();
  }

  Future<int> pendingSyncMutationCount() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM sync_outbox'),
      ) ??
      0;

  Future<int> syncConflictCount() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM sync_conflicts'),
      ) ??
      0;

  Future<List<SyncConflict>> syncConflicts() async {
    final rows = await _db.query('sync_conflicts', orderBy: 'created_at ASC');
    return rows
        .map(
          (row) => SyncConflict(
            id: row['id'] as String,
            local: SyncMutation.fromJson(
              jsonDecode(row['local_mutation'] as String)
                  as Map<String, dynamic>,
            ),
            remote: SyncEntity.fromJson(
              jsonDecode(row['remote_entity'] as String)
                  as Map<String, dynamic>,
            ),
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> storeSyncConflicts(List<SyncConflict> conflicts) async {
    await _db.transaction((txn) async {
      for (final conflict in conflicts) {
        await txn.insert('sync_conflicts', {
          'id': conflict.id,
          'entity_type': conflict.local.entity.type.name,
          'entity_id': conflict.local.entity.id,
          'local_mutation': jsonEncode(conflict.local.toJson()),
          'remote_entity': jsonEncode(conflict.remote.toJson()),
          'created_at': conflict.createdAt.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.delete(
          'sync_outbox',
          where: 'mutation_id = ?',
          whereArgs: [conflict.local.mutationId],
        );
      }
    });
  }

  Future<void> acknowledgeSyncMutations(
    Map<String, int> accepted, {
    List<SyncMutation> sent = const [],
  }) async {
    if (accepted.isEmpty) return;
    final sentById = {
      for (final mutation in sent) mutation.mutationId: mutation,
    };
    await _db.transaction((txn) async {
      for (final entry in accepted.entries) {
        final rows = await txn.query(
          'sync_outbox',
          where: 'mutation_id = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        final sentMutation = sentById[entry.key];
        if (rows.isEmpty && sentMutation == null) continue;
        final type = rows.isEmpty
            ? sentMutation!.entity.type.name
            : rows.first['entity_type'] as String;
        final entityId = rows.isEmpty
            ? sentMutation!.entity.id
            : rows.first['entity_id'] as String;
        await txn.insert('sync_versions', {
          'entity_type': type,
          'entity_id': entityId,
          'revision': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.delete(
          'sync_outbox',
          where: 'mutation_id = ?',
          whereArgs: [entry.key],
        );
        if (sentMutation != null) {
          await txn.rawUpdate(
            'UPDATE sync_outbox SET base_revision = ? '
            'WHERE entity_type = ? AND entity_id = ? AND base_revision = ?',
            [
              entry.value,
              sentMutation.entity.type.name,
              sentMutation.entity.id,
              sentMutation.baseRevision,
            ],
          );
        }
      }
    });
  }

  Future<List<SyncEntity>> localCourseSyncEntities({
    bool includeDeleted = false,
  }) async {
    final rows = await _db.query(
      _tableName,
      where: includeDeleted ? null : 'deleted_at IS NULL',
    );
    final revisions = await _syncRevisionMap();
    final aliases = await reminderSessionAliases();
    return [
      for (final row in rows)
        SyncEntity(
          type: SyncEntityType.courseSession,
          id: row['id'] as String,
          payload: {
            ...courseSessionSyncPayload(CourseSession.fromMap(row)),
            if (aliases.containsKey(row['id']))
              'statisticsSourceId': aliases[row['id']],
          },
          revision:
              revisions['${SyncEntityType.courseSession.name}|${row['id']}'] ??
              0,
          deleted: row['deleted_at'] != null,
        ),
    ];
  }

  Future<void> enqueueSyncEntity(
    SyncEntity entity, {
    SyncOperation operation = SyncOperation.upsert,
  }) async {
    await _db.transaction((txn) => _queueSyncEntity(txn, entity, operation));
    _syncChanges.add(null);
  }

  Future<void> discardPendingSyncEntity(SyncEntity entity) async {
    await _db.transaction((txn) async {
      for (final table in ['sync_outbox', 'sync_conflicts']) {
        await txn.delete(
          table,
          where: 'entity_type=? AND entity_id=?',
          whereArgs: [entity.type.name, entity.id],
        );
      }
    });
  }

  Future<void> applyRemoteEntities(List<SyncEntity> entities) async {
    await _db.transaction((txn) async {
      for (final entity in entities) {
        if (entity.type == SyncEntityType.courseSession) {
          if (entity.payload['statisticsSourceId'] is String) {
            await txn.insert(
              'reminder_session_alias',
              {
                'session_id': entity.id,
                'stable_id': entity.payload['statisticsSourceId'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          if (entity.deleted) {
            await txn.update(
              _tableName,
              {'deleted_at': DateTime.now().toIso8601String()},
              where: 'id = ?',
              whereArgs: [entity.id],
            );
          } else {
            await txn.insert(
              _tableName,
              courseSessionFromSyncPayload(entity.payload).toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } else if (entity.type == SyncEntityType.statistic) {
          await _mergeStatistic(
            txn,
            await _statisticsOwner(txn),
            entity.id,
            entity.payload,
          );
        } else if (entity.type == SyncEntityType.deadline) {
          if (entity.deleted) {
            final changed = await txn.update(
              'deadlines',
              {'deleted_at': DateTime.now().toUtc().toIso8601String()},
              where: 'id=?',
              whereArgs: [entity.id],
            );
            if (changed == 0) {
              await txn.insert('deadlines', {
                'id': entity.id,
                'subject': '',
                'title': '',
                'due_at': DateTime.fromMillisecondsSinceEpoch(
                  0,
                  isUtc: true,
                ).toIso8601String(),
                'lead_minutes': '[]',
                'deleted_at': DateTime.now().toUtc().toIso8601String(),
              });
            }
          } else {
            await txn.insert(
              'deadlines',
              Deadline.fromSyncPayload(entity.payload).toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        await txn.insert('sync_versions', {
          'entity_type': entity.type.name,
          'entity_id': entity.id,
          'revision': entity.revision,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> resolveSyncConflict(
    SyncConflict conflict, {
    required bool useLocal,
  }) async {
    if (useLocal) {
      final entity = conflict.local.entity;
      await _db.transaction((txn) async {
        await txn.delete(
          'sync_conflicts',
          where: 'id = ?',
          whereArgs: [conflict.id],
        );
        await txn.delete(
          'sync_outbox',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: [entity.type.name, entity.id],
        );
        await txn.insert('sync_versions', {
          'entity_type': entity.type.name,
          'entity_id': entity.id,
          'revision': conflict.remote.revision,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSyncEntity(
          txn,
          entity,
          conflict.local.operation,
          baseRevision: conflict.remote.revision,
        );
      });
      return;
    }
    await applyRemoteEntities([conflict.remote]);
    await _db.transaction((txn) async {
      await txn.delete(
        'sync_conflicts',
        where: 'id = ?',
        whereArgs: [conflict.id],
      );
      await txn.delete(
        'sync_outbox',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [conflict.remote.type.name, conflict.remote.id],
      );
    });
  }

  Future<Map<String, int>> _syncRevisionMap() async => {
    for (final row in await _db.query('sync_versions'))
      '${row['entity_type']}|${row['entity_id']}': row['revision'] as int,
  };

  static SyncMutation _mutationFromRow(Map<String, Object?> row) {
    final type = SyncEntityType.values.byName(row['entity_type'] as String);
    final operation = SyncOperation.values.byName(row['operation'] as String);
    return SyncMutation(
      mutationId: row['mutation_id'] as String,
      operation: operation,
      baseRevision: row['base_revision'] as int,
      entity: SyncEntity(
        type: type,
        id: row['entity_id'] as String,
        schemaVersion: row['schema_version'] as int,
        deleted: operation == SyncOperation.delete,
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String) as Map,
        ),
      ),
    );
  }

  static Future<void> _queueCourseMutation(
    Transaction txn,
    CourseSession session,
    SyncOperation operation,
  ) async {
    final aliases = await txn.query(
      'reminder_session_alias',
      where: 'session_id=?',
      whereArgs: [session.id],
    );
    await _queueSyncEntity(
      txn,
      SyncEntity(
        type: SyncEntityType.courseSession,
        id: session.id,
        payload: {
          ...courseSessionSyncPayload(session),
          if (aliases.isNotEmpty)
            'statisticsSourceId': aliases.first['stable_id'],
        },
        deleted: operation == SyncOperation.delete,
      ),
      operation,
    );
  }

  static Future<void> _queueSyncEntity(
    DatabaseExecutor txn,
    SyncEntity entity,
    SyncOperation operation, {
    int? baseRevision,
  }) async {
    final account = await txn.query(
      'sync_metadata',
      columns: ['value'],
      where: 'key IN (?, ?)',
      whereArgs: ['active_account_uid', 'bound_account_uid'],
      limit: 1,
    );
    if (account.isEmpty) return;
    final pending = await txn.query(
      'sync_outbox',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entity.type.name, entity.id],
      limit: 1,
    );
    var revision = baseRevision;
    revision ??= pending.isEmpty ? null : pending.first['base_revision'] as int;
    if (revision == null) {
      final rows = await txn.query(
        'sync_versions',
        columns: ['revision'],
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entity.type.name, entity.id],
        limit: 1,
      );
      revision = rows.isEmpty ? 0 : rows.first['revision'] as int;
    }
    if (pending.isNotEmpty) {
      await txn.delete(
        'sync_outbox',
        where: 'mutation_id = ?',
        whereArgs: [pending.first['mutation_id']],
      );
    }
    await txn.insert('sync_outbox', {
      'mutation_id': _uuid.v4(),
      'entity_type': entity.type.name,
      'entity_id': entity.id,
      'operation': operation.name,
      'base_revision': revision,
      'schema_version': entity.schemaVersion,
      'payload': jsonEncode(entity.payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> close() async {
    await _syncChanges.close();
    await _db.close();
  }

  static String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
