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
      version: 2,
      onCreate: (database, version) async {
        await _createSchema(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            'ALTER TABLE $_tableName ADD COLUMN note TEXT',
          );
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
        note TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_course_sessions_start_at ON $_tableName(start_at)',
    );
    await database.execute(
      'CREATE INDEX idx_course_sessions_date ON $_tableName(date)',
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

  Future<void> updateSessionWithIdChange(
    String oldId,
    CourseSession session,
  ) async {
    await _db.transaction((txn) async {
      await txn.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [oldId],
      );
      await txn.insert(
        _tableName,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<DateTime?> getEarliestSessionDate() async {
    final result = await _db.rawQuery(
      'SELECT MIN(date) AS min_date FROM $_tableName',
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
      orderBy: 'start_at ASC',
    );
    return rows.map(CourseSession.fromMap).toList();
  }

  Future<CourseSession?> getSessionById(String id) async {
    final rows = await _db.query(
      _tableName,
      where: 'id = ?',
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
          'course_name LIKE ? OR course_code LIKE ? OR room LIKE ? OR teachers LIKE ?',
      whereArgs: [pattern, pattern, pattern, pattern],
      orderBy: 'start_at ASC',
      limit: 100,
    );
    return rows.map(CourseSession.fromMap).toList();
  }

  Future<List<CourseSession>> getUpcomingSessions(DateTime from) async {
    final rows = await _db.query(
      _tableName,
      where: 'start_at > ?',
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
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        _dateKey(startInclusive),
        _dateKey(endInclusive),
      ],
      orderBy: 'start_at ASC',
    );
    return rows.map(CourseSession.fromMap).toList();
  }

  Future<void> clearAllSessions() async {
    await _db.delete(_tableName);
  }

  Future<void> deleteSessionById(String id) async {
    await _db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countEndedSessions(DateTime before) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_tableName WHERE end_at <= ?',
      [before.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteEndedSessions(DateTime before) async {
    return _db.delete(
      _tableName,
      where: 'end_at <= ?',
      whereArgs: [before.toIso8601String()],
    );
  }

  Future<int> countSessionsFullyInRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_tableName WHERE start_at >= ? AND end_at <= ?',
      [startInclusive.toIso8601String(), endInclusive.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteSessionsFullyInRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    return _db.delete(
      _tableName,
      where: 'start_at >= ? AND end_at <= ?',
      whereArgs: [
        startInclusive.toIso8601String(),
        endInclusive.toIso8601String(),
      ],
    );
  }

  Future<void> close() => _db.close();

  static String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
