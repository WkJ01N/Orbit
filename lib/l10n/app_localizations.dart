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

  /// No description provided for @importAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto detect'**
  String get importAuto;

  /// No description provided for @importTemplates.
  ///
  /// In en, this message translates to:
  /// **'Recognition templates'**
  String get importTemplates;

  /// No description provided for @importPlans.
  ///
  /// In en, this message translates to:
  /// **'Semester & period times'**
  String get importPlans;

  /// No description provided for @importListLayout.
  ///
  /// In en, this message translates to:
  /// **'Course list'**
  String get importListLayout;

  /// No description provided for @importGridLayout.
  ///
  /// In en, this message translates to:
  /// **'Weekly grid'**
  String get importGridLayout;

  /// No description provided for @importLegacyLayout.
  ///
  /// In en, this message translates to:
  /// **'Orbit 13-column format'**
  String get importLegacyLayout;

  /// No description provided for @importTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get importTemplateName;

  /// No description provided for @importBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in · copy to edit'**
  String get importBuiltIn;

  /// No description provided for @importCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get importCopy;

  /// No description provided for @importShareTemplate.
  ///
  /// In en, this message translates to:
  /// **'Export template JSON'**
  String get importShareTemplate;

  /// No description provided for @importLoadTemplate.
  ///
  /// In en, this message translates to:
  /// **'Import template JSON'**
  String get importLoadTemplate;

  /// No description provided for @importLayoutStep.
  ///
  /// In en, this message translates to:
  /// **'Layout & region'**
  String get importLayoutStep;

  /// No description provided for @importFieldsStep.
  ///
  /// In en, this message translates to:
  /// **'Field mapping'**
  String get importFieldsStep;

  /// No description provided for @importRegexStep.
  ///
  /// In en, this message translates to:
  /// **'Extraction rules'**
  String get importRegexStep;

  /// No description provided for @importTestStep.
  ///
  /// In en, this message translates to:
  /// **'Test & preview'**
  String get importTestStep;

  /// No description provided for @importHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'Header row (1-based)'**
  String get importHeaderRow;

  /// No description provided for @importFirstRow.
  ///
  /// In en, this message translates to:
  /// **'First course row'**
  String get importFirstRow;

  /// No description provided for @importLastRow.
  ///
  /// In en, this message translates to:
  /// **'Last course row (blank = end)'**
  String get importLastRow;

  /// No description provided for @importFirstColumn.
  ///
  /// In en, this message translates to:
  /// **'First course column (1-based)'**
  String get importFirstColumn;

  /// No description provided for @importLastColumn.
  ///
  /// In en, this message translates to:
  /// **'Last course column'**
  String get importLastColumn;

  /// No description provided for @importWeekdayColumns.
  ///
  /// In en, this message translates to:
  /// **'Column:weekday, e.g. 2:1,3:2'**
  String get importWeekdayColumns;

  /// No description provided for @importPeriodRows.
  ///
  /// In en, this message translates to:
  /// **'Row:periods, e.g. 2:1-2;3:3-4'**
  String get importPeriodRows;

  /// No description provided for @importColumnSource.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get importColumnSource;

  /// No description provided for @importTextSource.
  ///
  /// In en, this message translates to:
  /// **'Course text'**
  String get importTextSource;

  /// No description provided for @importFixedSource.
  ///
  /// In en, this message translates to:
  /// **'Fixed value'**
  String get importFixedSource;

  /// No description provided for @importWeekdaySource.
  ///
  /// In en, this message translates to:
  /// **'Grid weekday'**
  String get importWeekdaySource;

  /// No description provided for @importPeriodsSource.
  ///
  /// In en, this message translates to:
  /// **'Grid periods'**
  String get importPeriodsSource;

  /// No description provided for @importColumnNumber.
  ///
  /// In en, this message translates to:
  /// **'Column number (1-based)'**
  String get importColumnNumber;

  /// No description provided for @importFixedValue.
  ///
  /// In en, this message translates to:
  /// **'Fixed value'**
  String get importFixedValue;

  /// No description provided for @importPattern.
  ///
  /// In en, this message translates to:
  /// **'Regular expression (blank = original)'**
  String get importPattern;

  /// No description provided for @importCaptureGroup.
  ///
  /// In en, this message translates to:
  /// **'Capture group number or name'**
  String get importCaptureGroup;

  /// No description provided for @importCaseSensitive.
  ///
  /// In en, this message translates to:
  /// **'Case sensitive'**
  String get importCaseSensitive;

  /// No description provided for @importMultiLine.
  ///
  /// In en, this message translates to:
  /// **'Multiline anchors'**
  String get importMultiLine;

  /// No description provided for @importDotAll.
  ///
  /// In en, this message translates to:
  /// **'Dot matches newline'**
  String get importDotAll;

  /// No description provided for @importUnicode.
  ///
  /// In en, this message translates to:
  /// **'Unicode mode'**
  String get importUnicode;

  /// No description provided for @importBlockPattern.
  ///
  /// In en, this message translates to:
  /// **'Course block separator / match regex'**
  String get importBlockPattern;

  /// No description provided for @importRepeatBlocks.
  ///
  /// In en, this message translates to:
  /// **'Repeated course block matching'**
  String get importRepeatBlocks;

  /// No description provided for @importTestText.
  ///
  /// In en, this message translates to:
  /// **'Sample course text'**
  String get importTestText;

  /// No description provided for @importRunTest.
  ///
  /// In en, this message translates to:
  /// **'Run test'**
  String get importRunTest;

  /// No description provided for @importOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original text'**
  String get importOriginal;

  /// No description provided for @importMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches & capture groups'**
  String get importMatches;

  /// No description provided for @importExtracted.
  ///
  /// In en, this message translates to:
  /// **'Extracted fields'**
  String get importExtracted;

  /// No description provided for @importSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get importSave;

  /// No description provided for @importNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get importNext;

  /// No description provided for @importBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get importBack;

  /// No description provided for @importSemesterName.
  ///
  /// In en, this message translates to:
  /// **'Semester name'**
  String get importSemesterName;

  /// No description provided for @importFirstMonday.
  ///
  /// In en, this message translates to:
  /// **'First week Monday (YYYY-MM-DD)'**
  String get importFirstMonday;

  /// No description provided for @importTotalWeeks.
  ///
  /// In en, this message translates to:
  /// **'Total weeks (1–30)'**
  String get importTotalWeeks;

  /// No description provided for @importPeriodPlanName.
  ///
  /// In en, this message translates to:
  /// **'Period time plan name'**
  String get importPeriodPlanName;

  /// No description provided for @importPeriodTimeInput.
  ///
  /// In en, this message translates to:
  /// **'Period,start,end — one per line; e.g. 1,08:00,08:45'**
  String get importPeriodTimeInput;

  /// No description provided for @importDefaultWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks when absent from file (e.g. 1-18)'**
  String get importDefaultWeeks;

  /// No description provided for @importConfirmContext.
  ///
  /// In en, this message translates to:
  /// **'Confirm semester, weeks and period times for this import'**
  String get importConfirmContext;

  /// No description provided for @importTemporaryContext.
  ///
  /// In en, this message translates to:
  /// **'Temporary changes apply only to this import. Save plans separately.'**
  String get importTemporaryContext;

  /// No description provided for @importEncoding.
  ///
  /// In en, this message translates to:
  /// **'CSV encoding'**
  String get importEncoding;

  /// No description provided for @importDelimiter.
  ///
  /// In en, this message translates to:
  /// **'CSV delimiter'**
  String get importDelimiter;

  /// No description provided for @importComma.
  ///
  /// In en, this message translates to:
  /// **'Comma'**
  String get importComma;

  /// No description provided for @importSemicolon.
  ///
  /// In en, this message translates to:
  /// **'Semicolon'**
  String get importSemicolon;

  /// No description provided for @importTab.
  ///
  /// In en, this message translates to:
  /// **'Tab'**
  String get importTab;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'Parse & preview'**
  String get importPreview;

  /// No description provided for @importSkipErrors.
  ///
  /// In en, this message translates to:
  /// **'Explicitly skip failed courses'**
  String get importSkipErrors;

  /// No description provided for @importSkipDescription.
  ///
  /// In en, this message translates to:
  /// **'Failed courses will not be imported. Review each error first.'**
  String get importSkipDescription;

  /// No description provided for @importCancelTask.
  ///
  /// In en, this message translates to:
  /// **'Cancel parsing'**
  String get importCancelTask;

  /// No description provided for @importSelectSheet.
  ///
  /// In en, this message translates to:
  /// **'Select worksheets to import'**
  String get importSelectSheet;

  /// No description provided for @importRawTable.
  ///
  /// In en, this message translates to:
  /// **'Original table — tap a cell to select coordinates'**
  String get importRawTable;

  /// No description provided for @importChooseCoordinate.
  ///
  /// In en, this message translates to:
  /// **'Use selected cell as'**
  String get importChooseCoordinate;

  /// No description provided for @importNoSelection.
  ///
  /// In en, this message translates to:
  /// **'No worksheet selected'**
  String get importNoSelection;

  /// No description provided for @importNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get importNone;

  /// No description provided for @importValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get importValid;

  /// No description provided for @importDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get importDuplicates;

  /// No description provided for @importErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get importErrors;

  /// No description provided for @importDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this saved template or plan?'**
  String get importDeleteConfirm;

  /// No description provided for @importHelp.
  ///
  /// In en, this message translates to:
  /// **'Lists need course name, date (or weekday and weeks), and start/end times (or periods). Grids use weekday columns and period rows. Separate multiple courses by a blank line, or configure block rules. Weekly schedules need a confirmed semester and period time plan.'**
  String get importHelp;

  /// No description provided for @importFieldCourseName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get importFieldCourseName;

  /// No description provided for @importFieldCourseCode.
  ///
  /// In en, this message translates to:
  /// **'Course code'**
  String get importFieldCourseCode;

  /// No description provided for @importFieldSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get importFieldSection;

  /// No description provided for @importFieldRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get importFieldRoom;

  /// No description provided for @importFieldTeachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get importFieldTeachers;

  /// No description provided for @importFieldFaculty.
  ///
  /// In en, this message translates to:
  /// **'Faculty'**
  String get importFieldFaculty;

  /// No description provided for @importFieldClassType.
  ///
  /// In en, this message translates to:
  /// **'Class type'**
  String get importFieldClassType;

  /// No description provided for @importFieldSemester.
  ///
  /// In en, this message translates to:
  /// **'Semester'**
  String get importFieldSemester;

  /// No description provided for @importFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get importFieldDate;

  /// No description provided for @importFieldWeekday.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get importFieldWeekday;

  /// No description provided for @importFieldWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get importFieldWeeks;

  /// No description provided for @importFieldPeriods.
  ///
  /// In en, this message translates to:
  /// **'Periods'**
  String get importFieldPeriods;

  /// No description provided for @importFieldStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get importFieldStartTime;

  /// No description provided for @importFieldEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get importFieldEndTime;

  /// No description provided for @importErrorAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'Multiple templates match; select one explicitly.'**
  String get importErrorAmbiguous;

  /// No description provided for @importErrorTemplateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid template or region configuration.'**
  String get importErrorTemplateInvalid;

  /// No description provided for @importErrorTemplateVersion.
  ///
  /// In en, this message translates to:
  /// **'Unsupported template version.'**
  String get importErrorTemplateVersion;

  /// No description provided for @importErrorCaptureGroup.
  ///
  /// In en, this message translates to:
  /// **'Capture group number or name is invalid.'**
  String get importErrorCaptureGroup;

  /// No description provided for @importErrorMissingName.
  ///
  /// In en, this message translates to:
  /// **'Course name is required.'**
  String get importErrorMissingName;

  /// No description provided for @importErrorSemesterInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check semester name, Monday date and total weeks.'**
  String get importErrorSemesterInvalid;

  /// No description provided for @importErrorPeriodInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid period numbers or period time plan.'**
  String get importErrorPeriodInvalid;

  /// No description provided for @importErrorInvalidTime.
  ///
  /// In en, this message translates to:
  /// **'Invalid time; end must be later than start.'**
  String get importErrorInvalidTime;

  /// No description provided for @importErrorInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'Invalid calendar date.'**
  String get importErrorInvalidDate;

  /// No description provided for @importErrorInvalidWeekday.
  ///
  /// In en, this message translates to:
  /// **'Weekday must be Monday through Sunday.'**
  String get importErrorInvalidWeekday;

  /// No description provided for @importErrorWeekdayMismatch.
  ///
  /// In en, this message translates to:
  /// **'Weekday does not match the calendar date.'**
  String get importErrorWeekdayMismatch;

  /// No description provided for @importErrorInvalidWeeks.
  ///
  /// In en, this message translates to:
  /// **'Invalid weeks or weeks outside the semester.'**
  String get importErrorInvalidWeeks;

  /// No description provided for @importErrorWeeksRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm applicable weeks when missing from the file.'**
  String get importErrorWeeksRequired;

  /// No description provided for @importErrorContextRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm the semester and required period time plan.'**
  String get importErrorContextRequired;

  /// No description provided for @importErrorUnknownPeriod.
  ///
  /// In en, this message translates to:
  /// **'No time mapping for one or more periods.'**
  String get importErrorUnknownPeriod;

  /// No description provided for @importErrorHorizontalMerge.
  ///
  /// In en, this message translates to:
  /// **'Course merged across weekday columns is unsupported.'**
  String get importErrorHorizontalMerge;

  /// No description provided for @importErrorZeroLength.
  ///
  /// In en, this message translates to:
  /// **'Course block rules must not match empty text.'**
  String get importErrorZeroLength;

  /// No description provided for @importErrorNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching course block found.'**
  String get importErrorNoMatch;

  /// No description provided for @importErrorUnmatchedText.
  ///
  /// In en, this message translates to:
  /// **'Course block rule leaves unmatched text; refine the rule.'**
  String get importErrorUnmatchedText;

  /// No description provided for @importErrorIdConflict.
  ///
  /// In en, this message translates to:
  /// **'Same class ID has different content; resolve or explicitly skip.'**
  String get importErrorIdConflict;

  /// No description provided for @importErrorNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No valid courses found.'**
  String get importErrorNoSessions;

  /// No description provided for @importErrorNoSheet.
  ///
  /// In en, this message translates to:
  /// **'No worksheet found.'**
  String get importErrorNoSheet;

  /// No description provided for @importErrorUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'Only XLSX and CSV files are supported.'**
  String get importErrorUnsupportedFile;

  /// No description provided for @importErrorEncodingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not decode CSV; choose an encoding or convert the file.'**
  String get importErrorEncodingFailed;

  /// No description provided for @importErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Parsing timed out. Your configuration is retained.'**
  String get importErrorTimeout;

  /// No description provided for @importErrorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Parsing cancelled.'**
  String get importErrorCancelled;

  /// No description provided for @importErrorWorkerFailed.
  ///
  /// In en, this message translates to:
  /// **'Parsing worker failed. Please retry.'**
  String get importErrorWorkerFailed;

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
  /// **'The selected sessions will stay in Recently Deleted for 7 days. Continue?'**
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
  /// **'Go to Import and select your XLSX or CSV schedule files'**
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

  /// No description provided for @upcomingWeekMonday.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String upcomingWeekMonday(String date);

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
  /// **'Select XLSX / CSV schedule files'**
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

  /// No description provided for @settingsCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsCategoryGeneral;

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

  /// No description provided for @themeStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Course colors'**
  String get themeStyleTitle;

  /// No description provided for @themeStyleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use one accent or automatic colors for each course'**
  String get themeStyleSubtitle;

  /// No description provided for @themeStyleStandard.
  ///
  /// In en, this message translates to:
  /// **'Uniform color'**
  String get themeStyleStandard;

  /// No description provided for @themeStyleColorful.
  ///
  /// In en, this message translates to:
  /// **'Automatic colors'**
  String get themeStyleColorful;

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

  /// No description provided for @themeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeModeTitle;

  /// No description provided for @themeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose light, dark, or follow system'**
  String get themeModeSubtitle;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @weekStartDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Week start day'**
  String get weekStartDayTitle;

  /// No description provided for @weekStartDaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which day each week begins on the grid'**
  String get weekStartDaySubtitle;

  /// No description provided for @weekStartMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekStartMonday;

  /// No description provided for @weekStartSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekStartSunday;

  /// No description provided for @gridDensityTitle.
  ///
  /// In en, this message translates to:
  /// **'Grid density'**
  String get gridDensityTitle;

  /// No description provided for @gridDensitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust row height and font size'**
  String get gridDensitySubtitle;

  /// No description provided for @gridDensityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get gridDensityCompact;

  /// No description provided for @gridDensityStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get gridDensityStandard;

  /// No description provided for @gridDensityComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get gridDensityComfortable;

  /// No description provided for @scheduleNarrowLayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Narrow-screen schedule layout'**
  String get scheduleNarrowLayoutTitle;

  /// No description provided for @scheduleNarrowLayoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a full compact week or the classic adaptive day view'**
  String get scheduleNarrowLayoutSubtitle;

  /// No description provided for @scheduleNarrowLayoutCompactWeek.
  ///
  /// In en, this message translates to:
  /// **'Compact full week'**
  String get scheduleNarrowLayoutCompactWeek;

  /// No description provided for @scheduleNarrowLayoutAdaptive.
  ///
  /// In en, this message translates to:
  /// **'Classic adaptive'**
  String get scheduleNarrowLayoutAdaptive;

  /// No description provided for @scheduleMultiDayCountTitle.
  ///
  /// In en, this message translates to:
  /// **'Days in multi-day view'**
  String get scheduleMultiDayCountTitle;

  /// No description provided for @scheduleMultiDayCountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This window can show up to {maxCount} readable days'**
  String scheduleMultiDayCountSubtitle(int maxCount);

  /// No description provided for @scheduleDayCountOption.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String scheduleDayCountOption(int count);

  /// No description provided for @scheduleShowEmptyDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Show days without classes'**
  String get scheduleShowEmptyDaysTitle;

  /// No description provided for @scheduleShowEmptyDaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used by classic adaptive view; turn off to move directly between class days'**
  String get scheduleShowEmptyDaysSubtitle;

  /// No description provided for @upcomingShowCourseDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Show date beside countdown'**
  String get upcomingShowCourseDateTitle;

  /// No description provided for @upcomingShowCourseDateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display the course date in the Upcoming list'**
  String get upcomingShowCourseDateSubtitle;

  /// No description provided for @upcomingDateDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Course date format'**
  String get upcomingDateDisplayTitle;

  /// No description provided for @upcomingDateDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which date details to show'**
  String get upcomingDateDisplaySubtitle;

  /// No description provided for @upcomingDateDisplayDateAndWeekday.
  ///
  /// In en, this message translates to:
  /// **'Date + weekday'**
  String get upcomingDateDisplayDateAndWeekday;

  /// No description provided for @upcomingDateDisplayDateOnly.
  ///
  /// In en, this message translates to:
  /// **'Date only'**
  String get upcomingDateDisplayDateOnly;

  /// No description provided for @upcomingDateDisplayWeekdayOnly.
  ///
  /// In en, this message translates to:
  /// **'Weekday only'**
  String get upcomingDateDisplayWeekdayOnly;

  /// No description provided for @scheduleJumpToNearestCourse.
  ///
  /// In en, this message translates to:
  /// **'Nearest class day'**
  String get scheduleJumpToNearestCourse;

  /// No description provided for @scheduleCourseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} courses'**
  String scheduleCourseCount(int count);

  /// No description provided for @classLeadCustomizeTemplates.
  ///
  /// In en, this message translates to:
  /// **'Customize class reminders'**
  String get classLeadCustomizeTemplates;

  /// No description provided for @classLeadCustomizeTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for default text'**
  String get classLeadCustomizeTemplatesSubtitle;

  /// No description provided for @classLeadTemplateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Class reminder text'**
  String get classLeadTemplateSheetTitle;

  /// No description provided for @classLeadTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get classLeadTitleLabel;

  /// No description provided for @classLeadBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get classLeadBodyLabel;

  /// No description provided for @classLeadTemplatePlaceholderHint.
  ///
  /// In en, this message translates to:
  /// **'Use {courseToken}, {roomToken}, {timeToken}, {minutesToken}. Leave blank for defaults.'**
  String classLeadTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
    String minutesToken,
  );

  /// No description provided for @checkInCustomizeTemplates.
  ///
  /// In en, this message translates to:
  /// **'Customize check-in reminders'**
  String get checkInCustomizeTemplates;

  /// No description provided for @checkInCustomizeTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for default text'**
  String get checkInCustomizeTemplatesSubtitle;

  /// No description provided for @checkInTemplateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-in reminder text'**
  String get checkInTemplateSheetTitle;

  /// No description provided for @checkInTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get checkInTitleLabel;

  /// No description provided for @checkInBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get checkInBodyLabel;

  /// No description provided for @checkInTemplatePlaceholderHint.
  ///
  /// In en, this message translates to:
  /// **'Use {courseToken}, {roomToken}, {timeToken}. Leave blank for defaults.'**
  String checkInTemplatePlaceholderHint(
    String courseToken,
    String roomToken,
    String timeToken,
  );

  /// No description provided for @sessionColor.
  ///
  /// In en, this message translates to:
  /// **'Course color'**
  String get sessionColor;

  /// No description provided for @sessionColorShort.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get sessionColorShort;

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
  /// **'Reminders use background scheduled reminders and do not require the app to stay open. Complete the settings below for best reliability.'**
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
  /// **'On OriginOS / iQOO, allow autostart and unrestricted background activity, then lock Orbit in recents.'**
  String get androidAutostartHint;

  /// No description provided for @debugTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debugTitle;

  /// No description provided for @debugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification and background reminder diagnostics'**
  String get debugSubtitle;

  /// No description provided for @androidTestImmediateReminder.
  ///
  /// In en, this message translates to:
  /// **'Test notification now'**
  String get androidTestImmediateReminder;

  /// No description provided for @androidTestImmediateReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Immediately verifies notification permission and display.'**
  String get androidTestImmediateReminderSubtitle;

  /// No description provided for @androidTestImmediateReminderShown.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent.'**
  String get androidTestImmediateReminderShown;

  /// No description provided for @androidTestBackgroundReminder.
  ///
  /// In en, this message translates to:
  /// **'Test background reminder (1 min)'**
  String get androidTestBackgroundReminder;

  /// No description provided for @androidTestBackgroundReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Registers the same native alarm as class reminders. After one minute, reopen Orbit to inspect registration, receiver, and notification stages.'**
  String get androidTestBackgroundReminderSubtitle;

  /// No description provided for @androidTestBackgroundReminderScheduled.
  ///
  /// In en, this message translates to:
  /// **'Stage 1 passed: the one-minute alarm is registered. Leave Orbit, wait, then check Reminder diagnostics.'**
  String get androidTestBackgroundReminderScheduled;

  /// No description provided for @androidTestBackgroundReminderScheduledAt.
  ///
  /// In en, this message translates to:
  /// **'Stage 1 passed: Android registered the alarm for {time}. Leave Orbit, wait, then check Reminder diagnostics.'**
  String androidTestBackgroundReminderScheduledAt(String time);

  /// No description provided for @androidTestBackgroundNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Orbit background reminder test'**
  String get androidTestBackgroundNotificationTitle;

  /// No description provided for @androidTestBackgroundNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'The background reminder fired successfully. Orbit can notify you while it is not in the foreground.'**
  String get androidTestBackgroundNotificationBody;

  /// No description provided for @androidTestBackgroundReminderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not schedule the test reminder. Check exact alarm permission.'**
  String get androidTestBackgroundReminderFailed;

  /// No description provided for @androidTestReminderNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled. Allow notifications and try again.'**
  String get androidTestReminderNotificationsDenied;

  /// No description provided for @androidTestReminderExactAlarmsDenied.
  ///
  /// In en, this message translates to:
  /// **'Exact alarms are disabled. Allow exact alarms and try again.'**
  String get androidTestReminderExactAlarmsDenied;

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
  /// **'Ended sessions will stay in Recently Deleted for 7 days. Continue?'**
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
  /// **'All imported schedule data will be moved to Recently Deleted and kept for 7 days.'**
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

  /// No description provided for @nextDayRemindWhenNoClass.
  ///
  /// In en, this message translates to:
  /// **'Remind when no classes'**
  String get nextDayRemindWhenNoClass;

  /// No description provided for @nextDayRemindWhenNoClassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Still send a preview notification when tomorrow has no classes'**
  String get nextDayRemindWhenNoClassSubtitle;

  /// No description provided for @nextDayCustomizeTemplates.
  ///
  /// In en, this message translates to:
  /// **'Customize reminder text'**
  String get nextDayCustomizeTemplates;

  /// No description provided for @nextDayCustomizeTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit title and body; leave blank for defaults'**
  String get nextDayCustomizeTemplatesSubtitle;

  /// No description provided for @nextDayTemplateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Next-day reminder text'**
  String get nextDayTemplateSheetTitle;

  /// No description provided for @nextDayWithClassTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title (with classes)'**
  String get nextDayWithClassTitleLabel;

  /// No description provided for @nextDayWithClassBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body (with classes)'**
  String get nextDayWithClassBodyLabel;

  /// No description provided for @nextDayNoClassTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title (no classes)'**
  String get nextDayNoClassTitleLabel;

  /// No description provided for @nextDayNoClassBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body (no classes)'**
  String get nextDayNoClassBodyLabel;

  /// No description provided for @nextDayTemplatePlaceholderHint.
  ///
  /// In en, this message translates to:
  /// **'Body with classes: {countToken}, {timeToken}, {dateToken}. No-class body: {dateToken}. Leave blank for defaults.'**
  String nextDayTemplatePlaceholderHint(
    String countToken,
    String timeToken,
    String dateToken,
  );

  /// No description provided for @nextDayTemplateReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get nextDayTemplateReset;

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
  /// **'Delete class'**
  String get deleteSession;

  /// No description provided for @deleteSessionShort.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSessionShort;

  /// No description provided for @courseColorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get courseColorDefault;

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
  /// **'XLSX / CSV course lists and weekly grids'**
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
  /// **'Reminders were saved, but Android did not queue them. Check notification, exact alarm, and battery settings, then resync.'**
  String get reminderScheduleVerifyFailed;

  /// No description provided for @reminderScheduleVerifyFailedBanner.
  ///
  /// In en, this message translates to:
  /// **'Android did not queue any reminders. Check notification, exact alarm, and battery settings, then resync.'**
  String get reminderScheduleVerifyFailedBanner;

  /// No description provided for @reminderScheduledCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reminder(s) scheduled'**
  String reminderScheduledCount(int count);

  /// No description provided for @reminderRegisteredAlarmCount.
  ///
  /// In en, this message translates to:
  /// **'{count} background reminder(s) registered'**
  String reminderRegisteredAlarmCount(int count);

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

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted'**
  String get trashTitle;

  /// No description provided for @trashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted classes are kept for 7 days'**
  String get trashSubtitle;

  /// No description provided for @trashEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recently deleted classes'**
  String get trashEmpty;

  /// No description provided for @trashDeletedAt.
  ///
  /// In en, this message translates to:
  /// **'Deleted {time}'**
  String trashDeletedAt(Object time);

  /// No description provided for @trashRestoreSelected.
  ///
  /// In en, this message translates to:
  /// **'Restore selected'**
  String get trashRestoreSelected;

  /// No description provided for @trashRestoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore all'**
  String get trashRestoreAll;

  /// No description provided for @trashEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Empty trash'**
  String get trashEmptyAction;

  /// No description provided for @trashEmptyConfirm1Title.
  ///
  /// In en, this message translates to:
  /// **'Empty trash?'**
  String get trashEmptyConfirm1Title;

  /// No description provided for @trashEmptyConfirm1Content.
  ///
  /// In en, this message translates to:
  /// **'All recently deleted classes will be permanently removed.'**
  String get trashEmptyConfirm1Content;

  /// No description provided for @trashEmptyConfirm2Title.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete?'**
  String get trashEmptyConfirm2Title;

  /// No description provided for @trashEmptyConfirm2Content.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get trashEmptyConfirm2Content;

  /// No description provided for @trashRestoreResult.
  ///
  /// In en, this message translates to:
  /// **'Restored {restored}; skipped {skipped} conflicting class(es)'**
  String trashRestoreResult(Object restored, Object skipped);

  /// No description provided for @courseScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply changes to'**
  String get courseScopeTitle;

  /// No description provided for @courseScopeSingle.
  ///
  /// In en, this message translates to:
  /// **'This class only'**
  String get courseScopeSingle;

  /// No description provided for @courseScopeFromSelected.
  ///
  /// In en, this message translates to:
  /// **'This and future classes'**
  String get courseScopeFromSelected;

  /// No description provided for @courseScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All matching classes'**
  String get courseScopeAll;

  /// No description provided for @courseOperationSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} class(es), {start} to {end}. {conflicts} conflict(s) will be replaced.'**
  String courseOperationSummary(
    Object conflicts,
    Object count,
    Object end,
    Object start,
  );

  /// No description provided for @courseBatchUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {count} class(es)'**
  String courseBatchUpdated(Object count);

  /// No description provided for @courseBatchDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} class(es)'**
  String courseBatchDeleted(Object count);

  /// No description provided for @backupIncludesSettings.
  ///
  /// In en, this message translates to:
  /// **'Includes appearance, schedule, reminder and course color settings'**
  String get backupIncludesSettings;

  /// No description provided for @restorePreviewSummary.
  ///
  /// In en, this message translates to:
  /// **'Backup v{version} · {count} class(es) · {start} to {end}'**
  String restorePreviewSummary(
    Object count,
    Object end,
    Object start,
    Object version,
  );

  /// No description provided for @restoreCoursesOption.
  ///
  /// In en, this message translates to:
  /// **'Restore classes'**
  String get restoreCoursesOption;

  /// No description provided for @restoreSettingsOption.
  ///
  /// In en, this message translates to:
  /// **'Restore app settings'**
  String get restoreSettingsOption;

  /// No description provided for @restoreModeMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge and replace conflicts'**
  String get restoreModeMerge;

  /// No description provided for @restoreModeReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace current schedule'**
  String get restoreModeReplace;

  /// No description provided for @restoreNothingSelected.
  ///
  /// In en, this message translates to:
  /// **'Select classes or app settings to restore'**
  String get restoreNothingSelected;

  /// No description provided for @restoreSettingsDone.
  ///
  /// In en, this message translates to:
  /// **'App settings restored'**
  String get restoreSettingsDone;

  /// No description provided for @addSessionChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add class'**
  String get addSessionChoiceTitle;

  /// No description provided for @addSingleSession.
  ///
  /// In en, this message translates to:
  /// **'Add one class'**
  String get addSingleSession;

  /// No description provided for @addBatchSessions.
  ///
  /// In en, this message translates to:
  /// **'Add recurring classes'**
  String get addBatchSessions;

  /// No description provided for @batchAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add recurring classes'**
  String get batchAddTitle;

  /// No description provided for @batchFirstWeekMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday of week 1'**
  String get batchFirstWeekMonday;

  /// No description provided for @batchTotalWeeks.
  ///
  /// In en, this message translates to:
  /// **'Semester length'**
  String get batchTotalWeeks;

  /// No description provided for @batchSelectedWeeks.
  ///
  /// In en, this message translates to:
  /// **'Class weeks'**
  String get batchSelectedWeeks;

  /// No description provided for @batchMeetings.
  ///
  /// In en, this message translates to:
  /// **'Weekly meetings'**
  String get batchMeetings;

  /// No description provided for @batchAddMeeting.
  ///
  /// In en, this message translates to:
  /// **'Add weekly meeting'**
  String get batchAddMeeting;

  /// No description provided for @batchRemoveMeeting.
  ///
  /// In en, this message translates to:
  /// **'Remove meeting'**
  String get batchRemoveMeeting;

  /// No description provided for @batchSelectAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get batchSelectAll;

  /// No description provided for @batchSelectOdd.
  ///
  /// In en, this message translates to:
  /// **'Odd weeks'**
  String get batchSelectOdd;

  /// No description provided for @batchSelectEven.
  ///
  /// In en, this message translates to:
  /// **'Even weeks'**
  String get batchSelectEven;

  /// No description provided for @batchClearWeeks.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get batchClearWeeks;

  /// No description provided for @batchMeetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting {index}'**
  String batchMeetingTitle(Object index);

  /// No description provided for @batchWeekOption.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String batchWeekOption(Object week);

  /// No description provided for @batchRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Enter a course name and a room for every meeting'**
  String get batchRequiredFields;

  /// No description provided for @batchNoWeeks.
  ///
  /// In en, this message translates to:
  /// **'Select at least one class week'**
  String get batchNoWeeks;

  /// No description provided for @batchNoMeetings.
  ///
  /// In en, this message translates to:
  /// **'Add at least one weekly meeting'**
  String get batchNoMeetings;

  /// No description provided for @batchInvalidTime.
  ///
  /// In en, this message translates to:
  /// **'Every meeting must end after it starts'**
  String get batchInvalidTime;

  /// No description provided for @batchMeetingOverlap.
  ///
  /// In en, this message translates to:
  /// **'Weekly meetings on the same day cannot overlap'**
  String get batchMeetingOverlap;

  /// No description provided for @batchPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm recurring classes'**
  String get batchPreviewTitle;

  /// No description provided for @batchPreviewSummary.
  ///
  /// In en, this message translates to:
  /// **'{generated} classes will be created; {conflicts} existing classes conflict.'**
  String batchPreviewSummary(Object conflicts, Object generated);

  /// No description provided for @batchSkipConflicts.
  ///
  /// In en, this message translates to:
  /// **'Skip conflicts'**
  String get batchSkipConflicts;

  /// No description provided for @batchOverwriteConflicts.
  ///
  /// In en, this message translates to:
  /// **'Replace conflicts'**
  String get batchOverwriteConflicts;

  /// No description provided for @batchCreateResult.
  ///
  /// In en, this message translates to:
  /// **'Added {created}, skipped {skipped}, and replaced {overwritten} conflicting classes'**
  String batchCreateResult(Object created, Object overwritten, Object skipped);

  /// No description provided for @courseScopeMeetingFromSelected.
  ///
  /// In en, this message translates to:
  /// **'This meeting from here'**
  String get courseScopeMeetingFromSelected;

  /// No description provided for @courseScopeMeetingAll.
  ///
  /// In en, this message translates to:
  /// **'All weeks of this meeting'**
  String get courseScopeMeetingAll;

  /// No description provided for @courseScopeCourseCommon.
  ///
  /// In en, this message translates to:
  /// **'Common details for the whole course'**
  String get courseScopeCourseCommon;

  /// No description provided for @backToTop.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get backToTop;

  /// No description provided for @scheduleVerticalScaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule vertical scale'**
  String get scheduleVerticalScaleTitle;

  /// No description provided for @scheduleVerticalScaleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce the height to fit more of your schedule. Applies to the selected display density; short classes and large text may limit compression to keep names and time labels readable.'**
  String get scheduleVerticalScaleSubtitle;

  /// No description provided for @scheduleVerticalScaleReset.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get scheduleVerticalScaleReset;

  /// No description provided for @customReminders.
  ///
  /// In en, this message translates to:
  /// **'Custom reminder times'**
  String get customReminders;

  /// No description provided for @customRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Independent times, filters, messages and repetitions'**
  String get customRemindersSubtitle;

  /// No description provided for @reminderStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong alert'**
  String get reminderStrong;

  /// No description provided for @reminderStrongConfig.
  ///
  /// In en, this message translates to:
  /// **'Strong alert settings'**
  String get reminderStrongConfig;

  /// No description provided for @reminderStrongDescription.
  ///
  /// In en, this message translates to:
  /// **'Looping sound; respects system volume, Do Not Disturb and permissions'**
  String get reminderStrongDescription;

  /// No description provided for @reminderCatchUp.
  ///
  /// In en, this message translates to:
  /// **'Catch-up'**
  String get reminderCatchUp;

  /// No description provided for @reminderCatchUpNotice.
  ///
  /// In en, this message translates to:
  /// **'This is a catch-up message, not a real-time reminder.'**
  String get reminderCatchUpNotice;

  /// No description provided for @reminderOriginalTime.
  ///
  /// In en, this message translates to:
  /// **'Originally scheduled'**
  String get reminderOriginalTime;

  /// No description provided for @reminderDeliveredTime.
  ///
  /// In en, this message translates to:
  /// **'Catch-up time'**
  String get reminderDeliveredTime;

  /// No description provided for @reminderAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge'**
  String get reminderAcknowledge;

  /// No description provided for @reminderStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get reminderStop;

  /// No description provided for @reminderAdd.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get reminderAdd;

  /// No description provided for @reminderEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get reminderEdit;

  /// No description provided for @reminderCopy.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get reminderCopy;

  /// No description provided for @reminderDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get reminderDelete;

  /// No description provided for @reminderSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get reminderSave;

  /// No description provided for @reminderDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get reminderDiscard;

  /// No description provided for @reminderKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get reminderKeepEditing;

  /// No description provided for @reminderName.
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get reminderName;

  /// No description provided for @reminderBasis.
  ///
  /// In en, this message translates to:
  /// **'Time basis'**
  String get reminderBasis;

  /// No description provided for @reminderStart.
  ///
  /// In en, this message translates to:
  /// **'Course start'**
  String get reminderStart;

  /// No description provided for @reminderEnd.
  ///
  /// In en, this message translates to:
  /// **'Course end'**
  String get reminderEnd;

  /// No description provided for @reminderDate.
  ///
  /// In en, this message translates to:
  /// **'Fixed time on course date'**
  String get reminderDate;

  /// No description provided for @reminderBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get reminderBefore;

  /// No description provided for @reminderAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get reminderAfter;

  /// No description provided for @reminderDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get reminderDays;

  /// No description provided for @reminderHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get reminderHours;

  /// No description provided for @reminderMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get reminderMinutes;

  /// No description provided for @reminderSeconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get reminderSeconds;

  /// No description provided for @reminderScope.
  ///
  /// In en, this message translates to:
  /// **'Course scope'**
  String get reminderScope;

  /// No description provided for @reminderAll.
  ///
  /// In en, this message translates to:
  /// **'All courses'**
  String get reminderAll;

  /// No description provided for @reminderSeries.
  ///
  /// In en, this message translates to:
  /// **'Course series'**
  String get reminderSeries;

  /// No description provided for @reminderSessions.
  ///
  /// In en, this message translates to:
  /// **'Individual sessions'**
  String get reminderSessions;

  /// No description provided for @reminderWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekday filter'**
  String get reminderWeekdays;

  /// No description provided for @reminderTypes.
  ///
  /// In en, this message translates to:
  /// **'Course type filter'**
  String get reminderTypes;

  /// No description provided for @reminderDateRange.
  ///
  /// In en, this message translates to:
  /// **'Course date range'**
  String get reminderDateRange;

  /// No description provided for @reminderClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear date filter'**
  String get reminderClearFilter;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification title'**
  String get reminderTitle;

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'Notification message'**
  String get reminderBody;

  /// No description provided for @reminderCount.
  ///
  /// In en, this message translates to:
  /// **'Send count (1–100, including first)'**
  String get reminderCount;

  /// No description provided for @reminderInterval.
  ///
  /// In en, this message translates to:
  /// **'Repeat interval (seconds, at least 1)'**
  String get reminderInterval;

  /// No description provided for @reminderUntilAck.
  ///
  /// In en, this message translates to:
  /// **'Stop on acknowledgement, up to the send count'**
  String get reminderUntilAck;

  /// No description provided for @reminderInherit.
  ///
  /// In en, this message translates to:
  /// **'Use global setting'**
  String get reminderInherit;

  /// No description provided for @reminderNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal alert'**
  String get reminderNormal;

  /// No description provided for @reminderPreview.
  ///
  /// In en, this message translates to:
  /// **'Matching courses and delivery preview'**
  String get reminderPreview;

  /// No description provided for @reminderTimingNotice.
  ///
  /// In en, this message translates to:
  /// **'Times include seconds; the system may delay delivery. New or re-enabled rules only schedule future sends.'**
  String get reminderTimingNotice;

  /// No description provided for @reminderInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check numeric ranges, the required name and invalid placeholders'**
  String get reminderInvalid;

  /// No description provided for @reminderSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get reminderSound;

  /// No description provided for @reminderVibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get reminderVibration;

  /// No description provided for @reminderDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration (5–300 seconds)'**
  String get reminderDuration;

  /// No description provided for @reminderSystemSound.
  ///
  /// In en, this message translates to:
  /// **'Choose system sound'**
  String get reminderSystemSound;

  /// No description provided for @reminderImportSound.
  ///
  /// In en, this message translates to:
  /// **'Import audio (MP3/M4A/WAV, up to 5 MiB)'**
  String get reminderImportSound;

  /// No description provided for @reminderPreviewSound.
  ///
  /// In en, this message translates to:
  /// **'Preview / stop'**
  String get reminderPreviewSound;

  /// No description provided for @reminderOverride.
  ///
  /// In en, this message translates to:
  /// **'Override strong alert settings'**
  String get reminderOverride;

  /// No description provided for @reminderEmpty.
  ///
  /// In en, this message translates to:
  /// **'No custom reminder rules yet'**
  String get reminderEmpty;

  /// No description provided for @reminderSoundFallback.
  ///
  /// In en, this message translates to:
  /// **'Missing or unsupported sound replaced with the system default.'**
  String get reminderSoundFallback;

  /// No description provided for @reminderMaintenanceFailed.
  ///
  /// In en, this message translates to:
  /// **'Background maintenance registration failed. Later reminders may not be queued after exit. Please retry.'**
  String get reminderMaintenanceFailed;

  /// No description provided for @reminderStrongDegraded.
  ///
  /// In en, this message translates to:
  /// **'Strong playback was unavailable; the normal notification was retained. Check system restrictions and sound settings.'**
  String get reminderStrongDegraded;

  /// No description provided for @reminderVariableLabels.
  ///
  /// In en, this message translates to:
  /// **'Course|Room|Course date|Weekday|Start time|End time|Teachers|Course code|Send index|Total count|Scheduled time'**
  String get reminderVariableLabels;

  /// No description provided for @reminderWeekdayNames.
  ///
  /// In en, this message translates to:
  /// **'Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday'**
  String get reminderWeekdayNames;

  /// No description provided for @reminderDiscardAction.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get reminderDiscardAction;

  /// No description provided for @reminderAudioInvalid.
  ///
  /// In en, this message translates to:
  /// **'The audio cannot be played, or its format or size is unsupported.'**
  String get reminderAudioInvalid;

  /// No description provided for @reminderDateOffset.
  ///
  /// In en, this message translates to:
  /// **'Course date offset'**
  String get reminderDateOffset;

  /// No description provided for @reminderSameDay.
  ///
  /// In en, this message translates to:
  /// **'Course day'**
  String get reminderSameDay;

  /// No description provided for @reminderFixedTime.
  ///
  /// In en, this message translates to:
  /// **'Fixed time (hour / minute / second)'**
  String get reminderFixedTime;

  /// No description provided for @reminderFilterWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Mon|Tue|Wed|Thu|Fri|Sat|Sun'**
  String get reminderFilterWeekdays;

  /// No description provided for @reminderPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get reminderPreviousDay;

  /// No description provided for @reminderNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get reminderNextDay;

  /// No description provided for @scheduleFitPage.
  ///
  /// In en, this message translates to:
  /// **'Fit to page'**
  String get scheduleFitPage;

  /// No description provided for @scheduleFitPageHint.
  ///
  /// In en, this message translates to:
  /// **'Show 08:00–22:00 in full. Course text may be hidden; select a course for details.'**
  String get scheduleFitPageHint;

  /// No description provided for @themeMulticolor.
  ///
  /// In en, this message translates to:
  /// **'Multicolor palette'**
  String get themeMulticolor;

  /// No description provided for @themeMulticolorOff.
  ///
  /// In en, this message translates to:
  /// **'Original palette'**
  String get themeMulticolorOff;

  /// No description provided for @themeSchemeNames.
  ///
  /// In en, this message translates to:
  /// **'Vibrant|Expressive|Rainbow|Fruit salad|Content|Fidelity|Neutral|Monochrome'**
  String get themeSchemeNames;

  /// No description provided for @templateLeadMinutes.
  ///
  /// In en, this message translates to:
  /// **'Lead minutes'**
  String get templateLeadMinutes;

  /// No description provided for @templateCourseCount.
  ///
  /// In en, this message translates to:
  /// **'Course count'**
  String get templateCourseCount;

  /// No description provided for @palettePrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary color'**
  String get palettePrimary;

  /// No description provided for @paletteSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary color'**
  String get paletteSecondary;

  /// No description provided for @paletteTertiary.
  ///
  /// In en, this message translates to:
  /// **'Third color'**
  String get paletteTertiary;

  /// No description provided for @paletteColors.
  ///
  /// In en, this message translates to:
  /// **'Course palette'**
  String get paletteColors;

  /// No description provided for @paletteCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom combination'**
  String get paletteCustom;

  /// No description provided for @paletteDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This color is already in the palette'**
  String get paletteDuplicate;

  /// No description provided for @paletteUsePrimary.
  ///
  /// In en, this message translates to:
  /// **'Use as primary'**
  String get paletteUsePrimary;

  /// No description provided for @paletteUseSecondary.
  ///
  /// In en, this message translates to:
  /// **'Use as secondary'**
  String get paletteUseSecondary;

  /// No description provided for @paletteUseTertiary.
  ///
  /// In en, this message translates to:
  /// **'Use as third color'**
  String get paletteUseTertiary;

  /// No description provided for @paletteMoveEarlier.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get paletteMoveEarlier;

  /// No description provided for @paletteMoveLater.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get paletteMoveLater;

  /// No description provided for @paletteReset.
  ///
  /// In en, this message translates to:
  /// **'Reset multicolor settings?'**
  String get paletteReset;

  /// No description provided for @palettePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get palettePreview;

  /// No description provided for @paletteSingle.
  ///
  /// In en, this message translates to:
  /// **'Single color'**
  String get paletteSingle;

  /// No description provided for @paletteMode.
  ///
  /// In en, this message translates to:
  /// **'Interface colors'**
  String get paletteMode;

  /// No description provided for @paletteAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic from scheme'**
  String get paletteAutomatic;

  /// No description provided for @notificationWarning.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is off. Reminders cannot be delivered.'**
  String get notificationWarning;

  /// No description provided for @notificationOpen.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get notificationOpen;

  /// No description provided for @notificationIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore and do not show again'**
  String get notificationIgnore;

  /// No description provided for @notificationIgnoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Ignore the notification warning?'**
  String get notificationIgnoreTitle;

  /// No description provided for @notificationIgnoreBody.
  ///
  /// In en, this message translates to:
  /// **'Without notification permission, reminders will not work. You can restore this warning in Settings.'**
  String get notificationIgnoreBody;

  /// No description provided for @notificationIgnoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm ignore'**
  String get notificationIgnoreConfirm;

  /// No description provided for @notificationRestore.
  ///
  /// In en, this message translates to:
  /// **'Show permission warnings'**
  String get notificationRestore;

  /// No description provided for @notificationRestoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Warn when notifications are disabled on this device'**
  String get notificationRestoreDescription;

  /// No description provided for @notificationCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to check notification permission'**
  String get notificationCheckFailed;

  /// No description provided for @notificationAllowed.
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get notificationAllowed;

  /// No description provided for @notificationPermissions.
  ///
  /// In en, this message translates to:
  /// **'Notification permission'**
  String get notificationPermissions;

  /// No description provided for @strongTargets.
  ///
  /// In en, this message translates to:
  /// **'Apply strong reminders to'**
  String get strongTargets;

  /// No description provided for @strongClassLead.
  ///
  /// In en, this message translates to:
  /// **'Before class'**
  String get strongClassLead;

  /// No description provided for @strongCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get strongCheckIn;

  /// No description provided for @strongSummary.
  ///
  /// In en, this message translates to:
  /// **'Next-day summary'**
  String get strongSummary;

  /// No description provided for @strongCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom rules'**
  String get strongCustom;

  /// No description provided for @strongCourses.
  ///
  /// In en, this message translates to:
  /// **'Course range'**
  String get strongCourses;

  /// No description provided for @strongAllRules.
  ///
  /// In en, this message translates to:
  /// **'All inherited rules, including future rules'**
  String get strongAllRules;

  /// No description provided for @strongRuleOverrideNotice.
  ///
  /// In en, this message translates to:
  /// **'Rules explicitly set to Strong or Normal take priority over these selections.'**
  String get strongRuleOverrideNotice;

  /// No description provided for @strongSummaryNotice.
  ///
  /// In en, this message translates to:
  /// **'With a limited course range, the summary is strong only if it includes a selected course.'**
  String get strongSummaryNotice;

  /// No description provided for @settingsNavigationGroup.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get settingsNavigationGroup;

  /// No description provided for @settingsLayoutGroup.
  ///
  /// In en, this message translates to:
  /// **'Schedule layout'**
  String get settingsLayoutGroup;

  /// No description provided for @settingsMaintenanceGroup.
  ///
  /// In en, this message translates to:
  /// **'Permissions and maintenance'**
  String get settingsMaintenanceGroup;

  /// No description provided for @settingsDangerGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete data'**
  String get settingsDangerGroup;

  /// No description provided for @settingsDiagnosticsGroup.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnosticsGroup;

  /// No description provided for @settingsBackupGroup.
  ///
  /// In en, this message translates to:
  /// **'Backup and export'**
  String get settingsBackupGroup;

  /// No description provided for @paletteEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit color'**
  String get paletteEdit;

  /// No description provided for @paletteHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a color for actions. Long press to delete.'**
  String get paletteHint;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @paletteTonalSpot.
  ///
  /// In en, this message translates to:
  /// **'Tonal spot'**
  String get paletteTonalSpot;

  /// No description provided for @paletteHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get paletteHue;

  /// No description provided for @paletteChroma.
  ///
  /// In en, this message translates to:
  /// **'Color intensity'**
  String get paletteChroma;

  /// No description provided for @paletteTone.
  ///
  /// In en, this message translates to:
  /// **'Lightness'**
  String get paletteTone;

  /// No description provided for @paletteScheme.
  ///
  /// In en, this message translates to:
  /// **'Color scheme'**
  String get paletteScheme;

  /// No description provided for @paletteSchemeDescriptions.
  ///
  /// In en, this message translates to:
  /// **'Soft, coordinated hues|Vivid contrasting hues|Rotated expressive triad|Balanced three-hue spectrum|Fresh adjacent hues|Seed-led gentle contrast|Seed-led complementary contrast|Low saturation, subtle differences|Grayscale, no hue contrast'**
  String get paletteSchemeDescriptions;

  /// No description provided for @androidEnhancedReminder.
  ///
  /// In en, this message translates to:
  /// **'Enhanced reminder mode'**
  String get androidEnhancedReminder;

  /// No description provided for @androidEnhancedReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keeps a quiet ongoing notification while future reminders exist to improve reliability on some phones.'**
  String get androidEnhancedReminderSubtitle;

  /// No description provided for @androidEnhancedReminderLimit.
  ///
  /// In en, this message translates to:
  /// **'A real force stop still prevents Android from delivering alarms until Orbit is opened again.'**
  String get androidEnhancedReminderLimit;

  /// No description provided for @androidEnhancedReminderChannel.
  ///
  /// In en, this message translates to:
  /// **'Reminder reliability'**
  String get androidEnhancedReminderChannel;

  /// No description provided for @androidEnhancedReminderNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Enhanced reminders enabled'**
  String get androidEnhancedReminderNotificationTitle;

  /// No description provided for @androidEnhancedReminderNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Orbit is protecting future course reminders.'**
  String get androidEnhancedReminderNotificationBody;

  /// No description provided for @androidEnhancedReminderDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get androidEnhancedReminderDisable;

  /// No description provided for @androidOriginOsSettings.
  ///
  /// In en, this message translates to:
  /// **'OriginOS background settings'**
  String get androidOriginOsSettings;

  /// No description provided for @androidOriginOsSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable autostart and background high power usage, remove battery restrictions, then lock Orbit in Recents.'**
  String get androidOriginOsSettingsSubtitle;

  /// No description provided for @androidOpenAutostartSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get androidOpenAutostartSettings;

  /// No description provided for @androidForcedStopDetected.
  ///
  /// In en, this message translates to:
  /// **'Orbit was force-stopped'**
  String get androidForcedStopDetected;

  /// No description provided for @androidForcedStopDetectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The recent-app cleaner stopped Orbit and canceled its alarms. Complete the OriginOS settings below, then run the one-minute test again.'**
  String get androidForcedStopDetectedSubtitle;

  /// No description provided for @androidReminderReliability.
  ///
  /// In en, this message translates to:
  /// **'Reminder registration'**
  String get androidReminderReliability;

  /// No description provided for @androidReminderReliabilityStatus.
  ///
  /// In en, this message translates to:
  /// **'{registered} of {stored} future reminders are registered with Android.'**
  String androidReminderReliabilityStatus(int registered, int stored);

  /// No description provided for @androidReminderDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Reminder diagnostics'**
  String get androidReminderDiagnostics;

  /// No description provided for @androidReminderDiagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No native reminder events recorded yet.'**
  String get androidReminderDiagnosticsEmpty;
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
