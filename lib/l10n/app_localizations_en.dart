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
      'Switch to another week to view classes';

  @override
  String get actionRetry => 'Retry';

  @override
  String get importViewGrid => 'View schedule';

  @override
  String resyncPartialFailed(int count) {
    return '$count reminder(s) could not be scheduled';
  }

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
  String get countdownSoonLabel => 'Soon';

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
  String get androidBatteryOptimizationSubtitleOn =>
      'Exempt from battery optimization for more reliable reminders';

  @override
  String get androidBatteryOptimizationSubtitleOff =>
      'Enable to improve background reminder reliability';

  @override
  String get androidBatteryOptimizationDisableConfirmTitle =>
      'Turn off battery optimization exemption?';

  @override
  String get androidBatteryOptimizationDisableConfirmContent =>
      'You will be taken to system settings to restore battery optimization. Background reminders may be less reliable.';

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

  @override
  String get exportScheduleJson => 'Export JSON backup';

  @override
  String get exportScheduleJsonSubtitle =>
      'Save all schedule data for restore or migration';

  @override
  String get exportScheduleXlsx => 'Export as xlsx';

  @override
  String get exportScheduleXlsxSubtitle =>
      'Export in the same format as import';

  @override
  String get restoreFromBackup => 'Restore from backup';

  @override
  String get restoreFromBackupSubtitle =>
      'Import schedule from a JSON backup file';

  @override
  String exportDone(int count) {
    return 'Exported $count class sessions';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get exportNothingToExport => 'No schedule data to export';

  @override
  String get restoreConfirmTitle => 'Restore backup?';

  @override
  String restoreConfirmContent(int count) {
    return 'This will merge $count class sessions from the backup.';
  }

  @override
  String restoreDone(int count) {
    return 'Restored $count class sessions';
  }

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get backupInvalidFormat => 'Invalid backup file format';

  @override
  String get backupUnsupportedVersion => 'Unsupported backup version';

  @override
  String get addSession => 'Add class';

  @override
  String get addSessionTitle => 'Add class';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldCourseCode => 'Course code';

  @override
  String get fieldSection => 'Section';

  @override
  String get defaultClassType => 'General class';

  @override
  String get sessionCreated => 'Class added';

  @override
  String get sessionCreateRequiredFields => 'Course name and room are required';

  @override
  String get sessionTimeConflict => 'Another class overlaps this time slot';

  @override
  String sessionSavedWithOverride(int count) {
    return 'Saved. Replaced $count overlapping class(es).';
  }

  @override
  String get importStrategyTitle => 'Duplicate weeks detected';

  @override
  String importStrategyMessage(int count) {
    return '$count week(s) in this import already contain classes. Choose how to import them.';
  }

  @override
  String get importStrategyReplaceWeek => 'Replace whole week';

  @override
  String get importStrategyReplaceWeekDesc =>
      'Delete all existing classes in those weeks, then import the new ones.';

  @override
  String get importStrategyMerge => 'Merge and overwrite conflicts';

  @override
  String get importStrategyMergeDesc =>
      'Keep other classes; replace only those whose time overlaps an imported class.';

  @override
  String get actionCreate => 'Create';

  @override
  String sessionSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get languageChangedResynced =>
      'Language updated and reminders resynced';

  @override
  String get searchSessions => 'Search classes';

  @override
  String get searchHint => 'Search by course, room, or teacher';

  @override
  String get searchNoResults => 'No matching classes';

  @override
  String searchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String searchResultsTruncated(int count) {
    return 'Showing first $count results only';
  }

  @override
  String gridBatchDeleteFailed(String error) {
    return 'Batch delete failed: $error';
  }

  @override
  String clearAllFailed(String error) {
    return 'Failed to clear schedule: $error';
  }

  @override
  String launchAtStartupFailed(String error) {
    return 'Failed to update startup setting: $error';
  }

  @override
  String get sectionSchedule => 'Schedule';

  @override
  String get gridDefaultWeekTitle => 'Default week';

  @override
  String get gridDefaultWeekSubtitle =>
      'Which week to show when opening the schedule';

  @override
  String get gridDefaultWeekSmart => 'Smart';

  @override
  String get gridDefaultWeekCurrent => 'This week';

  @override
  String get gridDefaultWeekEarliest => 'Earliest week with classes';

  @override
  String get exportInProgress => 'Exporting…';

  @override
  String get importFormatTitle => 'Schedule file format';

  @override
  String get importFormatSubtitle =>
      'xlsx columns A–M (one row per class session)';

  @override
  String get importFormatColumn => 'Col';

  @override
  String get importFormatField => 'Field';

  @override
  String get importFormatExample => 'Example';

  @override
  String get importFormatClassType => 'Class type';

  @override
  String get importFormatClassTypeExample => 'General class';

  @override
  String get importFormatRoom => 'Room';

  @override
  String get importFormatRoomExample => 'A001';

  @override
  String get importFormatCapacity => 'Capacity';

  @override
  String get importFormatCapacityExample => '67';

  @override
  String get importFormatFaculty => 'Faculty';

  @override
  String get importFormatFacultyExample => 'Example Faculty';

  @override
  String get importFormatDate => 'Date';

  @override
  String get importFormatDateExample => '2026-07-27';

  @override
  String get importFormatWeekday => 'Weekday';

  @override
  String get importFormatWeekdayExample => '1 (Mon) – 7 (Sun)';

  @override
  String get importFormatCourseName => 'Course name';

  @override
  String get importFormatCourseNameExample => 'Physics';

  @override
  String get importFormatCourseCode => 'Course code';

  @override
  String get importFormatCourseCodeExample => 'P0721';

  @override
  String get importFormatSection => 'Section';

  @override
  String get importFormatSectionExample => 'EX1';

  @override
  String get importFormatStartTime => 'Start time';

  @override
  String get importFormatStartTimeExample => '12:30';

  @override
  String get importFormatEndTime => 'End time';

  @override
  String get importFormatEndTimeExample => '15:20';

  @override
  String get importFormatTeachers => 'Teachers';

  @override
  String get importFormatTeachersExample => 'Miku,null';

  @override
  String get importFormatSemester => 'Semester';

  @override
  String get importFormatSemesterExample => '2606';

  @override
  String get xlsxErrorNoSheet => 'No worksheet found in file';

  @override
  String get xlsxErrorEmptySheet => 'Schedule file is empty';

  @override
  String get xlsxErrorNoSessions => 'No class sessions parsed';

  @override
  String xlsxErrorInsufficientColumns(String detail) {
    return 'Insufficient columns ($detail)';
  }

  @override
  String xlsxErrorInvalidDate(String detail) {
    return 'Invalid date: $detail';
  }

  @override
  String xlsxErrorInvalidTime(String detail) {
    return 'Invalid time: $detail';
  }

  @override
  String reminderSyncFailed(String error) {
    return 'Reminder sync failed: $error';
  }

  @override
  String get reminderResyncFailedBanner =>
      'Reminders could not be synced. Tap Resync to try again.';

  @override
  String get reminderScheduleVerifyFailed =>
      'Reminders saved, but the system did not queue any alarms. Please allow exact alarms and disable battery optimization, then resync.';

  @override
  String get reminderScheduleVerifyFailedBanner =>
      'The system did not queue any reminders. Check exact alarm and battery settings, then resync.';

  @override
  String reminderScheduledCount(int count) {
    return '$count reminder(s) scheduled';
  }

  @override
  String get androidNotificationsEnabled => 'Notifications enabled';

  @override
  String get androidNotificationsDisabled => 'Notifications disabled';

  @override
  String get androidExactAlarmsEnabled => 'Exact alarms allowed';

  @override
  String get androidExactAlarmsDisabled => 'Exact alarms not allowed';
}
