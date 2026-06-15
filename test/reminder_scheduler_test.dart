import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/timezone_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/reminder_alarm_planner.dart';
import 'package:timezone/timezone.dart' as tz;

CourseSession _manualSession({required DateTime startAt}) {
  final date = DateTime(startAt.year, startAt.month, startAt.day);
  final endAt = startAt.add(const Duration(hours: 1));
  return CourseSession(
    id: '',
    classType: '一般课堂',
    room: 'A101',
    date: date,
    weekday: date.weekday,
    courseName: '手动测试课',
    courseCode: 'MANUAL|abc123',
    section: '1',
    startAt: startAt,
    endAt: endAt,
    teachers: const [],
    faculty: '测试学院',
    semester: '',
  );
}

int countSchedulableClassReminders({
  required List<CourseSession> upcoming,
  required ReminderSettings settings,
  required DateTime now,
}) {
  var count = 0;
  if (settings.enabled) {
    for (final session in upcoming) {
      final reminderAt =
          session.startAt.subtract(Duration(minutes: settings.leadMinutes));
      if (reminderAt.isAfter(now)) {
        count++;
      }
    }
  }
  if (settings.checkInReminderEnabled) {
    for (final session in upcoming) {
      if (session.startAt.isAfter(now)) {
        count++;
      }
    }
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await configureReminderTimezone();
  });

  test('reminderAtToTzDateTime preserves local wall clock', () {
    final local = DateTime(2026, 6, 15, 14, 30, 45);
    final tzTime = reminderAtToTzDateTime(local);
    expect(tzTime.year, 2026);
    expect(tzTime.month, 6);
    expect(tzTime.day, 15);
    expect(tzTime.hour, 14);
    expect(tzTime.minute, 30);
    expect(tzTime.second, 45);
    expect(tzTime.location, tz.local);
  });

  test('isWithinNearTermHorizon accepts upcoming within two hours', () {
    final now = DateTime(2026, 6, 15, 10, 0);
    expect(
      isWithinNearTermHorizon(
        DateTime(2026, 6, 15, 11, 30),
        now,
        const Duration(hours: 2),
      ),
      isTrue,
    );
    expect(
      isWithinNearTermHorizon(
        DateTime(2026, 6, 15, 12, 1),
        now,
        const Duration(hours: 2),
      ),
      isFalse,
    );
    expect(
      isWithinNearTermHorizon(
        DateTime(2026, 6, 15, 9, 0),
        now,
        const Duration(hours: 2),
      ),
      isFalse,
    );
  });

  test('buildReminderAlarmSpecs produces class-lead and check-in alarms', () {
    final now = DateTime(2026, 6, 15, 10, 0);
    final session = _manualSession(
      startAt: DateTime(2026, 6, 15, 11, 0),
    );
    final copy = NotificationCopy.fromL10n(lookupL10n(const Locale('zh')));
    final settings = const ReminderSettings(
      enabled: true,
      checkInReminderEnabled: true,
      leadMinutes: 15,
    );

    final specs = buildReminderAlarmSpecs(
      upcomingSessions: [session],
      settings: settings,
      now: now,
      copy: copy,
    );

    expect(specs.length, 2);
    expect(specs.first.alarmId, 1);
    expect(specs.first.payload, isNot(contains('checkin_')));
    expect(specs.last.alarmId, 500000);
    expect(specs.last.payload, startsWith('checkin_'));
    expect(specs.first.fireAt, DateTime(2026, 6, 15, 10, 45));
    expect(specs.last.fireAt, session.startAt);
  });

  test('manual session in upcoming list yields schedulable reminders', () {
    final now = DateTime(2026, 6, 15, 10, 0);
    final session = _manualSession(
      startAt: DateTime(2026, 6, 15, 11, 0),
    );
    final upcoming = [session];
    final settings = const ReminderSettings(
      enabled: true,
      checkInReminderEnabled: true,
      leadMinutes: 15,
    );

    expect(
      countSchedulableClassReminders(
        upcoming: upcoming,
        settings: settings,
        now: now,
      ),
      2,
    );
  });
}
