import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/schedule_import.dart';

List<String> normalizeReminderCourseKeys({
  required ReminderCourseScope scope,
  required List<String> keys,
  required List<CourseSession> sessions,
  Map<String, String> aliases = const {},
  Map<String, List<String>> memberships = const {},
  bool keepHistorical = true,
}) {
  if (scope == ReminderCourseScope.all) return keys;
  final normalized = <String>{};
  for (final key in keys) {
    final matching = sessions.where(
      (s) => scope == ReminderCourseScope.sessions
          ? (aliases[s.id] ?? s.id) == (aliases[key] ?? key)
          : CourseSeriesKey.fromSession(s).value == key ||
                (memberships[aliases[s.id] ?? s.id] ?? const <String>[])
                    .contains(key),
    );
    if (matching.isEmpty ||
        keepHistorical && scope == ReminderCourseScope.series) {
      normalized.add(key);
    }
    normalized.addAll(
      matching.map(
        (s) => scope == ReminderCourseScope.sessions
            ? s.id
            : CourseSeriesKey.fromSession(s).value,
      ),
    );
  }
  return normalized.toList();
}

bool matchesStrongCourse(
  StrongReminderSettings settings,
  CourseSession session, {
  Map<String, String> aliases = const {},
  Map<String, List<String>> memberships = const {},
}) {
  if (settings.courseScope == ReminderCourseScope.all) return true;
  final stable = aliases[session.id] ?? session.id;
  if (settings.courseScope == ReminderCourseScope.sessions) {
    return settings.courseKeys.any((key) => (aliases[key] ?? key) == stable);
  }
  return settings.courseKeys.contains(
        CourseSeriesKey.fromSession(session).value,
      ) ||
      settings.courseKeys.any(
        (memberships[stable] ?? const <String>[]).contains,
      );
}

bool matchesFirstClass(
  StrongReminderSettings settings,
  CourseSession session,
  List<CourseSession> dailySessions,
  List<PeriodTimePlan> plans,
) {
  if (!settings.onlyFirstClass) return true;
  final minute = session.startAt.hour * 60 + session.startAt.minute;
  if (settings.firstClassMode == FirstClassMode.firstPeriod) {
    if (session.startPeriod != null) return session.startPeriod == 1;
    final chosen = settings.periodTimePlanId ?? session.periodTimePlanId;
    final candidates = plans.where((p) => chosen == null || p.id == chosen);
    final matches = candidates
        .expand((p) => p.periods.where((t) => t.startMinute == minute))
        .map((p) => p.number)
        .toSet();
    if (matches.length == 1) return matches.first == 1;
  }
  if (minute >= settings.cutoffMinute) return false;
  final eligible = (dailySessions.isEmpty ? [session] : dailySessions).where(
    (s) =>
        s.deletedAt == null &&
        !s.archived &&
        s.startAt.year == session.startAt.year &&
        s.startAt.month == session.startAt.month &&
        s.startAt.day == session.startAt.day &&
        s.startAt.hour * 60 + s.startAt.minute < settings.cutoffMinute,
  );
  return !eligible.any((s) => s.startAt.isBefore(session.startAt));
}

StrongReminderSettings resolveStrongReminder({
  required StrongReminderSettings global,
  required StrongReminderType type,
  CourseSession? session,
  List<CourseSession> dailySessions = const [],
  List<PeriodTimePlan> periodPlans = const [],
  List<CourseSession> summarySessions = const [],
  CustomReminderRule? rule,
  Map<String, String> aliases = const {},
  Map<String, List<String>> memberships = const {},
}) {
  final audio = rule?.strongOverride ?? global;
  if (rule != null && rule.strength != ReminderStrength.inherit) {
    return audio.copyWith(enabled: rule.strength == ReminderStrength.strong);
  }
  final matches =
      global.courseScope == ReminderCourseScope.all ||
      (session != null &&
          matchesStrongCourse(
            global,
            session,
            aliases: aliases,
            memberships: memberships,
          )) ||
      (type == StrongReminderType.summary &&
          summarySessions.any(
            (s) => matchesStrongCourse(
              global,
              s,
              aliases: aliases,
              memberships: memberships,
            ),
          ));
  return audio.copyWith(
    enabled:
        global.enabled &&
        global.types.contains(type) &&
        matches &&
        (type == StrongReminderType.summary ||
            !global.onlyFirstClass ||
            session != null &&
                matchesFirstClass(
                  global,
                  session,
                  dailySessions,
                  periodPlans,
                )) &&
        (rule == null ||
            global.ruleIds == null ||
            global.ruleIds!.contains(rule.id)),
  );
}
