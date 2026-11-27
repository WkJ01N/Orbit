part of 'app_database.dart';

Future<void> _createSyncSchema(Database database) async {
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
    'CREATE TABLE IF NOT EXISTS sync_conflict_history ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, mutation_id TEXT NOT NULL UNIQUE, '
    'entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, '
    'local_mutation TEXT NOT NULL, remote_entity TEXT NOT NULL, '
    'created_at TEXT NOT NULL, resolved_at TEXT)',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS idx_sync_conflict_history_time '
    'ON sync_conflict_history(created_at)',
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

SyncMutation _mutationFromRow(Map<String, Object?> row) {
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

Future<void> _queueCourseMutationImpl(
  Transaction txn,
  CourseSession session,
  SyncOperation operation,
) async {
  final aliases = await txn.query(
    'reminder_session_alias',
    where: 'session_id=?',
    whereArgs: [session.id],
  );
  await _queueSyncEntityImpl(
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

Future<void> _queueSyncEntityImpl(
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
    'mutation_id': AppDatabase._uuid.v4(),
    'entity_type': entity.type.name,
    'entity_id': entity.id,
    'operation': operation.name,
    'base_revision': revision,
    'schema_version': entity.schemaVersion,
    'payload': jsonEncode(entity.payload),
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });
}

mixin _AppDatabaseSyncMixin on _AppDatabaseBase {
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

  /// Every edit that lost a race, newest first. The conflict list above is
  /// one row per entity; this keeps the whole sequence.
  Future<List<Map<String, Object?>>> syncConflictHistory({int limit = 100}) =>
      _db.query(
        'sync_conflict_history',
        orderBy: 'created_at DESC, id DESC',
        limit: limit,
      );

  Future<int> syncConflictHistoryCount() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM sync_conflict_history'),
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
        // The row above only keeps the newest conflict per entity; the
        // history keeps every edit that never reached the server.
        await txn.insert('sync_conflict_history', {
          'mutation_id': conflict.local.mutationId,
          'entity_type': conflict.local.entity.type.name,
          'entity_id': conflict.local.entity.id,
          'local_mutation': jsonEncode(conflict.local.toJson()),
          'remote_entity': jsonEncode(conflict.remote.toJson()),
          'created_at': conflict.createdAt.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.delete(
          'sync_outbox',
          where: 'mutation_id = ?',
          whereArgs: [conflict.local.mutationId],
        );
      }
    });
  }

  /// Parks an outbox mutation that the server will always reject, so the rest
  /// of the queue keeps syncing. The local row itself is untouched; the
  /// conflict entry only records that this single upload was dropped.
  Future<void> quarantineSyncMutation(
    SyncMutation mutation,
    String code,
  ) async {
    await _db.transaction((txn) async {
      await txn.insert('sync_conflicts', {
        'id': 'quarantine:$code:${mutation.mutationId}',
        'entity_type': mutation.entity.type.name,
        'entity_id': mutation.entity.id,
        'local_mutation': jsonEncode(mutation.toJson()),
        'remote_entity': jsonEncode(mutation.entity.toJson()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'sync_outbox',
        where: 'mutation_id = ?',
        whereArgs: [mutation.mutationId],
      );
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
      AppDatabase._tableName,
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
    await _db.transaction(
      (txn) => _queueSyncEntityImpl(txn, entity, operation),
    );
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

  Future<void> applyRemoteEntities(
    List<SyncEntity> entities, {
    String? accountUid,
  }) async {
    await _db.transaction((txn) async {
      final owner = accountUid ?? await _self._statisticsOwner(txn);
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
              AppDatabase._tableName,
              {'deleted_at': DateTime.now().toIso8601String()},
              where: 'id = ?',
              whereArgs: [entity.id],
            );
          } else {
            await txn.insert(
              AppDatabase._tableName,
              courseSessionFromSyncPayload(entity.payload).toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            if (owner != 'guest') {
              final stableId = entity.payload['statisticsSourceId'] is String
                  ? entity.payload['statisticsSourceId'] as String
                  : entity.id;
              final sourceId =
                  '${entity.payload['kind'] == 'exam' ? 'exam' : 'course'}|$stableId';
              await txn.insert('statistics_sources', {
                'id': sourceId,
                'owner': owner,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        } else if (entity.type == SyncEntityType.statistic) {
          await _self._mergeStatistic(txn, owner, entity.id, entity.payload);
          if (owner != 'guest' &&
              (entity.id.startsWith('course|') ||
                  entity.id.startsWith('exam|') ||
                  entity.id.startsWith('ddl|'))) {
            await txn.insert('statistics_sources', {
              'id': entity.id,
              'owner': owner,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
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
            if (owner != 'guest') {
              await txn.insert('statistics_sources', {
                'id': 'ddl|${entity.id}',
                'owner': owner,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
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
        await txn.update(
          'sync_conflict_history',
          {'resolved_at': DateTime.now().toUtc().toIso8601String()},
          where: 'mutation_id = ?',
          whereArgs: [conflict.local.mutationId],
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
        await _queueSyncEntityImpl(
          txn,
          entity,
          conflict.local.operation,
          baseRevision: conflict.remote.revision,
        );
      });
      return;
    }
    await applyRemoteEntities([
      conflict.remote,
    ], accountUid: (await activeSyncAccount())?.uid);
    await _db.transaction((txn) async {
      await txn.delete(
        'sync_conflicts',
        where: 'id = ?',
        whereArgs: [conflict.id],
      );
      await txn.update(
        'sync_conflict_history',
        {'resolved_at': DateTime.now().toUtc().toIso8601String()},
        where: 'mutation_id = ?',
        whereArgs: [conflict.local.mutationId],
      );
      await txn.delete(
        'sync_outbox',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [conflict.remote.type.name, conflict.remote.id],
      );
    });
  }

  @override
  Future<Map<String, int>> _syncRevisionMap() async => {
    for (final row in await _db.query('sync_versions'))
      '${row['entity_type']}|${row['entity_id']}': row['revision'] as int,
  };
}
