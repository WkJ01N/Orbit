part of 'app_database.dart';

Future<void> _createDeadlineSchema(Database database) async {
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

Future<void> _createDeadlineStrongSchema(Database database) async {
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

SyncEntity _buildDeadlineEntity(Deadline value, {int revision = 0}) =>
    SyncEntity(
      type: SyncEntityType.deadline,
      id: value.id,
      revision: revision,
      payload: value.toSyncPayload(),
      deleted: value.deleted,
    );

mixin _AppDatabaseDeadlinesMixin on _AppDatabaseBase {
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
        await AppDatabase._queueSyncEntity(
          txn,
          _buildDeadlineEntity(value),
          SyncOperation.upsert,
        );
        if (value.completed && value.countsTowardStatistics) {
          final owner = await _self._statisticsOwner(txn);
          final id = 'ddl|${value.id}';
          if (await _self._claimStatistic(txn, id, owner)) {
            final exists = await txn.query(
              'statistics_records',
              where: 'owner=? AND id=?',
              whereArgs: [owner, id],
            );
            if (exists.isEmpty) {
              await _self._writeStatistic(txn, owner, id, {
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
        await AppDatabase._queueSyncEntity(
          txn,
          _buildDeadlineEntity(next),
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
      await AppDatabase._queueSyncEntity(
        txn,
        _buildDeadlineEntity(deleted),
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

  Future<List<SyncEntity>> localDeadlineSyncEntities({
    bool includeDeleted = false,
  }) async {
    final revisions = await _syncRevisionMap();
    return [
      for (final value in await getDeadlines(includeDeleted: includeDeleted))
        _buildDeadlineEntity(
          value,
          revision: revisions['deadline|${value.id}'] ?? 0,
        ),
    ];
  }

  Future<List<String>> getAutoArchivableDeadlineIds(
    DateTime completedBefore,
  ) async {
    final rows = await _db.query(
      'deadlines',
      columns: ['id'],
      where:
          'deleted_at IS NULL AND archived_at IS NULL AND auto_archive_paused = 0 '
          'AND completed_at IS NOT NULL AND completed_at <= ?',
      whereArgs: [completedBefore.toUtc().toIso8601String()],
    );
    return [for (final row in rows) row['id'] as String];
  }
}
