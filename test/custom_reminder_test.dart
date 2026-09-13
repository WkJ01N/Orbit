import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/custom_reminder_planner.dart';
import 'package:orbit/services/reminder_audio_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/windows_notification_worker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 9, 12, 12);
  CourseSession session(String id, DateTime start) => CourseSession(
    id: id,
    classType: 'Lecture',
    room: 'A101',
    date: DateTime(start.year, start.month, start.day),
    weekday: start.weekday,
    courseName: 'Algorithms',
    courseCode: 'CS101',
    section: 'A',
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    teachers: ['Teacher'],
    faculty: 'F',
    semester: 'S',
  );
  CustomReminderRule rule() => CustomReminderRule(
    id: 'r',
    name: 'Rule',
    activeFrom: now.subtract(const Duration(days: 2)),
  );
  List<ReminderAlarmSpec> plan(
    CustomReminderRule r,
    List<CourseSession> sessions, {
    List<Map<String, Object?>> states = const [],
    Map<String, String> aliases = const {},
  }) => planCustomReminders(
    sessions: sessions,
    rules: [r],
    strong: const StrongReminderSettings(),
    now: now,
    states: states,
    sessionAliases: aliases,
  );

  test(
    '100 repeats are based on first scheduled time with one-second intervals',
    () {
      final s = session('s', now.add(const Duration(hours: 1)));
      final specs = plan(rule().copyWith(sendCount: 100, intervalSeconds: 1), [
        s,
      ]);
      expect(specs.length, 100);
      expect(specs.last.sendIndex, 100);
      expect(
        specs.last.fireAt.difference(specs.first.fireAt),
        const Duration(seconds: 99),
      );
    },
  );
  test('ended courses retain future end-based reminders', () {
    final s = session('s', now.subtract(const Duration(hours: 2)));
    final specs = plan(
      rule().copyWith(basis: ReminderTimeBasis.end, offsetSeconds: 7200),
      [s],
    );
    expect(specs.single.fireAt, now.add(const Duration(hours: 1)));
  });
  test('fixed clock uses the calendar date and supports cross-day offset', () {
    final s = session('s', now.add(const Duration(days: 3)));
    final r = rule().copyWith(
      basis: ReminderTimeBasis.date,
      dayOffset: -1,
      secondOfDay: 3661,
    );
    expect(r.firstFireAt(s), DateTime(2026, 9, 14, 1, 1, 1));
  });
  test(
    'catch-up chooses only latest missed sequence and preserves future times',
    () {
      final s = session('s', now.subtract(const Duration(minutes: 1)));
      final specs = plan(
        rule().copyWith(offsetSeconds: 0, sendCount: 4, intervalSeconds: 60),
        [s],
      );
      expect(specs.map((s) => s.sendIndex), [2, 3, 4]);
      expect(specs.first.catchUp, isTrue);
      expect(specs.first.originalFireAt, now);
      expect(specs[1].fireAt, now.add(const Duration(minutes: 1)));
      expect(specs.first.title, contains('Catch-up'));
      expect(specs.first.body, contains('not a real-time'));
    },
  );
  test(
    'catch-up excludes deliveries older than 24 hours and includes exact boundary',
    () {
      final s = session('s', now.subtract(const Duration(hours: 24)));
      expect(
        plan(rule().copyWith(offsetSeconds: 0), [s]).single.catchUp,
        isTrue,
      );
      expect(plan(rule().copyWith(offsetSeconds: -1), [s]), isEmpty);
    },
  );
  test('new and reenabled rules do not catch up old sends', () {
    final s = session('s', now.subtract(const Duration(minutes: 1)));
    expect(
      plan(rule().copyWith(offsetSeconds: 0, activeFrom: now), [s]),
      isEmpty,
    );
  });
  test('acknowledgement and processed indexes survive replanning', () {
    final s = session('s', now.add(const Duration(hours: 1)));
    final r = rule().copyWith(sendCount: 3, intervalSeconds: 1);
    expect(
      plan(
        r,
        [s],
        states: [
          {'rule_id': 'r', 'session_id': 's', 'acknowledged': 1},
        ],
      ),
      isEmpty,
    );
    expect(
      plan(
        r,
        [s],
        states: [
          {'rule_id': 'r', 'session_id': 's', 'processed_index': 2},
        ],
      ).single.sendIndex,
      3,
    );
  });
  test('catch-up reservation prevents repeated recovery notifications', () {
    final s = session('s', now.subtract(const Duration(minutes: 1)));
    expect(
      plan(
        rule().copyWith(offsetSeconds: 0),
        [s],
        states: [
          {'rule_id': 'r', 'session_id': 's', 'catchup_index': 1},
        ],
      ),
      isEmpty,
    );
  });
  test(
    'course edits preserve acknowledgement and session filters via stable aliases',
    () {
      final s = session('new', now.add(const Duration(hours: 1)));
      final r = rule().copyWith(
        scope: ReminderCourseScope.sessions,
        courseKeys: ['old'],
      );
      expect(plan(r, [s], aliases: {'new': 'old'}).single.sessionId, 'old');
      expect(
        plan(
          r,
          [s],
          aliases: {'new': 'old'},
          states: [
            {'rule_id': 'r', 'session_id': 'old', 'acknowledged': 1},
          ],
        ),
        isEmpty,
      );
    },
  );
  test('filter selections union internally and intersect across filters', () {
    final s = session('s', now.add(const Duration(hours: 1)));
    expect(
      rule()
          .copyWith(weekdays: [1, s.weekday], classTypes: ['Lecture', 'Lab'])
          .matches(s),
      isTrue,
    );
    expect(
      rule().copyWith(weekdays: [s.weekday], classTypes: ['Lab']).matches(s),
      isFalse,
    );
    expect(
      rule().copyWith(dateTo: now.subtract(const Duration(days: 1))).matches(s),
      isFalse,
    );
  });
  test('template validation and all sequence variables render', () {
    expect(invalidReminderVariables('{course} {unknown} {unknown}'), [
      'unknown',
    ]);
    final s = session('s', now.add(const Duration(hours: 1)));
    final spec = plan(
      rule().copyWith(
        sendCount: 2,
        titleTemplate: '{course} {sendIndex}/{sendCount}',
        bodyTemplate: '{scheduledTime} {teachers}',
      ),
      [s],
    ).last;
    expect(spec.title, 'Algorithms 2/2');
    expect(spec.body, contains('Teacher'));
  });
  test(
    'strength overrides preserve global default and independent forced values',
    () {
      const global = StrongReminderSettings(enabled: true, durationSeconds: 60);
      expect(
        rule()
            .copyWith(strength: ReminderStrength.normal)
            .effectiveStrong(global)
            .enabled,
        isFalse,
      );
      expect(
        rule()
            .copyWith(strength: ReminderStrength.strong)
            .effectiveStrong(const StrongReminderSettings())
            .enabled,
        isTrue,
      );
      expect(rule().effectiveStrong(global).durationSeconds, 60);
    },
  );
  test(
    'old specs decode without custom metadata and Windows XML escapes user content',
    () {
      final spec = ReminderAlarmSpec(
        alarmId: 1,
        notificationId: 1,
        title: 'A&B',
        body: '<course>',
        payload: 's',
        fireAt: now,
        strong: const StrongReminderSettings(enabled: true),
      );
      expect(
        ReminderAlarmSpec.fromJson({...spec.toJson()}).strong.enabled,
        isTrue,
      );
      final xml = windowsReminderXml(spec);
      expect(xml, contains('A&amp;B'));
      expect(xml, contains('&lt;course&gt;'));
      expect(xml, contains('activationType="system"'));
      expect(xml, contains('loop="true"'));
    },
  );
  test(
    'settings round trip rules and strong configuration; old and malformed settings default safely',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();
      expect((await service.load()).customRules, isEmpty);
      expect((await service.load()).strong.enabled, isFalse);
      await service.save(
        ReminderSettings(
          customRules: [rule()],
          strong: const StrongReminderSettings(enabled: true),
        ),
      );
      expect(
        (await service.load()).customRules.single.toJson(),
        rule().toJson(),
      );
      expect((await service.load()).strong.enabled, isTrue);
      SharedPreferences.setMockInitialValues({
        'custom_reminder_rules': 'broken',
        'strong_reminder_settings': '{}',
      });
      expect((await SettingsService().load()).customRules, isEmpty);
    },
  );
  test('audio rejects oversized content and mismatched file types', () {
    expect(
      () => ReminderAudioService.validate(
        '.mp3',
        Uint8List.fromList(utf8.encode('not audio')),
      ),
      throwsFormatException,
    );
    expect(
      () => ReminderAudioService.validate(
        '.wav',
        Uint8List(ReminderAudioService.maxFileBytes + 1),
      ),
      throwsFormatException,
    );
  });
  test(
    'v4 audio backup deduplicates content, remaps safe paths and starts restored rules now',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('orbit_audio_test_');
      final previous = ReminderAudioService.supportDirectory;
      ReminderAudioService.supportDirectory = () async => dir;
      try {
        final bytes = Uint8List(2044);
        final view = ByteData.sublistView(bytes);
        bytes.setRange(0, 4, utf8.encode('RIFF'));
        view.setUint32(4, bytes.length - 8, Endian.little);
        bytes.setRange(8, 16, utf8.encode('WAVEfmt '));
        view.setUint32(16, 16, Endian.little);
        view.setUint16(20, 1, Endian.little);
        view.setUint16(22, 1, Endian.little);
        view.setUint32(24, 48000, Endian.little);
        view.setUint32(28, 96000, Endian.little);
        view.setUint16(32, 2, Endian.little);
        view.setUint16(34, 16, Endian.little);
        bytes.setRange(36, 40, utf8.encode('data'));
        view.setUint32(40, 2000, Endian.little);
        final a = await ReminderAudioService.importBytes('../tone.wav', bytes);
        final b = await ReminderAudioService.importBytes('tone.wav', bytes);
        final base = await SettingsService().exportPortableSettings();
        final settings = base.withReminders(
          ReminderSettings(
            strong: StrongReminderSettings(sound: a),
            customRules: [
              rule().copyWith(
                scope: ReminderCourseScope.sessions,
                courseKeys: ['old'],
                strongOverride: StrongReminderSettings(sound: b),
              ),
            ],
          ),
        );
        final service = ScheduleBackupService();
        final raw = await service.encodeWithAudio(
          [session('new', now)],
          settings,
          sessionAliases: {'new': 'old'},
        );
        final backup = service.decodeBackup(raw);
        expect(backup.audio.length, 1);
        expect(backup.version, 4);
        expect(backup.settings!.reminders.customRules.single.courseKeys, [
          'new',
        ]);
        final before = DateTime.now();
        final restored = await service.restoreAudio(backup);
        final sound = restored.settings.reminders.strong.sound;
        expect(sound.value, startsWith(dir.path));
        expect(sound.value, isNot(a.value));
        expect(await File(sound.value).readAsBytes(), bytes);
        expect(
          restored.settings.reminders.customRules.single.activeFrom.isBefore(
            before,
          ),
          isFalse,
        );
        expect(
          restored
              .settings
              .reminders
              .customRules
              .single
              .strongOverride!
              .sound
              .value,
          sound.value,
        );
        final corrupted = jsonDecode(raw) as Map<String, dynamic>;
        (corrupted['audio'] as Map).values.first['data'] = base64Encode(
          utf8.encode('broken'),
        );
        expect(
          () => service.decodeBackup(jsonEncode(corrupted)),
          throwsA(isA<ScheduleBackupException>()),
        );
      } finally {
        ReminderAudioService.supportDirectory = previous;
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'audio backup rejects more than 50 MiB of distinct valid sounds',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('orbit_audio_limit_');
      try {
        final bytes = Uint8List(ReminderAudioService.maxFileBytes);
        final view = ByteData.sublistView(bytes);
        bytes.setRange(0, 4, utf8.encode('RIFF'));
        view.setUint32(4, bytes.length - 8, Endian.little);
        bytes.setRange(8, 16, utf8.encode('WAVEfmt '));
        view.setUint32(16, 16, Endian.little);
        view.setUint16(20, 1, Endian.little);
        view.setUint16(22, 1, Endian.little);
        view.setUint32(24, 48000, Endian.little);
        view.setUint32(28, 96000, Endian.little);
        view.setUint16(32, 2, Endian.little);
        view.setUint16(34, 16, Endian.little);
        bytes.setRange(36, 40, utf8.encode('data'));
        view.setUint32(40, bytes.length - 44, Endian.little);
        final rules = <CustomReminderRule>[];
        for (var i = 0; i < 11; i++) {
          bytes[bytes.length - 1] = i;
          final file = File('${dir.path}/tone$i.wav');
          await file.writeAsBytes(bytes);
          rules.add(
            rule().copyWith(
              id: 'r$i',
              strongOverride: StrongReminderSettings(
                sound: ReminderSound(kind: 'file', value: file.path),
              ),
            ),
          );
        }
        final base = await SettingsService().exportPortableSettings();
        await expectLater(
          ScheduleBackupService().encodeWithAudio(
            [],
            base.withReminders(ReminderSettings(customRules: rules)),
          ),
          throwsA(isA<ScheduleBackupException>()),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test('old v3 backups use ordinary reminders without custom rules', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService().exportPortableSettings();
    final service = ScheduleBackupService();
    final json =
        jsonDecode(
              service.encodeToJson([session('s', now)], settings: settings),
            )
            as Map<String, dynamic>;
    json['version'] = 3;
    final reminders = (json['settings'] as Map)['reminders'] as Map;
    reminders.remove('customRules');
    reminders.remove('strong');
    final restored = service.decodeBackup(jsonEncode(json)).settings!.reminders;
    expect(restored.customRules, isEmpty);
    expect(restored.strong.enabled, isFalse);
  });

  test(
    'scheduled IDs survive replan and time changes update the queue ledger',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('orbit_queue_test_');
      final db = await AppDatabase.open(dir.path);
      try {
        final first = await db.materializeReminderSchedules(
          plan(rule(), [session('s', now.add(const Duration(hours: 1)))]),
        );
        final later = await db.materializeReminderSchedules(
          plan(rule(), [session('s', now.add(const Duration(hours: 2)))]),
        );
        expect(later.single.notificationId, first.single.notificationId);
        expect(
          (await db.reminderSchedules()).single['fire_at'],
          later.single.fireAt.millisecondsSinceEpoch,
        );
        final builtin = ReminderAlarmSpec(
          alarmId: 1,
          notificationId: 1,
          fireAt: now.add(const Duration(hours: 1)),
          title: 'Builtin',
          body: 'Body',
          payload: 's',
        );
        await db.storeWindowsBuiltinSchedules([builtin]);
        await db.markQueuedReminders({later.single.notificationId, 1});
        expect(
          (await db.reminderSchedules()).map((row) => row['queued']),
          everyElement(1),
        );
        await db.acknowledgeReminder('r', 's');
        expect((await db.reminderSchedules()).single['rule_id'], '@builtin');
        expect(
          plan(rule(), [
            session('s', now.add(const Duration(hours: 2))),
          ], states: await db.reminderDeliveryStates()),
          isEmpty,
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'database v5 persists delivery state, stable aliases and scheduled identifiers',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('orbit_reminder_test_');
      final db = await AppDatabase.open(dir.path);
      try {
        await db.acknowledgeReminder('r', 'old');
        await db.markReminderProcessed('r', 'old', 3, catchUp: true);
        await db.updateSessionWithIdChange('old', session('new', now));
        expect((await db.reminderDeliveryStates()).single['acknowledged'], 1);
        expect(
          (await db.reminderDeliveryStates()).single['processed_index'],
          3,
        );
        expect(await db.reminderSessionAliases(), {'new': 'old'});
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
