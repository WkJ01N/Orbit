import 'package:orbit/features/grid/grid_event_motion.dart';
import 'package:orbit/features/grid/text_height_cache.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/features/session/course_quick_action_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/features/grid/strong_grid_decoration.dart';
import 'package:orbit/models/wake_text.dart';
import 'package:orbit/features/grid/grid_selection.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/models/grid_action_text.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/providers/course_color_providers.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';
import 'package:orbit/features/grid/grid_week_picker.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/deadline/deadline_ui.dart';
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
import 'package:orbit/core/motion/launch_motion.dart';
import 'package:orbit/providers/launch_providers.dart';

part 'grid_toolbar.dart';
part 'grid_time_layers.dart';
part 'grid_session_chip.dart';

class _DeadlineDates {
  const _DeadlineDates(this.values);
  final List<DateTime> values;
  @override
  bool operator ==(Object other) =>
      other is _DeadlineDates && listEquals(values, other.values);
  @override
  int get hashCode => Object.hashAll(values);
}

class WeekGridView extends ConsumerStatefulWidget {
  const WeekGridView({super.key, required this.grid, this.sessions});

  final WeekGrid grid;
  final List<CourseSession>? sessions;

  @override
  ConsumerState<WeekGridView> createState() => WeekGridViewState();
}

class WeekGridViewState extends ConsumerState<WeekGridView>
    with TickerProviderStateMixin {
  LaunchMotion? _dateMotion, _dateParentMotion;
  final _scrollController = ScrollController();
  final _previousScrollController = ScrollController();
  final _nextScrollController = ScrollController();
  final _pagerController = AdjacentPagePagerController();
  final _focusNode = FocusNode();
  String? _lastAutoScrollKey;
  String? _selectedSessionId;
  DateTime? _defaultAnchor;
  int _rangeTransitionDirection = 1;
  Object? _sessionSource;
  Object? _lastViewportIdentity;
  List<CourseSession> _visibleSessions = const [];
  Object? _layoutConfiguration;
  final Map<DateTime, _SchedulePageData> _pageLayouts = {};

  final Map<DateTime, List<CourseSession>> _sessionsByDate = {};
  List<DateTime> _courseDates = const [];
  List<CourseSession> get _sessions {
    final source = widget.sessions ?? widget.grid;
    if (identical(source, _sessionSource)) return _visibleSessions;
    _sessionSource = source;
    if (widget.sessions != null) {
      _visibleSessions = widget.sessions!.where((s) => s.visible).toList();
    } else {
      final byId = <String, CourseSession>{};
      for (final cell in widget.grid.cells.values) {
        for (final session in cell) {
          byId[session.id] = session;
        }
      }
      _visibleSessions = byId.values.where((s) => s.visible).toList();
    }
    _sessionsByDate.clear();
    final normalized = <(int, bool), DateTime>{};
    for (final session in _visibleSessions) {
      final date = session.date;
      final day = normalized.putIfAbsent((
        date.millisecondsSinceEpoch,
        date.isUtc,
      ), () => dateOnly(date));
      _sessionsByDate.putIfAbsent(day, () => []).add(session);
    }
    _courseDates = _sessionsByDate.keys.toList()..sort();
    return _visibleSessions;
  }

  @override
  void dispose() {
    _dateMotion?.dispose();
    _scrollController.dispose();
    _previousScrollController.dispose();
    _nextScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  DateTime _anchor(int weekStartDay) {
    final selected = ref.read(selectedScheduleDateProvider);
    if (selected != null) return dateOnly(selected);
    if (_defaultAnchor != null) return _defaultAnchor!;
    final now = DateTime.now();
    final currentWeek = weekStartFor(now, startWeekday: weekStartDay);
    final displayed = weekStartFor(
      widget.grid.weekStart,
      startWeekday: weekStartDay,
    );
    return _defaultAnchor = currentWeek == displayed
        ? dateOnly(now)
        : displayed;
  }

  /// Arrow-key order: the courses on the visible page, top to bottom. An
  /// empty page falls back to the whole timetable so the keys still move.
  List<CourseSession> _keyboardOrder(
    List<CourseSession> sessions,
    List<DateTime> visibleDates,
  ) {
    int byStart(CourseSession a, CourseSession b) {
      final byTime = a.startAt.compareTo(b.startAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    }

    final days = visibleDates.map(dateOnly).toSet();
    final visible =
        sessions
            .where((session) => days.contains(dateOnly(session.startAt)))
            .toList()
          ..sort(byStart);
    if (visible.isNotEmpty) return visible;
    return sessions.toList()..sort(byStart);
  }

  void _clearSelection() {
    if (mounted && _selectedSessionId != null) {
      setState(() => _selectedSessionId = null);
    }
  }

  Future<void> _openSession(CourseSession session) async {
    if (ref.read(gridSelectionProvider).active) {
      ref.read(gridSelectionProvider.notifier).toggle(session.id);
      return;
    }
    setState(() => _selectedSessionId = session.id);
    try {
      await SessionDetailSheet.show(context, session);
    } finally {
      if (mounted && _selectedSessionId == session.id) _clearSelection();
    }
  }

  void _setAnchor(DateTime value, int weekStartDay) {
    _clearSelection();
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

  void _cancelGridEntrance() {
    _dateMotion?.finish();
    LaunchMotionScope.maybeOf(context)?.finish();
    ModuleEntranceScope.maybeOf(context)?.finish();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedScheduleDateProvider, (previous, next) {
      if (previous != next) _cancelGridEntrance();
    });
    ref.listen(gridDefaultWeekModeProvider, (_, _) {
      _defaultAnchor = null;
      _cancelGridEntrance();
    });
    ref.listen(selectedWeekStartProvider, (_, next) {
      if (next != null && ref.read(selectedScheduleDateProvider) == null) {
        _defaultAnchor = dateOnly(next);
        _cancelGridEntrance();
      }
    });
    ref.listen(appNavIndexProvider, (_, next) {
      if (next != AppTab.grid.index) _clearSelection();
    });
    final selection = ref.watch(gridSelectionProvider);
    final dateSet = ref.watch(
      schedulePresentationProvider.select(
        (value) => _DeadlineDates(
          (value?.deadlines ?? [])
              .where((d) => !d.completed || d.archived)
              .map((d) => d.dueAt)
              .toList(),
        ),
      ),
    );
    final deadlineDates = dateSet.values;
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
        final previousSource = _sessionSource;
        final sessions = _sessions;
        final sourceChanged =
            previousSource != null &&
            !identical(previousSource, _sessionSource);
        final configuration = (
          mode,
          settings,
          weekStartDay,
          constraints.maxWidth,
          _sessionSource,
          dateSet,
        );
        if (_layoutConfiguration != configuration) {
          _pageLayouts.clear();
          _layoutConfiguration = configuration;
        }
        _SchedulePageData pageData(DateTime pageAnchor) {
          final cached = _pageLayouts[pageAnchor];
          if (cached != null) return cached;
          final dates = visibleScheduleDates(
            anchor: pageAnchor,
            mode: mode,
            preferredMultiDayCount: settings.preferredMultiDayCount,
            maxMultiDayCount: maxMultiDayCountForWidth(constraints.maxWidth),
            showEmptyDays: settings.showEmptyDays,
            sessions: sessions,
            availableCourseDates: _courseDates,
            eventDates: deadlineDates,
            weekStartDay: weekStartDay,
          );
          final result = _SchedulePageData(
            anchor: pageAnchor,
            visibleDates: dates,
            layout: const ScheduleLayoutEngine().build(
              dates: dates,
              sessions: [for (final date in dates) ...?_sessionsByDate[date]],
              mode: mode,
              fitToPage: settings.fitToPage,
            ),
          );
          if (_pageLayouts.length >= 7) {
            _pageLayouts.remove(_pageLayouts.keys.first);
          }
          _pageLayouts[pageAnchor] = result;
          return result;
        }

        final current = pageData(anchor);
        final visibleDates = current.visibleDates;
        final viewportIdentity = Object.hashAll(visibleDates);
        final animateAddition =
            sourceChanged && _lastViewportIdentity == viewportIdentity;
        _lastViewportIdentity = viewportIdentity;
        final layout = current.layout;

        final visibleDayCount = math.max(1, visibleDates.length);
        final previousAnchor = navigateScheduleAnchor(
          anchor: anchor,
          direction: -1,
          mode: mode,
          visibleDayCount: visibleDayCount,
          showEmptyDays: settings.showEmptyDays,
          sessions: sessions,
          availableCourseDates: _courseDates,
          eventDates: deadlineDates,
          weekStartDay: weekStartDay,
        );
        final nextAnchor = navigateScheduleAnchor(
          anchor: anchor,
          direction: 1,
          mode: mode,
          visibleDayCount: visibleDayCount,
          showEmptyDays: settings.showEmptyDays,
          sessions: sessions,
          availableCourseDates: _courseDates,
          eventDates: deadlineDates,
          weekStartDay: weekStartDay,
        );
        final canGoPrevious = !isSameScheduleDate(previousAnchor, anchor);
        final canGoNext = !isSameScheduleDate(nextAnchor, anchor);
        final previousPage = canGoPrevious ? pageData(previousAnchor) : null;
        final nextPage = canGoNext ? pageData(nextAnchor) : null;

        void commitNavigation(int direction) {
          final target = direction < 0 ? previousAnchor : nextAnchor;
          if (isSameScheduleDate(target, anchor)) return;
          _cancelGridEntrance();
          setState(() => _rangeTransitionDirection = direction);
          _setAnchor(target, weekStartDay);
        }

        void selectAnchor(DateTime target, {bool animateCards = true}) {
          _cancelGridEntrance();
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
          if (animateCards &&
              !listEquals(visibleDates, pageData(normalized).visibleDates) &&
              ref.read(launchSettingsProvider).pageEnabled[0] &&
              !ref.read(pageTransitionSuppressedProvider) &&
              !MediaQuery.disableAnimationsOf(context)) {
            final previous = _dateMotion;
            _dateParentMotion = LaunchMotionScope.maybeOf(context);
            _dateMotion = LaunchMotion(
              vsync: this,
              settings: ref.read(launchSettingsProvider),
              cardsOnly: true,
            );
            _dateMotion!.timeline.value = 1;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => previous?.dispose(),
            );
          }
        }

        final currentPage = _SchedulePageData(
          anchor: anchor,
          visibleDates: visibleDates,
          layout: layout,
        );
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final currentSchedulePage = _SchedulePage(
          animateEntrance: true,
          animateAddition: animateAddition,
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
          onJump: () => selectAnchor(
            nearestCourseDate(
              anchor,
              sessions,
              availableCourseDates: _courseDates,
            ),
            animateCards: false,
          ),
          onSelectSession: _openSession,
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

        final parentMotion = LaunchMotionScope.maybeOf(context);
        final pageMotion =
            _dateMotion != null && identical(_dateParentMotion, parentMotion)
            ? _dateMotion
            : parentMotion;
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
              onSelectWeek: (date) => selectAnchor(date),
            ),
            Expanded(
              child: CourseQuickActionViewport(
                child: AdjacentPagePager(
                  pageKey:
                      '${mode.name}|${dateOnly(anchor)}|${visibleDates.length}',
                  controller: _pagerController,
                  reduceMotion: reduceMotion,
                  onInteractionStart: () {
                    _cancelGridEntrance();
                    _clearSelection();
                    _syncAdjacentScrollPositions(
                      previousPage?.layout,
                      nextPage?.layout,
                    );
                  },
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
                          onSelectSession: selection.active
                              ? _openSession
                              : null,
                        ),
                  nextChild: nextPage == null
                      ? null
                      : _SchedulePage(
                          data: nextPage,
                          density: density,
                          scrollController: _nextScrollController,
                          onSelectSession: selection.active
                              ? _openSession
                              : null,
                        ),
                  child: pageMotion != null
                      ? LaunchMotionScope(
                          motion: pageMotion,
                          child: currentSchedulePage,
                        )
                      : currentSchedulePage,
                ),
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
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowLeft) {
              _pagerController.animateToPrevious();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowRight) {
              _pagerController.animateToNext();
              return KeyEventResult.handled;
            }
            // Arrows walk the courses of the visible page so the grid can be
            // browsed without a mouse; the highlighted card is the one Enter
            // opens.
            if (key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.arrowUp) {
              final order = _keyboardOrder(sessions, visibleDates);
              if (order.isEmpty) return KeyEventResult.ignored;
              final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
              final current = order.indexWhere(
                (session) => session.id == _selectedSessionId,
              );
              final next = current < 0
                  ? (step > 0 ? 0 : order.length - 1)
                  : (current + step + order.length) % order.length;
              setState(() => _selectedSessionId = order[next].id);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter) {
              final id = _selectedSessionId;
              if (id == null) return KeyEventResult.ignored;
              final match = sessions.where((session) => session.id == id);
              if (match.isEmpty) return KeyEventResult.ignored;
              _openSession(match.first);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.escape) {
              if (_selectedSessionId == null) return KeyEventResult.ignored;
              _clearSelection();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _clearSelection,
            child: content,
          ),
        );
      },
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

class _SchedulePage extends ConsumerWidget {
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
    this.animateEntrance = false,
    this.animateAddition = false,
  });

  final _SchedulePageData data;
  final bool animateEntrance, animateAddition;
  final GridDensity density;
  final ScrollController scrollController;
  final bool shouldAutoScroll;
  final VoidCallback? onAutoScrolled;
  final String? selectedSessionId;
  final VoidCallback? onJump;
  final ValueChanged<CourseSession>? onSelectSession;
  final void Function(CourseSession, Offset?)? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LaunchEntranceRegion(
    enabled: animateEntrance,
    child: _buildContent(context, ref),
  );

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final hasDeadlines =
        (ref.watch(schedulePresentationProvider)?.deadlines ?? []).any(
          (d) =>
              (!d.completed || d.archived) &&
              data.visibleDates.contains(dateOnly(d.dueAt)),
        );
    if (data.visibleDates.isEmpty ||
        data.layout.days.every((day) => day.events.isEmpty) && !hasDeadlines) {
      if (animateEntrance) {
        final motion = LaunchMotionScope.maybeOf(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) motion?.skipGridEntrance();
        });
      }
      return AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        child: BackgroundRegion(
          region: BackgroundRegionId.content,
          child: ColoredBox(
            color: BackgroundPageScope.color(
              context,
              BackgroundRegionId.content,
              Theme.of(context).colorScheme.surface,
            ),
            child: _NoVisibleCourses(onJump: onJump ?? () {}),
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      child: _ScheduleTimeline(
        animateEntrance: animateEntrance,
        animateAddition: animateAddition,
        layout: data.layout,
        density: density,
        scrollController: scrollController,
        shouldAutoScroll: shouldAutoScroll,
        onAutoScrolled: onAutoScrolled ?? () {},
        selectedSessionId: selectedSessionId,
        onSelectSession: onSelectSession ?? (_) {},
        onMenu: onMenu ?? (_, _) {},
      ),
    );
  }
}

class _NoVisibleCourses extends StatelessWidget {
  const _NoVisibleCourses({required this.onJump});

  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PageModule(
      enabled:
          LaunchEntranceRegion.enabledOf(context) &&
          LaunchMotionScope.maybeOf(context)?.startup == false,
      child: Center(
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
    this.animateEntrance = false,
    this.animateAddition = false,
  });

  final ScheduleTimelineLayout layout;
  final bool animateEntrance, animateAddition;
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
  LaunchMotion? _launch;
  bool _entrancePrepared = false;
  bool _entranceQueued = false;
  Map<String, CardEntranceSpec> _entrances = const {};
  Map<String, Offset> _entranceOffsets = const {};

  bool get _pendingEntrance =>
      widget.animateEntrance &&
      !_entrancePrepared &&
      (_launch?.canClaimGrid ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = LaunchMotionScope.maybeOf(context);
    if (!identical(next, _launch)) {
      _entrancePrepared = false;
      _entranceQueued = false;
      _entrances = const {};
      _entranceOffsets = const {};
    }
    _launch = next;
  }

  Widget _entrance(String id, Widget child) => LaunchCard(
    spec: _entrances[id],
    offset: _entranceOffsets[id]?.dy ?? 0,
    travel: _entranceOffsets[id] ?? Offset.zero,
    pending: _pendingEntrance,
    child: child,
  );

  void _prepareEntrance(
    List<({ScheduleEventLayout event, int dayIndex, Rect rect})> placements,
    double viewportHeight,
    double width,
    double dayWidth,
    double ppm,
    double inset,
    DateTime now,
  ) {
    if (!_pendingEntrance || _entranceQueued) return;
    _entranceQueued = true;
    final plannedMotion = _launch;
    // Registered after the existing scroll-position callbacks in this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_launch, plannedMotion)) return;
      _entranceQueued = false;
      if (!mounted || !_pendingEntrance || !scrollController.hasClients) return;
      final top = scrollController.offset;
      final viewport = Rect.fromLTWH(
        kScheduleTimeRailWidth,
        top,
        width - kScheduleTimeRailWidth,
        viewportHeight,
      );
      final columns = <int, List<String>>{};
      final rects = <String, Rect>{};
      for (final placement in placements) {
        if (!placement.rect.overlaps(viewport)) continue;
        final id = placement.event.session.id;
        columns.putIfAbsent(placement.dayIndex, () => []).add(id);
        rects[id] = placement.rect;
      }
      final day = layout.days.indexWhere(
        (d) => isSameScheduleDate(d.date, now),
      );
      final minute = now.hour * 60 + now.minute + now.second / 60;
      if (day >= 0 &&
          minute >= layout.startMinute &&
          minute <= layout.endMinute) {
        final rect = Rect.fromLTWH(
          kScheduleTimeRailWidth + day * dayWidth,
          inset + (minute - layout.startMinute) * ppm - 9,
          dayWidth,
          18,
        );
        if (rect.overlaps(viewport)) {
          columns.putIfAbsent(day, () => []).add('@current-time');
          rects['@current-time'] = rect;
        }
      }
      final motion = _launch!;
      if (!motion.startGrid(this)) return;
      setState(() {
        _entrancePrepared = true;
        final visualOrder = rects.keys.toList()
          ..sort((a, b) {
            final y = rects[a]!.top.compareTo(rects[b]!.top);
            return y == 0 ? rects[a]!.left.compareTo(rects[b]!.left) : y;
          });
        _entrances = planCardEntrances(
          columns,
          random: motion.random,
          visualOrder: visualOrder,
        );
        _entranceOffsets = {
          for (final entry in _entrances.entries)
            entry.key: motion.startup
                ? Offset(
                    0,
                    cardEntranceOffset(
                      rect: rects[entry.key]!,
                      viewport: viewport,
                      spec: entry.value,
                      mode: motion.settings.cardEntrance,
                    ),
                  )
                : Offset(
                    motion.direction *
                        (motion.settings.cardEntrance == CardEntranceMode.nearby
                            ? 48
                            : motion.direction > 0
                            ? viewport.right - rects[entry.key]!.left + 8
                            : rects[entry.key]!.right - viewport.left + 8),
                    0,
                  ),
        };
      });
    });
  }

  double? _lastPixelsPerMinute;
  bool? _lastFit;
  double? _lastInset;
  int? _lastStartMinute;
  String? _lastRangeKey;
  bool _initialScrollDone = false, _initialScrollQueued = false;

  ScheduleTimelineLayout get layout => widget.layout;
  ScrollController get scrollController => widget.scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    // The clock only drives the now affordances (_DateHeader and
    // _CurrentTimeLine watch it themselves), so reading it here keeps the
    // whole timetable from rebuilding every minute.
    final now = ref.read(currentTimeProvider);
    final settings = ref.watch(scheduleDisplaySettingsProvider);
    final strongIds =
        ref.watch(strongCourseIdsProvider).valueOrNull ?? <String>{};
    const headerHeight = 58.0;
    final scalePercent = ScheduleDisplaySettings.normalizeVerticalScalePercent(
      settings.verticalScalePercent,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth =
            (constraints.maxWidth - kScheduleTimeRailWidth) /
            layout.days.length;
        final fitGeometry = ScheduleFitGeometry(
          constraints.maxHeight - headerHeight,
        );
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
          constraints.maxHeight - headerHeight,
          timelineHeight + inset * 2,
        );
        final placements = [
          for (var dayIndex = 0; dayIndex < layout.days.length; dayIndex++)
            for (final event in layout.days[dayIndex].events)
              (
                event: event,
                dayIndex: dayIndex,
                rect: scheduleCardRect(
                  event: event,
                  dayIndex: dayIndex,
                  dayWidth: dayWidth,
                  startMinute: layout.startMinute,
                  pixelsPerMinute: pixelsPerMinute,
                  topInset: inset,
                ),
              ),
        ];
        final strongIndices = {
          for (var i = 0; i < placements.length; i++)
            if (strongIds.contains(placements[i].event.session.id)) i,
        };
        _preserveScrollTime(pixelsPerMinute, inset, settings.fitToPage);
        if (!settings.fitToPage) {
          _scheduleInitialScroll(now, pixelsPerMinute, constraints.maxHeight);
        }
        _prepareEntrance(
          placements,
          constraints.maxHeight - headerHeight,
          constraints.maxWidth,
          dayWidth,
          pixelsPerMinute,
          inset,
          now,
        );
        return Column(
          children: [
            BackgroundRegion(
              region: BackgroundRegionId.dates,
              child: _DateHeader(layout: layout),
            ),
            Expanded(
              child: ClipRect(
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
                        color:
                            BackgroundPageScope.enabled(
                                  context,
                                  BackgroundRegionId.content,
                                ) ||
                                BackgroundPageScope.enabled(
                                  context,
                                  BackgroundRegionId.timeRail,
                                )
                            ? Colors.transparent
                            : colorScheme.surface,
                        child: Stack(
                          children: [
                            _TimeGrid(
                              layout: layout,
                              dayWidth: dayWidth,
                              pixelsPerMinute: pixelsPerMinute,
                              topInset: inset,
                              colorScheme: colorScheme,
                            ),
                            Positioned.fill(
                              child: GridEventMotion(
                                viewportIdentity: Object.hashAll(
                                  layout.days.map((day) => day.date),
                                ),
                                animateInitial:
                                    widget.animateEntrance &&
                                    widget.animateAddition,
                                viewport: Rect.fromLTWH(
                                  kScheduleTimeRailWidth,
                                  scrollController.hasClients
                                      ? scrollController.offset
                                      : 0,
                                  constraints.maxWidth - kScheduleTimeRailWidth,
                                  constraints.maxHeight - headerHeight,
                                ),
                                mode: ref
                                    .watch(launchSettingsProvider)
                                    .cardEntrance,
                                identityChanges: ref.watch(
                                  scheduleIdentityChangesProvider,
                                ),
                                events: [
                                  for (final placement in placements)
                                    GridMotionEvent(
                                      id: placement.event.session.id,
                                      signature: _motionSignature(
                                        placement.event.session,
                                      ),
                                      rect: placement.rect,
                                      child: _eventWidget(
                                        placement.event,
                                        placement.dayIndex,
                                        placement.rect,
                                        pixelsPerMinute,
                                        colorScheme,
                                        l10n,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (settings.fitToPage)
                              for (
                                var dayIndex = 0;
                                dayIndex < layout.days.length;
                                dayIndex++
                              )
                                for (final event
                                    in layout.days[dayIndex].events)
                                  if (event.durationMinutes * pixelsPerMinute <
                                      48)
                                    Positioned(
                                      left:
                                          kScheduleTimeRailWidth +
                                          dayIndex * dayWidth +
                                          event.lane *
                                              dayWidth /
                                              event.laneCount,
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
                                      child: _entrance(
                                        event.session.id,
                                        Semantics(
                                          button: true,
                                          label:
                                              '${event.session.displayName}, ${_time(event.session.startAt)}, ${event.session.room}',
                                          child: CourseQuickActionGesture(
                                            session: event.session,
                                            enabled: !ref
                                                .watch(gridSelectionProvider)
                                                .active,
                                            onFallback: () => widget.onMenu(
                                              event.session,
                                              null,
                                            ),
                                            sourceRect: () {
                                              final box =
                                                  context.findRenderObject()
                                                      as RenderBox;
                                              final rect = scheduleCardRect(
                                                event: event,
                                                dayIndex: dayIndex,
                                                dayWidth: dayWidth,
                                                startMinute: layout.startMinute,
                                                pixelsPerMinute:
                                                    pixelsPerMinute,
                                                topInset: inset,
                                              );
                                              return box.localToGlobal(
                                                    Offset(
                                                      rect.left,
                                                      58 +
                                                          rect.top -
                                                          scrollController
                                                              .offset,
                                                    ),
                                                  ) &
                                                  rect.size;
                                            },
                                            preview: GridSessionChip(
                                              session: event.session,
                                              colorScheme: colorScheme,
                                              l10n: l10n,
                                              isSelected: true,
                                              compact:
                                                  layout.mode ==
                                                  ScheduleViewportMode
                                                      .compactWeek,
                                              onTap: () {},
                                              onMenu: (_) {},
                                              previewOnly: true,
                                            ),
                                            child: InkWell(
                                              key: ValueKey(
                                                'grid-fit-target-${event.session.id}',
                                              ),
                                              onTap: () => _selectAtEvent(
                                                event,
                                                dayIndex,
                                                pixelsPerMinute,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            if (strongIndices.isNotEmpty)
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: scrollController,
                                  builder: (context, child) {
                                    final offset = scrollController.hasClients
                                        ? scrollController.offset
                                        : 0.0;
                                    final visible = visibleStrongGridBells(
                                      cards: [
                                        for (final p in placements) p.rect,
                                      ],
                                      strongIndices: strongIndices,
                                      bounds: Rect.fromLTRB(
                                        kScheduleTimeRailWidth,
                                        math.max(0, offset),
                                        constraints.maxWidth,
                                        math.min(
                                          bodyHeight,
                                          offset +
                                              constraints.maxHeight -
                                              headerHeight,
                                        ),
                                      ),
                                    );
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        for (final index in visible)
                                          Positioned.fromRect(
                                            rect: strongGridBellRect(
                                              placements[index].rect,
                                            ),
                                            child: _entrance(
                                              placements[index]
                                                  .event
                                                  .session
                                                  .id,
                                              _GridStrongBell(
                                                key: ValueKey(
                                                  'grid-strong-bell-${placements[index].event.session.id}',
                                                ),
                                                session: placements[index]
                                                    .event
                                                    .session,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            _CurrentTimeLine(
                              entranceSpec: _entrances['@current-time'],
                              entranceOffset:
                                  _entranceOffsets['@current-time'] ??
                                  Offset.zero,
                              entrancePending: _pendingEntrance,
                              key: ValueKey(
                                '${now.year}-${now.month}-${now.day}|$pixelsPerMinute',
                              ),
                              layout: layout,
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
        if (reset && widget.shouldAutoScroll) {
          _initialScrollDone = true;
          widget.onAutoScrolled();
        }
      });
    }
  }

  void _scheduleInitialScroll(
    DateTime now,
    double pixelsPerMinute,
    double viewportHeight,
  ) {
    if (!widget.shouldAutoScroll ||
        _initialScrollDone ||
        _initialScrollQueued) {
      return;
    }
    _initialScrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialScrollQueued = false;
      if (!mounted || !scrollController.hasClients) return;
      if (_initialScrollDone) return;
      _initialScrollDone = true;
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
                '${candidate.session.displayName} · ${_time(candidate.session.startAt)}',
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
    Rect rect,
    double pixelsPerMinute,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return _entrance(
      event.session.id,
      GridSessionChip(
        key: ValueKey(event.session.id),
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
        event.session.displayName,
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
  return scheduleTextHeightCache.measure(
    value,
    style,
    width,
    scaler,
    direction,
    maxLines: maxLines,
  );
}

/// Digest of the fields the movement animation keys on. Cheaper than
/// `session.toMap().toString()`, which allocates a map plus a string of every
/// column on every rebuild.
String _motionSignature(CourseSession session) =>
    '${session.id}|${session.courseName}|${session.section}|${session.room}'
    '|${session.teachers.join(',')}'
    '|${session.startAt.millisecondsSinceEpoch}'
    '|${session.endAt.millisecondsSinceEpoch}';

const kScheduleTimelineTopInset = 24.0;
const kScheduleTimelineBottomInset = 24.0;

class GridSwipePreviousIntent extends Intent {
  const GridSwipePreviousIntent();
}

class GridSwipeNextIntent extends Intent {
  const GridSwipeNextIntent();
}
