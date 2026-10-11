import 'package:intl/intl.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';

List<ReminderAlarmSpec> buildDeadlineReminderSpecs({
  required List<Deadline> deadlines,
  required Map<String, int> notificationIds,
  required DateTime now,
  required DeadlineText text,
  StrongReminderSettings strongSettings = const StrongReminderSettings(),
}) {
  final result = <ReminderAlarmSpec>[];
  for (final deadline in deadlines) {
    if (deadline.archived ||
        deadline.deleted ||
        deadline.completed ||
        !deadline.dueAt.isAfter(now)) {
      continue;
    }
    for (final minutes in deadline.leadMinutes.toSet()) {
      if (minutes <= 0 || !deadline.reminderEnabledAt(minutes)) continue;
      final fireAt = deadline.dueAt.subtract(Duration(minutes: minutes));
      final id = notificationIds['${deadline.id}|$minutes'];
      if (id == null || !fireAt.isAfter(now)) continue;
      result.add(
        ReminderAlarmSpec(
          alarmId: id,
          notificationId: id,
          title: text.reminderTitle(deadline.subject, deadline.title),
          body: text.reminderBody(
            DateFormat.yMd(
              text.locale.toString(),
            ).add_Hm().format(deadline.dueAt),
          ),
          payload: 'deadline:${deadline.id}',
          localeTag: text.locale.toLanguageTag(),
          fireAt: fireAt,
          deadlineId: deadline.id,
          leadMinutes: minutes,
          acknowledgementMode: deadline.usesStrongReminderAt(minutes)
              ? 'openApp'
              : null,
          strong: strongSettings.copyWith(
            enabled: deadline.usesStrongReminderAt(minutes),
          ),
          acknowledgeLabel: text.pick('Open Orbit', '打开 Orbit', '開啟 Orbit'),
        ),
      );
    }
  }
  return result;
}
