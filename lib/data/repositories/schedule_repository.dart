import 'package:orbit/core/l10n/zh_variant.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/batch_course.dart';
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
    ImportMergeStrategy strategy, {
    bool deleteStatistics = false,
  }) async {
    if (sessions.isEmpty) {
      return sessions;
    }
    final existing = await getAllSessions();
    final List<String> deleteIds;
    if (strategy == ImportMergeStrategy.replaceWeek) {
      final importWeeks = sessions.map((s) => weekStartFor(s.date)).toSet();
      deleteIds = existing
          .where((s) => !s.isExam && importWeeks.contains(weekStartFor(s.date)))
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
    await _database.replaceSessions(
      deleteIds: deleteIds,
      upsert: sessions,
      deleteStatistics: deleteStatistics,
    );
    return sessions;
  }

  bool _timeOverlaps(CourseSession a, CourseSession b) {
    if (a.kind != b.kind || !_sameDate(a.date, b.date)) {
      return false;
    }
    return a.startAt.isBefore(b.endAt) && b.startAt.isBefore(a.endAt);
  }

  Future<int> archiveCourse(
    CourseSession selected, {
    required bool wholeCourse,
    bool hide = true,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final all = await getAllSessions();
    final key = CourseSeriesKey.fromSession(selected);
    final ids = all
        .where(
          (s) =>
              !s.archived &&
              !s.endAt.isAfter(now) &&
              (wholeCourse
                  ? CourseSeriesKey.fromSession(s) == key &&
                        s.semester == selected.semester
                  : s.id == selected.id),
        )
        .map((s) => s.id)
        .toList();
    return _database.updateArchive(
      sessionIds: ids,
      action: ArchiveMutation.archive,
      hide: hide,
      at: now,
    );
  }

  Future<List<CourseSession>> getUnarchivedEndedSessions({DateTime? at}) async {
    final now = at ?? DateTime.now();
    return (await getAllSessions())
        .where((session) => !session.archived && !session.endAt.isAfter(now))
        .toList();
  }

  /// Optional IDs keep a confirmation limited to the displayed snapshot.
  /// The transaction rechecks eligibility in case a class was edited meanwhile.
  Future<int> archiveEndedSessions({
    List<String>? sessionIds,
    bool hide = true,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final ids =
        sessionIds ??
        (await getUnarchivedEndedSessions(
          at: now,
        )).map((session) => session.id).toList();
    return _database.updateArchive(
      sessionIds: ids,
      action: ArchiveMutation.archive,
      hide: hide,
      at: now,
    );
  }

  Future<int> runAutoArchive(ArchiveSettings settings, {DateTime? at}) async {
    if (!settings.autoCourses && !settings.autoDeadlines) return 0;
    final now = at ?? DateTime.now();
    final sessions = settings.autoCourses
        ? await getAllSessions()
        : <CourseSession>[];
    final deadlines = settings.autoDeadlines
        ? await _database.getDeadlines()
        : <Deadline>[];
    final courseIds = sessions
        .where(
          (s) =>
              !s.archived &&
              !s.autoArchivePaused &&
              !s.endAt
                  .add(Duration(days: settings.courseDelayDays))
                  .isAfter(now),
        )
        .map((s) => s.id)
        .toList();
    final deadlineIds = deadlines
        .where(
          (d) =>
              !d.archived &&
              !d.autoArchivePaused &&
              d.completed &&
              !d.completedAt!
                  .add(Duration(days: settings.deadlineDelayDays))
                  .isAfter(now),
        )
        .map((d) => d.id)
        .toList();
    final courses = await _database.updateArchive(
      sessionIds: courseIds,
      action: ArchiveMutation.archive,
      hide: settings.hideCourses,
      at: now,
    );
    final ddl = await _database.updateArchive(
      deadlineIds: deadlineIds,
      action: ArchiveMutation.archive,
      hide: settings.hideDeadlines,
      at: now,
    );
    return courses + ddl;
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
      if (CourseSeriesKey.fromSession(session) != key ||
          session.semester != selected.semester) {
        return false;
      }
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
    bool deleteStatistics = false,
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
      deleteStatistics: deleteStatistics,
      identityChanges: {
        for (var i = 0; i < prepared.targets.length; i++)
          prepared.targets[i].id: prepared.updated[i].id,
      },
    );
    return CourseOperationResult(
      affectedCount: prepared.targets.length,
      conflictCount: prepared.conflictIds.length,
    );
  }

  Future<CourseOperationResult> deleteCourseSeries({
    required CourseSession selected,
    required CourseOperationScope scope,
    bool deleteStatistics = false,
  }) async {
    final targets = await getCourseSeries(selected, scope);
    final deleted = await _database.softDeleteSessionIds(
      targets.map((session) => session.id).toList(),
      deleteStatistics: deleteStatistics,
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

  Future<int> purgeAllDeletedSessions({bool deleteStatistics = false}) =>
      _database.purgeAllDeleted(deleteStatistics: deleteStatistics);

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
    return ScheduleBackupService().encodeToJson(
      sessions,
      deadlines: await _database.getDeadlines(),
      settings: settings,
    );
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
    bool deleteStatistics = false,
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
      deleteStatistics: deleteStatistics,
      identityChanges: original == null ? const {} : {original.id: newId},
    );
    return conflicts.length;
  }

  Future<CourseOperationPreview> previewRecurringCourseUpdate({
    required CourseSession selected,
    required CourseSession changes,
    required RecurringCourseEditScope scope,
  }) async {
    final prepared = await _prepareRecurringCourseUpdate(
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

  Future<CourseOperationResult> updateRecurringCourse({
    required CourseSession selected,
    required CourseSession changes,
    required RecurringCourseEditScope scope,
    bool deleteStatistics = false,
  }) async {
    final prepared = await _prepareRecurringCourseUpdate(
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
      deleteStatistics: deleteStatistics,
      identityChanges: {
        for (var i = 0; i < prepared.targets.length; i++)
          prepared.targets[i].id: prepared.updated[i].id,
      },
    );
    return CourseOperationResult(
      affectedCount: prepared.targets.length,
      conflictCount: prepared.conflictIds.length,
    );
  }

  Future<BatchCoursePreview> previewBatchCreate(
    List<CourseSession> generated,
  ) async {
    final existing = await getAllSessions();
    final conflicts = existing
        .where(
          (stored) =>
              generated.any((candidate) => _timeOverlaps(stored, candidate)),
        )
        .map((session) => session.id)
        .toSet();
    return BatchCoursePreview(
      generatedCount: generated.length,
      conflictCount: conflicts.length,
    );
  }

  Future<BatchCourseSaveResult> saveBatchSessions(
    List<CourseSession> generated, {
    required BatchConflictStrategy strategy,
    bool deleteStatistics = false,
  }) async {
    if (generated.isEmpty) {
      return const BatchCourseSaveResult(
        createdCount: 0,
        skippedCount: 0,
        overwrittenCount: 0,
      );
    }
    final existing = await getAllSessions();
    final conflictIds = <String>{};
    final conflictingCandidates = <String>{};
    for (final candidate in generated) {
      for (final stored in existing) {
        if (_timeOverlaps(stored, candidate)) {
          conflictIds.add(stored.id);
          conflictingCandidates.add(candidate.id);
        }
      }
    }
    final toInsert = strategy == BatchConflictStrategy.skip
        ? generated
              .where((session) => !conflictingCandidates.contains(session.id))
              .toList()
        : generated;
    await _database.replaceSessions(
      deleteIds: strategy == BatchConflictStrategy.overwrite
          ? conflictIds.toList()
          : const [],
      upsert: toInsert,
      deleteStatistics: deleteStatistics,
    );
    return BatchCourseSaveResult(
      createdCount: toInsert.length,
      skippedCount: generated.length - toInsert.length,
      overwrittenCount: strategy == BatchConflictStrategy.overwrite
          ? conflictIds.length
          : 0,
    );
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

  Future<int> clearAll({bool deleteStatistics = false}) {
    return _database.clearAllSessions(deleteStatistics: deleteStatistics);
  }

  Future<int> deleteSessionIds(
    Iterable<String> ids, {
    bool deleteStatistics = false,
  }) => _database.softDeleteSessionIds(
    ids.toSet().toList(),
    deleteStatistics: deleteStatistics,
  );

  Future<int> deleteSession(String id, {bool deleteStatistics = false}) {
    return _database.deleteSessionById(id, deleteStatistics: deleteStatistics);
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

  Future<int> deleteEndedSessions({
    DateTime? before,
    bool deleteStatistics = false,
  }) {
    return _database.deleteEndedSessions(
      before ?? DateTime.now(),
      deleteStatistics: deleteStatistics,
    );
  }

  Future<int> countSessionsFullyInRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) {
    return _database.countSessionsFullyInRange(startInclusive, endInclusive);
  }

  Future<int> deleteSessionsFullyInRange(
    DateTime startInclusive,
    DateTime endInclusive, {
    bool deleteStatistics = false,
  }) {
    return _database.deleteSessionsFullyInRange(
      startInclusive,
      endInclusive,
      deleteStatistics: deleteStatistics,
    );
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
    bool deleteStatistics = false,
  }) async {
    if (strategy == ImportMergeStrategy.replaceWeek) {
      await _database.replaceAllActiveSessions(
        sessions,
        deleteStatistics: deleteStatistics,
      );
      return sessions;
    }
    return importParsedSessionsWithStrategy(
      sessions,
      ImportMergeStrategy.mergeOverwrite,
      deleteStatistics: deleteStatistics,
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

  Future<
    ({
      List<CourseSession> targets,
      List<CourseSession> updated,
      List<String> conflictIds,
    })
  >
  _prepareRecurringCourseUpdate({
    required CourseSession selected,
    required CourseSession changes,
    required RecurringCourseEditScope scope,
  }) async {
    final seriesId = selected.recurrenceSeriesId;
    final meetingId = selected.recurrenceMeetingId;
    if (seriesId == null || meetingId == null) {
      throw StateError('Recurring course identity is missing');
    }
    final active = await getAllSessions();
    var targets = active
        .where(
          (session) =>
              CourseSeriesKey.fromSession(session) ==
                  CourseSeriesKey.fromSession(selected) &&
              session.semester == selected.semester,
        )
        .where((session) {
          return switch (scope) {
            RecurringCourseEditScope.single => session.id == selected.id,
            RecurringCourseEditScope.meetingFromSelected =>
              session.recurrenceMeetingId == meetingId &&
                  !session.startAt.isBefore(selected.startAt),
            RecurringCourseEditScope.meetingAll =>
              session.recurrenceMeetingId == meetingId,
            RecurringCourseEditScope.courseCommon => true,
          };
        })
        .toList();
    targets.sort((a, b) => a.startAt.compareTo(b.startAt));
    final commonOnly = scope == RecurringCourseEditScope.courseCommon;
    final updated = targets.map((target) {
      final startAt = commonOnly
          ? target.startAt
          : DateTime(
              target.date.year,
              target.date.month,
              target.date.day,
              changes.startAt.hour,
              changes.startAt.minute,
            );
      final endAt = commonOnly
          ? target.endAt
          : DateTime(
              target.date.year,
              target.date.month,
              target.date.day,
              changes.endAt.hour,
              changes.endAt.minute,
            );
      final next = target.copyWith(
        courseName: changes.courseName,
        courseCode: changes.courseCode,
        section: changes.section,
        room: commonOnly ? target.room : changes.room,
        teachers: changes.teachers,
        faculty: changes.faculty,
        classType: changes.classType,
        semester: changes.semester,
        startAt: startAt,
        endAt: endAt,
        clearDeletedAt: true,
      );
      return next.copyWith(id: next.computeId());
    }).toList();
    final targetIds = targets.map((session) => session.id).toSet();
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
