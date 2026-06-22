import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/next_day_summary_builder.dart';
import 'package:orbit/services/reminder_alarm_planner.dart';
import 'package:orbit/services/reminder_id_ranges.dart';

CourseSession _session({
  required DateTime date,
  required int startHour,
}) {
  final startAt = DateTime(date.year, date.month, date.day, startHour);
  return CourseSession(
    id: '${date.toIso8601String()}|TEST|1|$startHour:00',
    classType: '一般課堂',
    room: 'A101',
    date: date,
    weekday: date.weekday,
    courseName: '物理',
    courseCode: 'PHYS',
    section: '1',
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 1)),
    teachers: const [],
    faculty: '',
    semester: '',
  );
}

NotificationCopy _copy() =>
    NotificationCopy.fromL10n(lookupL10n(defaultLocale));

void main() {
  test('applyNextDayTemplate replaces placeholders and falls back when empty',
      () {
    expect(
      applyNextDayTemplate(null, 'default', {'count': '3'}),
      'default',
    );
    expect(
      applyNextDayTemplate('共 {count} 节', 'default', {'count': '3'}),
      '共 3 节',
    );
  });

  test('buildNextDaySummarySlots schedules tonight at configured hour', () {
    final now = DateTime(2026, 6, 15, 20, 0);
    final tomorrow = DateTime(2026, 6, 16);
    final settings = const ReminderSettings(
      nextDaySummaryEnabled: true,
      nextDaySummaryHour: 23,
      nextDaySummaryMinute: 0,
    );
    final slots = buildNextDaySummarySlots(
      allSessions: [_session(date: tomorrow, startHour: 9)],
      settings: settings,
      now: now,
      copy: _copy(),
    );

    expect(slots, isNotEmpty);
    final tonight = slots.first;
    expect(tonight.fireAt, DateTime(2026, 6, 15, 23, 0));
    expect(tonight.notificationId, nextDaySummaryAlarmBase);
    expect(tonight.body, contains('9:00'));
  });

  test('nextDayRemindWhenNoClass false skips empty days', () {
    final now = DateTime(2026, 6, 15, 20, 0);
    final settings = const ReminderSettings(
      nextDaySummaryEnabled: true,
      nextDayRemindWhenNoClass: false,
    );
    final slots = buildNextDaySummarySlots(
      allSessions: const [],
      settings: settings,
      now: now,
      copy: _copy(),
    );

    expect(slots, isEmpty);
    expect(
      countNextDaySummarySlots(
        allSessions: const [],
        settings: settings,
        now: now,
      ),
      0,
    );
  });

  test('custom templates override default title and body', () {
    final now = DateTime(2026, 6, 15, 20, 0);
    final tomorrow = DateTime(2026, 6, 16);
    const settings = ReminderSettings(
      nextDaySummaryEnabled: true,
      nextDayWithClassTitleTemplate: '明日 {date}',
      nextDayWithClassBodyTemplate: '{count} 节 @ {time}',
    );
    final slots = buildNextDaySummarySlots(
      allSessions: [
        _session(date: tomorrow, startHour: 9),
        _session(date: tomorrow, startHour: 14),
      ],
      settings: settings,
      now: now,
      copy: _copy(),
    );

    expect(slots.first.title, '明日 6/16');
    expect(slots.first.body, '2 节 @ 09:00');
  });

  test('buildNextDaySummaryAlarmSpecs uses matching alarm ids', () {
    final now = DateTime(2026, 6, 15, 20, 0);
    final tomorrow = DateTime(2026, 6, 16);
    final specs = buildNextDaySummaryAlarmSpecs(
      allSessions: [_session(date: tomorrow, startHour: 10)],
      settings: const ReminderSettings(nextDaySummaryEnabled: true),
      now: now,
      copy: _copy(),
    );

    expect(specs.first.alarmId, nextDaySummaryAlarmBase);
    expect(specs.first.notificationId, nextDaySummaryAlarmBase);
    expect(specs.first.fireAt, DateTime(2026, 6, 15, 23, 0));
  });
}
