import 'package:orbit/models/background_settings.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/models/auto_sync_settings.dart';

class PortableSettings {
  const PortableSettings({
    required this.locale,
    required this.themeColor,
    required this.themeMode,
    required this.themeStyle,
    required this.gridDefaultWeekMode,
    required this.weekStartDay,
    required this.gridDensity,
    required this.reminders,
    required this.scheduleDisplay,
    required this.courseColorOverrides,
    this.colorScheme = 'original',
    this.automaticCourseColorIds = const {},
    this.multicolor,
    this.importConfiguration,
    this.autoSyncSettings,
    this.archive = const ArchiveSettings(),
    this.localPreferences = const {},
    this.sourcePlatform,
    this.backgrounds,
  });

  final Map<String, dynamic> localPreferences;
  final String? sourcePlatform;
  final BackgroundSettings? backgrounds;
  final ArchiveSettings archive;
  final String locale;
  final ImportConfiguration? importConfiguration;
  final AutoSyncSettings? autoSyncSettings;
  final int themeColor;
  final String themeMode;
  final String themeStyle;
  final String colorScheme;
  final MulticolorSettings? multicolor;
  final Map<String, int> automaticCourseColorIds;
  final String gridDefaultWeekMode;
  final int weekStartDay;
  final String gridDensity;
  final ReminderSettings reminders;
  final ScheduleDisplaySettings scheduleDisplay;
  final Map<String, int> courseColorOverrides;

  /// Merge collections by ID, keeping unrelated local templates and rules.
  /// Scalar settings and matching IDs use the values selected from the backup.
  PortableSettings mergeWith(PortableSettings local) {
    List<T> union<T>(
      List<T> previous,
      List<T> incoming,
      String Function(T) id,
    ) => {
      for (final item in [...previous, ...incoming]) id(item): item,
    }.values.toList();
    final data = toJson();
    final imported = importConfiguration ?? const ImportConfiguration();
    final previous = local.importConfiguration ?? const ImportConfiguration();
    if (importConfiguration != null || local.importConfiguration != null) {
      data['importConfiguration'] = ImportConfiguration(
        templates: union(previous.templates, imported.templates, (t) => t.id),
        semesters: union(previous.semesters, imported.semesters, (p) => p.id),
        periodTimes: union(
          previous.periodTimes,
          imported.periodTimes,
          (p) => p.id,
        ),
      ).toJson();
    }
    data['reminders'] = _remindersToJson(
      reminders.copyWith(
        customRules: union(
          local.reminders.customRules,
          reminders.customRules,
          (r) => r.id,
        ),
      ),
    );
    data['courseColorOverrides'] = {
      ...local.courseColorOverrides,
      ...courseColorOverrides,
    };
    data['automaticCourseColorIds'] = {
      ...local.automaticCourseColorIds,
      ...automaticCourseColorIds,
    };
    data['localPreferences'] = {...local.localPreferences, ...localPreferences};
    return PortableSettings.fromJson(data);
  }

  PortableSettings withReminders(ReminderSettings value) => PortableSettings(
    localPreferences: localPreferences,
    sourcePlatform: sourcePlatform,
    backgrounds: backgrounds,
    locale: locale,
    themeColor: themeColor,
    themeMode: themeMode,
    themeStyle: themeStyle,
    colorScheme: colorScheme,
    multicolor: multicolor,
    automaticCourseColorIds: automaticCourseColorIds,
    gridDefaultWeekMode: gridDefaultWeekMode,
    weekStartDay: weekStartDay,
    gridDensity: gridDensity,
    reminders: value,
    scheduleDisplay: scheduleDisplay,
    courseColorOverrides: courseColorOverrides,
    importConfiguration: importConfiguration,
    autoSyncSettings: autoSyncSettings,
    archive: archive,
  );

  Map<String, dynamic> toJson() => {
    'localPreferences': localPreferences,
    'sourcePlatform': sourcePlatform,
    if (backgrounds != null) 'backgrounds': backgrounds!.toJson(),
    'archive': archive.toJson(),
    'locale': locale,
    if (importConfiguration != null)
      'importConfiguration': importConfiguration!.toJson(),
    if (autoSyncSettings != null)
      'autoSyncSettings': autoSyncSettings!.toJson(),
    'themeColor': themeColor,
    'themeMode': themeMode,
    'themeStyle': themeStyle,
    'colorScheme': colorScheme,
    if (multicolor != null) 'multicolor': multicolor!.toJson(),
    'automaticCourseColorIds': automaticCourseColorIds,
    'gridDefaultWeekMode': gridDefaultWeekMode,
    'weekStartDay': weekStartDay,
    'gridDensity': gridDensity,
    'reminders': _remindersToJson(reminders),
    'scheduleDisplay': {
      'fitToPage': scheduleDisplay.fitToPage,
      'hideUpcomingPage': scheduleDisplay.hideUpcomingPage,
      'hideImportPage': scheduleDisplay.hideImportPage,
      'strongCardGradient': scheduleDisplay.strongCardGradient.name,
      'narrowLayout': scheduleDisplay.narrowLayout.name,
      'preferredMultiDayCount': scheduleDisplay.preferredMultiDayCount,
      'showEmptyDays': scheduleDisplay.showEmptyDays,
      'showUpcomingCourseDate': scheduleDisplay.showUpcomingCourseDate,
      'upcomingDateDisplay': scheduleDisplay.upcomingDateDisplay.name,
      'backToTopPosition': scheduleDisplay.backToTopPosition.name,
      'verticalScalePercent':
          ScheduleDisplaySettings.normalizeVerticalScalePercent(
            scheduleDisplay.verticalScalePercent,
          ),
    },
    'courseColorOverrides': courseColorOverrides,
  };

  factory PortableSettings.fromJson(Map<String, dynamic> json) {
    final reminders = json['reminders'];
    final display = json['scheduleDisplay'];
    final colors = json['courseColorOverrides'];
    if (reminders is! Map<String, dynamic> ||
        display is! Map<String, dynamic> ||
        colors is! Map<String, dynamic>) {
      throw const FormatException('Invalid portable settings');
    }
    final preferences = Map<String, dynamic>.from(
      json['localPreferences'] as Map? ?? {},
    );
    if (preferences.containsKey('syncSelection') &&
        (preferences['syncSelection'] is! Map ||
            (preferences['syncSelection'] as Map).values.any(
              (v) => v is! bool,
            ))) {
      throw const FormatException('Invalid sync selection');
    }
    for (final e in preferences.entries) {
      if ([
            'launch_at_startup',
            'notification_warning_ignored',
          ].contains(e.key) &&
          e.value is! bool) {
        throw const FormatException('Invalid boolean preference');
      }
      if (e.key == 'batch_total_weeks' &&
          (e.value is! int || e.value < 1 || e.value > 30)) {
        throw const FormatException('Invalid batch weeks');
      }
      if (e.key == 'batch_first_week_monday' &&
          (e.value is! String || DateTime.tryParse(e.value) == null)) {
        throw const FormatException('Invalid first week');
      }
    }
    return PortableSettings(
      localPreferences: Map<String, dynamic>.from(
        json['localPreferences'] as Map? ?? {},
      ),
      sourcePlatform: json['sourcePlatform'] as String?,
      backgrounds: json['backgrounds'] == null
          ? null
          : BackgroundSettings.fromJson(
              Map<String, dynamic>.from(json['backgrounds'] as Map),
            ),
      archive: ArchiveSettings.fromJson(
        Map<String, dynamic>.from(json['archive'] as Map? ?? {}),
      ),
      importConfiguration: json['importConfiguration'] == null
          ? null
          : ImportConfiguration.fromJson(
              Map<String, dynamic>.from(json['importConfiguration'] as Map),
            ),
      autoSyncSettings: json['autoSyncSettings'] == null
          ? null
          : AutoSyncSettings.fromJson(
              Map<String, dynamic>.from(json['autoSyncSettings'] as Map),
            ),
      locale: json['locale'] as String? ?? 'zh_Hant',
      themeColor: json['themeColor'] as int? ?? 0xFF39C5BB,
      themeMode: json['themeMode'] as String? ?? 'system',
      themeStyle: json['themeStyle'] as String? ?? 'standard',
      colorScheme: json['colorScheme'] is String
          ? json['colorScheme'] as String
          : 'original',
      multicolor: json['multicolor'] is Map<String, dynamic>
          ? MulticolorSettings.fromJson(
              json['multicolor'] as Map<String, dynamic>,
            )
          : null,
      automaticCourseColorIds: json['automaticCourseColorIds'] is Map
          ? {
              for (final e in (json['automaticCourseColorIds'] as Map).entries)
                if (e.key is String && e.value is int && e.value >= 0)
                  e.key as String: e.value as int,
            }
          : const {},
      gridDefaultWeekMode: json['gridDefaultWeekMode'] as String? ?? 'smart',
      weekStartDay: json['weekStartDay'] as int? ?? DateTime.monday,
      gridDensity: json['gridDensity'] as String? ?? 'standard',
      reminders: _remindersFromJson(reminders),
      scheduleDisplay: ScheduleDisplaySettings(
        hideUpcomingPage: display['hideUpcomingPage'] as bool? ?? false,
        hideImportPage: display['hideImportPage'] as bool? ?? false,
        fitToPage: display['fitToPage'] == true,
        strongCardGradient: StrongCardGradient.values.firstWhere(
          (v) => v.name == display['strongCardGradient'],
          orElse: () => StrongCardGradient.upperHalf,
        ),
        verticalScalePercent:
            ScheduleDisplaySettings.normalizeVerticalScalePercent(
              display['verticalScalePercent'],
            ),
        narrowLayout: NarrowScheduleLayout.values.firstWhere(
          (value) => value.name == display['narrowLayout'],
          orElse: () => NarrowScheduleLayout.compactWeek,
        ),
        preferredMultiDayCount: display['preferredMultiDayCount'] as int? ?? 3,
        showEmptyDays: display['showEmptyDays'] as bool? ?? true,
        showUpcomingCourseDate:
            display['showUpcomingCourseDate'] as bool? ?? true,
        backToTopPosition: BackToTopPosition.values.firstWhere(
          (value) => value.name == display['backToTopPosition'],
          orElse: () => BackToTopPosition.smart,
        ),
        upcomingDateDisplay: UpcomingDateDisplay.values.firstWhere(
          (value) => value.name == display['upcomingDateDisplay'],
          orElse: () => UpcomingDateDisplay.dateAndWeekday,
        ),
      ),
      courseColorOverrides: colors.map(
        (key, value) => MapEntry(key, value as int),
      ),
    );
  }

  static Map<String, dynamic> _remindersToJson(ReminderSettings value) => {
    'customRules': value.customRules.map((r) => r.toJson()).toList(),
    'strong': value.strong.toJson(),
    'leadMinutes': value.leadMinutes,
    'enabled': value.enabled,
    'nextDaySummaryEnabled': value.nextDaySummaryEnabled,
    'nextDaySummaryHour': value.nextDaySummaryHour,
    'nextDaySummaryMinute': value.nextDaySummaryMinute,
    'nextDayRemindWhenNoClass': value.nextDayRemindWhenNoClass,
    'nextDayWithClassTitleTemplate': value.nextDayWithClassTitleTemplate,
    'nextDayWithClassBodyTemplate': value.nextDayWithClassBodyTemplate,
    'nextDayNoClassTitleTemplate': value.nextDayNoClassTitleTemplate,
    'nextDayNoClassBodyTemplate': value.nextDayNoClassBodyTemplate,
    'classLeadTitleTemplate': value.classLeadTitleTemplate,
    'classLeadBodyTemplate': value.classLeadBodyTemplate,
    'checkInTitleTemplate': value.checkInTitleTemplate,
    'checkInBodyTemplate': value.checkInBodyTemplate,
    'checkInReminderEnabled': value.checkInReminderEnabled,
  };

  static ReminderSettings _remindersFromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      customRules: (json['customRules'] as List? ?? [])
          .map(
            (v) => CustomReminderRule.fromJson(
              Map<String, dynamic>.from(v as Map),
            ),
          )
          .toList(),
      strong: StrongReminderSettings.fromJson(
        Map<String, dynamic>.from(json['strong'] as Map? ?? {}),
      ),
      leadMinutes: json['leadMinutes'] as int? ?? 15,
      enabled: json['enabled'] as bool? ?? true,
      nextDaySummaryEnabled: json['nextDaySummaryEnabled'] as bool? ?? true,
      nextDaySummaryHour: json['nextDaySummaryHour'] as int? ?? 23,
      nextDaySummaryMinute: json['nextDaySummaryMinute'] as int? ?? 0,
      nextDayRemindWhenNoClass:
          json['nextDayRemindWhenNoClass'] as bool? ?? true,
      nextDayWithClassTitleTemplate:
          json['nextDayWithClassTitleTemplate'] as String?,
      nextDayWithClassBodyTemplate:
          json['nextDayWithClassBodyTemplate'] as String?,
      nextDayNoClassTitleTemplate:
          json['nextDayNoClassTitleTemplate'] as String?,
      nextDayNoClassBodyTemplate: json['nextDayNoClassBodyTemplate'] as String?,
      classLeadTitleTemplate: json['classLeadTitleTemplate'] as String?,
      classLeadBodyTemplate: json['classLeadBodyTemplate'] as String?,
      checkInTitleTemplate: json['checkInTitleTemplate'] as String?,
      checkInBodyTemplate: json['checkInBodyTemplate'] as String?,
      checkInReminderEnabled: json['checkInReminderEnabled'] as bool? ?? true,
    );
  }
}
