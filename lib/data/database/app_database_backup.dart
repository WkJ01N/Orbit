part of 'app_database.dart';

extension BackupDatabase on AppDatabase {
  /// The database transaction also surrounds preference restoration; a failed
  /// settings write rolls back data, outbox entries and aliases together.
  Future<void> restoreUserBackup({
    List<CourseSession>? sessions,
    List<Deadline>? deadlines,
    List<Map<String, dynamic>>? statistics,
    Map<String, String> aliases = const {},
    Map<String, List<String>> memberships = const {},
    bool replace = false,
    bool deleteStatistics = false,
    Future<void> Function()? restoreSettings,
  }) async {
    await refreshStatistics();
    await _db.transaction((txn) async {
      final owner = await _statisticsOwner(txn);
      if (sessions != null) {
        final existing = await txn.query('course_sessions');
        final importedIds = sessions.map((s) => s.id).toSet();
        final removed = existing.where((row) {
          if (replace) return true;
          final s = CourseSession.fromMap(row);
          return !importedIds.contains(s.id) &&
              s.deletedAt == null &&
              sessions.any(
                (i) =>
                    i.deletedAt == null &&
                    i.startAt.isBefore(s.endAt) &&
                    s.startAt.isBefore(i.endAt),
              );
        }).toList();
        await _withdrawPendingStatistics(
          txn,
          removed
              .where((r) => !importedIds.contains(r['id']))
              .map((r) => r['id'] as String),
        );
        if (deleteStatistics) {
          await _setCourseStatisticsExcluded(
            txn,
            removed.map((r) => r['id'] as String),
            true,
          );
        }
        if (replace) {
          await txn.delete('course_sessions');
          await txn.delete('reminder_session_alias');
          await txn.delete('reminder_series_membership');
        } else {
          for (final row in removed) {
            await txn.update(
              'course_sessions',
              {'deleted_at': DateTime.now().toIso8601String()},
              where: 'id=?',
              whereArgs: [row['id']],
            );
          }
        }
        for (final row in removed.where(
          (r) => !importedIds.contains(r['id']),
        )) {
          await AppDatabase._queueCourseMutation(
            txn,
            CourseSession.fromMap(row),
            SyncOperation.delete,
          );
        }
        // Restore stable identities before preparing course sync mutations.
        for (final e in aliases.entries) {
          await txn.insert('reminder_session_alias', {
            'session_id': e.key,
            'stable_id': e.value,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final s in sessions) {
          await txn.insert(
            'course_sessions',
            s.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await AppDatabase._queueCourseMutation(
            txn,
            s,
            s.deletedAt == null ? SyncOperation.upsert : SyncOperation.delete,
          );
        }
        for (final e in memberships.entries) {
          for (final key in e.value) {
            await txn.insert(
              'reminder_series_membership',
              {'session_id': e.key, 'series_key': key},
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      }
      if (deadlines != null) {
        if (replace) {
          final importedIds = deadlines.map((d) => d.id).toSet();
          for (final row in await txn.query('deadlines')) {
            final d = Deadline.fromMap(row);
            if (!importedIds.contains(d.id)) {
              await AppDatabase._queueSyncEntity(
                txn,
                AppDatabase._deadlineEntity(d),
                SyncOperation.delete,
              );
            }
          }
          await txn.delete('deadlines');
        }
        for (final d in deadlines) {
          await txn.insert(
            'deadlines',
            d.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await AppDatabase._queueSyncEntity(
            txn,
            AppDatabase._deadlineEntity(d),
            d.deleted ? SyncOperation.delete : SyncOperation.upsert,
          );
        }
      }
      if (statistics != null) {
        if (replace) {
          for (final row in await txn.query(
            'statistics_records',
            where: 'owner=?',
            whereArgs: [owner],
          )) {
            final r = Map<String, dynamic>.from(
              jsonDecode(row['payload'] as String) as Map,
            )..remove('updatedAt');
            await _writeStatistic(txn, owner, row['id'] as String, {
              ...r,
              'excluded': true,
            });
          }
        }
        for (final r in statistics) {
          final id = r['id'] as String;
          final value = {...r}..remove('id');
          if (replace) {
            value['updatedAt'] = DateTime.now().toUtc().toIso8601String();
            await _writeStatistic(txn, owner, id, value);
          } else {
            await _mergeStatistic(txn, owner, id, value);
            final rows = await txn.query(
              'statistics_records',
              where: 'owner=? AND id=?',
              whereArgs: [owner, id],
            );
            if (owner != 'guest') {
              await AppDatabase._queueSyncEntity(
                txn,
                SyncEntity(
                  type: SyncEntityType.statistic,
                  id: id,
                  payload: Map<String, dynamic>.from(
                    jsonDecode(rows.first['payload'] as String) as Map,
                  ),
                ),
                SyncOperation.upsert,
              );
            }
          }
          if (id.startsWith('course|') || id.startsWith('ddl|')) {
            await txn.insert('statistics_sources', {
              'id': id,
              'owner': owner,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
      if (restoreSettings != null) await restoreSettings();
    });
    _syncChanges.add(null);
  }
}
