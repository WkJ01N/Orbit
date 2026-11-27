part of 'app_database.dart';

Future<void> _createStrongSchema(Database database) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS strong_reminder_sessions (id TEXT PRIMARY KEY, expires_at INTEGER NOT NULL, state TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS idx_strong_session_expiry ON strong_reminder_sessions(expires_at)',
  );
}

Future<void> _createReminderSchema(Database database) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS reminder_series_membership(session_id TEXT NOT NULL, series_key TEXT NOT NULL, PRIMARY KEY(session_id,series_key))',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS reminder_session_alias(session_id TEXT PRIMARY KEY, stable_id TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS reminder_delivery ('
    'rule_id TEXT NOT NULL, session_id TEXT NOT NULL, acknowledged INTEGER NOT NULL DEFAULT 0, '
    'processed_index INTEGER NOT NULL DEFAULT 0, catchup_index INTEGER NOT NULL DEFAULT 0, '
    'PRIMARY KEY(rule_id, session_id))',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS reminder_schedule ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, delivery_key TEXT NOT NULL UNIQUE, '
    'rule_id TEXT NOT NULL, session_id TEXT NOT NULL, send_index INTEGER NOT NULL, '
    'fire_at INTEGER NOT NULL, spec TEXT NOT NULL, queued INTEGER NOT NULL DEFAULT 0)',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS idx_reminder_schedule_time ON reminder_schedule(fire_at)',
  );
}

Future<void> _rememberReminderIdentityImpl(
  Transaction txn,
  String oldId,
  CourseSession session,
) async {
  final previous = await txn.query(
    'reminder_session_alias',
    where: 'session_id=?',
    whereArgs: [oldId],
  );
  final stable = previous.isEmpty
      ? oldId
      : previous.first['stable_id'] as String;
  await txn.insert('reminder_session_alias', {
    'session_id': session.id,
    'stable_id': stable,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  final old = await txn.query(
    AppDatabase._tableName,
    where: 'id=?',
    whereArgs: [oldId],
  );
  final series = {
    CourseSeriesKey.fromSession(session).value,
    if (old.isNotEmpty)
      CourseSeriesKey.fromSession(CourseSession.fromMap(old.first)).value,
  };
  for (final key in series) {
    await txn.insert('reminder_series_membership', {
      'session_id': stable,
      'series_key': key,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

mixin _AppDatabaseRemindersMixin on _AppDatabaseBase {
  Future<void> saveStrongSession(
    String id,
    int expiry,
    Map<String, dynamic> state,
  ) async {
    await _db.insert('strong_reminder_sessions', {
      'id': id,
      'expires_at': expiry,
      'state': jsonEncode(state),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> strongSessions() async =>
      (await _db.query('strong_reminder_sessions', orderBy: 'expires_at DESC'))
          .map(
            (row) => Map<String, dynamic>.from(
              jsonDecode(row['state'] as String) as Map,
            ),
          )
          .toList();

  Future<void> pruneStrongSessions(int before) async => _db.delete(
    'strong_reminder_sessions',
    where: 'expires_at < ?',
    whereArgs: [before],
  );

  Future<Map<String, List<String>>> reminderSeriesMemberships() async {
    final result = <String, List<String>>{};
    for (final row in await _db.query('reminder_series_membership')) {
      result
          .putIfAbsent(row['session_id'] as String, () => [])
          .add(row['series_key'] as String);
    }
    return result;
  }

  Future<void> markCatchUpQueued(
    String ruleId,
    String sessionId,
    int index,
  ) async {
    await _db.rawInsert(
      'INSERT OR IGNORE INTO reminder_delivery(rule_id,session_id) VALUES(?,?)',
      [ruleId, sessionId],
    );
    await _db.rawUpdate(
      'UPDATE reminder_delivery SET catchup_index=MAX(catchup_index,?) WHERE rule_id=? AND session_id=?',
      [index, ruleId, sessionId],
    );
  }

  @override
  Future<Map<String, String>> reminderSessionAliases() async => {
    for (final row in await _db.query('reminder_session_alias'))
      row['session_id'] as String: row['stable_id'] as String,
  };

  Future<void> clearReminderHistory() async {
    await _db.delete('reminder_delivery');
    await _db.delete('reminder_schedule');
  }

  Future<List<Map<String, Object?>>> reminderDeliveryStates() =>
      _db.query('reminder_delivery');

  Future<void> acknowledgeReminder(String ruleId, String sessionId) async {
    await _db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR IGNORE INTO reminder_delivery(rule_id,session_id) VALUES(?,?)',
        [ruleId, sessionId],
      );
      await txn.rawUpdate(
        'UPDATE reminder_delivery SET acknowledged=1 WHERE rule_id=? AND session_id=?',
        [ruleId, sessionId],
      );
      await txn.delete(
        'reminder_schedule',
        where: 'rule_id=? AND session_id=?',
        whereArgs: [ruleId, sessionId],
      );
    });
  }

  Future<void> markReminderProcessed(
    String ruleId,
    String sessionId,
    int index, {
    bool catchUp = false,
  }) async {
    await _db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR IGNORE INTO reminder_delivery(rule_id,session_id) VALUES(?,?)',
        [ruleId, sessionId],
      );
      await txn.rawUpdate(
        'UPDATE reminder_delivery SET processed_index=MAX(processed_index,?),catchup_index=MAX(catchup_index,?) WHERE rule_id=? AND session_id=?',
        [index, catchUp ? index : 0, ruleId, sessionId],
      );
    });
  }

  @override
  Future<List<Map<String, Object?>>> reminderSchedules() =>
      _db.query('reminder_schedule', orderBy: 'fire_at');

  Future<Set<String>> storeWindowsBuiltinSchedules(
    List<ReminderAlarmSpec> specs,
  ) => _db.transaction((txn) async {
    final existing = {
      for (final row in await txn.query(
        'reminder_schedule',
        where: 'rule_id=?',
        whereArgs: ['@builtin'],
      ))
        row['delivery_key'] as String: row,
    };
    final keys = <String>{};
    final batch = txn.batch();
    for (final spec in specs) {
      final key = '@builtin|${spec.notificationId}';
      keys.add(key);
      final values = <String, Object?>{
        'delivery_key': key,
        'rule_id': '@builtin',
        'session_id': spec.payload,
        'send_index': 0,
        'fire_at': spec.fireAt.millisecondsSinceEpoch,
        'spec': jsonEncode(spec.toJson()),
      };
      if (existing.containsKey(key)) {
        batch.update(
          'reminder_schedule',
          values,
          where: 'delivery_key=?',
          whereArgs: [key],
        );
      } else {
        batch.insert('reminder_schedule', values);
      }
    }
    await batch.commit(noResult: true);
    return keys;
  });

  /// Mirrors deadline alarms into the ledger so a re-plan or a reboot can
  /// tell which ones were actually delivered. Android keeps its alarms in the
  /// native store, which has no delivery receipts of its own.
  Future<Set<String>> storeDeadlineSchedules(List<ReminderAlarmSpec> specs) =>
      _db.transaction((txn) async {
        final existing = {
          for (final row in await txn.query(
            'reminder_schedule',
            where: 'rule_id=?',
            whereArgs: ['@deadline'],
          ))
            row['delivery_key'] as String: row,
        };
        final keys = <String>{};
        final batch = txn.batch();
        for (final spec in specs) {
          final key = '@deadline|${spec.deadlineId}|${spec.leadMinutes}';
          keys.add(key);
          final values = <String, Object?>{
            'delivery_key': key,
            'rule_id': '@deadline',
            'session_id': key,
            'send_index': 1,
            'fire_at': spec.fireAt.millisecondsSinceEpoch,
            'spec': jsonEncode(spec.toJson()),
          };
          if (existing.containsKey(key)) {
            batch.update(
              'reminder_schedule',
              values,
              where: 'delivery_key=?',
              whereArgs: [key],
            );
          } else {
            batch.insert('reminder_schedule', values);
          }
        }
        await batch.commit(noResult: true);
        return keys;
      });

  /// Deadline alarms whose fire time has passed without a delivery receipt.
  Future<List<Map<String, Object?>>> missedDeadlineSchedules(
    DateTime now, {
    Duration window = const Duration(hours: 24),
  }) => _db.rawQuery(
    'SELECT s.* FROM reminder_schedule s '
    'LEFT JOIN reminder_delivery d ON s.rule_id = d.rule_id AND s.session_id = d.session_id '
    'WHERE s.rule_id = ? AND s.fire_at < ? AND s.fire_at >= ? '
    'AND COALESCE(d.processed_index, 0) < s.send_index '
    'ORDER BY s.fire_at',
    [
      '@deadline',
      now.millisecondsSinceEpoch,
      now.subtract(window).millisecondsSinceEpoch,
    ],
  );

  Future<void> markQueuedReminders(Set<int> ids) async {
    await _db.transaction((txn) async {
      await txn.update('reminder_schedule', {'queued': 0});
      final batch = txn.batch();
      for (final row in await txn.query(
        'reminder_schedule',
        where: 'rule_id=?',
        whereArgs: ['@builtin'],
      )) {
        final spec = ReminderAlarmSpec.fromJson(
          jsonDecode(row['spec'] as String) as Map<String, dynamic>,
        );
        if (ids.contains(spec.notificationId)) {
          batch.update(
            'reminder_schedule',
            {'queued': 1},
            where: 'id=?',
            whereArgs: [row['id']],
          );
        }
      }
      for (final id in ids) {
        if (id < 3000000) continue;
        batch.update(
          'reminder_schedule',
          {'queued': 1},
          where: 'id=?',
          whereArgs: [id - 3000000],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<ReminderAlarmSpec>> materializeReminderSchedules(
    List<ReminderAlarmSpec> specs,
  ) => _db.transaction((txn) async {
    final rows = {
      for (final row in await txn.query('reminder_schedule'))
        row['delivery_key'] as String: row,
    };
    final result = <ReminderAlarmSpec>[];
    final batch = txn.batch();
    for (final spec in specs) {
      final key = '${spec.ruleId}|${spec.sessionId}|${spec.sendIndex}';
      final old = rows[key];
      final rowId =
          old?['id'] as int? ??
          await txn.insert('reminder_schedule', {
            'delivery_key': key,
            'rule_id': spec.ruleId,
            'session_id': spec.sessionId,
            'send_index': spec.sendIndex,
            'fire_at': spec.fireAt.millisecondsSinceEpoch,
            'spec': jsonEncode(spec.toJson()),
          });
      final id = 3000000 + rowId;
      final stored = ReminderAlarmSpec.fromJson({
        ...spec.toJson(),
        'alarmId': id,
        'notificationId': id,
      });
      final json = jsonEncode(stored.toJson());
      if (old?['spec'] != json) {
        batch.update(
          'reminder_schedule',
          {'spec': json, 'fire_at': spec.fireAt.millisecondsSinceEpoch},
          where: 'id=?',
          whereArgs: [rowId],
        );
      }
      result.add(stored);
    }
    await batch.commit(noResult: true);
    return result;
  });

  Future<void> updateReminderSchedule(int id, String spec) async {
    await _db.update(
      'reminder_schedule',
      {'spec': spec},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<int> putReminderSchedule(Map<String, Object?> row) async {
    await _db.insert(
      'reminder_schedule',
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return (await _db.query(
          'reminder_schedule',
          columns: ['id'],
          where: 'delivery_key=?',
          whereArgs: [row['delivery_key']],
        )).first['id']
        as int;
  }

  Future<void> pruneReminderSchedules(Set<String> keys) async {
    final rows = await reminderSchedules();
    final batch = _db.batch();
    for (final row in rows) {
      if (!keys.contains(row['delivery_key'])) {
        batch.delete(
          'reminder_schedule',
          where: 'id=?',
          whereArgs: [row['id']],
        );
      }
    }
    await batch.commit(noResult: true);
  }
}
