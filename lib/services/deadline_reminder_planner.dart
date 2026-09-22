import 'package:intl/intl.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';

List<ReminderAlarmSpec> buildDeadlineReminderSpecs({
  required List<Deadline> deadlines,
  required Map<String, int> notificationIds,
  required DateTime now,
  required DeadlineText text,
}) {
  final result = <ReminderAlarmSpec>[];
  for (final deadline in deadlines) {
    if (deadline.deleted ||
        deadline.completed ||
        !deadline.dueAt.isAfter(now)) {
      continue;
    }
    for (final minutes in deadline.leadMinutes.toSet()) {
      if (minutes <= 0) continue;
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
          fireAt: fireAt,
        ),
      );
    }
  }
  return result;
}
