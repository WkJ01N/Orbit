import 'package:orbit/models/custom_reminder_rule.dart';

class ReminderSettings {
  const ReminderSettings({
    this.leadMinutes = 15,
    this.enabled = true,
    this.nextDaySummaryEnabled = true,
    this.nextDaySummaryHour = 23,
    this.nextDaySummaryMinute = 0,
    this.nextDayRemindWhenNoClass = true,
    this.nextDayWithClassTitleTemplate,
    this.nextDayWithClassBodyTemplate,
    this.nextDayNoClassTitleTemplate,
    this.nextDayNoClassBodyTemplate,
    this.classLeadTitleTemplate,
    this.classLeadBodyTemplate,
    this.checkInTitleTemplate,
    this.checkInBodyTemplate,
    this.checkInReminderEnabled = true,
    this.customRules = const [],
    this.strong = const StrongReminderSettings(),
  });

  final int leadMinutes;
  final bool enabled;
  final bool nextDaySummaryEnabled;
  final int nextDaySummaryHour;
  final int nextDaySummaryMinute;
  final bool nextDayRemindWhenNoClass;
  final String? nextDayWithClassTitleTemplate;
  final String? nextDayWithClassBodyTemplate;
  final String? nextDayNoClassTitleTemplate;
  final String? nextDayNoClassBodyTemplate;
  final String? classLeadTitleTemplate;
  final String? classLeadBodyTemplate;
  final String? checkInTitleTemplate;
  final String? checkInBodyTemplate;
  final bool checkInReminderEnabled;
  final List<CustomReminderRule> customRules;
  final StrongReminderSettings strong;

  static const List<int> leadMinuteOptions = [5, 10, 15, 30, 45, 60, 90, 120];

  ReminderSettings copyWith({
    int? leadMinutes,
    bool? enabled,
    bool? nextDaySummaryEnabled,
    int? nextDaySummaryHour,
    int? nextDaySummaryMinute,
    bool? nextDayRemindWhenNoClass,
    String? nextDayWithClassTitleTemplate,
    String? nextDayWithClassBodyTemplate,
    String? nextDayNoClassTitleTemplate,
    String? nextDayNoClassBodyTemplate,
    String? classLeadTitleTemplate,
    String? classLeadBodyTemplate,
    String? checkInTitleTemplate,
    String? checkInBodyTemplate,
    bool clearNextDayWithClassTitleTemplate = false,
    bool clearNextDayWithClassBodyTemplate = false,
    bool clearNextDayNoClassTitleTemplate = false,
    bool clearNextDayNoClassBodyTemplate = false,
    bool clearClassLeadTitleTemplate = false,
    bool clearClassLeadBodyTemplate = false,
    bool clearCheckInTitleTemplate = false,
    bool clearCheckInBodyTemplate = false,
    bool? checkInReminderEnabled,
    List<CustomReminderRule>? customRules,
    StrongReminderSettings? strong,
  }) {
    return ReminderSettings(
      leadMinutes: leadMinutes ?? this.leadMinutes,
      enabled: enabled ?? this.enabled,
      nextDaySummaryEnabled:
          nextDaySummaryEnabled ?? this.nextDaySummaryEnabled,
      nextDaySummaryHour: nextDaySummaryHour ?? this.nextDaySummaryHour,
      nextDaySummaryMinute: nextDaySummaryMinute ?? this.nextDaySummaryMinute,
      nextDayRemindWhenNoClass:
          nextDayRemindWhenNoClass ?? this.nextDayRemindWhenNoClass,
      nextDayWithClassTitleTemplate: clearNextDayWithClassTitleTemplate
          ? null
          : (nextDayWithClassTitleTemplate ??
                this.nextDayWithClassTitleTemplate),
      nextDayWithClassBodyTemplate: clearNextDayWithClassBodyTemplate
          ? null
          : (nextDayWithClassBodyTemplate ?? this.nextDayWithClassBodyTemplate),
      nextDayNoClassTitleTemplate: clearNextDayNoClassTitleTemplate
          ? null
          : (nextDayNoClassTitleTemplate ?? this.nextDayNoClassTitleTemplate),
      nextDayNoClassBodyTemplate: clearNextDayNoClassBodyTemplate
          ? null
          : (nextDayNoClassBodyTemplate ?? this.nextDayNoClassBodyTemplate),
      classLeadTitleTemplate: clearClassLeadTitleTemplate
          ? null
          : (classLeadTitleTemplate ?? this.classLeadTitleTemplate),
      classLeadBodyTemplate: clearClassLeadBodyTemplate
          ? null
          : (classLeadBodyTemplate ?? this.classLeadBodyTemplate),
      checkInTitleTemplate: clearCheckInTitleTemplate
          ? null
          : (checkInTitleTemplate ?? this.checkInTitleTemplate),
      checkInBodyTemplate: clearCheckInBodyTemplate
          ? null
          : (checkInBodyTemplate ?? this.checkInBodyTemplate),
      checkInReminderEnabled:
          checkInReminderEnabled ?? this.checkInReminderEnabled,
      customRules: customRules ?? this.customRules,
      strong: strong ?? this.strong,
    );
  }

  String get nextDaySummaryTimeLabel {
    return '${nextDaySummaryHour.toString().padLeft(2, '0')}:'
        '${nextDaySummaryMinute.toString().padLeft(2, '0')}';
  }
}
