import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/services/schedule_backup_service.dart';

void main() {
  test('encode and decode preserves session fields', () {
    final session = CourseSession(
      id: '2026-07-27|P0721|EX1|12:30',
      classType: '一般课堂',
      room: 'A001',
      date: DateTime(2026, 7, 27),
      weekday: 1,
      courseName: 'Physics',
      courseCode: 'P0721',
      section: 'EX1',
      startAt: DateTime(2026, 7, 27, 12, 30),
      endAt: DateTime(2026, 7, 27, 15, 20),
      teachers: const ['Miku'],
      faculty: 'Example',
      semester: '2606',
      note: 'note',
      recurrenceSeriesId: 'series-1',
      recurrenceMeetingId: 'meeting-1',
    );

    final service = ScheduleBackupService();
    final json = service.encodeToJson([session]);
    final restored = service.decodeFromJson(json);

    expect(restored, hasLength(1));
    expect(restored.first.id, session.id);
    expect(restored.first.courseName, session.courseName);
    expect(restored.first.room, session.room);
    expect(restored.first.teachers, session.teachers);
    expect(restored.first.note, session.note);
    expect(restored.first.recurrenceSeriesId, session.recurrenceSeriesId);
    expect(restored.first.recurrenceMeetingId, session.recurrenceMeetingId);
  });

  test('decode rejects invalid format', () {
    final service = ScheduleBackupService();
    expect(
      () => service.decodeFromJson('not json'),
      throwsA(isA<ScheduleBackupException>()),
    );
  });

  test('current backup preserves portable settings', () {
    const settings = PortableSettings(
      sourcePlatform: 'windows',
      localPreferences: {
        'batch_total_weeks': 12,
        'syncSelection': {'statistics': true},
      },
      locale: 'en',
      themeColor: 0xFF123456,
      themeMode: 'dark',
      themeStyle: 'colorful',
      gridDefaultWeekMode: 'current',
      weekStartDay: DateTime.sunday,
      gridDensity: 'comfortable',
      reminders: ReminderSettings(
        strong: StrongReminderSettings(
          arithmeticRounds: 10,
          sequenceRounds: 1,
          dismissTask: StrongDismissTask.mixed,
          mixedRounds: 3,
          sequenceNumberCount: 25,
          arithmeticDifficulty: ArithmeticDifficulty.hard,
          arithmeticAnswerMode: ArithmeticAnswerMode.choice6,
        ),
        leadMinutes: 30,
        checkInReminderEnabled: false,
      ),
      scheduleDisplay: ScheduleDisplaySettings(
        narrowLayout: NarrowScheduleLayout.adaptive,
        preferredMultiDayCount: 4,
        showEmptyDays: false,
      ),
      courseColorOverrides: {'P0721': 0xFFABCDEF},
    );
    final service = ScheduleBackupService();

    final backup = service.decodeBackup(
      service.encodeToJson(const [], settings: settings),
    );

    expect(backup.version, ScheduleBackupService.backupVersion);
    expect(backup.settings?.locale, 'en');
    expect(backup.settings?.reminders.leadMinutes, 30);
    expect(backup.settings?.reminders.strong.arithmeticRounds, 10);
    expect(backup.settings?.reminders.strong.sequenceRounds, 1);
    expect(
      backup.settings?.reminders.strong.dismissTask,
      StrongDismissTask.mixed,
    );
    expect(backup.settings?.reminders.strong.mixedRounds, 3);
    expect(backup.settings?.reminders.strong.sequenceNumberCount, 25);
    expect(
      backup.settings?.reminders.strong.arithmeticDifficulty,
      ArithmeticDifficulty.hard,
    );
    expect(
      backup.settings?.reminders.strong.arithmeticAnswerMode,
      ArithmeticAnswerMode.choice6,
    );
    expect(backup.settings?.localPreferences['batch_total_weeks'], 12);
    expect(backup.settings?.localPreferences['syncSelection'], {
      'statistics': true,
    });
    expect(backup.settings?.scheduleDisplay.showEmptyDays, isFalse);
    expect(
      backup.settings?.scheduleDisplay.narrowLayout,
      NarrowScheduleLayout.adaptive,
    );
    expect(backup.settings?.courseColorOverrides['P0721'], 0xFFABCDEF);
  });

  test('backup preserves DDL and accepts older backup without DDL', () {
    final service = ScheduleBackupService();
    final deadline = Deadline(
      countsTowardStatistics: false,
      batchId: 'batch-1',
      deletedAt: DateTime(2026, 10, 2),
      id: 'ddl-1',
      subject: 'Math',
      title: 'Report',
      dueAt: DateTime(2026, 10, 1, 23, 59),
      leadMinutes: const [1440, 60],
      completedAt: DateTime(2026, 9, 30),
    );
    final backup = service.decodeBackup(
      service.encodeToJson(const [], deadlines: [deadline]),
    );
    expect(backup.deadlines.single.title, 'Report');
    expect(backup.deadlines.single.completed, isTrue);
    expect(backup.deadlines.single.deleted, isTrue);
    expect(backup.deadlines.single.countsTowardStatistics, isFalse);
    expect(backup.deadlines.single.batchId, 'batch-1');
    final old = service.decodeBackup('{"version":5,"sessions":[]}');
    expect(old.deadlines, isEmpty);
  });

  test(
    'merge keeps unrelated semesters and rules while replacing matching IDs',
    () {
      PortableSettings snapshot(String name, List<String> ids) =>
          PortableSettings(
            locale: name == 'local' ? 'en' : 'zh_Hant',
            themeColor: 0xFF123456,
            themeMode: 'dark',
            themeStyle: 'standard',
            gridDefaultWeekMode: 'smart',
            weekStartDay: 1,
            gridDensity: 'standard',
            scheduleDisplay: const ScheduleDisplaySettings(),
            courseColorOverrides: {name: 0xFFABCDEF},
            reminders: ReminderSettings(
              customRules: [
                for (final id in ids)
                  CustomReminderRule(
                    id: id,
                    name: name,
                    activeFrom: DateTime(2026, 1, 1),
                  ),
              ],
            ),
            importConfiguration: ImportConfiguration(
              semesters: [
                for (final id in ids)
                  SemesterPlan(
                    id: id,
                    name: name,
                    firstWeekMonday: DateTime(2026, 9, 21),
                  ),
              ],
            ),
          );
      final local = snapshot('local', ['local-only', 'matching']);
      final backup = snapshot('backup', ['matching', 'backup-only']);
      final merged = backup.mergeWith(local);
      expect(merged.importConfiguration!.semesters.map((s) => s.id).toSet(), {
        'local-only',
        'matching',
        'backup-only',
      });
      expect(
        merged.importConfiguration!.semesters
            .firstWhere((s) => s.id == 'matching')
            .name,
        'backup',
      );
      expect(merged.reminders.customRules.map((r) => r.id).toSet(), {
        'local-only',
        'matching',
        'backup-only',
      });
      expect(merged.courseColorOverrides.keys.toSet(), {'local', 'backup'});
      expect(merged.locale, 'zh_Hant');
      expect(backup.importConfiguration!.semesters, hasLength(2));
    },
  );
  test('validation rejects malformed resources before restoration', () {
    final service = ScheduleBackupService();
    for (final extra in [
      {'settings': 'wrong type'},
      {
        'statistics': [
          {
            'id': 'day|2026-02-31',
            'kind': 'day',
            'date': '2026-02-31',
            'updatedAt': '2026-03-01T00:00:00Z',
          },
        ],
      },
      {
        'statistics': [
          {
            'id': 'day|wrong',
            'kind': 'day',
            'date': '2026-01-01',
            'updatedAt': '2026-03-01T00:00:00Z',
          },
        ],
      },
      {
        'audio': {
          'bad': {'name': 'bad.mp3', 'data': 'invalid base64'},
        },
      },
    ]) {
      expect(
        () => service.decodeBackup(
          jsonEncode({'version': 9, 'sessions': [], ...extra}),
        ),
        throwsA(isA<ScheduleBackupException>()),
      );
    }
  });
  test('v2 backup without recurrence metadata remains supported', () {
    final service = ScheduleBackupService();
    final raw = jsonEncode({
      'version': 2,
      'exportedAt': '2026-08-30T12:00:00.000',
      'sessions': <Object?>[],
    });

    final backup = service.decodeBackup(raw);

    expect(backup.version, 2);
    expect(backup.sessions, isEmpty);
  });

  test('v1 session-only backup remains supported', () {
    final service = ScheduleBackupService();
    final raw = jsonEncode({
      'version': 1,
      'exportedAt': '2026-08-30T12:00:00.000',
      'sessions': <Object?>[],
    });

    final backup = service.decodeBackup(raw);

    expect(backup.version, 1);
    expect(backup.sessions, isEmpty);
    expect(backup.settings, isNull);
  });
}
