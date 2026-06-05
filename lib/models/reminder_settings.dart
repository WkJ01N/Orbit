class ReminderSettings {
  const ReminderSettings({
    this.leadMinutes = 15,
    this.enabled = true,
    this.nextDaySummaryEnabled = true,
    this.nextDaySummaryHour = 23,
    this.nextDaySummaryMinute = 0,
    this.systemAlarmEnabled = false,
    this.systemAlarmLeadMinutes = 10,
    this.checkInReminderEnabled = true,
  });

  final int leadMinutes;
  final bool enabled;
  final bool nextDaySummaryEnabled;
  final int nextDaySummaryHour;
  final int nextDaySummaryMinute;
  final bool systemAlarmEnabled;
  final int systemAlarmLeadMinutes;
  final bool checkInReminderEnabled;

  static const List<int> leadMinuteOptions = [
    5, 10, 15, 30, 45, 60, 90, 120,
  ];

  static const List<int> alarmLeadMinuteOptions = [5, 10, 15, 20, 30, 45, 60];

  ReminderSettings copyWith({
    int? leadMinutes,
    bool? enabled,
    bool? nextDaySummaryEnabled,
    int? nextDaySummaryHour,
    int? nextDaySummaryMinute,
    bool? systemAlarmEnabled,
    int? systemAlarmLeadMinutes,
    bool? checkInReminderEnabled,
  }) {
    return ReminderSettings(
      leadMinutes: leadMinutes ?? this.leadMinutes,
      enabled: enabled ?? this.enabled,
      nextDaySummaryEnabled:
          nextDaySummaryEnabled ?? this.nextDaySummaryEnabled,
      nextDaySummaryHour: nextDaySummaryHour ?? this.nextDaySummaryHour,
      nextDaySummaryMinute:
          nextDaySummaryMinute ?? this.nextDaySummaryMinute,
      systemAlarmEnabled: systemAlarmEnabled ?? this.systemAlarmEnabled,
      systemAlarmLeadMinutes:
          systemAlarmLeadMinutes ?? this.systemAlarmLeadMinutes,
      checkInReminderEnabled:
          checkInReminderEnabled ?? this.checkInReminderEnabled,
    );
  }

  String get nextDaySummaryTimeLabel {
    return '${nextDaySummaryHour.toString().padLeft(2, '0')}:'
        '${nextDaySummaryMinute.toString().padLeft(2, '0')}';
  }
}
