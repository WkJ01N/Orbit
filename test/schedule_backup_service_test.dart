import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
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

  test('v5 backup preserves portable settings', () {
    const settings = PortableSettings(
      locale: 'en',
      themeColor: 0xFF123456,
      themeMode: 'dark',
      themeStyle: 'colorful',
      gridDefaultWeekMode: 'current',
      weekStartDay: DateTime.sunday,
      gridDensity: 'comfortable',
      reminders: ReminderSettings(
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

    expect(backup.version, 5);
    expect(backup.settings?.locale, 'en');
    expect(backup.settings?.reminders.leadMinutes, 30);
    expect(backup.settings?.scheduleDisplay.showEmptyDays, isFalse);
    expect(
      backup.settings?.scheduleDisplay.narrowLayout,
      NarrowScheduleLayout.adaptive,
    );
    expect(backup.settings?.courseColorOverrides['P0721'], 0xFFABCDEF);
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
