import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/notification_template_utils.dart';
import 'package:orbit/services/schedule_summary_service.dart';

class ClassLeadNotificationText {
  const ClassLeadNotificationText({
    required this.title,
    required this.body,
    required this.bigText,
  });

  final String title;
  final String body;
  final String bigText;
}

ClassLeadNotificationText buildClassLeadNotificationText({
  required CourseSession session,
  required ReminderSettings settings,
  required NotificationCopy copy,
  required int leadMinutes,
}) {
  final teachers = session.teachers.isEmpty
      ? copy.teachersNotProvided
      : session.teachers.join('、');
  final timeLabel = formatTimeOfDay(session.startAt);
  final variables = {
    'course': session.courseName,
    'room': session.room,
    'time': timeLabel,
    'minutes': '$leadMinutes',
  };

  return ClassLeadNotificationText(
    title: applyNotificationTemplate(
      settings.classLeadTitleTemplate,
      copy.titleFor(leadMinutes),
      variables,
    ),
    body: applyNotificationTemplate(
      settings.classLeadBodyTemplate,
      copy.bodyFor(session.courseName, session.room),
      variables,
    ),
    bigText: copy.bigTextFor(
      course: session.courseName,
      time: timeLabel,
      room: session.room,
      teachers: teachers,
    ),
  );
}

class CheckInNotificationText {
  const CheckInNotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

CheckInNotificationText buildCheckInNotificationText({
  required CourseSession session,
  required ReminderSettings settings,
  required NotificationCopy copy,
}) {
  final timeLabel = formatTimeOfDay(session.startAt);
  final variables = {
    'course': session.courseName,
    'room': session.room,
    'time': timeLabel,
  };

  return CheckInNotificationText(
    title: applyNotificationTemplate(
      settings.checkInTitleTemplate,
      copy.checkInTitle(session.courseName, session.room),
      variables,
    ),
    body: applyNotificationTemplate(
      settings.checkInBodyTemplate,
      copy.checkInBody(session.courseName),
      variables,
    ),
  );
}
