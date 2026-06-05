// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Orbit Schedule';

  @override
  String get navGrid => 'Schedule';

  @override
  String get navUpcoming => 'Upcoming';

  @override
  String get navImport => 'Import';

  @override
  String get navSettings => 'Settings';

  @override
  String get gridTitle => 'Schedule';

  @override
  String get gridPrevWeek => 'Previous week';

  @override
  String get gridNextWeek => 'Next week';

  @override
  String get gridThisWeek => 'This week';

  @override
  String gridLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get gridImportHint =>
      'Please import your schedule on the Import tab first';

  @override
  String get gridBatchDelete => 'Batch delete';

  @override
  String get gridBatchDeleteTitle => 'Batch delete classes';

  @override
  String get gridBatchDeleteStart => 'Start';

  @override
  String get gridBatchDeleteEnd => 'End';

  @override
  String gridBatchDeletePreview(int count) {
    return 'Will delete $count class sessions';
  }

  @override
  String get gridBatchDeleteConfirm1Title => 'Delete classes in range?';

  @override
  String gridBatchDeleteConfirm1Content(int count) {
    return 'This will delete $count class sessions fully within the selected time range.';
  }

  @override
  String get gridBatchDeleteConfirm2Title => 'Confirm deletion';

  @override
  String get gridBatchDeleteConfirm2Content =>
      'Deleted sessions cannot be recovered. Continue?';

  @override
  String get gridBatchDeleteNone =>
      'No classes fully within the selected range';

  @override
  String gridBatchDeleteDone(int count) {
    return 'Deleted $count class sessions';
  }

  @override
  String get gridBatchDeleteInvalidRange => 'End time must be after start time';

  @override
  String get gridWeekPickerYear => 'Change year';

  @override
  String get gridWeekPickerMonth => 'Change month';

  @override
  String get gridNoSessionsThisWeek => 'No classes this week';

  @override
  String get gridTimeColumn => 'Time';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get gridNoSessionsThisWeekSubtitle =>
      'Switch to another week or import a schedule';

  @override
  String get actionRetry => 'Retry';

  @override
  String get importViewGrid => 'View schedule';

  @override
  String resyncPartialFailed(int count) {
    return '$count reminder(s) could not be scheduled';
  }

  @override
  String get androidBatteryOptimizationGuided => 'Setup guided';

  @override
  String get trayInitFailed => 'System tray unavailable';

  @override
  String importPickMissingPath(String name) {
    return 'Could not read file: $name';
  }

  @override
  String get upcomingGoToGrid => 'View schedule';

  @override
  String gridUntilTime(String time) {
    return 'until $time';
  }

  @override
  String get gridEmptyTitle => 'No schedule imported';

  @override
  String get gridEmptySubtitle =>
      'Go to Import and select your xlsx schedule files';

  @override
  String get gridImportNow => 'Import now';

  @override
  String get upcomingTitle => 'Upcoming classes';

  @override
  String upcomingLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get groupToday => 'Today';

  @override
  String get groupTomorrow => 'Tomorrow';

  @override
  String get groupThisWeek => 'This week';

  @override
  String groupLater(String date) {
    return 'After $date';
  }

  @override
  String get inClass => 'In class';

  @override
  String get upcomingEmptyTitle => 'No upcoming classes';

  @override
  String get upcomingEmptySubtitle =>
      'All classes have ended, or no schedule imported yet';

  @override
  String get importTitle => 'Import schedule';

  @override
  String get importInProgress => 'Importing schedule…';

  @override
  String get importConfirm => 'Confirm import';

  @override
  String get importCancel => 'Cancel';

  @override
  String get importPickTitle => 'Select xlsx schedule files';

  @override
  String get importPickSubtitle =>
      'You can select multiple weekly schedules at once';

  @override
  String importSuccess(int count) {
    return 'Imported $count class sessions';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String importPickFailed(String error) {
    return 'Failed to pick files: $error';
  }

  @override
  String importParseFailed(String error) {
    return 'Parse failed ($error)';
  }

  @override
  String sessionCount(int count) {
    return '$count classes';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String settingsLoadFailed(String error) {
    return 'Failed to load settings: $error';
  }

  @override
  String get sectionReminders => 'Class reminders';

  @override
  String get sectionData => 'Data management';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get themeColorTitle => 'Theme color';

  @override
  String get themeColorSubtitle => 'Choose the app\'s accent color';

  @override
  String get themeColorCustom => 'Custom';

  @override
  String get themeColorCustomTitle => 'Custom color';

  @override
  String get themeColorInvalidHex =>
      'Enter a valid 6-digit hex color (e.g. 39C5BB)';

  @override
  String get actionApply => 'Apply';

  @override
  String get sectionSystem => 'System';

  @override
  String get launchAtStartup => 'Launch at startup';

  @override
  String get launchAtStartupSubtitle =>
      'Start minimized to the system tray when Windows boots';

  @override
  String get editSession => 'Edit class';

  @override
  String get editSessionShort => 'Edit';

  @override
  String get addSessionNote => 'Add note';

  @override
  String get addSessionNoteShort => 'Note';

  @override
  String get sessionNoteTitle => 'Class note';

  @override
  String get sessionNoteHint => 'Add a personal note for this class session';

  @override
  String get editSessionTitle => 'Edit class details';

  @override
  String get fieldCourseName => 'Course name';

  @override
  String get fieldRoom => 'Room';

  @override
  String get fieldTeachers => 'Teachers (comma separated)';

  @override
  String get fieldStartTime => 'Start time';

  @override
  String get fieldEndTime => 'End time';

  @override
  String get sessionUpdated => 'Class updated';

  @override
  String get sessionNoteSaved => 'Note saved';

  @override
  String get editSessionEndBeforeStart => 'End time must be after start time';

  @override
  String countdownStartsIn(int days, int hours, int minutes) {
    return '${days}d ${hours}h ${minutes}m';
  }

  @override
  String countdownSoon(String countdown) {
    return 'Soon · $countdown';
  }

  @override
  String get enableReminders => 'Enable class reminders';

  @override
  String get enableRemindersSubtitle =>
      'Send system notifications before class';

  @override
  String get leadTimeTitle => 'Reminder lead time';

  @override
  String leadTimeSubtitle(int minutes) {
    return 'Notify $minutes minutes before class';
  }

  @override
  String leadTimeOption(int minutes) {
    return '$minutes min';
  }

  @override
  String get resyncReminders => 'Resync reminders';

  @override
  String get resyncRemindersSubtitle =>
      'Reschedule all reminders from current schedule';

  @override
  String get sectionAndroidBackground => 'Background reminders (Android)';

  @override
  String get androidBackgroundSubtitle =>
      'Reminders use system alarms and do not require the app to stay open. Complete the settings below for best reliability.';

  @override
  String get androidCheckReminderPermissions => 'Check reminder permissions';

  @override
  String get androidPermissionsChecked =>
      'Notification and exact alarm permissions requested';

  @override
  String get androidBatteryOptimization => 'Battery optimization exemption';

  @override
  String get androidBatteryOptimizationHint =>
      'Tap to allow ignoring battery optimization';

  @override
  String get androidBatteryOptimizationDone =>
      'Battery optimization exemption configured';

  @override
  String get androidAutostartHint =>
      'On some devices, also enable autostart and allow background activity in system settings.';

  @override
  String get deleteEndedSessions => 'Delete ended classes';

  @override
  String get deleteEndedSessionsSubtitle =>
      'Remove class sessions that have already finished';

  @override
  String get deleteEndedConfirm1Title => 'Delete ended classes?';

  @override
  String deleteEndedConfirm1Content(int count) {
    return 'This will delete $count ended class sessions from your schedule.';
  }

  @override
  String get deleteEndedConfirm2Title => 'Confirm deletion';

  @override
  String get deleteEndedConfirm2Content =>
      'Deleted sessions cannot be recovered. Continue?';

  @override
  String get deleteEndedNone => 'No ended classes to delete';

  @override
  String deleteEndedDone(int count) {
    return 'Deleted $count ended class sessions';
  }

  @override
  String get clearAllData => 'Clear all schedules';

  @override
  String get clearAllDataSubtitle => 'Delete all imported class data';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsGithub => 'GitHub repository';

  @override
  String get settingsGithubOpenFailed => 'Could not open link';

  @override
  String get appTagline => 'Orbit — class reminder app';

  @override
  String get resyncDone => 'Reminders rescheduled';

  @override
  String get confirmClearTitle => 'Confirm clear';

  @override
  String get confirmClearContent =>
      'This will delete all imported schedule data and cannot be undone.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClear => 'Clear';

  @override
  String get dataCleared => 'Schedule data cleared';

  @override
  String get languageTitle => 'App language';

  @override
  String get languageSubtitle => 'Choose display language';

  @override
  String get langZhHant => 'Traditional Chinese';

  @override
  String get langZhHans => 'Simplified Chinese';

  @override
  String get langEn => 'English';

  @override
  String get languageChangedHint =>
      'Language updated. Tap Resync reminders to update notification text.';

  @override
  String get notificationChannelName => 'Class reminders';

  @override
  String get notificationChannelDesc => 'Notifications before class starts';

  @override
  String notificationTitle(int minutes) {
    return 'Class starting in $minutes min';
  }

  @override
  String notificationBody(String course, String room) {
    return '$course @ $room';
  }

  @override
  String notificationTime(String time) {
    return 'Time: $time';
  }

  @override
  String notificationRoom(String room) {
    return 'Room: $room';
  }

  @override
  String notificationTeachers(String teachers) {
    return 'Teachers: $teachers';
  }

  @override
  String get teachersNotProvided => 'Not provided';

  @override
  String get sectionAdvancedReminders => 'Advanced reminders';

  @override
  String get enableNextDaySummary => 'Next-day schedule preview';

  @override
  String get enableNextDaySummarySubtitle =>
      'Notify the evening before with tomorrow\'s first class and class count';

  @override
  String get nextDaySummaryTimeTitle => 'Preview notification time';

  @override
  String nextDaySummaryTimeSubtitle(String time) {
    return 'Send at $time the day before';
  }

  @override
  String get enableSystemAlarm => 'System alarm for first class (Android)';

  @override
  String get enableSystemAlarmSubtitle =>
      'Open the system clock app to set an alarm for tomorrow\'s first class';

  @override
  String get systemAlarmLeadTitle => 'Alarm lead time';

  @override
  String systemAlarmLeadSubtitle(int minutes) {
    return 'Alarm rings $minutes minutes before first class';
  }

  @override
  String get setTomorrowAlarm => 'Set alarm for tomorrow';

  @override
  String get alarmSetSuccess => 'System alarm screen opened';

  @override
  String get alarmSetFailed => 'Failed to open system alarm';

  @override
  String get alarmNoClassTomorrow => 'No classes tomorrow';

  @override
  String get enableCheckInReminder => 'Check-in reminder';

  @override
  String get enableCheckInReminderSubtitle =>
      'Notify at class start time to check in via campus app Bluetooth';

  @override
  String get checkInDisableConfirm1Title => 'Turn off check-in reminders?';

  @override
  String get checkInDisableConfirm1Content =>
      'You may miss campus app Bluetooth check-in reminders.';

  @override
  String get checkInDisableConfirm2Title => 'Are you sure?';

  @override
  String get checkInDisableConfirm2Content =>
      'Without reminders, you may forget to check in on time.';

  @override
  String get checkInDisableConfirm3Title => 'Final confirmation';

  @override
  String get checkInDisableConfirm3Content =>
      'This will disable all check-in reminders. Continue?';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionConfirmDisable => 'Turn off';

  @override
  String get actionDelete => 'Delete';

  @override
  String get deleteSession => 'Delete this class';

  @override
  String get deleteSessionShort => 'Delete';

  @override
  String get deleteSessionConfirmTitle => 'Delete this class session?';

  @override
  String deleteSessionConfirmContent(
    String course,
    String date,
    String time,
    String room,
  ) {
    return '$course\n$date $time · $room';
  }

  @override
  String get sessionDeleted => 'Class session deleted';

  @override
  String get trayShow => 'Show Orbit';

  @override
  String get trayExit => 'Exit';

  @override
  String get trayHiddenHint =>
      'Orbit is running in the background. Use the tray icon to show or exit.';

  @override
  String notificationCheckInTitle(String course, String room) {
    return 'Check in now: $course @ $room';
  }

  @override
  String notificationCheckInBody(String course) {
    return 'Open the campus app and complete Bluetooth check-in for $course';
  }

  @override
  String get notificationNextDayTitle => 'Tomorrow\'s schedule';

  @override
  String notificationNextDayBody(int count, String time) {
    return '$count classes tomorrow. First class at $time.';
  }

  @override
  String get notificationNextDayNoClassTitle => 'Tomorrow\'s schedule';

  @override
  String get notificationNextDayNoClassBody =>
      'No classes scheduled for tomorrow.';
}
