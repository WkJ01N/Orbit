import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/wake_text.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:orbit/services/custom_reminder_planner.dart';
import 'package:orbit/services/strong_reminder_resolver.dart';

final strongCourseIdsProvider = FutureProvider<Set<String>>((ref) async {
  final settings = await ref.watch(effectiveReminderSettingsProvider.future);
  if (!settings.strong.enabled &&
      !settings.customRules.any(
        (r) => r.enabled && r.strength == ReminderStrength.strong,
      )) {
    return {};
  }
  final sessions = await ref.watch(sessionsProvider.future);
  final configuration = await ref.watch(importConfigurationProvider.future);
  final database = ref.read(appDatabaseProvider);
  final aliases = await database.reminderSessionAliases();
  final memberships = await database.reminderSeriesMemberships();
  final states = await database.reminderDeliveryStates();
  final result = <String>{};
  for (final session in sessions.where(
    (s) => !s.archived && s.deletedAt == null,
  )) {
    for (final type in [
      if (settings.enabled) StrongReminderType.classLead,
      if (settings.checkInReminderEnabled) StrongReminderType.checkIn,
    ]) {
      if (resolveStrongReminder(
        global: settings.strong,
        type: type,
        session: session,
        dailySessions: sessions,
        periodPlans: configuration.periodTimes,
        aliases: aliases,
        memberships: memberships,
      ).enabled) {
        result.add(session.id);
      }
    }
  }
  for (final spec in planCustomReminders(
    sessions: sessions,
    rules: settings.customRules,
    strong: settings.strong,
    now: DateTime.now(),
    states: states,
    periodPlans: configuration.periodTimes,
    sessionAliases: aliases,
    seriesMemberships: memberships,
  )) {
    if (spec.strong.enabled) {
      for (final session in sessions) {
        if ((aliases[session.id] ?? session.id) == spec.sessionId) {
          result.add(session.id);
        }
      }
    }
  }
  return result;
});

class StrongCourseBadge extends ConsumerWidget {
  const StrongCourseBadge({
    super.key,
    required this.session,
    this.compact = false,
  });
  final CourseSession session;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref
            .watch(strongCourseIdsProvider)
            .valueOrNull
            ?.contains(session.id) ??
        false)) {
      return const SizedBox.shrink();
    }
    final label = WakeText(Localizations.localeOf(context)).strong;
    return Semantics(
      label: label,
      child: Tooltip(
        message: '$label：${WakeText.of(context).guide}',
        triggerMode: TooltipTriggerMode.tap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_outlined, size: 14),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}
