import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/notification_template_utils.dart';
import 'package:orbit/services/reminder_id_ranges.dart';
import 'package:orbit/services/schedule_summary_service.dart';

const nextDaySummaryDays = 30;

class NextDaySummarySlot {
  const NextDaySummarySlot({
    required this.notificationId,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int notificationId;
  final DateTime fireAt;
  final String title;
  final String body;
  final String payload;
}

/// Replaces `{key}` placeholders; empty [template] falls back to [fallback].
String applyNextDayTemplate(
  String? template,
  String fallback,
  Map<String, String> variables,
) =>
    applyNotificationTemplate(template, fallback, variables);

String nextDayDateLabel(DateTime day) {
  return '${day.month}/${day.day}';
}

String nextDayPayloadKey(DateTime targetDay) {
  return '${targetDay.year}-${targetDay.month.toString().padLeft(2, '0')}-'
      '${targetDay.day.toString().padLeft(2, '0')}';
}

List<NextDaySummarySlot> buildNextDaySummarySlots({
  required List<CourseSession> allSessions,
  required ReminderSettings settings,
  required DateTime now,
  required NotificationCopy copy,
}) {
  if (!settings.nextDaySummaryEnabled) {
    return const [];
  }

  final today = DateTime(now.year, now.month, now.day);
  final sessionsByDate = groupSessionsByDate(allSessions);
  final slots = <NextDaySummarySlot>[];

  for (var offset = 0; offset < nextDaySummaryDays; offset++) {
    final targetDay = today.add(Duration(days: offset + 1));
    final notifyDay = targetDay.subtract(const Duration(days: 1));
    final notifyAt = DateTime(
      notifyDay.year,
      notifyDay.month,
      notifyDay.day,
      settings.nextDaySummaryHour,
      settings.nextDaySummaryMinute,
    );
    if (!notifyAt.isAfter(now)) {
      continue;
    }

    final summary = summarizeDayFromGrouped(sessionsByDate, targetDay);
    final dateLabel = nextDayDateLabel(targetDay);
    final notificationId = nextDaySummaryAlarmBase + offset;

    if (summary.hasClasses) {
      final firstTime = formatTimeOfDay(summary.firstSessionStart!);
      final variables = {
        'count': '${summary.sessionCount}',
        'time': firstTime,
        'date': dateLabel,
      };
      slots.add(
        NextDaySummarySlot(
          notificationId: notificationId,
          fireAt: notifyAt,
          title: applyNextDayTemplate(
            settings.nextDayWithClassTitleTemplate,
            copy.nextDaySummaryTitle,
            variables,
          ),
          body: applyNextDayTemplate(
            settings.nextDayWithClassBodyTemplate,
            copy.nextDaySummaryBody(summary.sessionCount, firstTime),
            variables,
          ),
          payload: 'next_day_${nextDayPayloadKey(targetDay)}',
        ),
      );
    } else {
      if (!settings.nextDayRemindWhenNoClass) {
        continue;
      }
      final variables = {'date': dateLabel};
      slots.add(
        NextDaySummarySlot(
          notificationId: notificationId,
          fireAt: notifyAt,
          title: applyNextDayTemplate(
            settings.nextDayNoClassTitleTemplate,
            copy.nextDayNoClassTitle,
            variables,
          ),
          body: applyNextDayTemplate(
            settings.nextDayNoClassBodyTemplate,
            copy.nextDayNoClassBody,
            variables,
          ),
          payload: 'next_day_empty_${nextDayPayloadKey(targetDay)}',
        ),
      );
    }
  }

  return slots;
}

int countNextDaySummarySlots({
  required List<CourseSession> allSessions,
  required ReminderSettings settings,
  required DateTime now,
}) {
  if (!settings.nextDaySummaryEnabled) {
    return 0;
  }

  final today = DateTime(now.year, now.month, now.day);
  final sessionsByDate = groupSessionsByDate(allSessions);
  var count = 0;

  for (var offset = 0; offset < nextDaySummaryDays; offset++) {
    final targetDay = today.add(Duration(days: offset + 1));
    final notifyDay = targetDay.subtract(const Duration(days: 1));
    final notifyAt = DateTime(
      notifyDay.year,
      notifyDay.month,
      notifyDay.day,
      settings.nextDaySummaryHour,
      settings.nextDaySummaryMinute,
    );
    if (!notifyAt.isAfter(now)) {
      continue;
    }

    final summary = summarizeDayFromGrouped(sessionsByDate, targetDay);
    if (!summary.hasClasses && !settings.nextDayRemindWhenNoClass) {
      continue;
    }
    count++;
  }

  return count;
}
