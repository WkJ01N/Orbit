import 'package:orbit/core/l10n/zh_variant.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/portable_settings.dart';
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
      final parsed = _parser.parseBytes(file.bytes, sourceFile: file.fileName);
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
      final importsByDate = <String, List<CourseSession>>{};
      for (final session in sessions) {
        final key =
            '${session.date.year}-${session.date.month}-${session.date.day}';
        importsByDate.putIfAbsent(key, () => []).add(session);
      }
      deleteIds = existing
          .where((s) => !importIds.contains(s.id))
          .where((s) {
            final key = '${s.date.year}-${s.date.month}-${s.date.day}';
            final sameDayImports = importsByDate[key];
            if (sameDayImports == null) {
              return false;
            }
            return sameDayImports.any((imp) => _timeOverlaps(s, imp));
          })
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

  Future<List<CourseSession>> getDeletedSessions() {
    return _database.getDeletedSessions();
  }

  Future<List<CourseSession>> getCourseSeries(
    CourseSession selected,
    CourseOperationScope scope,
  ) async {
    if (scope == CourseOperationScope.single) return [selected];
    final key = CourseSeriesKey.fromSession(selected);
    final sessions = await getAllSessions();
    return sessions.where((session) {
      if (CourseSeriesKey.fromSession(session) != key) return false;
      return scope != CourseOperationScope.fromSelected ||
          !session.startAt.isBefore(selected.startAt);
    }).toList();
  }

  Future<CourseOperationPreview> previewCourseSeriesUpdate({
    required CourseSession selected,
    required CourseSession changes,
    required CourseOperationScope scope,
  }) async {
    final prepared = await _prepareCourseSeriesUpdate(
      selected: selected,
      changes: changes,
      scope: scope,
    );
    return CourseOperationPreview(
      targetCount: prepared.targets.length,
      conflictCount: prepared.conflictIds.length,
      firstDate: prepared.targets.first.date,
      lastDate: prepared.targets.last.date,
    );
  }

  Future<CourseOperationResult> updateCourseSeries({
    required CourseSession selected,
    required CourseSession changes,
    required CourseOperationScope scope,
  }) async {
    final prepared = await _prepareCourseSeriesUpdate(
      selected: selected,
      changes: changes,
      scope: scope,
    );
    await _database.replaceSessions(
      deleteIds: [
        ...prepared.targets.map((session) => session.id),
        ...prepared.conflictIds,
      ],
      upsert: prepared.updated,
    );
    return CourseOperationResult(
      affectedCount: prepared.targets.length,
      conflictCount: prepared.conflictIds.length,
    );
  }

  Future<CourseOperationResult> deleteCourseSeries({
    required CourseSession selected,
    required CourseOperationScope scope,
  }) async {
    final targets = await getCourseSeries(selected, scope);
    final deleted = await _database.softDeleteSessionIds(
      targets.map((session) => session.id).toList(),
    );
    return CourseOperationResult(affectedCount: deleted);
  }

  Future<RestoreDeletedResult> restoreDeletedSessions(List<String> ids) async {
    final requested = ids.toSet();
    final deleted = (await _database.getDeletedSessions())
        .where((session) => requested.contains(session.id))
        .toList();
    final active = await getAllSessions();
    final restorable = <CourseSession>[];
    var skipped = 0;
    for (final session in deleted) {
      final conflicts = active.any((other) => _timeOverlaps(other, session));
      if (conflicts) {
        skipped++;
      } else {
        restorable.add(session);
      }
    }
    final restored = await _database.restoreDeletedSessionIds(
      restorable.map((session) => session.id).toList(),
    );
    return RestoreDeletedResult(restored: restored, skipped: skipped);
  }

  Future<int> purgeExpiredDeletedSessions({DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 7));
    return _database.purgeDeletedBefore(cutoff);
  }

  Future<int> purgeAllDeletedSessions() => _database.purgeAllDeleted();

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

  Future<String> exportToJsonBackup({PortableSettings? settings}) async {
    final sessions = await getAllSessions();
    return ScheduleBackupService().encodeToJson(sessions, settings: settings);
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

  Future<bool> hasTimeConflict(
    CourseSession candidate, {
    String? excludeId,
  }) async {
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

  Future<int> clearAll() {
    return _database.clearAllSessions();
  }

  Future<int> deleteSession(String id) {
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

  Future<List<CourseSession>> restoreBackupSessions(
    List<CourseSession> sessions, {
    required ImportMergeStrategy strategy,
  }) async {
    if (strategy == ImportMergeStrategy.replaceWeek) {
      await _database.replaceAllActiveSessions(sessions);
      return sessions;
    }
    return importParsedSessionsWithStrategy(
      sessions,
      ImportMergeStrategy.mergeOverwrite,
    );
  }

  Future<
    ({
      List<CourseSession> targets,
      List<CourseSession> updated,
      List<String> conflictIds,
    })
  >
  _prepareCourseSeriesUpdate({
    required CourseSession selected,
    required CourseSession changes,
    required CourseOperationScope scope,
  }) async {
    final targets = await getCourseSeries(selected, scope);
    targets.sort((a, b) => a.startAt.compareTo(b.startAt));
    final updated = targets.map((target) {
      final startAt = DateTime(
        target.date.year,
        target.date.month,
        target.date.day,
        changes.startAt.hour,
        changes.startAt.minute,
      );
      final endAt = DateTime(
        target.date.year,
        target.date.month,
        target.date.day,
        changes.endAt.hour,
        changes.endAt.minute,
      );
      final next = target.copyWith(
        courseName: changes.courseName,
        room: changes.room,
        teachers: changes.teachers,
        faculty: changes.faculty,
        startAt: startAt,
        endAt: endAt,
        clearDeletedAt: true,
      );
      return next.copyWith(id: next.computeId());
    }).toList();
    final targetIds = targets.map((session) => session.id).toSet();
    final active = await getAllSessions();
    final conflictIds = active
        .where((session) => !targetIds.contains(session.id))
        .where(
          (session) =>
              updated.any((candidate) => _timeOverlaps(session, candidate)),
        )
        .map((session) => session.id)
        .toSet()
        .toList();
    return (targets: targets, updated: updated, conflictIds: conflictIds);
  }
}
