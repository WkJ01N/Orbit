import 'package:orbit/models/course_session.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase(this._db);

  final Database _db;

  static const _tableName = 'course_sessions';

  static Future<AppDatabase> open(String databasePath) async {
    final db = await openDatabase(
      p.join(databasePath, 'orbit.db'),
      version: 3,
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
        deleted_at TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_course_sessions_start_at ON $_tableName(start_at)',
    );
    await database.execute(
      'CREATE INDEX idx_course_sessions_date ON $_tableName(date)',
    );
    await _createActiveIndexes(database);
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
  }) async {
    await _db.transaction((txn) async {
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
