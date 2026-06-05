import 'package:orbit/l10n/app_localizations.dart';

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
  }) bigTextFor;
  final String teachersNotProvided;
  final String Function(String course, String room) checkInTitle;
  final String Function(String course) checkInBody;
  final String nextDaySummaryTitle;
  final String Function(int count, String firstTime) nextDaySummaryBody;
  final String nextDayNoClassTitle;
  final String nextDayNoClassBody;

  factory NotificationCopy.fromL10n(AppLocalizations l10n) {
    return NotificationCopy(
      channelName: l10n.notificationChannelName,
      channelDescription: l10n.notificationChannelDesc,
      titleFor: l10n.notificationTitle,
      bodyFor: l10n.notificationBody,
      bigTextFor: ({
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
    );
  }
}
