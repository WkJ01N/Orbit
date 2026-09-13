import 'dart:convert';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/strong_reminder_resolver.dart';

const reminderVariables = [
  'course',
  'room',
  'date',
  'weekday',
  'startTime',
  'endTime',
  'teachers',
  'courseCode',
  'sendIndex',
  'sendCount',
  'scheduledTime',
];

List<String> invalidReminderVariables(String template) =>
    RegExp(r'\{([^{}]+)\}')
        .allMatches(template)
        .map((m) => m[1]!)
        .where((v) => !reminderVariables.contains(v))
        .toSet()
        .toList();

String renderReminderTemplate(String template, Map<String, String> values) =>
    template.replaceAllMapped(
      RegExp(r'\{([^{}]+)\}'),
      (m) => values[m[1]] ?? m[0]!,
    );

String reminderTimestamp(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}-'
    '${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

Map<String, String> reminderValues(
  CustomReminderRule rule,
  CourseSession session,
  int index,
  DateTime at, {
  List<String> weekdayNames = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ],
}) => {
  'course': session.courseName,
  'room': session.room,
  'date': reminderTimestamp(session.date).split(' ').first,
  'weekday': weekdayNames[session.weekday - 1],
  'startTime': reminderTimestamp(session.startAt).split(' ').last,
  'endTime': reminderTimestamp(session.endAt).split(' ').last,
  'teachers': session.teachers.join(', '),
  'courseCode': session.courseCode,
  'sendIndex': '$index',
  'sendCount': '${rule.sendCount}',
  'scheduledTime': reminderTimestamp(at),
};

bool matchesCustomReminder(
  CustomReminderRule rule,
  CourseSession session, {
  Map<String, String> sessionAliases = const {},
  Map<String, List<String>> seriesMemberships = const {},
}) {
  if (rule.scope == ReminderCourseScope.series) {
    final membership =
        seriesMemberships[sessionAliases[session.id] ?? session.id] ??
        const <String>[];
    return rule.matches(session) ||
        (rule.copyWith(scope: ReminderCourseScope.all).matches(session) &&
            rule.courseKeys.any(membership.contains));
  }
  if (rule.scope != ReminderCourseScope.sessions) return rule.matches(session);
  final stable = sessionAliases[session.id] ?? session.id;
  return rule.copyWith(scope: ReminderCourseScope.all).matches(session) &&
      rule.courseKeys.any((key) => (sessionAliases[key] ?? key) == stable);
}

/// Elapsed-time offsets and calendar-date times deliberately use different arithmetic.
List<ReminderAlarmSpec> planCustomReminders({
  required List<CourseSession> sessions,
  required List<CustomReminderRule> rules,
  required StrongReminderSettings strong,
  required DateTime now,
  List<Map<String, Object?>> states = const [],
  Map<String, String> sessionAliases = const {},
  Map<String, List<String>> seriesMemberships = const {},
  String catchUpLabel = 'Catch-up',
  String catchUpNotice =
      'This is a catch-up message, not a real-time reminder.',
  String originalLabel = 'Originally scheduled',
  String deliveredLabel = 'Delivered',
  String acknowledgeLabel = 'Acknowledge',
  String stopLabel = 'Stop',
  List<String> weekdayNames = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ],
}) {
  final ledger = {
    for (final row in states) '${row['rule_id']}|${row['session_id']}': row,
  };
  final result = <ReminderAlarmSpec>[];
  for (final rule in rules.where((r) => r.enabled)) {
    for (final session in sessions.where(
      (session) => matchesCustomReminder(
        rule,
        session,
        sessionAliases: sessionAliases,
        seriesMemberships: seriesMemberships,
      ),
    )) {
      final sessionId = sessionAliases[session.id] ?? session.id;
      final state = ledger['${rule.id}|$sessionId'];
      if (state?['acknowledged'] == 1) continue;
      final processed = state?['processed_index'] as int? ?? 0;
      final caughtUp = state?['catchup_index'] as int? ?? 0;
      final first = rule.firstFireAt(session);
      int? lastMissed;
      for (var i = processed + 1; i <= rule.sendCount; i++) {
        final at = first.add(Duration(seconds: (i - 1) * rule.intervalSeconds));
        if (at.isBefore(rule.activeFrom)) continue;
        if (i > caughtUp &&
            !at.isAfter(now) &&
            now.difference(at) <= const Duration(hours: 24)) {
          lastMissed = i;
        }
      }
      for (var i = processed + 1; i <= rule.sendCount; i++) {
        final at = first.add(Duration(seconds: (i - 1) * rule.intervalSeconds));
        if (at.isBefore(rule.activeFrom) ||
            (!at.isAfter(now) && i != lastMissed)) {
          continue;
        }
        final missed = i == lastMissed;
        final values = reminderValues(
          rule,
          session,
          i,
          at,
          weekdayNames: weekdayNames,
        );
        final title = renderReminderTemplate(
          rule.titleTemplate.isEmpty ? '{course}' : rule.titleTemplate,
          values,
        );
        final body = renderReminderTemplate(
          rule.bodyTemplate.isEmpty
              ? '{startTime} · {room}'
              : rule.bodyTemplate,
          values,
        );
        result.add(
          ReminderAlarmSpec(
            alarmId: 0,
            notificationId: 0,
            title: missed ? '[$catchUpLabel] $title' : title,
            body: missed
                ? '$body\n$originalLabel: ${reminderTimestamp(at)}\n'
                      '$deliveredLabel: ${reminderTimestamp(now)}\n$catchUpNotice'
                : body,
            payload: jsonEncode({
              'session': session.id,
              'rule': rule.id,
              'action': 'open',
              'identity': sessionId,
              'index': i,
            }),
            fireAt: missed ? now.add(const Duration(seconds: 1)) : at,
            originalFireAt: at,
            catchUp: missed,
            ruleId: rule.id,
            sessionId: sessionId,
            sendIndex: i,
            strong: resolveStrongReminder(
              global: strong,
              type: StrongReminderType.custom,
              session: session,
              rule: rule,
              aliases: sessionAliases,
              memberships: seriesMemberships,
            ),
            acknowledgeLabel:
                rule.repeatMode == ReminderRepeatMode.untilAcknowledged
                ? acknowledgeLabel
                : '',
            stopLabel: stopLabel,
          ),
        );
      }
    }
  }
  result.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return result;
}
