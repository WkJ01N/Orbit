import 'package:orbit/core/l10n/zh_variant.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/xlsx_exporter.dart';
import 'package:orbit/services/xlsx_parser.dart';

/// How imported sessions are merged into weeks that already contain classes.
enum ImportMergeStrategy {
  /// Delete every existing class in the overlapping weeks, then write the
  /// imported classes for those weeks.
  replaceWeek,

  /// Insert imported classes, replacing only existing classes whose time slot
  /// overlaps an imported class. Non-conflicting classes in the week are kept.
  mergeOverwrite,
}

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

  /// Weeks (Monday anchors) that appear in both [sessions] and the stored
  /// schedule. An empty result means the import touches no occupied week and
  /// can be applied without asking the user to pick a strategy.
  Future<Set<DateTime>> findOverlappingWeeks(
    List<CourseSession> sessions,
  ) async {
    if (sessions.isEmpty) {
      return {};
    }
    final existing = await getAllSessions();
    if (existing.isEmpty) {
      return {};
    }
    final existingWeeks = existing.map((s) => weekStartFor(s.date)).toSet();
    final importWeeks = sessions.map((s) => weekStartFor(s.date)).toSet();
    return importWeeks.intersection(existingWeeks);
  }

  Future<List<CourseSession>> importParsedSessionsWithStrategy(
    List<CourseSession> sessions,
    ImportMergeStrategy strategy,
  ) async {
    if (sessions.isEmpty) {
      return sessions;
    }
    final existing = await getAllSessions();
    final List<String> deleteIds;
    if (strategy == ImportMergeStrategy.replaceWeek) {
      final importWeeks = sessions.map((s) => weekStartFor(s.date)).toSet();
      deleteIds = existing
          .where((s) => importWeeks.contains(weekStartFor(s.date)))
          .map((s) => s.id)
          .toList();
    } else {
      final importIds = sessions.map((s) => s.id).toSet();
      deleteIds = existing
          .where((s) => !importIds.contains(s.id))
          .where((s) => sessions.any((imp) => _timeOverlaps(s, imp)))
          .map((s) => s.id)
          .toList();
    }
    await _database.replaceSessions(deleteIds: deleteIds, upsert: sessions);
    return sessions;
  }

  bool _timeOverlaps(CourseSession a, CourseSession b) {
    if (!_sameDate(a.date, b.date)) {
      return false;
    }
    return a.startAt.isBefore(b.endAt) && b.startAt.isBefore(a.endAt);
  }

  Future<List<CourseSession>> getAllSessions() {
    return _database.getAllSessions();
  }

  Future<CourseSession?> getSessionById(String id) {
    return _database.getSessionById(id);
  }

  static const _searchResultLimit = 100;

  /// Searches across course name, code, room and teachers. Both the query and
  /// the stored text are folded to Simplified Chinese first so a query typed in
  /// Simplified matches Traditional text and vice versa.
  Future<List<CourseSession>> searchSessions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }
    final needle = foldToSimplified(trimmed.toLowerCase());
    final all = await _database.getAllSessions();
    final matches = <CourseSession>[];
    for (final session in all) {
      final haystack = foldToSimplified(
        [
          session.courseName,
          session.courseCode,
          session.room,
          session.teachers.join(' '),
        ].join(' ').toLowerCase(),
      );
      if (haystack.contains(needle)) {
        matches.add(session);
        if (matches.length >= _searchResultLimit) {
          break;
        }
      }
    }
    return matches;
  }

  Future<List<int>> exportToXlsxBytes() async {
    final sessions = await getAllSessions();
    return XlsxExporter().exportBytes(sessions);
  }

  Future<String> exportToJsonBackup() async {
    final sessions = await getAllSessions();
    return ScheduleBackupService().encodeToJson(sessions);
  }

  Future<List<CourseSession>> importFromJsonBackup(String raw) async {
    final sessions = ScheduleBackupService().decodeFromJson(raw);
    return importParsedSessionsWithStrategy(
      sessions,
      ImportMergeStrategy.mergeOverwrite,
    );
  }

  Future<void> insertSession(CourseSession session) async {
    await _database.upsertSessions([session]);
  }

  /// Saves [session], overwriting any existing class whose time slot overlaps
  /// (same date, intersecting interval). When editing, pass the [original] so
  /// its row is replaced even if the computed id changed. Returns the number of
  /// distinct overlapping classes that were removed.
  Future<int> saveSessionWithConflictResolution(
    CourseSession session, {
    CourseSession? original,
  }) async {
    final newId = session.computeId();
    final sessionWithId = session.copyWith(id: newId);
    final existing = await getAllSessions();
    final conflicts = existing.where((other) {
      if (other.id == newId) {
        return false;
      }
      if (original != null && other.id == original.id) {
        return false;
      }
      return _timeOverlaps(other, sessionWithId);
    }).toList();

    final deleteIds = conflicts.map((s) => s.id).toList();
    if (original != null && original.id != newId) {
      deleteIds.add(original.id);
    }

    await _database.replaceSessions(
      deleteIds: deleteIds,
      upsert: [sessionWithId],
    );
    return conflicts.length;
  }

  Future<bool> hasTimeConflict(CourseSession candidate, {String? excludeId}) async {
    final sessions = await getAllSessions();
    for (final existing in sessions) {
      if (excludeId != null && existing.id == excludeId) {
        continue;
      }
      if (!_sameDate(existing.date, candidate.date)) {
        continue;
      }
      if (existing.startAt.isBefore(candidate.endAt) &&
          candidate.startAt.isBefore(existing.endAt)) {
        return true;
      }
    }
    return false;
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
