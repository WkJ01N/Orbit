enum UpcomingDateDisplay { dateAndWeekday, dateOnly, weekdayOnly }

enum BackToTopPosition { left, center, right, smart }

enum StrongCardGradient { upperHalf, fullCard, topQuarter }

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
    this.backToTopPosition = BackToTopPosition.smart,
    this.verticalScalePercent = 100,
    this.fitToPage = false,
    this.hideUpcomingPage = false,
    this.hideImportPage = false,
    this.strongCardGradient = StrongCardGradient.upperHalf,
  });

  final NarrowScheduleLayout narrowLayout;
  final int preferredMultiDayCount;
  final bool showEmptyDays;
  final bool showUpcomingCourseDate;
  final UpcomingDateDisplay upcomingDateDisplay;
  final BackToTopPosition backToTopPosition;
  final int verticalScalePercent;
  final bool fitToPage;
  final bool hideUpcomingPage;
  final bool hideImportPage;
  final StrongCardGradient strongCardGradient;

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
    BackToTopPosition? backToTopPosition,
    int? verticalScalePercent,
    bool? fitToPage,
    bool? hideUpcomingPage,
    bool? hideImportPage,
    StrongCardGradient? strongCardGradient,
  }) {
    return ScheduleDisplaySettings(
      fitToPage: fitToPage ?? this.fitToPage,
      hideUpcomingPage: hideUpcomingPage ?? this.hideUpcomingPage,
      hideImportPage: hideImportPage ?? this.hideImportPage,
      strongCardGradient: strongCardGradient ?? this.strongCardGradient,
      narrowLayout: narrowLayout ?? this.narrowLayout,
      preferredMultiDayCount:
          preferredMultiDayCount ?? this.preferredMultiDayCount,
      showEmptyDays: showEmptyDays ?? this.showEmptyDays,
      showUpcomingCourseDate:
          showUpcomingCourseDate ?? this.showUpcomingCourseDate,
      upcomingDateDisplay: upcomingDateDisplay ?? this.upcomingDateDisplay,
      backToTopPosition: backToTopPosition ?? this.backToTopPosition,
      verticalScalePercent: normalizeVerticalScalePercent(
        verticalScalePercent ?? this.verticalScalePercent,
      ),
    );
  }
}
