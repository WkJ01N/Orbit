import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';

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
  });

  final String locale;
  final int themeColor;
  final String themeMode;
  final String themeStyle;
  final String gridDefaultWeekMode;
  final int weekStartDay;
  final String gridDensity;
  final ReminderSettings reminders;
  final ScheduleDisplaySettings scheduleDisplay;
  final Map<String, int> courseColorOverrides;

  Map<String, dynamic> toJson() => {
    'locale': locale,
    'themeColor': themeColor,
    'themeMode': themeMode,
    'themeStyle': themeStyle,
    'gridDefaultWeekMode': gridDefaultWeekMode,
    'weekStartDay': weekStartDay,
    'gridDensity': gridDensity,
    'reminders': _remindersToJson(reminders),
    'scheduleDisplay': {
      'preferredMultiDayCount': scheduleDisplay.preferredMultiDayCount,
      'showEmptyDays': scheduleDisplay.showEmptyDays,
      'showUpcomingCourseDate': scheduleDisplay.showUpcomingCourseDate,
      'upcomingDateDisplay': scheduleDisplay.upcomingDateDisplay.name,
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
    return PortableSettings(
      locale: json['locale'] as String? ?? 'zh_Hant',
      themeColor: json['themeColor'] as int? ?? 0xFF39C5BB,
      themeMode: json['themeMode'] as String? ?? 'system',
      themeStyle: json['themeStyle'] as String? ?? 'standard',
      gridDefaultWeekMode: json['gridDefaultWeekMode'] as String? ?? 'smart',
      weekStartDay: json['weekStartDay'] as int? ?? DateTime.monday,
      gridDensity: json['gridDensity'] as String? ?? 'standard',
      reminders: _remindersFromJson(reminders),
      scheduleDisplay: ScheduleDisplaySettings(
        preferredMultiDayCount: display['preferredMultiDayCount'] as int? ?? 3,
        showEmptyDays: display['showEmptyDays'] as bool? ?? true,
        showUpcomingCourseDate:
            display['showUpcomingCourseDate'] as bool? ?? true,
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
    'systemAlarmEnabled': value.systemAlarmEnabled,
    'systemAlarmLeadMinutes': value.systemAlarmLeadMinutes,
    'checkInReminderEnabled': value.checkInReminderEnabled,
  };

  static ReminderSettings _remindersFromJson(Map<String, dynamic> json) {
    return ReminderSettings(
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
      systemAlarmEnabled: json['systemAlarmEnabled'] as bool? ?? false,
      systemAlarmLeadMinutes: json['systemAlarmLeadMinutes'] as int? ?? 10,
      checkInReminderEnabled: json['checkInReminderEnabled'] as bool? ?? true,
    );
  }
}
