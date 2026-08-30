enum UpcomingDateDisplay { dateAndWeekday, dateOnly, weekdayOnly }

class ScheduleDisplaySettings {
  const ScheduleDisplaySettings({
    this.preferredMultiDayCount = 3,
    this.showEmptyDays = true,
    this.showUpcomingCourseDate = true,
    this.upcomingDateDisplay = UpcomingDateDisplay.dateAndWeekday,
  });

  final int preferredMultiDayCount;
  final bool showEmptyDays;
  final bool showUpcomingCourseDate;
  final UpcomingDateDisplay upcomingDateDisplay;

  ScheduleDisplaySettings copyWith({
    int? preferredMultiDayCount,
    bool? showEmptyDays,
    bool? showUpcomingCourseDate,
    UpcomingDateDisplay? upcomingDateDisplay,
  }) {
    return ScheduleDisplaySettings(
      preferredMultiDayCount:
          preferredMultiDayCount ?? this.preferredMultiDayCount,
      showEmptyDays: showEmptyDays ?? this.showEmptyDays,
      showUpcomingCourseDate:
          showUpcomingCourseDate ?? this.showUpcomingCourseDate,
      upcomingDateDisplay: upcomingDateDisplay ?? this.upcomingDateDisplay,
    );
  }
}
