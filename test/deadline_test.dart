import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/services/deadline_reminder_planner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('en');
  });

  Deadline sample({DateTime? dueAt}) => Deadline(
    id: 'ddl-1',
    subject: 'Algorithms',
    title: 'Project',
    dueAt: dueAt ?? DateTime(2026, 10, 1, 12),
    leadMinutes: const [1440, 60],
  );

  test(
    'local DDL survives reopening, retains stable reminder IDs and tombstone',
    () async {
      final directory = await Directory.systemTemp.createTemp('orbit_ddl_');
      addTearDown(() => directory.delete(recursive: true));
      var database = await AppDatabase.open(directory.path);
      await database.saveDeadline(sample());
      final ids = await database.reserveDeadlineNotificationIds([sample()]);
      expect(ids.length, 2);
      expect(ids.values.every((id) => id >= 4000000), isTrue);
      await database.close();

      database = await AppDatabase.open(directory.path);
      addTearDown(database.close);
      expect((await database.getDeadlines()).single.title, 'Project');
      expect(await database.reserveDeadlineNotificationIds([sample()]), ids);
      await database.saveDeadline(
        sample().copyWith(completedAt: DateTime(2026, 9, 30)),
      );
      expect((await database.getDeadlines()).single.completed, isTrue);
      await database.deleteDeadline((await database.getDeadlines()).single);
      expect(await database.getDeadlines(), isEmpty);
      expect(
        (await database.localDeadlineSyncEntities(
          includeDeleted: true,
        )).single.deleted,
        isTrue,
      );
    },
  );

  test('remote DDL can be applied and completion syncs', () async {
    final directory = await Directory.systemTemp.createTemp(
      'orbit_ddl_remote_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = await AppDatabase.open(directory.path);
    addTearDown(database.close);
    final deadline = sample().copyWith(completedAt: DateTime(2026, 9, 30));
    await database.applyRemoteEntities([
      SyncEntity(
        type: SyncEntityType.deadline,
        id: deadline.id,
        payload: deadline.toSyncPayload(),
        revision: 3,
      ),
    ]);
    expect((await database.getDeadlines()).single.completed, isTrue);
    expect((await database.localDeadlineSyncEntities()).single.revision, 3);
  });

  test(
    'remote delete without a local DDL retains a tombstone and revision',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'orbit_ddl_delete_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = await AppDatabase.open(directory.path);
      addTearDown(database.close);
      await database.applyRemoteEntities([
        const SyncEntity(
          type: SyncEntityType.deadline,
          id: 'deleted-remotely',
          payload: {},
          deleted: true,
          revision: 4,
        ),
      ]);
      expect(await database.getDeadlines(), isEmpty);
      final entities = await database.localDeadlineSyncEntities(
        includeDeleted: true,
      );
      expect(entities.single.deleted, isTrue);
      expect(entities.single.revision, 4);
    },
  );

  test('planner schedules only future, unfinished reminders', () {
    final now = DateTime(2026, 10, 1, 10);
    final deadline = sample(dueAt: DateTime(2026, 10, 1, 12));
    final ids = {'ddl-1|1440': 4000001, 'ddl-1|60': 4000002};
    final text = DeadlineText(const Locale('en'));
    final specs = buildDeadlineReminderSpecs(
      deadlines: [deadline],
      notificationIds: ids,
      now: now,
      text: text,
    );
    expect(specs.map((spec) => spec.notificationId), [4000002]);
    expect(specs.single.payload, 'deadline:ddl-1');
    expect(
      buildDeadlineReminderSpecs(
        deadlines: [deadline.copyWith(completedAt: now)],
        notificationIds: ids,
        now: now,
        text: text,
      ),
      isEmpty,
    );
    expect(
      buildDeadlineReminderSpecs(
        deadlines: [deadline],
        notificationIds: ids,
        now: DateTime(2026, 10, 1, 13),
        text: text,
      ),
      isEmpty,
    );
  });
}
