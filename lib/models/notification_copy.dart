import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/deadline_text.dart';

class NotificationCopy {
  const NotificationCopy({
    required this.channelName,
    required this.channelDescription,
    required this.titleFor,
    required this.bodyFor,
    required this.bigTextFor,
    required this.teachersNotProvided,
    required this.checkInTitle,
    required this.checkInBody,
    required this.nextDaySummaryTitle,
    required this.nextDaySummaryBody,
    required this.nextDayNoClassTitle,
    required this.nextDayNoClassBody,
    this.deadlineText = const DeadlineText(Locale('en')),
    this.catchUpLabel = 'Catch-up',
    this.catchUpNotice =
        'This is a catch-up message, not a real-time reminder.',
    this.originalLabel = 'Originally scheduled',
    this.deliveredLabel = 'Delivered',
    this.acknowledgeLabel = 'Acknowledge',
    this.stopLabel = 'Stop',
    this.weekdayNames = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ],
  });

  final String channelName;
  final String channelDescription;
  final String Function(int minutes) titleFor;
  final String Function(String course, String room) bodyFor;
  final String Function({
    required String course,
    required String time,
    required String room,
    required String teachers,
  })
  bigTextFor;
  final String teachersNotProvided;
  final String Function(String course, String room) checkInTitle;
  final String Function(String course) checkInBody;
  final String nextDaySummaryTitle;
  final String Function(int count, String firstTime) nextDaySummaryBody;
  final String nextDayNoClassTitle;
  final String nextDayNoClassBody;
  final DeadlineText deadlineText;
  final String catchUpLabel,
      catchUpNotice,
      originalLabel,
      deliveredLabel,
      acknowledgeLabel,
      stopLabel;
  final List<String> weekdayNames;

  factory NotificationCopy.fromL10n(AppLocalizations l10n) {
    return NotificationCopy(
      channelName: l10n.notificationChannelName,
      channelDescription: l10n.notificationChannelDesc,
      titleFor: l10n.notificationTitle,
      bodyFor: l10n.notificationBody,
      bigTextFor:
          ({
            required String course,
            required String time,
            required String room,
            required String teachers,
          }) {
            return '$course\n'
                '${l10n.notificationTime(time)}\n'
                '${l10n.notificationRoom(room)}\n'
                '${l10n.notificationTeachers(teachers)}';
          },
      teachersNotProvided: l10n.teachersNotProvided,
      checkInTitle: l10n.notificationCheckInTitle,
      checkInBody: l10n.notificationCheckInBody,
      nextDaySummaryTitle: l10n.notificationNextDayTitle,
      nextDaySummaryBody: l10n.notificationNextDayBody,
      nextDayNoClassTitle: l10n.notificationNextDayNoClassTitle,
      nextDayNoClassBody: l10n.notificationNextDayNoClassBody,
      deadlineText: DeadlineText.fromTag(l10n.localeName),
      catchUpLabel: l10n.reminderCatchUp,
      catchUpNotice: l10n.reminderCatchUpNotice,
      originalLabel: l10n.reminderOriginalTime,
      deliveredLabel: l10n.reminderDeliveredTime,
      acknowledgeLabel: l10n.reminderAcknowledge,
      stopLabel: l10n.reminderStop,
      weekdayNames: l10n.reminderWeekdayNames.split('|'),
    );
  }
}
