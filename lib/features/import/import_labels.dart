import 'package:flutter/widgets.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/schedule_import.dart';

String importFieldLabel(AppLocalizations l, ImportField field) =>
    switch (field) {
      ImportField.courseName => l.importFieldCourseName,
      ImportField.courseCode => l.importFieldCourseCode,
      ImportField.section => l.importFieldSection,
      ImportField.room => l.importFieldRoom,
      ImportField.teachers => l.importFieldTeachers,
      ImportField.faculty => l.importFieldFaculty,
      ImportField.classType => l.importFieldClassType,
      ImportField.semester => l.importFieldSemester,
      ImportField.date => l.importFieldDate,
      ImportField.weekday => l.importFieldWeekday,
      ImportField.weeks => l.importFieldWeeks,
      ImportField.periods => l.importFieldPeriods,
      ImportField.startTime => l.importFieldStartTime,
      ImportField.endTime => l.importFieldEndTime,
    };
String importErrorMessage(AppLocalizations l, Object error) {
  final code = error is FormatException ? error.message : '$error';
  return switch (code) {
    'ambiguous' => l.importErrorAmbiguous,
    'templateInvalid' => l.importErrorTemplateInvalid,
    'templateVersion' => l.importErrorTemplateVersion,
    'captureGroup' => l.importErrorCaptureGroup,
    'missingName' => l.importErrorMissingName,
    'semesterInvalid' => l.importErrorSemesterInvalid,
    'periodInvalid' => l.importErrorPeriodInvalid,
    'invalidTime' => l.importErrorInvalidTime,
    'invalidDate' => l.importErrorInvalidDate,
    'invalidWeekday' => l.importErrorInvalidWeekday,
    'weekdayMismatch' => l.importErrorWeekdayMismatch,
    'invalidWeeks' => l.importErrorInvalidWeeks,
    'weeksRequired' => l.importErrorWeeksRequired,
    'contextRequired' => l.importErrorContextRequired,
    'unknownPeriod' => l.importErrorUnknownPeriod,
    'horizontalMerge' => l.importErrorHorizontalMerge,
    'zeroLength' => l.importErrorZeroLength,
    'noMatch' => l.importErrorNoMatch,
    'unmatchedText' => l.importErrorUnmatchedText,
    'idConflict' => l.importErrorIdConflict,
    'noSessions' => l.importErrorNoSessions,
    'noSheet' => l.importErrorNoSheet,
    'unsupportedFile' => l.importErrorUnsupportedFile,
    'encodingFailed' => l.importErrorEncodingFailed,
    'timeout' => l.importErrorTimeout,
    'cancelled' => l.importErrorCancelled,
    'workerFailed' => l.importErrorWorkerFailed,
    'emptySheet' => l.xlsxErrorEmptySheet,
    _ => l.importParseFailed(code),
  };
}

String templateLabel(AppLocalizations l, ScheduleImportTemplate t) => t.builtIn
    ? switch (t.layout) {
        ImportLayout.legacy => l.importLegacyLayout,
        ImportLayout.list => l.importListLayout,
        ImportLayout.grid => l.importGridLayout,
      }
    : t.name;
AppLocalizations importL10n(BuildContext context) =>
    AppLocalizations.of(context)!;
