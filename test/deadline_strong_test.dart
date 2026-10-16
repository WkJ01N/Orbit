import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/services/deadline_reminder_planner.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/settings_sync_codec.dart';
import 'package:orbit/services/windows_notification_worker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime(2026, 10, 11, 10);
  Deadline sample({String id = 'a'}) => Deadline(
    id: id,
    subject: 'Math',
    title: 'Project',
    dueAt: now.add(const Duration(days: 2)),
    leadMinutes: const [1440, 181, 180, 60, 5],
  );
  test(
    'old data remains normal and 180-minute default distinguishes unset from explicit empty',
    () {
      final d = Deadline.fromSyncPayload(
        sample().toSyncPayload()
          ..remove('strongReminderEnabled')
          ..remove('strongLeadMinutes')
          ..remove('disabledReminderLeadMinutes'),
      );
      expect(d.strongReminderEnabled, isFalse);
      expect(d.disabledReminderLeadMinutes, isEmpty);
      expect(
        d.copyWith(strongReminderEnabled: true).effectiveStrongLeadMinutes,
        [180, 60, 5],
      );
      expect(
        d.copyWith(strongReminderEnabled: true).usesStrongReminderAt(181),
        isFalse,
      );
      expect(
        d
            .copyWith(strongReminderEnabled: true, strongLeadMinutes: [])
            .hasStrongReminder,
        isFalse,
      );
      final s = d.copyWith(
        strongReminderEnabled: true,
        strongLeadMinutes: [1440],
        disabledReminderLeadMinutes: [1440],
      );
      expect(Deadline.fromMap(s.toMap()).toSyncPayload(), s.toSyncPayload());
      expect(s.hasStrongReminder, isTrue);
    },
  );
  test(
    'DDL planner ignores course strong master and excludes disabled slots with stable identity',
    () {
      final d = sample().copyWith(
        strongReminderEnabled: true,
        strongLeadMinutes: [1440, 180, 60],
        disabledReminderLeadMinutes: [60],
      );
      final ids = {for (final m in d.leadMinutes) '${d.id}|$m': 4000000 + m};
      final specs = buildDeadlineReminderSpecs(
        deadlines: [d],
        notificationIds: ids,
        now: now,
        text: const DeadlineText(Locale('en')),
        strongSettings: const StrongReminderSettings(
          enabled: false,
          types: {},
          durationSeconds: 50,
          soundEnabled: false,
        ),
      );
      expect(specs.map((s) => s.leadMinutes), [1440, 181, 180, 5]);
      expect(specs.where((s) => s.strong.enabled).map((s) => s.leadMinutes), [
        1440,
        180,
      ]);
      final strong = specs.first;
      expect(strong.strong.durationSeconds, 50);
      expect(strong.strong.soundEnabled, isFalse);
      expect(strong.acknowledgementMode, 'openApp');
      expect(strong.deadlineId, 'a');
      expect(
        ReminderAlarmSpec.fromJson(strong.toJson()).toJson(),
        strong.toJson(),
      );
      final xml = windowsReminderXml(strong);
      expect(xml, contains('open Orbit to stop.'));
      expect(xml, contains('deadline:a'));
      expect(xml, contains('Open Orbit'));
      expect(xml, isNot(contains('finish the task')));
      expect(
        buildDeadlineReminderSpecs(
          deadlines: [d.copyWith(completedAt: now)],
          notificationIds: ids,
          now: now,
          text: const DeadlineText(Locale('en')),
        ),
        isEmpty,
      );
    },
  );
  test('native DDL notification uses the configured language', () {
    final d = sample().copyWith(strongReminderEnabled: true);
    for (final entry in {
      const Locale('en'): 'Open Orbit',
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'):
          '打开 Orbit',
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'):
          '開啟 Orbit',
    }.entries) {
      final specs = buildDeadlineReminderSpecs(
        deadlines: [d],
        notificationIds: {'a|180': 123},
        now: now,
        text: DeadlineText(entry.key),
      );
      final spec = specs.single;
      expect(spec.localeTag, entry.key.toLanguageTag());
      expect(spec.acknowledgeLabel, entry.value);
      expect(windowsReminderXml(spec), contains(entry.value));
    }
  });
  test(
    'v11 migration preserves v10 DDL and defaults all new columns',
    () async {
      final dir = await Directory.systemTemp.createTemp('orbit_ddl_v11_');
      addTearDown(() => dir.delete(recursive: true));
      var db = await AppDatabase.open(dir.path);
      await db.saveDeadline(sample());
      await db.close();
      final raw = await openDatabase('${dir.path}/orbit.db');
      for (final column in [
        'strong_reminder_enabled',
        'strong_lead_minutes',
        'disabled_reminder_lead_minutes',
      ]) {
        await raw.execute('ALTER TABLE deadlines DROP COLUMN $column');
      }
      await raw.execute('PRAGMA user_version=10');
      await raw.close();
      db = await AppDatabase.open(dir.path);
      addTearDown(db.close);
      final restored = (await db.getDeadlines()).single;
      expect(restored.title, 'Project');
      expect(restored.strongReminderEnabled, isFalse);
      expect(restored.disabledReminderLeadMinutes, isEmpty);
      final next = restored.copyWith(
        strongReminderEnabled: true,
        strongLeadMinutes: [60],
        disabledReminderLeadMinutes: [180],
      );
      await db.saveDeadline(next);
      expect(
        (await db.getDeadlines()).single.toSyncPayload(),
        next.toSyncPayload(),
      );
    },
  );
  test(
    'future cancellation is transactional, scoped, synced and reopen restores configured slots',
    () async {
      final dir = await Directory.systemTemp.createTemp('orbit_ddl_cancel_');
      addTearDown(() => dir.delete(recursive: true));
      final db = await AppDatabase.open(dir.path);
      addTearDown(db.close);
      final a = sample().copyWith(strongReminderEnabled: true);
      final b = sample(id: 'b');
      await db.saveDeadlines([a, b]);
      await db.disableDeadlineReminders({
        'a': {1440, 60, 9999},
      }, now: now);
      var restored = (await db.getDeadlineById('a'))!;
      expect(restored.disabledReminderLeadMinutes.toSet(), {1440, 60});
      expect(
        (await db.getDeadlineById('b'))!.disabledReminderLeadMinutes,
        isEmpty,
      );
      final remote = (await db.localDeadlineSyncEntities()).singleWhere(
        (e) => e.id == 'a',
      );
      expect(
        Deadline.fromSyncPayload(
          remote.payload,
        ).disabledReminderLeadMinutes.toSet(),
        {1440, 60},
      );
      await db.disableDeadlineReminders({
        'a': {180},
      }, now: a.dueAt.subtract(const Duration(minutes: 100)));
      expect(
        (await db.getDeadlineById('a'))!.disabledReminderLeadMinutes.toSet(),
        {1440, 60},
      );
      restored = restored.copyWith(completedAt: now);
      await db.saveDeadline(restored);
      await db.saveDeadline(restored.copyWith(clearCompleted: true));
      expect(
        (await db.getDeadlineById('a'))!.disabledReminderLeadMinutes,
        isEmpty,
      );
      expect((await db.getDeadlineById('a'))!.strongReminderEnabled, isTrue);
    },
  );
  test(
    'current backup, repeated restore and remote sync retain strong choices and disabled slots',
    () async {
      final d = sample().copyWith(
        strongReminderEnabled: true,
        strongLeadMinutes: [181, 60],
        disabledReminderLeadMinutes: [60],
      );
      final backup = ScheduleBackupService();
      final json = backup.encodeToJson([], deadlines: [d]);
      expect(
        backup.decodeBackup(json).version,
        ScheduleBackupService.backupVersion,
      );
      expect(
        backup.decodeBackup(json).deadlines.single.toSyncPayload(),
        d.toSyncPayload(),
      );
      final dir = await Directory.systemTemp.createTemp('orbit_ddl_sync_');
      addTearDown(() => dir.delete(recursive: true));
      final db = await AppDatabase.open(dir.path);
      addTearDown(db.close);
      for (var i = 0; i < 2; i++) {
        await db.saveDeadlines(backup.decodeBackup(json).deadlines);
      }
      expect(await db.getDeadlines(), hasLength(1));
      await db.applyRemoteEntities([
        SyncEntity(
          type: SyncEntityType.deadline,
          id: d.id,
          payload: d
              .copyWith(disabledReminderLeadMinutes: [180, 60])
              .toSyncPayload(),
          revision: 2,
        ),
      ]);
      expect((await db.getDeadlines()).single.disabledReminderLeadMinutes, [
        180,
        60,
      ]);
      final bad = jsonDecode(json) as Map<String, dynamic>;
      bad['deadlines'][0]['strongLeadMinutes'] = [9999];
      expect(
        () => backup.decodeBackup(jsonEncode(bad)),
        throwsA(isA<ScheduleBackupException>()),
      );
    },
  );
  test(
    'navigation preferences default visible and survive preferences, display sync and backup',
    () async {
      final service = SettingsService();
      expect(
        (await service.loadScheduleDisplaySettings()).hideUpcomingPage,
        isFalse,
      );
      await service.saveScheduleDisplaySettings(
        const ScheduleDisplaySettings(
          hideUpcomingPage: true,
          hideImportPage: false,
        ),
      );
      final saved = await service.loadScheduleDisplaySettings();
      expect(saved.hideUpcomingPage, isTrue);
      expect(saved.hideImportPage, isFalse);
      final snapshot = await service.exportPortableSettings();
      final display =
          SettingsSyncCodec.groups(snapshot)['display']!['scheduleDisplay']
              as Map;
      expect(display['hideUpcomingPage'], true);
      expect(display['hideImportPage'], false);
      final restored = ScheduleBackupService()
          .decodeBackup(
            ScheduleBackupService().encodeToJson([], settings: snapshot),
          )
          .settings!
          .scheduleDisplay;
      expect(restored.hideUpcomingPage, isTrue);
      expect(restored.hideImportPage, isFalse);
    },
  );
}
