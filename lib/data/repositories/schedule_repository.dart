import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/xlsx_parser.dart';

class ScheduleRepository {
  ScheduleRepository(this._database, this._parser);

  final AppDatabase _database;
  final XlsxParser _parser;

  Future<List<CourseSession>> importFromFiles(
    List<({List<int> bytes, String fileName})> files,
  ) async {
    final sessions = <CourseSession>[];
    for (final file in files) {
      final parsed = _parser.parseBytes(
        file.bytes,
        sourceFile: file.fileName,
      );
      sessions.addAll(parsed);
    }
    return importParsedSessions(sessions);
  }

  Future<List<CourseSession>> importParsedSessions(
    List<CourseSession> sessions,
  ) async {
    await _database.upsertSessions(sessions);
    return sessions;
  }

  Future<List<CourseSession>> getAllSessions() {
    return _database.getAllSessions();
  }

  Future<List<CourseSession>> getUpcomingSessions({DateTime? from}) {
    return _database.getUpcomingSessions(from ?? DateTime.now());
  }

  Future<List<CourseSession>> getSessionsForWeek(DateTime weekStart) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 6));
    return _database.getSessionsBetween(start, end);
  }

  Future<void> clearAll() {
    return _database.clearAllSessions();
  }

  Future<void> deleteSession(String id) {
    return _database.deleteSessionById(id);
  }

  Future<void> updateSession(
    CourseSession original,
    CourseSession updated,
  ) async {
    final newId = updated.computeId();
    final sessionWithId = updated.copyWith(id: newId);
    if (newId != original.id) {
      await _database.updateSessionWithIdChange(original.id, sessionWithId);
    } else {
      await _database.updateSession(sessionWithId);
    }
  }

  Future<int> countEndedSessions({DateTime? before}) {
    return _database.countEndedSessions(before ?? DateTime.now());
  }

  Future<int> deleteEndedSessions({DateTime? before}) {
    return _database.deleteEndedSessions(before ?? DateTime.now());
  }

  Future<int> countSessionsFullyInRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) {
    return _database.countSessionsFullyInRange(startInclusive, endInclusive);
  }

  Future<int> deleteSessionsFullyInRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) {
    return _database.deleteSessionsFullyInRange(startInclusive, endInclusive);
  }

  Future<DateTime?> getEarliestWeekStart() async {
    final earliest = await _database.getEarliestSessionDate();
    if (earliest == null) {
      return null;
    }
    return weekStartFor(earliest);
  }
}
