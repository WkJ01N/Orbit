import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/schedule_summary_service.dart';

const classLeadAlarmBase = 1;
const checkInAlarmBase = 500000;
const checkInAlarmLimit = 1000000;

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
      final teachers = session.teachers.isEmpty
          ? copy.teachersNotProvided
          : session.teachers.join('、');
      final timeLabel = formatTimeOfDay(session.startAt);
      specs.add(
        ReminderAlarmSpec(
          alarmId: id,
          notificationId: id,
          title: copy.titleFor(settings.leadMinutes),
          body: copy.bodyFor(session.courseName, session.room),
          payload: session.id,
          fireAt: reminderAt,
          bigText: copy.bigTextFor(
            course: session.courseName,
            time: timeLabel,
            room: session.room,
            teachers: teachers,
          ),
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
      specs.add(
        ReminderAlarmSpec(
          alarmId: id,
          notificationId: id,
          title: copy.checkInTitle(session.courseName, session.room),
          body: copy.checkInBody(session.courseName),
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
