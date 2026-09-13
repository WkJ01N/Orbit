import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/custom_reminder_rule.dart';

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

StrongReminderSettings resolveStrongReminder({
  required StrongReminderSettings global,
  required StrongReminderType type,
  CourseSession? session,
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
        (rule == null ||
            global.ruleIds == null ||
            global.ruleIds!.contains(rule.id)),
  );
}
