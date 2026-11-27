part of 'grid_week_view.dart';

class _FitLargeText extends StatelessWidget {
  const _FitLargeText({required this.child, this.maxWidth = double.infinity});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(12) <= 12) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}

class _DateHeader extends ConsumerWidget {
  const _DateHeader({required this.layout});
  final ScheduleTimelineLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(currentTimeProvider);
    final l10n = AppLocalizations.of(context)!;
    final deadlines =
        ref.watch(schedulePresentationProvider)?.deadlines ??
        const <Deadline>[];
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final compact = layout.mode == ScheduleViewportMode.compactWeek;
    return Container(
      key: const Key('schedule-date-header'),
      height: 58,
      decoration: BoxDecoration(
        color: BackgroundPageScope.color(
          context,
          BackgroundRegionId.dates,
          colors.surface,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Row(
              children: [
                SizedBox(
                  key: const Key('schedule-corner'),
                  width: kScheduleTimeRailWidth,
                  height: double.infinity,
                  child: LaunchReveal(
                    startMs: 425,
                    child: Icon(
                      Icons.schedule,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                for (
                  var dayIndex = 0;
                  dayIndex < layout.days.length;
                  dayIndex++
                )
                  Expanded(
                    child: LaunchReveal(
                      startMs: 430 + dayIndex * 20,
                      child: Builder(
                        builder: (context) {
                          final day = layout.days[dayIndex];
                          final entries = deadlines
                              .where(
                                (d) => isSameScheduleDate(d.dueAt, day.date),
                              )
                              .toList();
                          final counted = entries
                              .where((d) => !d.completed || d.archived)
                              .toList();
                          final today = isSameScheduleDate(day.date, now);
                          final strong = counted.any(
                            (d) => d.hasStrongReminder,
                          );
                          return Container(
                            key: Key(
                              'schedule-day-${day.date.year}-${day.date.month}-${day.date.day}',
                            ),
                            decoration: BoxDecoration(
                              color: today
                                  ? colors.primaryContainer.withAlpha(90)
                                  : null,
                              border: Border(
                                left: BorderSide(color: colors.outlineVariant),
                              ),
                            ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                key: counted.isEmpty
                                    ? null
                                    : Key(
                                        'deadline-day-${day.date.year}-${day.date.month}-${day.date.day}',
                                      ),
                                onTap: counted.isEmpty
                                    ? null
                                    : () =>
                                          showDeadlinesForDay(context, entries),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 5,
                                  ),
                                  child: _FitLargeText(
                                    child: Column(
                                      mainAxisSize:
                                          MediaQuery.textScalerOf(
                                                context,
                                              ).scale(12) >
                                              12
                                          ? MainAxisSize.min
                                          : MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          compact
                                              ? weekdayLabel(
                                                  l10n,
                                                  day.date.weekday,
                                                )
                                              : '${weekdayLabel(l10n, day.date.weekday)} ${DateFormat.Md(locale).format(day.date)}',
                                          textAlign: TextAlign.center,
                                          maxLines: compact ? 1 : null,
                                          overflow: compact
                                              ? TextOverflow.clip
                                              : null,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontSize: compact ? 10 : null,
                                                height: compact ? 1.1 : null,
                                                fontWeight: FontWeight.w700,
                                                color: today
                                                    ? colors.primary
                                                    : colors.onSurface,
                                              ),
                                        ),
                                        if (compact)
                                          Text(
                                            DateFormat.Md(
                                              locale,
                                            ).format(day.date),
                                            maxLines: 1,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  fontSize: 8,
                                                  height: 1.1,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          )
                                        else
                                          Text(
                                            l10n.scheduleCourseCount(
                                              day.events.length,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                        AnimatedSwitcher(
                                          duration:
                                              MediaQuery.disableAnimationsOf(
                                                context,
                                              )
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 220,
                                                ),
                                          child: counted.isEmpty
                                              ? const SizedBox.shrink()
                                              : Text(
                                                  'DDL ${counted.length}',
                                                  key: ValueKey(
                                                    '${day.date}|${counted.length}|$strong',
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: colors.error,
                                                        fontSize: compact
                                                            ? 8
                                                            : null,
                                                        fontWeight: strong
                                                            ? FontWeight.w700
                                                            : FontWeight.w400,
                                                      ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 1,
            child: LaunchReveal(
              startMs: 425,
              child: ColoredBox(color: colors.outlineVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.layout,
    required this.dayWidth,
    required this.pixelsPerMinute,
    required this.topInset,
    required this.colorScheme,
  });
  final ScheduleTimelineLayout layout;
  final double dayWidth;
  final double pixelsPerMinute;
  final double topInset;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final labelHeight = MediaQuery.textScalerOf(context).scale(12) + 8;
    final tickStep =
        math.max(1, (labelHeight / (60 * pixelsPerMinute)).ceil()) * 60;
    final hours = [
      for (
        var minute = layout.startMinute;
        minute <= layout.endMinute;
        minute += 60
      )
        minute,
    ];
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: kScheduleTimeRailWidth,
          child: const BackgroundRegion(
            region: BackgroundRegionId.timeRail,
            child: SizedBox.expand(),
          ),
        ),
        Positioned(
          left: kScheduleTimeRailWidth,
          top: 0,
          right: 0,
          bottom: 0,
          child: const BackgroundRegion(
            region: BackgroundRegionId.content,
            child: SizedBox.expand(),
          ),
        ),
        for (var day = 0; day < layout.days.length; day++)
          Positioned(
            left: kScheduleTimeRailWidth + day * dayWidth,
            top: 0,
            bottom: 0,
            width: dayWidth,
            child: LaunchReveal(
              startMs: 440 + day * 20,
              durationMs: 260,
              grow: Axis.vertical,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
              ),
            ),
          ),
        for (final minute in hours) ...[
          if (minute == 480 ||
              minute == 1320 ||
              (minute % tickStep == 0 &&
                  (minute - 480).abs() * pixelsPerMinute >= labelHeight &&
                  (minute - 1320).abs() * pixelsPerMinute >= labelHeight))
            Positioned(
              key: Key('schedule-time-label-$minute'),
              left: 0,
              top:
                  topInset +
                  (minute - layout.startMinute) * pixelsPerMinute -
                  8,
              width: kScheduleTimeRailWidth - 6,
              child: LaunchReveal(
                startMs:
                    450 +
                    (minute - layout.startMinute) /
                        (layout.endMinute - layout.startMinute) *
                        140,
                child: Text(
                  _formatMinute(minute),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Positioned(
            left: kScheduleTimeRailWidth,
            right: 0,
            top: topInset + (minute - layout.startMinute) * pixelsPerMinute,
            child: LaunchReveal(
              startMs:
                  450 +
                  (minute - layout.startMinute) /
                      (layout.endMinute - layout.startMinute) *
                      140,
              durationMs: 260,
              grow: Axis.horizontal,
              child: Divider(
                height: 1,
                color: colorScheme.outlineVariant.withAlpha(150),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CurrentTimeLine extends ConsumerWidget {
  const _CurrentTimeLine({
    super.key,
    required this.layout,
    required this.dayWidth,
    required this.pixelsPerMinute,
    required this.topInset,
    this.entranceSpec,
    this.entranceOffset = Offset.zero,
    this.entrancePending = false,
  });
  final ScheduleTimelineLayout layout;
  final CardEntranceSpec? entranceSpec;
  final Offset entranceOffset;
  final bool entrancePending;
  final double dayWidth;
  final double pixelsPerMinute;
  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(currentTimeProvider);
    final index = layout.days.indexWhere(
      (day) => isSameScheduleDate(day.date, now),
    );
    final minute =
        now.hour * 60 + now.minute + now.second / 60 + now.millisecond / 60000;
    if (index < 0 || minute < layout.startMinute || minute > layout.endMinute) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final color = appThemeStyleOf(context) == AppThemeStyle.colorful
        ? (theme.brightness == Brightness.dark
              ? const Color(0xFFFF6B6B)
              : const Color(0xFFD32F2F))
        : theme.colorScheme.tertiary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final compact = layout.mode == ScheduleViewportMode.compactWeek;
    return AnimatedPositioned(
      key: const Key('schedule-current-time-line'),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      left: kScheduleTimeRailWidth + index * dayWidth,
      top: topInset + (minute - layout.startMinute) * pixelsPerMinute - 9,
      width: dayWidth,
      height: 18,
      child: IgnorePointer(
        child: LaunchCard(
          spec: entranceSpec,
          offset: entranceOffset.dy,
          travel: entranceOffset,
          pending: entrancePending,
          child: compact
              ? Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 2),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(child: Container(height: 2, color: color)),
                  ],
                )
              : Row(
                  children: [
                    _FitLargeText(
                      maxWidth: math.max(1.0, dayWidth - 16),
                      child: Container(
                        margin: const EdgeInsets.only(left: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(color: color.withAlpha(180)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatMinute(now.hour * 60 + now.minute),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

Color _gridCourseAccent(
  BuildContext context,
  WidgetRef ref,
  CourseSession session,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final overrides = ref.watch(courseColorOverridesProvider);
  final themeStyle = appThemeStyleOf(context);
  final multi = ref.watch(multicolorSettingsProvider);
  return resolvedCourseColor(
    palette: multi.enabled ? multi.palette : const [],
    session: session,
    automaticColorId: themeStyle == AppThemeStyle.colorful
        ? ref.watch(
            resolvedAutomaticCourseColorIdsProvider,
          )[automaticCourseColorKey(session)]
        : null,
    colorScheme: colorScheme,
    themeStyle: themeStyle,
    override: overrides[courseColorKey(session)],
  );
}

class _GridStrongBell extends ConsumerWidget {
  const _GridStrongBell({super.key, required this.session});
  final CourseSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) => StrongCourseBadge(
    session: session,
    compact: true,
    color: strongGridHighlight(_gridCourseAccent(context, ref, session)),
  );
}

String _formatMinute(int minute) {
  final value = minute.clamp(0, 24 * 60);
  return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}
