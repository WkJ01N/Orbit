part of 'app_database.dart';

Future<void> _createStatisticsSchema(DatabaseExecutor db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS statistics_records (owner TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(owner,id))',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS statistics_sources (id TEXT PRIMARY KEY, owner TEXT NOT NULL)',
  );
  final columns = (await db.rawQuery(
    'PRAGMA table_info(deadlines)',
  )).map((r) => r['name']).toSet();
  if (!columns.contains('counts_toward_statistics')) {
    await db.execute(
      'ALTER TABLE deadlines ADD COLUMN counts_toward_statistics INTEGER NOT NULL DEFAULT 1',
    );
  }
  if (!columns.contains('batch_id')) {
    await db.execute('ALTER TABLE deadlines ADD COLUMN batch_id TEXT');
  }
}

extension StatisticsDatabase on AppDatabase {
  Future<String> _statisticsOwner(DatabaseExecutor db) async {
    final rows = await db.query(
      'sync_metadata',
      where: 'key=?',
      whereArgs: ['active_account_uid'],
    );
    return rows.isEmpty ? 'guest' : rows.first['value'] as String;
  }

  Future<List<Map<String, dynamic>>> statisticsRecords({String? owner}) async {
    owner ??= await _statisticsOwner(_db);
    return (await _db.query(
          'statistics_records',
          where: 'owner=?',
          whereArgs: [owner],
        ))
        .map(
          (r) => Map<String, dynamic>.from(
            jsonDecode(r['payload'] as String) as Map,
          )..['id'] = r['id'],
        )
        .toList();
  }

  Future<bool> hasGuestStatistics() async =>
      (await statisticsRecords(owner: 'guest')).isNotEmpty;

  Future<bool> _writeStatistic(
    DatabaseExecutor txn,
    String owner,
    String id,
    Map<String, dynamic> payload, {
    bool queue = true,
  }) async {
    final rows = await txn.query(
      'statistics_records',
      where: 'owner=? AND id=?',
      whereArgs: [owner, id],
    );
    final old = rows.isEmpty
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(rows.first['payload'] as String) as Map,
          );
    final next = {...payload}..remove('id');
    final comparable = {...?old}..remove('updatedAt');
    final desired = {...next}..remove('updatedAt');
    final same =
        canonicalSyncPayload(comparable) == canonicalSyncPayload(desired);
    // Keep a newer merge timestamp even when its fields are unchanged. Otherwise
    // an older restoration could subsequently resurrect an excluded record.
    if (same &&
        (queue ||
            next['updatedAt'] == null ||
            DateTime.parse(
                  next['updatedAt'] as String,
                ).compareTo(DateTime.parse(old!['updatedAt'] as String)) <=
                0)) {
      return false;
    }
    next['updatedAt'] ??= DateTime.now().toUtc().toIso8601String();
    await txn.insert('statistics_records', {
      'owner': owner,
      'id': id,
      'payload': jsonEncode(next),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (queue && owner != 'guest' && owner == await _statisticsOwner(txn)) {
      await AppDatabase._queueSyncEntity(
        txn,
        SyncEntity(type: SyncEntityType.statistic, id: id, payload: next),
        SyncOperation.upsert,
      );
    }
    return true;
  }

  Future<bool> _claimStatistic(
    DatabaseExecutor txn,
    String id,
    String owner,
  ) async {
    final rows = await txn.query(
      'statistics_sources',
      where: 'id=?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      if (rows.first['owner'] == owner) return true;
      final previous = await txn.query(
        'statistics_records',
        where: 'owner=? AND id=?',
        whereArgs: [rows.first['owner'], id],
      );
      if (id.startsWith('course|') && previous.isNotEmpty) {
        final old = Map<String, dynamic>.from(
          jsonDecode(previous.first['payload'] as String) as Map,
        );
        if (old['counted'] != true) {
          await txn.update(
            'statistics_sources',
            {'owner': owner},
            where: 'id=?',
            whereArgs: [id],
          );
          return true;
        }
      }
      return false;
    }
    await txn.insert('statistics_sources', {'id': id, 'owner': owner});
    return true;
  }

  Future<void> refreshStatistics({
    DateTime? now,
    bool recordActivity = false,
  }) async {
    final at = now ?? DateTime.now();
    var changed = false;
    await _db.transaction((txn) async {
      final owner = await _statisticsOwner(txn);
      if (recordActivity) {
        final date = AppDatabase._dateKey(at);
        changed |= await _writeStatistic(txn, owner, 'day|$date', {
          'kind': 'day',
          'date': date,
        });
        final profile = await txn.query(
          'statistics_records',
          where: 'owner=? AND id=?',
          whereArgs: [owner, 'profile'],
        );
        if (profile.isEmpty) {
          final dates =
              (await txn.query(
                    'statistics_records',
                    where: 'owner=? AND id LIKE ?',
                    whereArgs: [owner, 'day|%'],
                  ))
                  .map((row) => jsonDecode(row['payload'] as String) as Map)
                  .where((row) => row['excluded'] != true)
                  .map((row) => row['date'] as String)
                  .toList()
                ..sort();
          changed |= await _writeStatistic(txn, owner, 'profile', {
            'kind': 'profile',
            'firstUsedDate': dates.first,
            'firstUsedDateAutomatic': true,
          });
        }
      }
      final aliases = {
        for (final r in await txn.query('reminder_session_alias'))
          r['session_id']: r['stable_id'],
      };
      final activeSources = <String>{};
      for (final row in await txn.query(
        'course_sessions',
        where: 'deleted_at IS NULL',
      )) {
        final s = CourseSession.fromMap(row);
        final id = 'course|${aliases[s.id] ?? s.id}';
        if (!await _claimStatistic(txn, id, owner)) continue;
        activeSources.add(id);
        final previous = await txn.query(
          'statistics_records',
          where: 'owner=? AND id=?',
          whereArgs: [owner, id],
        );
        final old = previous.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(
                jsonDecode(previous.first['payload'] as String) as Map,
              );
        if (old['excluded'] == true) continue;
        // Freeze completed lessons; editing their identity must not count them twice.
        if (old['counted'] == true) continue;
        changed |= await _writeStatistic(txn, owner, id, {
          'kind': 'course',
          'name': s.courseName,
          'semester': s.semester,
          'courseKey': '${s.semester}|${s.courseCode}|${s.courseName}',
          'minutes': s.endAt.difference(s.startAt).inMinutes.clamp(0, 1440),
          'counted': !s.endAt.isAfter(at),
          'endAt': s.endAt.toUtc().toIso8601String(),
        });
      }
      // Old clients only send course deletions. Retire their pending lesson
      // snapshots too, so absent future lessons cannot block course completion.
      for (final row in await txn.query(
        'statistics_records',
        where: 'owner=? AND id LIKE ?',
        whereArgs: [owner, 'course|%'],
      )) {
        final value = Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String) as Map,
        );
        if (value['counted'] != true &&
            !activeSources.contains(row['id']) &&
            value['withdrawn'] != true) {
          value.remove('updatedAt');
          changed |= await _writeStatistic(txn, owner, row['id'] as String, {
            ...value,
            'withdrawn': true,
          });
        }
      }
      for (final row in await txn.query(
        'deadlines',
        where:
            'deleted_at IS NULL AND completed_at IS NOT NULL AND counts_toward_statistics=1',
      )) {
        final d = Deadline.fromMap(row);
        final id = 'ddl|${d.id}';
        if (await _claimStatistic(txn, id, owner)) {
          final exists = await txn.query(
            'statistics_records',
            where: 'owner=? AND id=?',
            whereArgs: [owner, id],
          );
          if (exists.isEmpty) {
            changed |= await _writeStatistic(txn, owner, id, {
              'kind': 'ddl',
              'name': d.title,
              'completedAt': d.completedAt!.toUtc().toIso8601String(),
            });
          }
        }
      }
    });
    if (changed) _syncChanges.add(null);
  }

  Future<void> setFirstUsedDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    if (day.isAfter(DateTime.now())) {
      throw ArgumentError('Future first-use date');
    }
    await _db.transaction(
      (txn) async => _writeStatistic(
        txn,
        await _statisticsOwner(txn),
        'profile',
        {'kind': 'profile', 'firstUsedDate': AppDatabase._dateKey(day)},
      ),
    );
    _syncChanges.add(null);
  }

  Future<void> _setCourseStatisticsExcluded(
    DatabaseExecutor txn,
    Iterable<String> ids,
    bool excluded,
  ) async {
    final owner = await _statisticsOwner(txn);
    for (final source in ids) {
      final aliases = await txn.query(
        'reminder_session_alias',
        where: 'session_id=?',
        whereArgs: [source],
      );
      final id =
          'course|${aliases.isEmpty ? source : aliases.first['stable_id']}';
      final rows = await txn.query(
        'statistics_records',
        where: 'owner=? AND id=?',
        whereArgs: [owner, id],
      );
      if (rows.isEmpty) continue;
      final value = Map<String, dynamic>.from(
        jsonDecode(rows.first['payload'] as String) as Map,
      )..remove('updatedAt');
      if (excluded) {
        value['excluded'] = true;
      } else {
        value.remove('excluded');
        value.remove('withdrawn');
      }
      await _writeStatistic(txn, owner, id, value);
    }
  }

  Future<void> _withdrawPendingStatistics(
    DatabaseExecutor txn,
    Iterable<String> ids,
  ) async {
    final owner = await _statisticsOwner(txn);
    for (final source in ids) {
      final alias = await txn.query(
        'reminder_session_alias',
        where: 'session_id=?',
        whereArgs: [source],
      );
      final id = 'course|${alias.isEmpty ? source : alias.first['stable_id']}';
      final rows = await txn.query(
        'statistics_records',
        where: 'owner=? AND id=?',
        whereArgs: [owner, id],
      );
      if (rows.isEmpty) continue;
      final value = Map<String, dynamic>.from(
        jsonDecode(rows.first['payload'] as String) as Map,
      );
      if (value['counted'] != true) {
        value.remove('updatedAt');
        await _writeStatistic(txn, owner, id, {...value, 'withdrawn': true});
      }
    }
  }

  Future<void> mergeGuestStatistics(String uid) async {
    await _db.transaction((txn) async {
      for (final row in await txn.query(
        'statistics_records',
        where: 'owner=?',
        whereArgs: ['guest'],
      )) {
        final id = row['id'] as String;
        final value = Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String) as Map,
        );
        await _mergeStatistic(txn, uid, id, value);
        await txn.update(
          'statistics_sources',
          {'owner': uid},
          where: 'id=? AND owner=?',
          whereArgs: [id, 'guest'],
        );
      }
      await txn.delete(
        'statistics_records',
        where: 'owner=?',
        whereArgs: ['guest'],
      );
      for (final row in await txn.query(
        'statistics_records',
        where: 'owner=?',
        whereArgs: [uid],
      )) {
        await AppDatabase._queueSyncEntity(
          txn,
          SyncEntity(
            type: SyncEntityType.statistic,
            id: row['id'] as String,
            payload: Map<String, dynamic>.from(
              jsonDecode(row['payload'] as String) as Map,
            ),
          ),
          SyncOperation.upsert,
        );
      }
    });
    _syncChanges.add(null);
  }

  Future<void> _mergeStatistic(
    DatabaseExecutor txn,
    String owner,
    String id,
    Map<String, dynamic> incoming,
  ) async {
    final rows = await txn.query(
      'statistics_records',
      where: 'owner=? AND id=?',
      whereArgs: [owner, id],
    );
    final old = rows.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(rows.first['payload'] as String) as Map,
          );
    var value = incoming;
    if (old.isNotEmpty) {
      final comparison = DateTime.parse(
        incoming['updatedAt'] as String,
      ).compareTo(DateTime.parse(old['updatedAt'] as String));
      value =
          comparison > 0 ||
              (comparison == 0 &&
                  canonicalSyncPayload(
                        incoming,
                      ).compareTo(canonicalSyncPayload(old)) >
                      0)
          ? incoming
          : old;
      if (value['kind'] == 'course') {
        value = {
          ...value,
          'counted': old['counted'] == true || incoming['counted'] == true,
        };
      } else if (value['kind'] == 'profile') {
        final oldAutomatic = old['firstUsedDateAutomatic'] == true;
        final incomingAutomatic = incoming['firstUsedDateAutomatic'] == true;
        if (oldAutomatic != incomingAutomatic) {
          value = oldAutomatic ? incoming : old;
        } else if (oldAutomatic) {
          final dates = [
            old['firstUsedDate'] as String,
            incoming['firstUsedDate'] as String,
          ]..sort();
          value = {...value, 'firstUsedDate': dates.first};
        }
      }
    }
    await _writeStatistic(txn, owner, id, value, queue: false);
  }

  Future<List<SyncEntity>> localStatisticsSyncEntities({String? owner}) async {
    final revisions = await _syncRevisionMap();
    return [
      for (final r in await statisticsRecords(owner: owner))
        SyncEntity(
          type: SyncEntityType.statistic,
          id: r['id'] as String,
          payload: {...r}..remove('id'),
          revision: revisions['statistic|${r['id']}'] ?? 0,
        ),
    ];
  }
}
