// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get importAuto => 'Auto detect';

  @override
  String get importTemplates => 'Recognition templates';

  @override
  String get importPlans => 'Semester & period times';

  @override
  String get importListLayout => 'Course list';

  @override
  String get importGridLayout => 'Weekly grid';

  @override
  String get importLegacyLayout => 'Orbit 13-column format';

  @override
  String get importTemplateName => 'Template name';

  @override
  String get importBuiltIn => 'Built-in · copy to edit';

  @override
  String get importCopy => 'Copy';

  @override
  String get importShareTemplate => 'Export template JSON';

  @override
  String get importLoadTemplate => 'Import template JSON';

  @override
  String get importLayoutStep => 'Layout & region';

  @override
  String get importFieldsStep => 'Field mapping';

  @override
  String get importRegexStep => 'Extraction rules';

  @override
  String get importTestStep => 'Test & preview';

  @override
  String get importHeaderRow => 'Header row (1-based)';

  @override
  String get importFirstRow => 'First course row';

  @override
  String get importLastRow => 'Last course row (blank = end)';

  @override
  String get importFirstColumn => 'First course column (1-based)';

  @override
  String get importLastColumn => 'Last course column';

  @override
  String get importWeekdayColumns => 'Column:weekday, e.g. 2:1,3:2';

  @override
  String get importPeriodRows => 'Row:periods, e.g. 2:1-2;3:3-4';

  @override
  String get importColumnSource => 'Column';

  @override
  String get importTextSource => 'Course text';

  @override
  String get importFixedSource => 'Fixed value';

  @override
  String get importWeekdaySource => 'Grid weekday';

  @override
  String get importPeriodsSource => 'Grid periods';

  @override
  String get importColumnNumber => 'Column number (1-based)';

  @override
  String get importFixedValue => 'Fixed value';

  @override
  String get importPattern => 'Regular expression (blank = original)';

  @override
  String get importCaptureGroup => 'Capture group number or name';

  @override
  String get importCaseSensitive => 'Case sensitive';

  @override
  String get importMultiLine => 'Multiline anchors';

  @override
  String get importDotAll => 'Dot matches newline';

  @override
  String get importUnicode => 'Unicode mode';

  @override
  String get importBlockPattern => 'Course block separator / match regex';

  @override
  String get importRepeatBlocks => 'Repeated course block matching';

  @override
  String get importTestText => 'Sample course text';

  @override
  String get importRunTest => 'Run test';

  @override
  String get importOriginal => 'Original text';

  @override
  String get importMatches => 'Matches & capture groups';

  @override
  String get importExtracted => 'Extracted fields';

  @override
  String get importSave => 'Save';

  @override
  String get importNext => 'Next';

  @override
  String get importBack => 'Back';

  @override
  String get importSemesterName => 'Semester name';

  @override
  String get importFirstMonday => 'First week Monday (YYYY-MM-DD)';

  @override
  String get importTotalWeeks => 'Total weeks (1–30)';

  @override
  String get importPeriodPlanName => 'Period time plan name';

  @override
  String get importPeriodTimeInput =>
      'Period,start,end — one per line; e.g. 1,08:00,08:45';

  @override
  String get importDefaultWeeks => 'Weeks when absent from file (e.g. 1-18)';

  @override
  String get importConfirmContext =>
      'Confirm semester, weeks and period times for this import';

  @override
  String get importTemporaryContext =>
      'Temporary changes apply only to this import. Save plans separately.';

  @override
  String get importEncoding => 'CSV encoding';

  @override
  String get importDelimiter => 'CSV delimiter';

  @override
  String get importComma => 'Comma';

  @override
  String get importSemicolon => 'Semicolon';

  @override
  String get importTab => 'Tab';

  @override
  String get importPreview => 'Parse & preview';

  @override
  String get importSkipErrors => 'Explicitly skip failed courses';

  @override
  String get importSkipDescription =>
      'Failed courses will not be imported. Review each error first.';

  @override
  String get importCancelTask => 'Cancel parsing';

  @override
  String get importSelectSheet => 'Select worksheets to import';

  @override
  String get importRawTable =>
      'Original table — tap a cell to select coordinates';

  @override
  String get importChooseCoordinate => 'Use selected cell as';

  @override
  String get importNoSelection => 'No worksheet selected';

  @override
  String get importNone => 'None';

  @override
  String get importValid => 'Valid';

  @override
  String get importDuplicates => 'Duplicates';

  @override
  String get importErrors => 'Errors';

  @override
  String get importDeleteConfirm => 'Delete this saved template or plan?';

  @override
  String get importHelp =>
      'Lists need course name, date (or weekday and weeks), and start/end times (or periods). Grids use weekday columns and period rows. Separate multiple courses by a blank line, or configure block rules. Weekly schedules need a confirmed semester and period time plan.';

  @override
  String get importFieldCourseName => 'Course name';

  @override
  String get importFieldCourseCode => 'Course code';

  @override
  String get importFieldSection => 'Section';

  @override
  String get importFieldRoom => 'Room';

  @override
  String get importFieldTeachers => 'Teachers';

  @override
  String get importFieldFaculty => 'Faculty';

  @override
  String get importFieldClassType => 'Class type';

  @override
  String get importFieldSemester => 'Semester';

  @override
  String get importFieldDate => 'Date';

  @override
  String get importFieldWeekday => 'Weekday';

  @override
  String get importFieldWeeks => 'Weeks';

  @override
  String get importFieldPeriods => 'Periods';

  @override
  String get importFieldStartTime => 'Start time';

  @override
  String get importFieldEndTime => 'End time';

  @override
  String get importErrorAmbiguous =>
      'Multiple templates match; select one explicitly.';

  @override
  String get importErrorTemplateInvalid =>
      'Invalid template or region configuration.';

  @override
  String get importErrorTemplateVersion => 'Unsupported template version.';

  @override
  String get importErrorCaptureGroup =>
      'Capture group number or name is invalid.';

  @override
  String get importErrorMissingName => 'Course name is required.';

  @override
  String get importErrorSemesterInvalid =>
      'Check semester name, Monday date and total weeks.';

  @override
  String get importErrorPeriodInvalid =>
      'Invalid period numbers or period time plan.';

  @override
  String get importErrorInvalidTime =>
      'Invalid time; end must be later than start.';

  @override
  String get importErrorInvalidDate => 'Invalid calendar date.';

  @override
  String get importErrorInvalidWeekday =>
      'Weekday must be Monday through Sunday.';

  @override
  String get importErrorWeekdayMismatch =>
      'Weekday does not match the calendar date.';

  @override
  String get importErrorInvalidWeeks =>
      'Invalid weeks or weeks outside the semester.';

  @override
  String get importErrorWeeksRequired =>
      'Confirm applicable weeks when missing from the file.';

  @override
  String get importErrorContextRequired =>
      'Confirm the semester and required period time plan.';

  @override
  String get importErrorUnknownPeriod =>
      'No time mapping for one or more periods.';

  @override
  String get importErrorHorizontalMerge =>
      'Course merged across weekday columns is unsupported.';

  @override
  String get importErrorZeroLength =>
      'Course block rules must not match empty text.';

  @override
  String get importErrorNoMatch => 'No matching course block found.';

  @override
  String get importErrorUnmatchedText =>
      'Course block rule leaves unmatched text; refine the rule.';

  @override
  String get importErrorIdConflict =>
      'Same class ID has different content; resolve or explicitly skip.';

  @override
  String get importErrorNoSessions => 'No valid courses found.';

  @override
  String get importErrorNoSheet => 'No worksheet found.';

  @override
  String get importErrorUnsupportedFile =>
      'Only XLSX and CSV files are supported.';

  @override
  String get importErrorEncodingFailed =>
      'Could not decode CSV; choose an encoding or convert the file.';

  @override
  String get importErrorTimeout =>
      'Parsing timed out. Your configuration is retained.';

  @override
  String get importErrorCancelled => 'Parsing cancelled.';

  @override
  String get importErrorWorkerFailed => 'Parsing worker failed. Please retry.';

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
      'The selected sessions will stay in Recently Deleted for 7 days. Continue?';

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
      'Go to Import and select your XLSX or CSV schedule files';

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
  String upcomingWeekMonday(String date) {
    return '$date';
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
  String get importPickTitle => 'Select XLSX / CSV schedule files';

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
  String get settingsCategoryGeneral => 'General';

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
  String get themeStyleTitle => 'Course colors';

  @override
  String get themeStyleSubtitle =>
      'Use one accent or automatic colors for each course';

  @override
  String get themeStyleStandard => 'Uniform color';

  @override
  String get themeStyleColorful => 'Automatic colors';

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
  String get themeModeTitle => 'Theme mode';

  @override
  String get themeModeSubtitle => 'Choose light, dark, or follow system';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get weekStartDayTitle => 'Week start day';

  @override
  String get weekStartDaySubtitle => 'Which day each week begins on the grid';

  @override
  String get weekStartMonday => 'Monday';

  @override
  String get weekStartSunday => 'Sunday';

  @override
  String get gridDensityTitle => 'Grid density';

  @override
  String get gridDensitySubtitle => 'Adjust row height and font size';

  @override
  String get gridDensityCompact => 'Compact';

  @override
  String get gridDensityStandard => 'Standard';

  @override
  String get gridDensityComfortable => 'Comfortable';

  @override
  String get scheduleNarrowLayoutTitle => 'Narrow-screen schedule layout';

  @override
  String get scheduleNarrowLayoutSubtitle =>
      'Choose a full compact week or the classic adaptive day view';

  @override
  String get scheduleNarrowLayoutCompactWeek => 'Compact full week';

  @override
  String get scheduleNarrowLayoutAdaptive => 'Classic adaptive';

  @override
  String get scheduleMultiDayCountTitle => 'Days in multi-day view';

  @override
  String scheduleMultiDayCountSubtitle(int maxCount) {
    return 'This window can show up to $maxCount readable days';
  }

  @override
  String scheduleDayCountOption(int count) {
    return '$count days';
  }

  @override
  String get scheduleShowEmptyDaysTitle => 'Show days without classes';

  @override
  String get scheduleShowEmptyDaysSubtitle =>
      'Used by classic adaptive view; turn off to move directly between class days';

  @override
  String get upcomingShowCourseDateTitle => 'Show date beside countdown';

  @override
  String get upcomingShowCourseDateSubtitle =>
      'Display the course date in the Upcoming list';

  @override
  String get upcomingDateDisplayTitle => 'Course date format';

  @override
  String get upcomingDateDisplaySubtitle => 'Choose which date details to show';

  @override
  String get upcomingDateDisplayDateAndWeekday => 'Date + weekday';

  @override
  String get upcomingDateDisplayDateOnly => 'Date only';

  @override
  String get upcomingDateDisplayWeekdayOnly => 'Weekday only';

  @override
  String get scheduleJumpToNearestCourse => 'Nearest class day';

  @override
  String scheduleCourseCount(int count) {
    return '$count courses';
  }

  @override
  String get classLeadCustomizeTemplates => 'Customize class reminders';

  @override
  String get classLeadCustomizeTemplatesSubtitle =>
      'Leave blank for default text';

  @override
  String get classLeadTemplateSheetTitle => 'Class reminder text';

  @override
  String get classLeadTitleLabel => 'Title';

  @override
  String get classLeadBodyLabel => 'Body';

  @override
  String classLeadTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
    String minutesToken,
  ) {
    return 'Use $courseToken, $roomToken, $timeToken, $minutesToken. Leave blank for defaults.';
  }

  @override
  String get checkInCustomizeTemplates => 'Customize check-in reminders';

  @override
  String get checkInCustomizeTemplatesSubtitle =>
      'Leave blank for default text';

  @override
  String get checkInTemplateSheetTitle => 'Check-in reminder text';

  @override
  String get checkInTitleLabel => 'Title';

  @override
  String get checkInBodyLabel => 'Body';

  @override
  String checkInTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
  ) {
    return 'Use $courseToken, $roomToken, $timeToken. Leave blank for defaults.';
  }

  @override
  String get sessionColor => 'Course color';

  @override
  String get sessionColorShort => 'Color';

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
  String get fieldFaculty => 'Faculty';

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
      'Reminders use background scheduled reminders and do not require the app to stay open. Complete the settings below for best reliability.';

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
      'On OriginOS / iQOO, allow autostart and unrestricted background activity, then lock Orbit in recents.';

  @override
  String get debugTitle => 'Debug';

  @override
  String get debugSubtitle =>
      'Notification and background reminder diagnostics';

  @override
  String get androidTestImmediateReminder => 'Test notification now';

  @override
  String get androidTestImmediateReminderSubtitle =>
      'Immediately verifies notification permission and display.';

  @override
  String get androidTestImmediateReminderShown => 'Test notification sent.';

  @override
  String get androidTestBackgroundReminder =>
      'Test background reminder (1 min)';

  @override
  String get androidTestBackgroundReminderSubtitle =>
      'Registers the same native alarm as class reminders. After one minute, reopen Orbit to inspect registration, receiver, and notification stages.';

  @override
  String get androidTestBackgroundReminderScheduled =>
      'Stage 1 passed: the one-minute alarm is registered. Leave Orbit, wait, then check Reminder diagnostics.';

  @override
  String androidTestBackgroundReminderScheduledAt(String time) {
    return 'Stage 1 passed: Android registered the alarm for $time. Leave Orbit, wait, then check Reminder diagnostics.';
  }

  @override
  String get androidTestBackgroundNotificationTitle =>
      'Orbit background reminder test';

  @override
  String get androidTestBackgroundNotificationBody =>
      'The background reminder fired successfully. Orbit can notify you while it is not in the foreground.';

  @override
  String get androidTestBackgroundReminderFailed =>
      'Could not schedule the test reminder. Check exact alarm permission.';

  @override
  String get androidTestReminderNotificationsDenied =>
      'Notifications are disabled. Allow notifications and try again.';

  @override
  String get androidTestReminderExactAlarmsDenied =>
      'Exact alarms are disabled. Allow exact alarms and try again.';

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
      'Ended sessions will stay in Recently Deleted for 7 days. Continue?';

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
      'All imported schedule data will be moved to Recently Deleted and kept for 7 days.';

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
  String get nextDayRemindWhenNoClass => 'Remind when no classes';

  @override
  String get nextDayRemindWhenNoClassSubtitle =>
      'Still send a preview notification when tomorrow has no classes';

  @override
  String get nextDayCustomizeTemplates => 'Customize reminder text';

  @override
  String get nextDayCustomizeTemplatesSubtitle =>
      'Edit title and body; leave blank for defaults';

  @override
  String get nextDayTemplateSheetTitle => 'Next-day reminder text';

  @override
  String get nextDayWithClassTitleLabel => 'Title (with classes)';

  @override
  String get nextDayWithClassBodyLabel => 'Body (with classes)';

  @override
  String get nextDayNoClassTitleLabel => 'Title (no classes)';

  @override
  String get nextDayNoClassBodyLabel => 'Body (no classes)';

  @override
  String nextDayTemplatePlaceholderHint(
    String countToken,
    String timeToken,
    String dateToken,
  ) {
    return 'Body with classes: $countToken, $timeToken, $dateToken. No-class body: $dateToken. Leave blank for defaults.';
  }

  @override
  String get nextDayTemplateReset => 'Reset to defaults';

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
  String get deleteSession => 'Delete class';

  @override
  String get deleteSessionShort => 'Delete';

  @override
  String get courseColorDefault => 'Default';

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
  String get importFormatSubtitle => 'XLSX / CSV course lists and weekly grids';

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
      'Reminders were saved, but Android did not queue them. Check notification, exact alarm, and battery settings, then resync.';

  @override
  String get reminderScheduleVerifyFailedBanner =>
      'Android did not queue any reminders. Check notification, exact alarm, and battery settings, then resync.';

  @override
  String reminderScheduledCount(int count) {
    return '$count reminder(s) scheduled';
  }

  @override
  String reminderRegisteredAlarmCount(int count) {
    return '$count background reminder(s) registered';
  }

  @override
  String get androidNotificationsEnabled => 'Notifications enabled';

  @override
  String get androidNotificationsDisabled => 'Notifications disabled';

  @override
  String get androidExactAlarmsEnabled => 'Exact alarms allowed';

  @override
  String get androidExactAlarmsDisabled => 'Exact alarms not allowed';

  @override
  String get actionUndo => 'Undo';

  @override
  String get trashTitle => 'Recently deleted';

  @override
  String get trashSubtitle => 'Deleted classes are kept for 7 days';

  @override
  String get trashEmpty => 'No recently deleted classes';

  @override
  String trashDeletedAt(Object time) {
    return 'Deleted $time';
  }

  @override
  String get trashRestoreSelected => 'Restore selected';

  @override
  String get trashRestoreAll => 'Restore all';

  @override
  String get trashEmptyAction => 'Empty trash';

  @override
  String get trashEmptyConfirm1Title => 'Empty trash?';

  @override
  String get trashEmptyConfirm1Content =>
      'All recently deleted classes will be permanently removed.';

  @override
  String get trashEmptyConfirm2Title => 'Permanently delete?';

  @override
  String get trashEmptyConfirm2Content => 'This action cannot be undone.';

  @override
  String trashRestoreResult(Object restored, Object skipped) {
    return 'Restored $restored; skipped $skipped conflicting class(es)';
  }

  @override
  String get courseScopeTitle => 'Apply changes to';

  @override
  String get courseScopeSingle => 'This class only';

  @override
  String get courseScopeFromSelected => 'This and future classes';

  @override
  String get courseScopeAll => 'All matching classes';

  @override
  String courseOperationSummary(
    Object conflicts,
    Object count,
    Object end,
    Object start,
  ) {
    return '$count class(es), $start to $end. $conflicts conflict(s) will be replaced.';
  }

  @override
  String courseBatchUpdated(Object count) {
    return 'Updated $count class(es)';
  }

  @override
  String courseBatchDeleted(Object count) {
    return 'Deleted $count class(es)';
  }

  @override
  String get backupIncludesSettings =>
      'Includes appearance, schedule, reminder and course color settings';

  @override
  String restorePreviewSummary(
    Object count,
    Object end,
    Object start,
    Object version,
  ) {
    return 'Backup v$version · $count class(es) · $start to $end';
  }

  @override
  String get restoreCoursesOption => 'Restore classes';

  @override
  String get restoreSettingsOption => 'Restore app settings';

  @override
  String get restoreModeMerge => 'Merge and replace conflicts';

  @override
  String get restoreModeReplace => 'Replace current schedule';

  @override
  String get restoreNothingSelected =>
      'Select classes or app settings to restore';

  @override
  String get restoreSettingsDone => 'App settings restored';

  @override
  String get addSessionChoiceTitle => 'Add class';

  @override
  String get addSingleSession => 'Add one class';

  @override
  String get addBatchSessions => 'Add recurring classes';

  @override
  String get batchAddTitle => 'Add recurring classes';

  @override
  String get batchFirstWeekMonday => 'Monday of week 1';

  @override
  String get batchTotalWeeks => 'Semester length';

  @override
  String get batchSelectedWeeks => 'Class weeks';

  @override
  String get batchMeetings => 'Weekly meetings';

  @override
  String get batchAddMeeting => 'Add weekly meeting';

  @override
  String get batchRemoveMeeting => 'Remove meeting';

  @override
  String get batchSelectAll => 'All';

  @override
  String get batchSelectOdd => 'Odd weeks';

  @override
  String get batchSelectEven => 'Even weeks';

  @override
  String get batchClearWeeks => 'Clear';

  @override
  String batchMeetingTitle(Object index) {
    return 'Meeting $index';
  }

  @override
  String batchWeekOption(Object week) {
    return 'Week $week';
  }

  @override
  String get batchRequiredFields =>
      'Enter a course name and a room for every meeting';

  @override
  String get batchNoWeeks => 'Select at least one class week';

  @override
  String get batchNoMeetings => 'Add at least one weekly meeting';

  @override
  String get batchInvalidTime => 'Every meeting must end after it starts';

  @override
  String get batchMeetingOverlap =>
      'Weekly meetings on the same day cannot overlap';

  @override
  String get batchPreviewTitle => 'Confirm recurring classes';

  @override
  String batchPreviewSummary(Object conflicts, Object generated) {
    return '$generated classes will be created; $conflicts existing classes conflict.';
  }

  @override
  String get batchSkipConflicts => 'Skip conflicts';

  @override
  String get batchOverwriteConflicts => 'Replace conflicts';

  @override
  String batchCreateResult(Object created, Object overwritten, Object skipped) {
    return 'Added $created, skipped $skipped, and replaced $overwritten conflicting classes';
  }

  @override
  String get courseScopeMeetingFromSelected => 'This meeting from here';

  @override
  String get courseScopeMeetingAll => 'All weeks of this meeting';

  @override
  String get courseScopeCourseCommon => 'Common details for the whole course';

  @override
  String get backToTop => 'Back to top';

  @override
  String get scheduleVerticalScaleTitle => 'Schedule vertical scale';

  @override
  String get scheduleVerticalScaleSubtitle =>
      'Reduce the height to fit more of your schedule. Applies to the selected display density; short classes and large text may limit compression to keep names and time labels readable.';

  @override
  String get scheduleVerticalScaleReset => 'Restore defaults';

  @override
  String get customReminders => 'Custom reminder times';

  @override
  String get customRemindersSubtitle =>
      'Independent times, filters, messages and repetitions';

  @override
  String get reminderStrong => 'Strong alert';

  @override
  String get reminderStrongConfig => 'Strong alert settings';

  @override
  String get reminderStrongDescription =>
      'Looping sound; respects system volume, Do Not Disturb and permissions';

  @override
  String get reminderCatchUp => 'Catch-up';

  @override
  String get reminderCatchUpNotice =>
      'This is a catch-up message, not a real-time reminder.';

  @override
  String get reminderOriginalTime => 'Originally scheduled';

  @override
  String get reminderDeliveredTime => 'Catch-up time';

  @override
  String get reminderAcknowledge => 'Acknowledge';

  @override
  String get reminderStop => 'Stop';

  @override
  String get reminderAdd => 'Add rule';

  @override
  String get reminderEdit => 'Edit rule';

  @override
  String get reminderCopy => 'Duplicate';

  @override
  String get reminderDelete => 'Delete';

  @override
  String get reminderSave => 'Save';

  @override
  String get reminderDiscard => 'Discard unsaved changes?';

  @override
  String get reminderKeepEditing => 'Keep editing';

  @override
  String get reminderName => 'Rule name';

  @override
  String get reminderBasis => 'Time basis';

  @override
  String get reminderStart => 'Course start';

  @override
  String get reminderEnd => 'Course end';

  @override
  String get reminderDate => 'Fixed time on course date';

  @override
  String get reminderBefore => 'Before';

  @override
  String get reminderAfter => 'After';

  @override
  String get reminderDays => 'Days';

  @override
  String get reminderHours => 'Hours';

  @override
  String get reminderMinutes => 'Minutes';

  @override
  String get reminderSeconds => 'Seconds';

  @override
  String get reminderScope => 'Course scope';

  @override
  String get reminderAll => 'All courses';

  @override
  String get reminderSeries => 'Course series';

  @override
  String get reminderSessions => 'Individual sessions';

  @override
  String get reminderWeekdays => 'Weekday filter';

  @override
  String get reminderTypes => 'Course type filter';

  @override
  String get reminderDateRange => 'Course date range';

  @override
  String get reminderClearFilter => 'Clear date filter';

  @override
  String get reminderTitle => 'Notification title';

  @override
  String get reminderBody => 'Notification message';

  @override
  String get reminderCount => 'Send count (1–100, including first)';

  @override
  String get reminderInterval => 'Repeat interval (seconds, at least 1)';

  @override
  String get reminderUntilAck =>
      'Stop on acknowledgement, up to the send count';

  @override
  String get reminderInherit => 'Use global setting';

  @override
  String get reminderNormal => 'Normal alert';

  @override
  String get reminderPreview => 'Matching courses and delivery preview';

  @override
  String get reminderTimingNotice =>
      'Times include seconds; the system may delay delivery. New or re-enabled rules only schedule future sends.';

  @override
  String get reminderInvalid =>
      'Check numeric ranges, the required name and invalid placeholders';

  @override
  String get reminderSound => 'Sound';

  @override
  String get reminderVibration => 'Vibration';

  @override
  String get reminderDuration => 'Duration (5–300 seconds)';

  @override
  String get reminderSystemSound => 'Choose system sound';

  @override
  String get reminderImportSound => 'Import audio (MP3/M4A/WAV, up to 5 MiB)';

  @override
  String get reminderPreviewSound => 'Preview / stop';

  @override
  String get reminderOverride => 'Override strong alert settings';

  @override
  String get reminderEmpty => 'No custom reminder rules yet';

  @override
  String get reminderSoundFallback =>
      'Missing or unsupported sound replaced with the system default.';

  @override
  String get reminderMaintenanceFailed =>
      'Background maintenance registration failed. Later reminders may not be queued after exit. Please retry.';

  @override
  String get reminderStrongDegraded =>
      'Strong playback was unavailable; the normal notification was retained. Check system restrictions and sound settings.';

  @override
  String get reminderVariableLabels =>
      'Course|Room|Course date|Weekday|Start time|End time|Teachers|Course code|Send index|Total count|Scheduled time';

  @override
  String get reminderWeekdayNames =>
      'Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday';

  @override
  String get reminderDiscardAction => 'Discard changes';

  @override
  String get reminderAudioInvalid =>
      'The audio cannot be played, or its format or size is unsupported.';

  @override
  String get reminderDateOffset => 'Course date offset';

  @override
  String get reminderSameDay => 'Course day';

  @override
  String get reminderFixedTime => 'Fixed time (hour / minute / second)';

  @override
  String get reminderFilterWeekdays => 'Mon|Tue|Wed|Thu|Fri|Sat|Sun';

  @override
  String get reminderPreviousDay => 'Previous day';

  @override
  String get reminderNextDay => 'Next day';

  @override
  String get scheduleFitPage => 'Fit to page';

  @override
  String get scheduleFitPageHint =>
      'Show 08:00–22:00 in full. Course text may be hidden; select a course for details.';

  @override
  String get themeMulticolor => 'Multicolor palette';

  @override
  String get themeMulticolorOff => 'Original palette';

  @override
  String get themeSchemeNames =>
      'Vibrant|Expressive|Rainbow|Fruit salad|Content|Fidelity|Neutral|Monochrome';

  @override
  String get templateLeadMinutes => 'Lead minutes';

  @override
  String get templateCourseCount => 'Course count';

  @override
  String get palettePrimary => 'Primary color';

  @override
  String get paletteSecondary => 'Secondary color';

  @override
  String get paletteTertiary => 'Third color';

  @override
  String get paletteColors => 'Course palette';

  @override
  String get paletteCustom => 'Custom combination';

  @override
  String get paletteDuplicate => 'This color is already in the palette';

  @override
  String get paletteUsePrimary => 'Use as primary';

  @override
  String get paletteUseSecondary => 'Use as secondary';

  @override
  String get paletteUseTertiary => 'Use as third color';

  @override
  String get paletteMoveEarlier => 'Move earlier';

  @override
  String get paletteMoveLater => 'Move later';

  @override
  String get paletteReset => 'Reset multicolor settings?';

  @override
  String get palettePreview => 'Preview';

  @override
  String get paletteSingle => 'Single color';

  @override
  String get paletteMode => 'Interface colors';

  @override
  String get paletteAutomatic => 'Automatic from scheme';

  @override
  String get notificationWarning =>
      'Notification permission is off. Reminders cannot be delivered.';

  @override
  String get notificationOpen => 'Enable notifications';

  @override
  String get notificationIgnore => 'Ignore and do not show again';

  @override
  String get notificationIgnoreTitle => 'Ignore the notification warning?';

  @override
  String get notificationIgnoreBody =>
      'Without notification permission, reminders will not work. You can restore this warning in Settings.';

  @override
  String get notificationIgnoreConfirm => 'Confirm ignore';

  @override
  String get notificationRestore => 'Show permission warnings';

  @override
  String get notificationRestoreDescription =>
      'Warn when notifications are disabled on this device';

  @override
  String get notificationCheckFailed =>
      'Unable to check notification permission';

  @override
  String get notificationAllowed => 'Notifications enabled';

  @override
  String get notificationPermissions => 'Notification permission';

  @override
  String get strongTargets => 'Apply strong reminders to';

  @override
  String get strongClassLead => 'Before class';

  @override
  String get strongCheckIn => 'Check-in';

  @override
  String get strongSummary => 'Next-day summary';

  @override
  String get strongCustom => 'Custom rules';

  @override
  String get strongCourses => 'Course range';

  @override
  String get strongAllRules => 'All inherited rules, including future rules';

  @override
  String get strongRuleOverrideNotice =>
      'Rules explicitly set to Strong or Normal take priority over these selections.';

  @override
  String get strongSummaryNotice =>
      'With a limited course range, the summary is strong only if it includes a selected course.';

  @override
  String get settingsNavigationGroup => 'Navigation';

  @override
  String get settingsLayoutGroup => 'Schedule layout';

  @override
  String get settingsMaintenanceGroup => 'Permissions and maintenance';

  @override
  String get settingsDangerGroup => 'Delete data';

  @override
  String get settingsDiagnosticsGroup => 'Diagnostics';

  @override
  String get settingsBackupGroup => 'Backup and export';

  @override
  String get paletteEdit => 'Edit color';

  @override
  String get paletteHint => 'Tap a color for actions. Long press to delete.';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get paletteTonalSpot => 'Tonal spot';

  @override
  String get paletteHue => 'Hue';

  @override
  String get paletteChroma => 'Color intensity';

  @override
  String get paletteTone => 'Lightness';

  @override
  String get paletteScheme => 'Color scheme';

  @override
  String get paletteSchemeDescriptions =>
      'Soft, coordinated hues|Vivid contrasting hues|Rotated expressive triad|Balanced three-hue spectrum|Fresh adjacent hues|Seed-led gentle contrast|Seed-led complementary contrast|Low saturation, subtle differences|Grayscale, no hue contrast';

  @override
  String get androidEnhancedReminder => 'Enhanced reminder mode';

  @override
  String get androidEnhancedReminderSubtitle =>
      'Keeps a quiet ongoing notification while future reminders exist to improve reliability on some phones.';

  @override
  String get androidEnhancedReminderLimit =>
      'A real force stop still prevents Android from delivering alarms until Orbit is opened again.';

  @override
  String get androidEnhancedReminderChannel => 'Reminder reliability';

  @override
  String get androidEnhancedReminderNotificationTitle =>
      'Enhanced reminders enabled';

  @override
  String get androidEnhancedReminderNotificationBody =>
      'Orbit is protecting future course reminders.';

  @override
  String get androidEnhancedReminderDisable => 'Turn off';

  @override
  String get androidOriginOsSettings => 'OriginOS background settings';

  @override
  String get androidOriginOsSettingsSubtitle =>
      'Enable autostart and background high power usage, remove battery restrictions, then lock Orbit in Recents.';

  @override
  String get androidOpenAutostartSettings => 'Open settings';

  @override
  String get androidForcedStopDetected => 'Orbit was force-stopped';

  @override
  String get androidForcedStopDetectedSubtitle =>
      'The recent-app cleaner stopped Orbit and canceled its alarms. Complete the OriginOS settings below, then run the one-minute test again.';

  @override
  String get androidReminderReliability => 'Reminder registration';

  @override
  String androidReminderReliabilityStatus(int registered, int stored) {
    return '$registered of $stored future reminders are registered with Android.';
  }

  @override
  String get androidReminderDiagnostics => 'Reminder diagnostics';

  @override
  String get androidReminderDiagnosticsEmpty =>
      'No native reminder events recorded yet.';
}
