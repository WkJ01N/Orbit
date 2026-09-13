enum UpcomingDateDisplay { dateAndWeekday, dateOnly, weekdayOnly }

enum NarrowScheduleLayout { compactWeek, adaptive }

class ScheduleDisplaySettings {
  static const minVerticalScalePercent = 50;
  static const maxVerticalScalePercent = 150;
  static const verticalScaleStep = 5;

  const ScheduleDisplaySettings({
    this.narrowLayout = NarrowScheduleLayout.compactWeek,
    this.preferredMultiDayCount = 3,
    this.showEmptyDays = true,
    this.showUpcomingCourseDate = true,
    this.upcomingDateDisplay = UpcomingDateDisplay.dateAndWeekday,
    this.verticalScalePercent = 100,
    this.fitToPage = false,
  });

  final NarrowScheduleLayout narrowLayout;
  final int preferredMultiDayCount;
  final bool showEmptyDays;
  final bool showUpcomingCourseDate;
  final UpcomingDateDisplay upcomingDateDisplay;
  final int verticalScalePercent;
  final bool fitToPage;

  static int normalizeVerticalScalePercent(Object? value) {
    if (value is! num || !value.isFinite) return 100;
    final bounded = value.clamp(
      minVerticalScalePercent,
      maxVerticalScalePercent,
    );
    return (bounded / verticalScaleStep).round() * verticalScaleStep;
  }

  ScheduleDisplaySettings copyWith({
    NarrowScheduleLayout? narrowLayout,
    int? preferredMultiDayCount,
    bool? showEmptyDays,
    bool? showUpcomingCourseDate,
    UpcomingDateDisplay? upcomingDateDisplay,
    int? verticalScalePercent,
    bool? fitToPage,
  }) {
    return ScheduleDisplaySettings(
      fitToPage: fitToPage ?? this.fitToPage,
      narrowLayout: narrowLayout ?? this.narrowLayout,
      preferredMultiDayCount:
          preferredMultiDayCount ?? this.preferredMultiDayCount,
      showEmptyDays: showEmptyDays ?? this.showEmptyDays,
      showUpcomingCourseDate:
          showUpcomingCourseDate ?? this.showUpcomingCourseDate,
      upcomingDateDisplay: upcomingDateDisplay ?? this.upcomingDateDisplay,
      verticalScalePercent: normalizeVerticalScalePercent(
        verticalScalePercent ?? this.verticalScalePercent,
      ),
    );
  }
}
