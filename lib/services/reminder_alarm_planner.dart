import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/class_notification_builder.dart';
import 'package:orbit/services/next_day_summary_builder.dart';
import 'package:orbit/services/reminder_id_ranges.dart';

/// Builds Android AlarmManager specs for class-lead and check-in reminders.
List<ReminderAlarmSpec> buildReminderAlarmSpecs({
  required List<CourseSession> upcomingSessions,
  required ReminderSettings settings,
  required DateTime now,
  required NotificationCopy copy,
}) {
  final specs = <ReminderAlarmSpec>[];
  var classLeadId = classLeadAlarmBase;
  var checkInId = checkInAlarmBase;

  if (settings.enabled) {
    for (final session in upcomingSessions) {
      final reminderAt =
          session.startAt.subtract(Duration(minutes: settings.leadMinutes));
      if (!reminderAt.isAfter(now)) {
        continue;
      }

      final id = classLeadId++;
      final text = buildClassLeadNotificationText(
        session: session,
        settings: settings,
        copy: copy,
        leadMinutes: settings.leadMinutes,
      );
      specs.add(
        ReminderAlarmSpec(
          alarmId: id,
          notificationId: id,
          title: text.title,
          body: text.body,
          payload: session.id,
          fireAt: reminderAt,
          bigText: text.bigText,
        ),
      );
      if (classLeadId >= checkInAlarmBase) {
        break;
      }
    }
  }

  if (settings.checkInReminderEnabled) {
    for (final session in upcomingSessions) {
      if (!session.startAt.isAfter(now)) {
        continue;
      }

      final id = checkInId++;
      final text = buildCheckInNotificationText(
        session: session,
        settings: settings,
        copy: copy,
      );
      specs.add(
        ReminderAlarmSpec(
          alarmId: id,
          notificationId: id,
          title: text.title,
          body: text.body,
          payload: 'checkin_${session.id}',
          fireAt: session.startAt,
        ),
      );
      if (checkInId >= checkInAlarmLimit) {
        break;
      }
    }
  }

  return specs;
}

/// Builds Android AlarmManager specs for next-day summary notifications.
List<ReminderAlarmSpec> buildNextDaySummaryAlarmSpecs({
  required List<CourseSession> allSessions,
  required ReminderSettings settings,
  required DateTime now,
  required NotificationCopy copy,
}) {
  return buildNextDaySummarySlots(
    allSessions: allSessions,
    settings: settings,
    now: now,
    copy: copy,
  )
      .map(
        (slot) => ReminderAlarmSpec(
          alarmId: slot.notificationId,
          notificationId: slot.notificationId,
          title: slot.title,
          body: slot.body,
          payload: slot.payload,
          fireAt: slot.fireAt,
        ),
      )
      .toList();
}
