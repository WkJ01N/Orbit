part of 'grid_week_view.dart';

class _ScheduleToolbar extends StatelessWidget {
  const _ScheduleToolbar({
    required this.anchor,
    required this.visibleDates,
    required this.transitionDirection,
    required this.reduceMotion,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onSelectWeek,
  });

  final DateTime anchor;
  final List<DateTime> visibleDates;
  final int transitionDirection;
  final bool reduceMotion;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectWeek;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final first = visibleDates.isEmpty ? anchor : visibleDates.first;
    final last = visibleDates.isEmpty ? anchor : visibleDates.last;
    final range = isSameScheduleDate(first, last)
        ? DateFormat.MMMd(locale).format(first)
        : '${DateFormat.MMMd(locale).format(first)} - ${DateFormat.MMMd(locale).format(last)}';
    final rangeKey = '${dateOnly(first)}|${dateOnly(last)}';
    return BackgroundRegion(
      region: BackgroundRegionId.week,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: BackgroundPageScope.color(
            context,
            BackgroundRegionId.week,
            theme.colorScheme.surface,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Row(
                children: [
                  LaunchReveal(
                    startMs: 400,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: l10n.gridPrevWeek,
                      onPressed: onPrevious,
                    ),
                  ),
                  Expanded(
                    child: LaunchReveal(
                      startMs: 420,
                      child: AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.center,
                              children: [...previousChildren, ?currentChild],
                            ),
                        transitionBuilder: (child, animation) {
                          final incoming = child.key == ValueKey(rangeKey);
                          final direction = transitionDirection == 0
                              ? 0.0
                              : transitionDirection.toDouble();
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(
                                  (incoming ? direction : -direction) * 0.08,
                                  0,
                                ),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Center(
                          key: ValueKey(rangeKey),
                          child: GridWeekPicker(
                            weekStart: weekStartFor(anchor),
                            onChanged: onSelectWeek,
                            labelOverride: range,
                          ),
                        ),
                      ),
                    ),
                  ),
                  LaunchReveal(
                    startMs: 440,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: l10n.gridNextWeek,
                      onPressed: onNext,
                    ),
                  ),
                  LaunchReveal(
                    startMs: 460,
                    child: IconButton(
                      icon: const Icon(Icons.today_outlined),
                      tooltip: l10n.gridThisWeek,
                      onPressed: onToday,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: -8,
              right: -8,
              bottom: 0,
              height: 1,
              child: LaunchReveal(
                startMs: 425,
                child: ColoredBox(color: theme.colorScheme.outlineVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
