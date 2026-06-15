import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Orbit Schedule'**
  String get appTitle;

  /// No description provided for @navGrid.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navGrid;

  /// No description provided for @navUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get navUpcoming;

  /// No description provided for @navImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get navImport;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @gridTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get gridTitle;

  /// No description provided for @gridPrevWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get gridPrevWeek;

  /// No description provided for @gridNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get gridNextWeek;

  /// No description provided for @gridThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get gridThisWeek;

  /// No description provided for @gridLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String gridLoadFailed(String error);

  /// No description provided for @gridImportHint.
  ///
  /// In en, this message translates to:
  /// **'Please import your schedule on the Import tab first'**
  String get gridImportHint;

  /// No description provided for @gridBatchDelete.
  ///
  /// In en, this message translates to:
  /// **'Batch delete'**
  String get gridBatchDelete;

  /// No description provided for @gridBatchDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch delete classes'**
  String get gridBatchDeleteTitle;

  /// No description provided for @gridBatchDeleteStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get gridBatchDeleteStart;

  /// No description provided for @gridBatchDeleteEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get gridBatchDeleteEnd;

  /// No description provided for @gridBatchDeletePreview.
  ///
  /// In en, this message translates to:
  /// **'Will delete {count} class sessions'**
  String gridBatchDeletePreview(int count);

  /// No description provided for @gridBatchDeleteConfirm1Title.
  ///
  /// In en, this message translates to:
  /// **'Delete classes in range?'**
  String get gridBatchDeleteConfirm1Title;

  /// No description provided for @gridBatchDeleteConfirm1Content.
  ///
  /// In en, this message translates to:
  /// **'This will delete {count} class sessions fully within the selected time range.'**
  String gridBatchDeleteConfirm1Content(int count);

  /// No description provided for @gridBatchDeleteConfirm2Title.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get gridBatchDeleteConfirm2Title;

  /// No description provided for @gridBatchDeleteConfirm2Content.
  ///
  /// In en, this message translates to:
  /// **'Deleted sessions cannot be recovered. Continue?'**
  String get gridBatchDeleteConfirm2Content;

  /// No description provided for @gridBatchDeleteNone.
  ///
  /// In en, this message translates to:
  /// **'No classes fully within the selected range'**
  String get gridBatchDeleteNone;

  /// No description provided for @gridBatchDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} class sessions'**
  String gridBatchDeleteDone(int count);

  /// No description provided for @gridBatchDeleteInvalidRange.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get gridBatchDeleteInvalidRange;

  /// No description provided for @gridWeekPickerYear.
  ///
  /// In en, this message translates to:
  /// **'Change year'**
  String get gridWeekPickerYear;

  /// No description provided for @gridWeekPickerMonth.
  ///
  /// In en, this message translates to:
  /// **'Change month'**
  String get gridWeekPickerMonth;

  /// No description provided for @gridNoSessionsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No classes this week'**
  String get gridNoSessionsThisWeek;

  /// No description provided for @gridTimeColumn.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get gridTimeColumn;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @gridNoSessionsThisWeekSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to another week to view classes'**
  String get gridNoSessionsThisWeekSubtitle;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @importViewGrid.
  ///
  /// In en, this message translates to:
  /// **'View schedule'**
  String get importViewGrid;

  /// No description provided for @resyncPartialFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} reminder(s) could not be scheduled'**
  String resyncPartialFailed(int count);

  /// No description provided for @trayInitFailed.
  ///
  /// In en, this message translates to:
  /// **'System tray unavailable'**
  String get trayInitFailed;

  /// No description provided for @importPickMissingPath.
  ///
  /// In en, this message translates to:
  /// **'Could not read file: {name}'**
  String importPickMissingPath(String name);

  /// No description provided for @upcomingGoToGrid.
  ///
  /// In en, this message translates to:
  /// **'View schedule'**
  String get upcomingGoToGrid;

  /// No description provided for @gridUntilTime.
  ///
  /// In en, this message translates to:
  /// **'until {time}'**
  String gridUntilTime(String time);

  /// No description provided for @gridEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No schedule imported'**
  String get gridEmptyTitle;

  /// No description provided for @gridEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Go to Import and select your xlsx schedule files'**
  String get gridEmptySubtitle;

  /// No description provided for @gridImportNow.
  ///
  /// In en, this message translates to:
  /// **'Import now'**
  String get gridImportNow;

  /// No description provided for @upcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming classes'**
  String get upcomingTitle;

  /// No description provided for @upcomingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String upcomingLoadFailed(String error);

  /// No description provided for @groupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get groupToday;

  /// No description provided for @groupTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get groupTomorrow;

  /// No description provided for @groupThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get groupThisWeek;

  /// No description provided for @groupLater.
  ///
  /// In en, this message translates to:
  /// **'After {date}'**
  String groupLater(String date);

  /// No description provided for @inClass.
  ///
  /// In en, this message translates to:
  /// **'In class'**
  String get inClass;

  /// No description provided for @upcomingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No upcoming classes'**
  String get upcomingEmptyTitle;

  /// No description provided for @upcomingEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'All classes have ended, or no schedule imported yet'**
  String get upcomingEmptySubtitle;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import schedule'**
  String get importTitle;

  /// No description provided for @importInProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing schedule…'**
  String get importInProgress;

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm import'**
  String get importConfirm;

  /// No description provided for @importCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get importCancel;

  /// No description provided for @importPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Select xlsx schedule files'**
  String get importPickTitle;

  /// No description provided for @importPickSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can select multiple weekly schedules at once'**
  String get importPickSubtitle;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} class sessions'**
  String importSuccess(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @importPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick files: {error}'**
  String importPickFailed(String error);

  /// No description provided for @importParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Parse failed ({error})'**
  String importParseFailed(String error);

  /// No description provided for @sessionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} classes'**
  String sessionCount(int count);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load settings: {error}'**
  String settingsLoadFailed(String error);

  /// No description provided for @sectionReminders.
  ///
  /// In en, this message translates to:
  /// **'Class reminders'**
  String get sectionReminders;

  /// No description provided for @sectionData.
  ///
  /// In en, this message translates to:
  /// **'Data management'**
  String get sectionData;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @themeColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get themeColorTitle;

  /// No description provided for @themeColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app\'s accent color'**
  String get themeColorSubtitle;

  /// No description provided for @themeColorCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get themeColorCustom;

  /// No description provided for @themeColorCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get themeColorCustomTitle;

  /// No description provided for @themeColorInvalidHex.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit hex color (e.g. 39C5BB)'**
  String get themeColorInvalidHex;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @sectionSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get sectionSystem;

  /// No description provided for @launchAtStartup.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup'**
  String get launchAtStartup;

  /// No description provided for @launchAtStartupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start minimized to the system tray when Windows boots'**
  String get launchAtStartupSubtitle;

  /// No description provided for @editSession.
  ///
  /// In en, this message translates to:
  /// **'Edit class'**
  String get editSession;

  /// No description provided for @editSessionShort.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editSessionShort;

  /// No description provided for @addSessionNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addSessionNote;

  /// No description provided for @addSessionNoteShort.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get addSessionNoteShort;

  /// No description provided for @sessionNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Class note'**
  String get sessionNoteTitle;

  /// No description provided for @sessionNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a personal note for this class session'**
  String get sessionNoteHint;

  /// No description provided for @editSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit class details'**
  String get editSessionTitle;

  /// No description provided for @fieldCourseName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get fieldCourseName;

  /// No description provided for @fieldRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get fieldRoom;

  /// No description provided for @fieldTeachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers (comma separated)'**
  String get fieldTeachers;

  /// No description provided for @fieldFaculty.
  ///
  /// In en, this message translates to:
  /// **'Faculty'**
  String get fieldFaculty;

  /// No description provided for @fieldStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get fieldStartTime;

  /// No description provided for @fieldEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get fieldEndTime;

  /// No description provided for @sessionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Class updated'**
  String get sessionUpdated;

  /// No description provided for @sessionNoteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get sessionNoteSaved;

  /// No description provided for @editSessionEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get editSessionEndBeforeStart;

  /// No description provided for @countdownStartsIn.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h {minutes}m'**
  String countdownStartsIn(int days, int hours, int minutes);

  /// No description provided for @countdownSoon.
  ///
  /// In en, this message translates to:
  /// **'Soon · {countdown}'**
  String countdownSoon(String countdown);

  /// No description provided for @countdownSoonLabel.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get countdownSoonLabel;

  /// No description provided for @enableReminders.
  ///
  /// In en, this message translates to:
  /// **'Enable class reminders'**
  String get enableReminders;

  /// No description provided for @enableRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send system notifications before class'**
  String get enableRemindersSubtitle;

  /// No description provided for @leadTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder lead time'**
  String get leadTimeTitle;

  /// No description provided for @leadTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notify {minutes} minutes before class'**
  String leadTimeSubtitle(int minutes);

  /// No description provided for @leadTimeOption.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String leadTimeOption(int minutes);

  /// No description provided for @resyncReminders.
  ///
  /// In en, this message translates to:
  /// **'Resync reminders'**
  String get resyncReminders;

  /// No description provided for @resyncRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reschedule all reminders from current schedule'**
  String get resyncRemindersSubtitle;

  /// No description provided for @sectionAndroidBackground.
  ///
  /// In en, this message translates to:
  /// **'Background reminders (Android)'**
  String get sectionAndroidBackground;

  /// No description provided for @androidBackgroundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders use system alarms and do not require the app to stay open. Complete the settings below for best reliability.'**
  String get androidBackgroundSubtitle;

  /// No description provided for @androidCheckReminderPermissions.
  ///
  /// In en, this message translates to:
  /// **'Check reminder permissions'**
  String get androidCheckReminderPermissions;

  /// No description provided for @androidPermissionsChecked.
  ///
  /// In en, this message translates to:
  /// **'Notification and exact alarm permissions requested'**
  String get androidPermissionsChecked;

  /// No description provided for @androidBatteryOptimization.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization exemption'**
  String get androidBatteryOptimization;

  /// No description provided for @androidBatteryOptimizationSubtitleOn.
  ///
  /// In en, this message translates to:
  /// **'Exempt from battery optimization for more reliable reminders'**
  String get androidBatteryOptimizationSubtitleOn;

  /// No description provided for @androidBatteryOptimizationSubtitleOff.
  ///
  /// In en, this message translates to:
  /// **'Enable to improve background reminder reliability'**
  String get androidBatteryOptimizationSubtitleOff;

  /// No description provided for @androidBatteryOptimizationDisableConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off battery optimization exemption?'**
  String get androidBatteryOptimizationDisableConfirmTitle;

  /// No description provided for @androidBatteryOptimizationDisableConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'You will be taken to system settings to restore battery optimization. Background reminders may be less reliable.'**
  String get androidBatteryOptimizationDisableConfirmContent;

  /// No description provided for @androidAutostartHint.
  ///
  /// In en, this message translates to:
  /// **'On some devices, also enable autostart and allow background activity in system settings.'**
  String get androidAutostartHint;

  /// No description provided for @deleteEndedSessions.
  ///
  /// In en, this message translates to:
  /// **'Delete ended classes'**
  String get deleteEndedSessions;

  /// No description provided for @deleteEndedSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove class sessions that have already finished'**
  String get deleteEndedSessionsSubtitle;

  /// No description provided for @deleteEndedConfirm1Title.
  ///
  /// In en, this message translates to:
  /// **'Delete ended classes?'**
  String get deleteEndedConfirm1Title;

  /// No description provided for @deleteEndedConfirm1Content.
  ///
  /// In en, this message translates to:
  /// **'This will delete {count} ended class sessions from your schedule.'**
  String deleteEndedConfirm1Content(int count);

  /// No description provided for @deleteEndedConfirm2Title.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get deleteEndedConfirm2Title;

  /// No description provided for @deleteEndedConfirm2Content.
  ///
  /// In en, this message translates to:
  /// **'Deleted sessions cannot be recovered. Continue?'**
  String get deleteEndedConfirm2Content;

  /// No description provided for @deleteEndedNone.
  ///
  /// In en, this message translates to:
  /// **'No ended classes to delete'**
  String get deleteEndedNone;

  /// No description provided for @deleteEndedDone.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} ended class sessions'**
  String deleteEndedDone(int count);

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear all schedules'**
  String get clearAllData;

  /// No description provided for @clearAllDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all imported class data'**
  String get clearAllDataSubtitle;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub repository'**
  String get settingsGithub;

  /// No description provided for @settingsGithubOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get settingsGithubOpenFailed;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Orbit — class reminder app'**
  String get appTagline;

  /// No description provided for @resyncDone.
  ///
  /// In en, this message translates to:
  /// **'Reminders rescheduled'**
  String get resyncDone;

  /// No description provided for @confirmClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm clear'**
  String get confirmClearTitle;

  /// No description provided for @confirmClearContent.
  ///
  /// In en, this message translates to:
  /// **'This will delete all imported schedule data and cannot be undone.'**
  String get confirmClearContent;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @dataCleared.
  ///
  /// In en, this message translates to:
  /// **'Schedule data cleared'**
  String get dataCleared;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose display language'**
  String get languageSubtitle;

  /// No description provided for @langZhHant.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get langZhHant;

  /// No description provided for @langZhHans.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get langZhHans;

  /// No description provided for @langEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @languageChangedHint.
  ///
  /// In en, this message translates to:
  /// **'Language updated. Tap Resync reminders to update notification text.'**
  String get languageChangedHint;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Class reminders'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Notifications before class starts'**
  String get notificationChannelDesc;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Class starting in {minutes} min'**
  String notificationTitle(int minutes);

  /// No description provided for @notificationBody.
  ///
  /// In en, this message translates to:
  /// **'{course} @ {room}'**
  String notificationBody(String course, String room);

  /// No description provided for @notificationTime.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String notificationTime(String time);

  /// No description provided for @notificationRoom.
  ///
  /// In en, this message translates to:
  /// **'Room: {room}'**
  String notificationRoom(String room);

  /// No description provided for @notificationTeachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers: {teachers}'**
  String notificationTeachers(String teachers);

  /// No description provided for @teachersNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get teachersNotProvided;

  /// No description provided for @sectionAdvancedReminders.
  ///
  /// In en, this message translates to:
  /// **'Advanced reminders'**
  String get sectionAdvancedReminders;

  /// No description provided for @enableNextDaySummary.
  ///
  /// In en, this message translates to:
  /// **'Next-day schedule preview'**
  String get enableNextDaySummary;

  /// No description provided for @enableNextDaySummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notify the evening before with tomorrow\'s first class and class count'**
  String get enableNextDaySummarySubtitle;

  /// No description provided for @nextDaySummaryTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview notification time'**
  String get nextDaySummaryTimeTitle;

  /// No description provided for @nextDaySummaryTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send at {time} the day before'**
  String nextDaySummaryTimeSubtitle(String time);

  /// No description provided for @enableSystemAlarm.
  ///
  /// In en, this message translates to:
  /// **'System alarm for first class (Android)'**
  String get enableSystemAlarm;

  /// No description provided for @enableSystemAlarmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the system clock app to set an alarm for tomorrow\'s first class'**
  String get enableSystemAlarmSubtitle;

  /// No description provided for @systemAlarmLeadTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm lead time'**
  String get systemAlarmLeadTitle;

  /// No description provided for @systemAlarmLeadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm rings {minutes} minutes before first class'**
  String systemAlarmLeadSubtitle(int minutes);

  /// No description provided for @setTomorrowAlarm.
  ///
  /// In en, this message translates to:
  /// **'Set alarm for tomorrow'**
  String get setTomorrowAlarm;

  /// No description provided for @alarmSetSuccess.
  ///
  /// In en, this message translates to:
  /// **'System alarm screen opened'**
  String get alarmSetSuccess;

  /// No description provided for @alarmSetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open system alarm'**
  String get alarmSetFailed;

  /// No description provided for @alarmNoClassTomorrow.
  ///
  /// In en, this message translates to:
  /// **'No classes tomorrow'**
  String get alarmNoClassTomorrow;

  /// No description provided for @enableCheckInReminder.
  ///
  /// In en, this message translates to:
  /// **'Check-in reminder'**
  String get enableCheckInReminder;

  /// No description provided for @enableCheckInReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notify at class start time to check in via campus app Bluetooth'**
  String get enableCheckInReminderSubtitle;

  /// No description provided for @checkInDisableConfirm1Title.
  ///
  /// In en, this message translates to:
  /// **'Turn off check-in reminders?'**
  String get checkInDisableConfirm1Title;

  /// No description provided for @checkInDisableConfirm1Content.
  ///
  /// In en, this message translates to:
  /// **'You may miss campus app Bluetooth check-in reminders.'**
  String get checkInDisableConfirm1Content;

  /// No description provided for @checkInDisableConfirm2Title.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get checkInDisableConfirm2Title;

  /// No description provided for @checkInDisableConfirm2Content.
  ///
  /// In en, this message translates to:
  /// **'Without reminders, you may forget to check in on time.'**
  String get checkInDisableConfirm2Content;

  /// No description provided for @checkInDisableConfirm3Title.
  ///
  /// In en, this message translates to:
  /// **'Final confirmation'**
  String get checkInDisableConfirm3Title;

  /// No description provided for @checkInDisableConfirm3Content.
  ///
  /// In en, this message translates to:
  /// **'This will disable all check-in reminders. Continue?'**
  String get checkInDisableConfirm3Content;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionConfirmDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get actionConfirmDisable;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete this class'**
  String get deleteSession;

  /// No description provided for @deleteSessionShort.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSessionShort;

  /// No description provided for @deleteSessionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this class session?'**
  String get deleteSessionConfirmTitle;

  /// No description provided for @deleteSessionConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'{course}\n{date} {time} · {room}'**
  String deleteSessionConfirmContent(
    String course,
    String date,
    String time,
    String room,
  );

  /// No description provided for @sessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Class session deleted'**
  String get sessionDeleted;

  /// No description provided for @trayShow.
  ///
  /// In en, this message translates to:
  /// **'Show Orbit'**
  String get trayShow;

  /// No description provided for @trayExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get trayExit;

  /// No description provided for @trayHiddenHint.
  ///
  /// In en, this message translates to:
  /// **'Orbit is running in the background. Use the tray icon to show or exit.'**
  String get trayHiddenHint;

  /// No description provided for @notificationCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Check in now: {course} @ {room}'**
  String notificationCheckInTitle(String course, String room);

  /// No description provided for @notificationCheckInBody.
  ///
  /// In en, this message translates to:
  /// **'Open the campus app and complete Bluetooth check-in for {course}'**
  String notificationCheckInBody(String course);

  /// No description provided for @notificationNextDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s schedule'**
  String get notificationNextDayTitle;

  /// No description provided for @notificationNextDayBody.
  ///
  /// In en, this message translates to:
  /// **'{count} classes tomorrow. First class at {time}.'**
  String notificationNextDayBody(int count, String time);

  /// No description provided for @notificationNextDayNoClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s schedule'**
  String get notificationNextDayNoClassTitle;

  /// No description provided for @notificationNextDayNoClassBody.
  ///
  /// In en, this message translates to:
  /// **'No classes scheduled for tomorrow.'**
  String get notificationNextDayNoClassBody;

  /// No description provided for @exportScheduleJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON backup'**
  String get exportScheduleJson;

  /// No description provided for @exportScheduleJsonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save all schedule data for restore or migration'**
  String get exportScheduleJsonSubtitle;

  /// No description provided for @exportScheduleXlsx.
  ///
  /// In en, this message translates to:
  /// **'Export as xlsx'**
  String get exportScheduleXlsx;

  /// No description provided for @exportScheduleXlsxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export in the same format as import'**
  String get exportScheduleXlsxSubtitle;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreFromBackup;

  /// No description provided for @restoreFromBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import schedule from a JSON backup file'**
  String get restoreFromBackupSubtitle;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} class sessions'**
  String exportDone(int count);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @exportNothingToExport.
  ///
  /// In en, this message translates to:
  /// **'No schedule data to export'**
  String get exportNothingToExport;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore backup?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'This will merge {count} class sessions from the backup.'**
  String restoreConfirmContent(int count);

  /// No description provided for @restoreDone.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} class sessions'**
  String restoreDone(int count);

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailed(String error);

  /// No description provided for @backupInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file format'**
  String get backupInvalidFormat;

  /// No description provided for @backupUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'Unsupported backup version'**
  String get backupUnsupportedVersion;

  /// No description provided for @addSession.
  ///
  /// In en, this message translates to:
  /// **'Add class'**
  String get addSession;

  /// No description provided for @addSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add class'**
  String get addSessionTitle;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fieldCourseCode.
  ///
  /// In en, this message translates to:
  /// **'Course code'**
  String get fieldCourseCode;

  /// No description provided for @fieldSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get fieldSection;

  /// No description provided for @defaultClassType.
  ///
  /// In en, this message translates to:
  /// **'General class'**
  String get defaultClassType;

  /// No description provided for @sessionCreated.
  ///
  /// In en, this message translates to:
  /// **'Class added'**
  String get sessionCreated;

  /// No description provided for @sessionCreateRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Course name and room are required'**
  String get sessionCreateRequiredFields;

  /// No description provided for @sessionTimeConflict.
  ///
  /// In en, this message translates to:
  /// **'Another class overlaps this time slot'**
  String get sessionTimeConflict;

  /// No description provided for @sessionSavedWithOverride.
  ///
  /// In en, this message translates to:
  /// **'Saved. Replaced {count} overlapping class(es).'**
  String sessionSavedWithOverride(int count);

  /// No description provided for @importStrategyTitle.
  ///
  /// In en, this message translates to:
  /// **'Duplicate weeks detected'**
  String get importStrategyTitle;

  /// No description provided for @importStrategyMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} week(s) in this import already contain classes. Choose how to import them.'**
  String importStrategyMessage(int count);

  /// No description provided for @importStrategyReplaceWeek.
  ///
  /// In en, this message translates to:
  /// **'Replace whole week'**
  String get importStrategyReplaceWeek;

  /// No description provided for @importStrategyReplaceWeekDesc.
  ///
  /// In en, this message translates to:
  /// **'Delete all existing classes in those weeks, then import the new ones.'**
  String get importStrategyReplaceWeekDesc;

  /// No description provided for @importStrategyMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge and overwrite conflicts'**
  String get importStrategyMerge;

  /// No description provided for @importStrategyMergeDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep other classes; replace only those whose time overlaps an imported class.'**
  String get importStrategyMergeDesc;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// No description provided for @sessionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String sessionSaveFailed(String error);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(String error);

  /// No description provided for @languageChangedResynced.
  ///
  /// In en, this message translates to:
  /// **'Language updated and reminders resynced'**
  String get languageChangedResynced;

  /// No description provided for @searchSessions.
  ///
  /// In en, this message translates to:
  /// **'Search classes'**
  String get searchSessions;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by course, room, or teacher'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching classes'**
  String get searchNoResults;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(String error);

  /// No description provided for @searchResultsTruncated.
  ///
  /// In en, this message translates to:
  /// **'Showing first {count} results only'**
  String searchResultsTruncated(int count);

  /// No description provided for @gridBatchDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Batch delete failed: {error}'**
  String gridBatchDeleteFailed(String error);

  /// No description provided for @clearAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear schedule: {error}'**
  String clearAllFailed(String error);

  /// No description provided for @launchAtStartupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update startup setting: {error}'**
  String launchAtStartupFailed(String error);

  /// No description provided for @sectionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get sectionSchedule;

  /// No description provided for @gridDefaultWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Default week'**
  String get gridDefaultWeekTitle;

  /// No description provided for @gridDefaultWeekSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which week to show when opening the schedule'**
  String get gridDefaultWeekSubtitle;

  /// No description provided for @gridDefaultWeekSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get gridDefaultWeekSmart;

  /// No description provided for @gridDefaultWeekCurrent.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get gridDefaultWeekCurrent;

  /// No description provided for @gridDefaultWeekEarliest.
  ///
  /// In en, this message translates to:
  /// **'Earliest week with classes'**
  String get gridDefaultWeekEarliest;

  /// No description provided for @exportInProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exportInProgress;

  /// No description provided for @importFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule file format'**
  String get importFormatTitle;

  /// No description provided for @importFormatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'xlsx columns A–M (one row per class session)'**
  String get importFormatSubtitle;

  /// No description provided for @importFormatColumn.
  ///
  /// In en, this message translates to:
  /// **'Col'**
  String get importFormatColumn;

  /// No description provided for @importFormatField.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get importFormatField;

  /// No description provided for @importFormatExample.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get importFormatExample;

  /// No description provided for @importFormatClassType.
  ///
  /// In en, this message translates to:
  /// **'Class type'**
  String get importFormatClassType;

  /// No description provided for @importFormatClassTypeExample.
  ///
  /// In en, this message translates to:
  /// **'General class'**
  String get importFormatClassTypeExample;

  /// No description provided for @importFormatRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get importFormatRoom;

  /// No description provided for @importFormatRoomExample.
  ///
  /// In en, this message translates to:
  /// **'A001'**
  String get importFormatRoomExample;

  /// No description provided for @importFormatCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get importFormatCapacity;

  /// No description provided for @importFormatCapacityExample.
  ///
  /// In en, this message translates to:
  /// **'67'**
  String get importFormatCapacityExample;

  /// No description provided for @importFormatFaculty.
  ///
  /// In en, this message translates to:
  /// **'Faculty'**
  String get importFormatFaculty;

  /// No description provided for @importFormatFacultyExample.
  ///
  /// In en, this message translates to:
  /// **'Example Faculty'**
  String get importFormatFacultyExample;

  /// No description provided for @importFormatDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get importFormatDate;

  /// No description provided for @importFormatDateExample.
  ///
  /// In en, this message translates to:
  /// **'2026-07-27'**
  String get importFormatDateExample;

  /// No description provided for @importFormatWeekday.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get importFormatWeekday;

  /// No description provided for @importFormatWeekdayExample.
  ///
  /// In en, this message translates to:
  /// **'1 (Mon) – 7 (Sun)'**
  String get importFormatWeekdayExample;

  /// No description provided for @importFormatCourseName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get importFormatCourseName;

  /// No description provided for @importFormatCourseNameExample.
  ///
  /// In en, this message translates to:
  /// **'Physics'**
  String get importFormatCourseNameExample;

  /// No description provided for @importFormatCourseCode.
  ///
  /// In en, this message translates to:
  /// **'Course code'**
  String get importFormatCourseCode;

  /// No description provided for @importFormatCourseCodeExample.
  ///
  /// In en, this message translates to:
  /// **'P0721'**
  String get importFormatCourseCodeExample;

  /// No description provided for @importFormatSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get importFormatSection;

  /// No description provided for @importFormatSectionExample.
  ///
  /// In en, this message translates to:
  /// **'EX1'**
  String get importFormatSectionExample;

  /// No description provided for @importFormatStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get importFormatStartTime;

  /// No description provided for @importFormatStartTimeExample.
  ///
  /// In en, this message translates to:
  /// **'12:30'**
  String get importFormatStartTimeExample;

  /// No description provided for @importFormatEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get importFormatEndTime;

  /// No description provided for @importFormatEndTimeExample.
  ///
  /// In en, this message translates to:
  /// **'15:20'**
  String get importFormatEndTimeExample;

  /// No description provided for @importFormatTeachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get importFormatTeachers;

  /// No description provided for @importFormatTeachersExample.
  ///
  /// In en, this message translates to:
  /// **'Miku,null'**
  String get importFormatTeachersExample;

  /// No description provided for @importFormatSemester.
  ///
  /// In en, this message translates to:
  /// **'Semester'**
  String get importFormatSemester;

  /// No description provided for @importFormatSemesterExample.
  ///
  /// In en, this message translates to:
  /// **'2606'**
  String get importFormatSemesterExample;

  /// No description provided for @xlsxErrorNoSheet.
  ///
  /// In en, this message translates to:
  /// **'No worksheet found in file'**
  String get xlsxErrorNoSheet;

  /// No description provided for @xlsxErrorEmptySheet.
  ///
  /// In en, this message translates to:
  /// **'Schedule file is empty'**
  String get xlsxErrorEmptySheet;

  /// No description provided for @xlsxErrorNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No class sessions parsed'**
  String get xlsxErrorNoSessions;

  /// No description provided for @xlsxErrorInsufficientColumns.
  ///
  /// In en, this message translates to:
  /// **'Insufficient columns ({detail})'**
  String xlsxErrorInsufficientColumns(String detail);

  /// No description provided for @xlsxErrorInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'Invalid date: {detail}'**
  String xlsxErrorInvalidDate(String detail);

  /// No description provided for @xlsxErrorInvalidTime.
  ///
  /// In en, this message translates to:
  /// **'Invalid time: {detail}'**
  String xlsxErrorInvalidTime(String detail);

  /// No description provided for @reminderSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Reminder sync failed: {error}'**
  String reminderSyncFailed(String error);

  /// No description provided for @reminderResyncFailedBanner.
  ///
  /// In en, this message translates to:
  /// **'Reminders could not be synced. Tap Resync to try again.'**
  String get reminderResyncFailedBanner;

  /// No description provided for @reminderScheduleVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Reminders saved, but the system did not queue any alarms. On OriginOS / iQOO, also allow autostart and unrestricted background activity. Then allow exact alarms, disable battery optimization, and resync.'**
  String get reminderScheduleVerifyFailed;

  /// No description provided for @reminderScheduleVerifyFailedBanner.
  ///
  /// In en, this message translates to:
  /// **'The system did not queue any reminders. Check exact alarm, battery, and autostart settings (OriginOS / iQOO), then resync.'**
  String get reminderScheduleVerifyFailedBanner;

  /// No description provided for @reminderScheduledCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reminder(s) scheduled'**
  String reminderScheduledCount(int count);

  /// No description provided for @androidNotificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get androidNotificationsEnabled;

  /// No description provided for @androidNotificationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications disabled'**
  String get androidNotificationsDisabled;

  /// No description provided for @androidExactAlarmsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Exact alarms allowed'**
  String get androidExactAlarmsEnabled;

  /// No description provided for @androidExactAlarmsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Exact alarms not allowed'**
  String get androidExactAlarmsDisabled;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
