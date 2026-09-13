import 'package:orbit/providers/course_color_providers.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';
import 'package:orbit/features/grid/grid_week_picker.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/session/session_action_menu.dart';
import 'package:orbit/features/session/session_countdown.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/grid_models.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/models/schedule_layout.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/course_color_utils.dart';
import 'package:orbit/services/schedule_layout_engine.dart';

class WeekGridView extends ConsumerStatefulWidget {
  const WeekGridView({super.key, required this.grid, this.sessions});

  final WeekGrid grid;
  final List<CourseSession>? sessions;

  @override
  ConsumerState<WeekGridView> createState() => WeekGridViewState();
}

class WeekGridViewState extends ConsumerState<WeekGridView> {
  final _scrollController = ScrollController();
  final _previousScrollController = ScrollController();
  final _nextScrollController = ScrollController();
  final _pagerController = AdjacentPagePagerController();
  final _focusNode = FocusNode();
  String? _lastAutoScrollKey;
  String? _selectedSessionId;
  int _rangeTransitionDirection = 1;

  List<CourseSession> get _sessions {
    if (widget.sessions != null) return widget.sessions!;
    final byId = <String, CourseSession>{};
    for (final cell in widget.grid.cells.values) {
      for (final session in cell) {
        byId[session.id] = session;
      }
    }
    return byId.values.toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _previousScrollController.dispose();
    _nextScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  DateTime _anchor(int weekStartDay) {
    final selected = ref.read(selectedScheduleDateProvider);
    if (selected != null) return dateOnly(selected);
    final now = DateTime.now();
    final currentWeek = weekStartFor(now, startWeekday: weekStartDay);
    final displayed = weekStartFor(
      widget.grid.weekStart,
      startWeekday: weekStartDay,
    );
    return currentWeek == displayed ? dateOnly(now) : displayed;
  }

  void _setAnchor(DateTime value, int weekStartDay) {
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : null;
    final normalized = dateOnly(value);
    ref.read(selectedScheduleDateProvider.notifier).state = normalized;
    ref.read(selectedWeekStartProvider.notifier).state = weekStartFor(
      normalized,
      startWeekday: weekStartDay,
    );
    if (scrollOffset != null &&
        !ref.read(scheduleDisplaySettingsProvider).fitToPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        _scrollController.jumpTo(
          scrollOffset.clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      });
    }
  }

  void _syncAdjacentScrollPositions(
    ScheduleTimelineLayout? previous,
    ScheduleTimelineLayout? next,
  ) {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final fit = ref.read(scheduleDisplaySettingsProvider).fitToPage;
    for (final pair in [
      (_previousScrollController, previous),
      (_nextScrollController, next),
    ]) {
      final controller = pair.$1;
      if (!controller.hasClients) continue;
      final position = controller.position;
      final layout = pair.$2;
      final target = fit && layout != null
          ? (480 - layout.startMinute) *
                ScheduleFitGeometry(position.viewportDimension).pixelsPerMinute
          : offset;
      controller.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(scheduleDisplaySettingsProvider);
    final now = ref.watch(currentTimeProvider);
    final density = ref.watch(gridDensityProvider);
    final weekStartDay = ref.watch(weekStartDayProvider);
    ref.watch(selectedScheduleDateProvider);
    final anchor = _anchor(weekStartDay);

    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = scheduleViewportModeForWidth(
          constraints.maxWidth,
          narrowLayout: settings.narrowLayout,
        );
        final visibleDates = visibleScheduleDates(
          anchor: anchor,
          mode: mode,
          preferredMultiDayCount: settings.preferredMultiDayCount,
          maxMultiDayCount: maxMultiDayCountForWidth(constraints.maxWidth),
          showEmptyDays: settings.showEmptyDays,
          sessions: _sessions,
          weekStartDay: weekStartDay,
        );
        final layout = const ScheduleLayoutEngine().build(
          dates: visibleDates,
          sessions: _sessions,
          mode: mode,
          fitToPage: settings.fitToPage,
        );

        _SchedulePageData pageData(DateTime pageAnchor) {
          final dates = visibleScheduleDates(
            anchor: pageAnchor,
            mode: mode,
            preferredMultiDayCount: settings.preferredMultiDayCount,
            maxMultiDayCount: maxMultiDayCountForWidth(constraints.maxWidth),
            showEmptyDays: settings.showEmptyDays,
            sessions: _sessions,
            weekStartDay: weekStartDay,
          );
          return _SchedulePageData(
            anchor: pageAnchor,
            visibleDates: dates,
            layout: const ScheduleLayoutEngine().build(
              dates: dates,
              sessions: _sessions,
              mode: mode,
              fitToPage: settings.fitToPage,
            ),
          );
        }

        final visibleDayCount = math.max(1, visibleDates.length);
        final previousAnchor = navigateScheduleAnchor(
          anchor: anchor,
          direction: -1,
          mode: mode,
          visibleDayCount: visibleDayCount,
          showEmptyDays: settings.showEmptyDays,
          sessions: _sessions,
          weekStartDay: weekStartDay,
        );
        final nextAnchor = navigateScheduleAnchor(
          anchor: anchor,
          direction: 1,
          mode: mode,
          visibleDayCount: visibleDayCount,
          showEmptyDays: settings.showEmptyDays,
          sessions: _sessions,
          weekStartDay: weekStartDay,
        );
        final canGoPrevious = !isSameScheduleDate(previousAnchor, anchor);
        final canGoNext = !isSameScheduleDate(nextAnchor, anchor);
        final previousPage = canGoPrevious ? pageData(previousAnchor) : null;
        final nextPage = canGoNext ? pageData(nextAnchor) : null;

        void commitNavigation(int direction) {
          final target = direction < 0 ? previousAnchor : nextAnchor;
          if (isSameScheduleDate(target, anchor)) return;
          setState(() => _rangeTransitionDirection = direction);
          _setAnchor(target, weekStartDay);
        }

        void selectAnchor(DateTime target) {
          _pagerController.cancelInteraction();
          final normalized = dateOnly(target);
          if (!isSameScheduleDate(normalized, anchor)) {
            setState(
              () => _rangeTransitionDirection = normalized.isAfter(anchor)
                  ? 1
                  : -1,
            );
          }
          _setAnchor(normalized, weekStartDay);
        }

        final currentPage = _SchedulePageData(
          anchor: anchor,
          visibleDates: visibleDates,
          layout: layout,
        );
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final currentSchedulePage = _SchedulePage(
          data: currentPage,
          density: density,
          scrollController: _scrollController,
          shouldAutoScroll:
              visibleDates.isNotEmpty &&
              _lastAutoScrollKey == null &&
              visibleDates.any((date) => isSameScheduleDate(date, now)),
          onAutoScrolled: visibleDates.isEmpty
              ? null
              : () => _lastAutoScrollKey = '${mode.name}|${visibleDates.first}',
          selectedSessionId: _selectedSessionId,
          onJump: () => selectAnchor(nearestCourseDate(anchor, _sessions)),
          onSelectSession: (session) {
            setState(() => _selectedSessionId = session.id);
            SessionDetailSheet.show(context, session);
          },
          onMenu: (session, position) => SessionActionMenu.show(
            context: context,
            ref: ref,
            session: session,
            position: position,
            onDeleted: () {
              if (_selectedSessionId == session.id) {
                setState(() => _selectedSessionId = null);
              }
            },
          ),
        );

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScheduleToolbar(
              anchor: anchor,
              visibleDates: visibleDates,
              transitionDirection: _rangeTransitionDirection,
              reduceMotion: reduceMotion,
              onPrevious: _pagerController.animateToPrevious,
              onNext: _pagerController.animateToNext,
              onToday: () => selectAnchor(DateTime.now()),
              onSelectWeek: selectAnchor,
            ),
            Expanded(
              child: AdjacentPagePager(
                pageKey:
                    '${mode.name}|${dateOnly(anchor)}|${visibleDates.length}',
                controller: _pagerController,
                reduceMotion: reduceMotion,
                onInteractionStart: () => _syncAdjacentScrollPositions(
                  previousPage?.layout,
                  nextPage?.layout,
                ),
                canSwipePrevious: () => canGoPrevious,
                canSwipeNext: () => canGoNext,
                onSwipeToPrevious: () => commitNavigation(-1),
                onSwipeToNext: () => commitNavigation(1),
                previousChild: previousPage == null
                    ? null
                    : _SchedulePage(
                        data: previousPage,
                        density: density,
                        scrollController: _previousScrollController,
                      ),
                nextChild: nextPage == null
                    ? null
                    : _SchedulePage(
                        data: nextPage,
                        density: density,
                        scrollController: _nextScrollController,
                      ),
                child: currentSchedulePage,
              ),
            ),
          ],
        );

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _pagerController.animateToPrevious();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _pagerController.animateToNext();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: content,
        );
      },
    );
  }
}

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
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.gridPrevWeek,
            onPressed: onPrevious,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
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
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.gridNextWeek,
            onPressed: onNext,
          ),
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: l10n.gridThisWeek,
            onPressed: onToday,
          ),
        ],
      ),
    );
  }
}

class _SchedulePageData {
  const _SchedulePageData({
    required this.anchor,
    required this.visibleDates,
    required this.layout,
  });

  final DateTime anchor;
  final List<DateTime> visibleDates;
  final ScheduleTimelineLayout layout;
}

class _SchedulePage extends StatelessWidget {
  const _SchedulePage({
    required this.data,
    required this.density,
    required this.scrollController,
    this.shouldAutoScroll = false,
    this.onAutoScrolled,
    this.selectedSessionId,
    this.onJump,
    this.onSelectSession,
    this.onMenu,
  });

  final _SchedulePageData data;
  final GridDensity density;
  final ScrollController scrollController;
  final bool shouldAutoScroll;
  final VoidCallback? onAutoScrolled;
  final String? selectedSessionId;
  final VoidCallback? onJump;
  final ValueChanged<CourseSession>? onSelectSession;
  final void Function(CourseSession, Offset?)? onMenu;

  @override
  Widget build(BuildContext context) {
    if (data.visibleDates.isEmpty ||
        data.layout.days.every((day) => day.events.isEmpty)) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: _NoVisibleCourses(onJump: onJump ?? () {}),
      );
    }
    return _ScheduleTimeline(
      layout: data.layout,
      density: density,
      scrollController: scrollController,
      shouldAutoScroll: shouldAutoScroll,
      onAutoScrolled: onAutoScrolled ?? () {},
      selectedSessionId: selectedSessionId,
      onSelectSession: onSelectSession ?? (_) {},
      onMenu: onMenu ?? (_, _) {},
    );
  }
}

class _NoVisibleCourses extends StatelessWidget {
  const _NoVisibleCourses({required this.onJump});

  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(l10n.gridNoSessionsThisWeek),
            const SizedBox(height: 6),
            Text(
              l10n.gridNoSessionsThisWeekSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onJump,
              icon: const Icon(Icons.near_me_outlined),
              label: Text(l10n.scheduleJumpToNearestCourse),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTimeline extends ConsumerStatefulWidget {
  const _ScheduleTimeline({
    required this.layout,
    required this.density,
    required this.scrollController,
    required this.shouldAutoScroll,
    required this.onAutoScrolled,
    required this.selectedSessionId,
    required this.onSelectSession,
    required this.onMenu,
  });

  final ScheduleTimelineLayout layout;
  final GridDensity density;
  final ScrollController scrollController;
  final bool shouldAutoScroll;
  final VoidCallback onAutoScrolled;
  final String? selectedSessionId;
  final ValueChanged<CourseSession> onSelectSession;
  final void Function(CourseSession, Offset?) onMenu;

  @override
  ConsumerState<_ScheduleTimeline> createState() => _ScheduleTimelineState();
}

class _ScheduleTimelineState extends ConsumerState<_ScheduleTimeline> {
  double? _lastPixelsPerMinute;
  bool? _lastFit;
  double? _lastInset;
  int? _lastStartMinute;
  String? _lastRangeKey;

  ScheduleTimelineLayout get layout => widget.layout;
  ScrollController get scrollController => widget.scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final now = ref.watch(currentTimeProvider);
    final settings = ref.watch(scheduleDisplaySettingsProvider);
    final scalePercent = ScheduleDisplaySettings.normalizeVerticalScalePercent(
      settings.verticalScalePercent,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth =
            (constraints.maxWidth - kScheduleTimeRailWidth) /
            layout.days.length;
        final fitGeometry = ScheduleFitGeometry(constraints.maxHeight - 58);
        final inset = settings.fitToPage
            ? fitGeometry.inset
            : kScheduleTimelineTopInset;
        final pixelsPerMinute = settings.fitToPage
            ? fitGeometry.pixelsPerMinute
            : _resolvePixelsPerMinute(
                context,
                layout,
                dayWidth,
                widget.density,
                scalePercent,
              );
        final timelineHeight =
            (layout.endMinute - layout.startMinute) * pixelsPerMinute;
        final bodyHeight = math.max(
          constraints.maxHeight - 58,
          timelineHeight + inset * 2,
        );
        _preserveScrollTime(pixelsPerMinute, inset, settings.fitToPage);
        if (!settings.fitToPage) {
          _scheduleInitialScroll(now, pixelsPerMinute, constraints.maxHeight);
        }
        return Column(
          children: [
            _DateHeader(layout: layout, now: now),
            Expanded(
              child: Scrollbar(
                controller: scrollController,
                child: SingleChildScrollView(
                  key: const Key('schedule-vertical-body'),
                  controller: scrollController,
                  child: SizedBox(
                    key: const Key('schedule-timeline-body'),
                    width: constraints.maxWidth,
                    height: bodyHeight,
                    child: ColoredBox(
                      color: colorScheme.surface,
                      child: Stack(
                        children: [
                          _TimeGrid(
                            layout: layout,
                            dayWidth: dayWidth,
                            pixelsPerMinute: pixelsPerMinute,
                            topInset: inset,
                            colorScheme: colorScheme,
                          ),
                          for (
                            var dayIndex = 0;
                            dayIndex < layout.days.length;
                            dayIndex++
                          )
                            for (final event in layout.days[dayIndex].events)
                              _eventWidget(
                                event,
                                dayIndex,
                                dayWidth,
                                pixelsPerMinute,
                                inset,
                                colorScheme,
                                l10n,
                              ),
                          if (settings.fitToPage)
                            for (
                              var dayIndex = 0;
                              dayIndex < layout.days.length;
                              dayIndex++
                            )
                              for (final event in layout.days[dayIndex].events)
                                if (event.durationMinutes * pixelsPerMinute <
                                    48)
                                  Positioned(
                                    left:
                                        kScheduleTimeRailWidth +
                                        dayIndex * dayWidth +
                                        event.lane * dayWidth / event.laneCount,
                                    top: math.max(
                                      0,
                                      inset +
                                          ((event.startMinute +
                                                          event.endMinute) /
                                                      2 -
                                                  layout.startMinute) *
                                              pixelsPerMinute -
                                          24,
                                    ),
                                    width: dayWidth / event.laneCount,
                                    height: 48,
                                    child: Semantics(
                                      button: true,
                                      label:
                                          '${event.session.courseName}, ${_time(event.session.startAt)}, ${event.session.room}',
                                      child: InkWell(
                                        onTap: () => _selectAtEvent(
                                          event,
                                          dayIndex,
                                          pixelsPerMinute,
                                        ),
                                      ),
                                    ),
                                  ),
                          _CurrentTimeLine(
                            key: ValueKey(
                              '${now.year}-${now.month}-${now.day}|$pixelsPerMinute',
                            ),
                            layout: layout,
                            now: now,
                            dayWidth: dayWidth,
                            pixelsPerMinute: pixelsPerMinute,
                            topInset: inset,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _preserveScrollTime(double pixelsPerMinute, double inset, bool fit) {
    final rangeKey =
        '${layout.mode.name}|${layout.days.first.date}|${layout.days.last.date}';
    final previous = _lastPixelsPerMinute;
    final reset = fit && (_lastFit != true || _lastRangeKey != rangeKey);
    double? target;
    if (reset) {
      target = (8 * 60 - layout.startMinute) * pixelsPerMinute;
    } else if (previous != null &&
        scrollController.hasClients &&
        _lastRangeKey == rangeKey &&
        (previous != pixelsPerMinute ||
            _lastInset != inset ||
            _lastStartMinute != layout.startMinute) &&
        !widget.shouldAutoScroll) {
      final minute =
          _lastStartMinute! +
          (scrollController.offset - _lastInset!) / previous;
      target = inset + (minute - layout.startMinute) * pixelsPerMinute;
    }
    _lastPixelsPerMinute = pixelsPerMinute;
    _lastInset = inset;
    _lastFit = fit;
    _lastStartMinute = layout.startMinute;
    _lastRangeKey = rangeKey;
    if (target != null) {
      final offset = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !scrollController.hasClients ||
            _lastRangeKey != rangeKey ||
            _lastPixelsPerMinute != pixelsPerMinute) {
          return;
        }
        final position = scrollController.position;
        scrollController.jumpTo(
          offset.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
        if (reset && widget.shouldAutoScroll) widget.onAutoScrolled();
      });
    }
  }

  void _scheduleInitialScroll(
    DateTime now,
    double pixelsPerMinute,
    double viewportHeight,
  ) {
    if (!widget.shouldAutoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      var targetMinute = layout.startMinute;
      if (layout.days.any((day) => isSameScheduleDate(day.date, now))) {
        targetMinute = now.hour * 60 + now.minute;
      } else {
        final events = layout.days.expand((day) => day.events);
        if (events.isNotEmpty) {
          targetMinute = events
              .map((event) => event.startMinute)
              .reduce(math.min);
        }
      }
      final target =
          (kScheduleTimelineTopInset +
                  (targetMinute - layout.startMinute) * pixelsPerMinute -
                  viewportHeight * 0.24)
              .clamp(0.0, scrollController.position.maxScrollExtent);
      scrollController.jumpTo(target);
      widget.onAutoScrolled();
    });
  }

  Future<void> _selectAtEvent(
    ScheduleEventLayout event,
    int dayIndex,
    double ppm,
  ) async {
    final center = (event.startMinute + event.endMinute) / 2;
    final candidates = layout.days[dayIndex].events.where((other) {
      final otherCenter = (other.startMinute + other.endMinute) / 2;
      final radius = math.max(24.0 / ppm, other.durationMinutes / 2);
      return (otherCenter - center).abs() <= radius &&
          (other.lane == event.lane || other.laneCount != event.laneCount);
    }).toList();
    if (event.durationMinutes * ppm >= 48 || candidates.length <= 1) {
      widget.onSelectSession(event.session);
      return;
    }
    final session = await showDialog<CourseSession>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(ctx)!.reminderSessions),
        children: [
          for (final candidate in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, candidate.session),
              child: Text(
                '${candidate.session.courseName} · ${_time(candidate.session.startAt)}',
              ),
            ),
        ],
      ),
    );
    if (session != null && mounted) widget.onSelectSession(session);
  }

  Widget _eventWidget(
    ScheduleEventLayout event,
    int dayIndex,
    double dayWidth,
    double pixelsPerMinute,
    double topInset,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    const gap = 2.0;
    final laneWidth = dayWidth / event.laneCount;
    return Positioned(
      left:
          kScheduleTimeRailWidth +
          dayIndex * dayWidth +
          event.lane * laneWidth +
          gap,
      top:
          topInset +
          (event.startMinute - layout.startMinute) * pixelsPerMinute +
          gap,
      width: math.max(1, laneWidth - gap * 2),
      height: math.max(1, event.durationMinutes * pixelsPerMinute - gap * 2),
      child: GridSessionChip(
        session: event.session,
        colorScheme: colorScheme,
        l10n: l10n,
        isSelected: widget.selectedSessionId == event.session.id,
        compact: layout.mode == ScheduleViewportMode.compactWeek,
        onTap: () => _selectAtEvent(event, dayIndex, pixelsPerMinute),
        onMenu: (position) => widget.onMenu(event.session, position),
      ),
    );
  }
}

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

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.layout, required this.now});
  final ScheduleTimelineLayout layout;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final compact = layout.mode == ScheduleViewportMode.compactWeek;
    return Container(
      key: const Key('schedule-date-header'),
      height: 58,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(
            key: const Key('schedule-corner'),
            width: kScheduleTimeRailWidth,
            height: double.infinity,
            child: Icon(
              Icons.schedule,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
          ),
          for (final day in layout.days)
            Expanded(
              child: Container(
                key: Key(
                  'schedule-day-${day.date.year}-${day.date.month}-${day.date.day}',
                ),
                decoration: BoxDecoration(
                  color: isSameScheduleDate(day.date, now)
                      ? colors.primaryContainer.withAlpha(90)
                      : null,
                  border: Border(
                    left: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                child: _FitLargeText(
                  child: Column(
                    mainAxisSize:
                        MediaQuery.textScalerOf(context).scale(12) > 12
                        ? MainAxisSize.min
                        : MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        compact
                            ? weekdayLabel(l10n, day.date.weekday)
                            : '${weekdayLabel(l10n, day.date.weekday)} ${DateFormat.Md(locale).format(day.date)}',
                        textAlign: TextAlign.center,
                        maxLines: compact ? 1 : null,
                        overflow: compact ? TextOverflow.clip : null,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontSize: compact ? 10 : null,
                              height: compact ? 1.1 : null,
                              fontWeight: FontWeight.w700,
                              color: isSameScheduleDate(day.date, now)
                                  ? colors.primary
                                  : colors.onSurface,
                            ),
                      ),
                      if (compact)
                        Text(
                          DateFormat.Md(locale).format(day.date),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 8,
                                height: 1.1,
                                color: colors.onSurfaceVariant,
                              ),
                        )
                      else
                        Text(
                          l10n.scheduleCourseCount(day.events.length),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
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
        for (var day = 0; day < layout.days.length; day++)
          Positioned(
            left: kScheduleTimeRailWidth + day * dayWidth,
            top: 0,
            bottom: 0,
            width: dayWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: colorScheme.outlineVariant),
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
              child: Text(
                _formatMinute(minute),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Positioned(
            left: kScheduleTimeRailWidth,
            right: 0,
            top: topInset + (minute - layout.startMinute) * pixelsPerMinute,
            child: Divider(
              height: 1,
              color: colorScheme.outlineVariant.withAlpha(150),
            ),
          ),
        ],
      ],
    );
  }
}

class _CurrentTimeLine extends StatelessWidget {
  const _CurrentTimeLine({
    super.key,
    required this.layout,
    required this.now,
    required this.dayWidth,
    required this.pixelsPerMinute,
    required this.topInset,
  });
  final ScheduleTimelineLayout layout;
  final DateTime now;
  final double dayWidth;
  final double pixelsPerMinute;
  final double topInset;

  @override
  Widget build(BuildContext context) {
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
    );
  }
}

class GridSessionChip extends ConsumerWidget {
  const GridSessionChip({
    super.key,
    required this.session,
    required this.colorScheme,
    required this.l10n,
    required this.isSelected,
    this.compact = false,
    required this.onTap,
    required this.onMenu,
  });
  final CourseSession session;
  final ColorScheme colorScheme;
  final AppLocalizations l10n;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;
  final void Function(Offset? position) onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(currentTimeProvider);
    final overrides = ref.watch(courseColorOverridesProvider);
    final themeStyle = appThemeStyleOf(context);
    final multi = ref.watch(multicolorSettingsProvider);
    final accent = resolvedCourseColor(
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
    final isPast = isSessionPast(now, session.endAt);
    final isOngoing = isSessionOngoing(now, session.startAt, session.endAt);
    final isSoon = isSessionStartingSoon(now, session.startAt) && !isPast;
    final time = '${_time(session.startAt)} - ${_time(session.endAt)}';
    final foreground = isPast
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface;
    return Semantics(
      button: true,
      label:
          '${session.courseName}, $time, ${session.room}, ${session.teachers.join('、')}',
      child: GestureDetector(
        onLongPress: () => onMenu(null),
        onSecondaryTapDown: (details) => onMenu(details.globalPosition),
        child: Material(
          color: courseCardSurface(
            accent: accent,
            colorScheme: colorScheme,
            themeStyle: themeStyle,
            highlighted: isOngoing || isSoon,
            isPast: isPast,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected || isOngoing
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected || isOngoing ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: compact ? 2 : 4,
                  color: isPast ? accent.withAlpha(100) : accent,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => compact
                        ? _CompactSessionChipContent(
                            session: session,
                            time: time,
                            foreground: foreground,
                            availableHeight: constraints.maxHeight,
                            availableWidth: constraints.maxWidth,
                          )
                        : _SessionChipContent(
                            session: session,
                            time: time,
                            foreground: foreground,
                            availableHeight: constraints.maxHeight,
                            availableWidth: constraints.maxWidth - 11,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double _resolvePixelsPerMinute(
  BuildContext context,
  ScheduleTimelineLayout layout,
  double dayWidth,
  GridDensity density,
  int verticalScalePercent,
) {
  var scale = switch (density) {
    GridDensity.compact => 0.8,
    GridDensity.standard => 1.0,
    GridDensity.comfortable => 1.2,
  };
  final compact = layout.mode == ScheduleViewportMode.compactWeek;
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  final theme = Theme.of(context);
  var readableMinimum = 0.0;
  for (final day in layout.days) {
    for (final event in day.events) {
      final laneWidth = dayWidth / event.laneCount;
      final contentWidth = laneWidth - 6;
      final width = compact
          ? math.max(1.0, contentWidth - 4)
          : math.max(20.0, laneWidth - 22);
      final nameHeight = _textHeight(
        event.session.courseName,
        compact
            ? _compactCourseNameStyle(null, contentWidth < 32)
            : theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
        width,
        scaler,
        direction,
        maxLines: compact ? 1 : null,
      );
      final required = (compact ? 6 : 10) + nameHeight + 4;
      readableMinimum = math.max(
        readableMinimum,
        required / event.durationMinutes,
      );
    }
  }
  // Classic layouts already expand their baseline for complete course names.
  // Compact layouts need enough space for at least one name line.
  if (!compact) scale = math.max(scale, readableMinimum);
  final timeLabelMinimum =
      (_textHeight(
            '00:00',
            theme.textTheme.labelSmall,
            kScheduleTimeRailWidth - 6,
            scaler,
            direction,
          ) +
          8) /
      60;
  return math.max(
    scale * verticalScalePercent / 100,
    math.max(readableMinimum, timeLabelMinimum),
  );
}

double _textHeight(
  String value,
  TextStyle? style,
  double width,
  TextScaler scaler,
  TextDirection direction, {
  int? maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: value.isEmpty ? ' ' : value, style: style),
    textScaler: scaler,
    textDirection: direction,
    maxLines: maxLines,
  )..layout(maxWidth: width);
  return painter.height;
}

String _formatMinute(int minute) {
  final value = minute.clamp(0, 24 * 60);
  return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

const kScheduleTimelineTopInset = 24.0;
const kScheduleTimelineBottomInset = 24.0;

TextStyle _compactCourseNameStyle(Color? color, bool narrow) => TextStyle(
  color: color,
  fontSize: narrow ? 8.5 : 9.5,
  fontWeight: FontWeight.w700,
  height: 1.12,
);

class _CompactSessionChipContent extends StatelessWidget {
  const _CompactSessionChipContent({
    required this.session,
    required this.time,
    required this.foreground,
    required this.availableHeight,
    required this.availableWidth,
  });

  final CourseSession session;
  final String time;
  final Color foreground;
  final double availableHeight;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final narrow = availableWidth < 32;
    final nameStyle = _compactCourseNameStyle(foreground, narrow);
    final detailStyle = TextStyle(
      color: foreground.withAlpha(210),
      fontSize: narrow ? 7.5 : 8,
      height: 1.08,
    );
    final width = math.max(1.0, availableWidth - 4);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle style, int lines) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: scaler,
        textDirection: Directionality.of(context),
        maxLines: lines,
      )..layout(maxWidth: width);
      return painter.height;
    }

    if (availableHeight < measure(session.courseName, nameStyle, 1) + 6) {
      return const SizedBox.shrink();
    }
    final roomStyle = detailStyle.copyWith(fontWeight: FontWeight.w600);
    final roomHeight = measure(session.room, roomStyle, 2);
    final nameHeight = measure(session.courseName, nameStyle, 1);
    var remaining = math.max(0.0, availableHeight - 6) - nameHeight;
    final showRoom = session.room.trim().isNotEmpty && remaining >= roomHeight;
    if (showRoom) remaining -= roomHeight;
    final timeHeight = measure(time, detailStyle, 2);
    final showTime = !narrow && remaining >= timeHeight;
    if (showTime) remaining -= timeHeight;
    final showTeacher =
        !narrow &&
        session.teachers.isNotEmpty &&
        remaining >= measure(session.teachers.join('、'), detailStyle, 1);
    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  session.courseName,
                  maxLines: 3,
                  overflow: TextOverflow.fade,
                  softWrap: true,
                  style: nameStyle,
                ),
              ),
            ),
            if (showTime)
              Text(
                time,
                maxLines: 2,
                overflow: TextOverflow.fade,
                style: detailStyle,
              ),
            if (showTeacher)
              Text(
                session.teachers.join('、'),
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: detailStyle,
              ),
            if (showRoom)
              Text(
                session.room,
                maxLines: 2,
                overflow: TextOverflow.fade,
                softWrap: true,
                style: roomStyle,
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionChipContent extends StatelessWidget {
  const _SessionChipContent({
    required this.session,
    required this.time,
    required this.foreground,
    required this.availableHeight,
    required this.availableWidth,
  });

  final CourseSession session;
  final String time;
  final Color foreground;
  final double availableHeight;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.labelMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    final detailStyle = theme.textTheme.labelSmall?.copyWith(
      color: foreground,
      height: 1.1,
    );
    final width = math.max(1.0, availableWidth);
    final nameHeight = _textHeight(
      session.courseName,
      nameStyle,
      width,
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final oneLineHeight = _textHeight(
      session.courseName,
      nameStyle,
      width,
      scaler,
      direction,
      maxLines: 1,
    );
    if (availableHeight < oneLineHeight + 10) return const SizedBox.shrink();
    final timeHeight = _textHeight(time, detailStyle, width, scaler, direction);
    final roomHeight = _textHeight(
      session.room,
      detailStyle,
      width,
      scaler,
      direction,
    );
    final teacherHeight = _textHeight(
      session.teachers.join('、'),
      detailStyle,
      width,
      scaler,
      direction,
    );
    var showTeacher = session.teachers.isNotEmpty;
    var showTime = true;
    var showRoom = session.room.trim().isNotEmpty;

    double requiredHeight() {
      var height = 10 + nameHeight;
      if (showTime) height += 3 + timeHeight;
      if (showRoom) height += 2 + roomHeight;
      if (showTeacher) height += 2 + teacherHeight;
      return height;
    }

    if (requiredHeight() > availableHeight) showTeacher = false;
    if (requiredHeight() > availableHeight) showTime = false;
    if (requiredHeight() > availableHeight) showRoom = false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            session.courseName,
            style: nameStyle,
            maxLines: nameHeight + 10 <= availableHeight
                ? null
                : math.max(1, ((availableHeight - 10) / oneLineHeight).floor()),
            overflow: nameHeight + 10 <= availableHeight
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
          ),
          if (showTime) ...[
            const SizedBox(height: 3),
            Text(time, style: detailStyle),
          ],
          if (showRoom) ...[
            const SizedBox(height: 2),
            Text(session.room, style: detailStyle),
          ],
          if (showTeacher) ...[
            const SizedBox(height: 2),
            Text(session.teachers.join('、'), style: detailStyle),
          ],
        ],
      ),
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class GridSwipePreviousIntent extends Intent {
  const GridSwipePreviousIntent();
}

class GridSwipeNextIntent extends Intent {
  const GridSwipeNextIntent();
}
