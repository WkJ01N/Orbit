import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/course_operation.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase(this._db);

  final Database _db;

  static const _tableName = 'course_sessions';

  static Future<AppDatabase> open(String databasePath) async {
    final db = await openDatabase(
      p.join(databasePath, 'orbit.db'),
      version: 5,
      onCreate: (database, version) async {
        await _createSchema(database);
      },
      onOpen: _createReminderSchema,
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
    final batch = _db.batch();
    for (final session in sessions) {
      batch.insert(
        _tableName,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateSession(CourseSession session) async {
    await _db.insert(
      _tableName,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Transactionally deletes [deleteIds] then upserts [upsert]. Used for
  /// conflict-overwrite saves and strategy-based imports so that removing the
  /// old rows and writing the new ones cannot leave the table half-updated.
  Future<void> replaceSessions({
    required List<String> deleteIds,
    required List<CourseSession> upsert,
    Map<String, String> identityChanges = const {},
  }) async {
    await _db.transaction((txn) async {
      for (final change in identityChanges.entries) {
        final updated = upsert.where((s) => s.id == change.value).firstOrNull;
        if (updated != null) {
          await _rememberReminderIdentity(txn, change.key, updated);
        }
      }
      if (deleteIds.isNotEmpty) {
        final placeholders = List.filled(deleteIds.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE $_tableName SET deleted_at = ? '
          'WHERE id IN ($placeholders) AND deleted_at IS NULL',
          [DateTime.now().toIso8601String(), ...deleteIds],
        );
      }
      for (final session in upsert) {
        await txn.insert(
          _tableName,
          session.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> updateSessionWithIdChange(
    String oldId,
    CourseSession session,
  ) async {
    await _db.transaction((txn) async {
      await _rememberReminderIdentity(txn, oldId, session);
      await txn.delete(_tableName, where: 'id = ?', whereArgs: [oldId]);
      await txn.insert(
        _tableName,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
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

  Future<List<CourseSession>> getAllSessions() async {
    final rows = await _db.query(
      _tableName,
      where: 'deleted_at IS NULL',
      orderBy: 'start_at ASC',
    );
    return rows.map(CourseSession.fromMap).toList();
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
    return rows.map(CourseSession.fromMap).toList();
  }

  Future<List<CourseSession>> getUpcomingSessions(DateTime from) async {
    final rows = await _db.query(
      _tableName,
      where: 'end_at > ? AND deleted_at IS NULL',
      whereArgs: [from.toIso8601String()],
      orderBy: 'start_at ASC',
    );
    return rows.map(CourseSession.fromMap).toList();
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
    return rows.map(CourseSession.fromMap).toList();
  }

  Future<int> clearAllSessions() {
    return _softDeleteWhere('deleted_at IS NULL', const []);
  }

  Future<int> deleteSessionById(String id) {
    return _softDeleteWhere('id = ? AND deleted_at IS NULL', [id]);
  }

  Future<int> countEndedSessions(DateTime before) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_tableName '
      'WHERE end_at <= ? AND deleted_at IS NULL',
      [before.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteEndedSessions(DateTime before) async {
    return _softDeleteWhere('end_at <= ? AND deleted_at IS NULL', [
      before.toIso8601String(),
    ]);
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
    DateTime endInclusive,
  ) async {
    return _softDeleteWhere(
      'start_at >= ? AND end_at <= ? AND deleted_at IS NULL',
      [startInclusive.toIso8601String(), endInclusive.toIso8601String()],
    );
  }

  Future<void> replaceAllActiveSessions(List<CourseSession> sessions) async {
    await _db.transaction((txn) async {
      await txn.update(_tableName, {
        'deleted_at': DateTime.now().toIso8601String(),
      }, where: 'deleted_at IS NULL');
      for (final session in sessions) {
        await txn.insert(
          _tableName,
          session.copyWith(clearDeletedAt: true).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<CourseSession>> getDeletedSessions() async {
    final rows = await _db.query(
      _tableName,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC, start_at ASC',
    );
    return rows.map(CourseSession.fromMap).toList();
  }

  Future<int> restoreDeletedSessionIds(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final placeholders = List.filled(ids.length, '?').join(',');
    return _db.rawUpdate(
      'UPDATE $_tableName SET deleted_at = NULL '
      'WHERE id IN ($placeholders) AND deleted_at IS NOT NULL',
      ids,
    );
  }

  Future<int> purgeDeletedBefore(DateTime cutoff) {
    return _db.delete(
      _tableName,
      where: 'deleted_at IS NOT NULL AND deleted_at <= ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  Future<int> purgeAllDeleted() {
    return _db.delete(_tableName, where: 'deleted_at IS NOT NULL');
  }

  Future<int> softDeleteSessionIds(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final placeholders = List.filled(ids.length, '?').join(',');
    return _db.rawUpdate(
      'UPDATE $_tableName SET deleted_at = ? '
      'WHERE id IN ($placeholders) AND deleted_at IS NULL',
      [DateTime.now().toIso8601String(), ...ids],
    );
  }

  Future<int> _softDeleteWhere(String where, List<Object?> whereArgs) {
    return _db.update(
      _tableName,
      {'deleted_at': DateTime.now().toIso8601String()},
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<void> close() => _db.close();

  static String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
