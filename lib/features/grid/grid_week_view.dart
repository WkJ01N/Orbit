import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';
import 'package:orbit/features/grid/grid_pager_cache.dart';
import 'package:orbit/features/grid/grid_week_header_delegate.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/session/current_time_indicator.dart';
import 'package:orbit/features/session/session_action_menu.dart';
import 'package:orbit/features/session/session_countdown.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/grid_models.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/course_color_utils.dart';

class WeekGridView extends ConsumerStatefulWidget {
  const WeekGridView({super.key, required this.grid});

  final WeekGrid grid;

  @override
  ConsumerState<WeekGridView> createState() => WeekGridViewState();
}

class WeekGridViewState extends ConsumerState<WeekGridView> {
  int? _selectedWeekday;
  String? _selectedSessionId;
  int? _crossWeekDirection;
  final _chipKeys = <int, GlobalKey>{};
  final _horizontalScrollController = ScrollController();
  final _verticalScrollController = ScrollController();
  final _focusNode = FocusNode();

  // These fields are updated by the scroll listener but do NOT trigger a
  // rebuild — the AdjacentPagePager reads them lazily via closures.
  bool _horizontalAtStart = true;
  bool _horizontalAtEnd = true;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController.addListener(_updateHorizontalScrollEdges);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateHorizontalScrollEdges();
      }
    });
  }

  @override
  void dispose() {
    _horizontalScrollController
      ..removeListener(_updateHorizontalScrollEdges)
      ..dispose();
    _verticalScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WeekGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grid.weekStart != widget.grid.weekStart) {
      _selectedSessionId = null;
    }

    final weekdays = presentWeekdays(
      widget.grid,
      startWeekday: ref.read(weekStartDayProvider),
    );
    _chipKeys.removeWhere((day, _) => !weekdays.contains(day));
    if (_selectedWeekday != null && !weekdays.contains(_selectedWeekday)) {
      _selectedWeekday = weekdays.isNotEmpty ? weekdays.first : null;
    }

    if (oldWidget.grid.weekStart == widget.grid.weekStart) {
      return;
    }

    if (_crossWeekDirection != null) {
      final weekdays = presentWeekdays(
      widget.grid,
      startWeekday: ref.read(weekStartDayProvider),
    );
      if (weekdays.isNotEmpty) {
        final targetDay =
            _crossWeekDirection! > 0 ? weekdays.first : weekdays.last;
        setState(() {
          _selectedWeekday = targetDay;
          _crossWeekDirection = null;
        });
        _scrollChipToDay(targetDay);
      } else {
        _crossWeekDirection = null;
      }
      return;
    }

    setState(() {
      _selectedWeekday = null;
      _selectedSessionId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateHorizontalScrollEdges();
      }
    });
  }

  /// Updates the scroll edge flags WITHOUT calling [setState].
  ///
  /// The [AdjacentPagePager] reads these via closures at gesture time, so a
  /// rebuild is not required for the values to take effect.
  void _updateHorizontalScrollEdges() {
    if (!_horizontalScrollController.hasClients) {
      return;
    }
    final position = _horizontalScrollController.position;
    _horizontalAtStart = position.pixels <= position.minScrollExtent + 0.5;
    _horizontalAtEnd = position.pixels >= position.maxScrollExtent - 0.5;
  }

  GridPagerSlot _currentDaySlot(int startWeekday) {
    final day = _selectedWeekday ??
        defaultWeekdayForGrid(widget.grid, startWeekday: startWeekday);
    return GridPagerSlot(grid: widget.grid, day: day);
  }

  void _handleSettledToNext({
    required bool isCompact,
    required int startWeekday,
  }) {
    if (isCompact) {
      final next = computeNextDaySlot(
        _currentDaySlot(startWeekday),
        startWeekday: startWeekday,
      );
      if (next == null) {
        return;
      }
      _applyNavigatedSlot(next, forward: true, startWeekday: startWeekday);
      return;
    }
    ref.read(selectedWeekStartProvider.notifier).state = weekStartFor(
      widget.grid.weekStart.add(const Duration(days: 7)),
      startWeekday: startWeekday,
    );
  }

  void _handleSettledToPrevious({
    required bool isCompact,
    required int startWeekday,
  }) {
    if (isCompact) {
      final previous = computePreviousDaySlot(
        _currentDaySlot(startWeekday),
        startWeekday: startWeekday,
      );
      if (previous == null) {
        return;
      }
      _applyNavigatedSlot(previous, forward: false, startWeekday: startWeekday);
      return;
    }
    ref.read(selectedWeekStartProvider.notifier).state = weekStartFor(
      widget.grid.weekStart.subtract(const Duration(days: 7)),
      startWeekday: startWeekday,
    );
  }

  void _applyNavigatedSlot(
    GridPagerSlot target, {
    required bool forward,
    required int startWeekday,
  }) {
    if (target.weekStart !=
        weekStartFor(widget.grid.weekStart, startWeekday: startWeekday)) {
      _crossWeekDirection = forward ? 1 : -1;
      ref.read(selectedWeekStartProvider.notifier).state = target.weekStart;
      return;
    }
    if (target.day == null) {
      return;
    }
    setState(() => _selectedWeekday = target.day);
    _scrollChipToDay(target.day!);
  }

  void _scrollChipToDay(int day) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final chipContext = _chipKeys[day]?.currentContext;
      if (chipContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        chipContext,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    });
  }

  Widget _buildKeyboardWrapper({
    required bool isCompact,
    required int startWeekday,
    required Widget child,
  }) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              GridSwipePreviousIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight): GridSwipeNextIntent(),
        },
        child: Actions(
          actions: {
            GridSwipePreviousIntent: CallbackAction<GridSwipePreviousIntent>(
              onInvoke: (_) {
                _handleSettledToPrevious(
                  isCompact: isCompact,
                  startWeekday: startWeekday,
                );
                return null;
              },
            ),
            GridSwipeNextIntent: CallbackAction<GridSwipeNextIntent>(
              onInvoke: (_) {
                _handleSettledToNext(
                  isCompact: isCompact,
                  startWeekday: startWeekday,
                );
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );
  }

  bool _isCurrentWeekFor(WeekGrid grid, int startWeekday) {
    return weekStartFor(DateTime.now(), startWeekday: startWeekday) ==
        weekStartFor(grid.weekStart, startWeekday: startWeekday);
  }

  Widget _buildEmptyWeekBody(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.gridNoSessionsThisWeek,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.gridNoSessionsThisWeekSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayChips({
    required AppLocalizations l10n,
    required List<int> weekdays,
    required int selectedDay,
    required double chipHeight,
  }) {
    if (weekdays.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: weekdays.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = weekdays[index];
          final selected = day == (_selectedWeekday ?? selectedDay);
          final chipKey = _chipKeys.putIfAbsent(day, GlobalKey.new);
          return Align(
            alignment: Alignment.center,
            child: KeyedSubtree(
              key: chipKey,
              child: ChoiceChip(
                label: Text(
                  weekdayLabel(l10n, day),
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.0),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                labelPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selected: selected,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _selectedWeekday = day);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageContent({
    required WeekGrid grid,
    required AppLocalizations l10n,
    required BoxConstraints constraints,
    required bool isCompact,
    required ColorScheme colorScheme,
    required DateTime now,
    required GridDensityMetrics metrics,
    required int startWeekday,
    int? day,
  }) {
    if (isEmptyWeekGrid(grid, startWeekday: startWeekday)) {
      return _buildEmptyWeekBody(l10n);
    }

    if (isCompact) {
      final selectedDay =
          day ?? defaultWeekdayForGrid(grid, startWeekday: startWeekday);
      final tableWidth = constraints.maxWidth;
      final columnWidths = <int, TableColumnWidth>{
        0: FixedColumnWidth(metrics.timeColumnWidth),
        1: FixedColumnWidth(tableWidth - metrics.timeColumnWidth),
      };
      return _buildPinnedGridScroll(
        colorScheme: colorScheme,
        metrics: metrics,
        headerKey: ValueKey('${grid.weekStart}-compact-$selectedDay'),
        header: _buildTableHeader(
          context,
          grid: grid,
          weekdays: [selectedDay],
          colorScheme: colorScheme,
          l10n: l10n,
          columnWidths: columnWidths,
          startWeekday: startWeekday,
        ),
        body: CurrentTimeIndicator(
          grid: grid,
          isCurrentWeek: _isCurrentWeekFor(grid, startWeekday),
          rowHeight: metrics.rowHeight,
          headerHeight: 0,
          timeColumnWidth: metrics.timeColumnWidth,
          now: now,
          visibleWeekdays: [selectedDay],
          child: _buildDayTableBody(
            context,
            grid: grid,
            day: selectedDay,
            colorScheme: colorScheme,
            now: now,
            l10n: l10n,
            tableWidth: tableWidth,
            metrics: metrics,
          ),
        ),
      );
    }

    final weekdays = presentWeekdays(grid, startWeekday: startWeekday);
    final dayWidth =
        ((constraints.maxWidth - metrics.timeColumnWidth) / weekdays.length)
            .clamp(72.0, 160.0);
    final columnWidths = <int, TableColumnWidth>{
      0: FixedColumnWidth(metrics.timeColumnWidth),
      for (var i = 1; i <= weekdays.length; i++) i: FixedColumnWidth(dayWidth),
    };
    final contentWidth =
        (metrics.timeColumnWidth + dayWidth * weekdays.length)
            .clamp(constraints.maxWidth, double.infinity);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _horizontalScrollController,
      child: SizedBox(
        width: contentWidth,
        child: _buildPinnedGridScroll(
          colorScheme: colorScheme,
          metrics: metrics,
          headerKey: ValueKey('${grid.weekStart}-wide-${weekdays.join('-')}'),
          header: _buildTableHeader(
            context,
            grid: grid,
            weekdays: weekdays,
            colorScheme: colorScheme,
            l10n: l10n,
            columnWidths: columnWidths,
            startWeekday: startWeekday,
          ),
          body: CurrentTimeIndicator(
            grid: grid,
            isCurrentWeek: _isCurrentWeekFor(grid, startWeekday),
            rowHeight: metrics.rowHeight,
            headerHeight: 0,
            timeColumnWidth: metrics.timeColumnWidth,
            now: now,
            visibleWeekdays: weekdays,
            dayColumnIndex: weekdays.contains(now.weekday)
                ? weekdays.indexOf(now.weekday)
                : null,
            dayColumnWidth: dayWidth,
            child: _buildWeekTableBody(
              context,
              grid: grid,
              weekdays: weekdays,
              colorScheme: colorScheme,
              now: now,
              l10n: l10n,
              dayWidth: dayWidth,
              metrics: metrics,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedGridScroll({
    required ColorScheme colorScheme,
    required GridDensityMetrics metrics,
    required Key headerKey,
    required Widget header,
    required Widget body,
  }) {
    return Scrollbar(
      controller: _verticalScrollController,
      child: CustomScrollView(
        controller: _verticalScrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: WeekGridTableHeaderDelegate(
              headerKey: headerKey,
              header: header,
              extent: metrics.tableHeaderExtent,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          SliverToBoxAdapter(child: body),
        ],
      ),
    );
  }

  Widget _buildSwipeWrapper({
    required bool isCompact,
    required AppLocalizations l10n,
    required BoxConstraints constraints,
    required ColorScheme colorScheme,
    required DateTime now,
    required GridDensityMetrics metrics,
    required int startWeekday,
    int? day,
  }) {
    return AdjacentPagePager(
      onSwipeToPrevious: () => _handleSettledToPrevious(
        isCompact: isCompact,
        startWeekday: startWeekday,
      ),
      onSwipeToNext: () => _handleSettledToNext(
        isCompact: isCompact,
        startWeekday: startWeekday,
      ),
      canSwipePrevious: isCompact ? null : () => _horizontalAtStart,
      canSwipeNext: isCompact ? null : () => _horizontalAtEnd,
      child: _buildPageContent(
        grid: widget.grid,
        l10n: l10n,
        constraints: constraints,
        isCompact: isCompact,
        colorScheme: colorScheme,
        now: now,
        metrics: metrics,
        startWeekday: startWeekday,
        day: day,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final startWeekday = ref.watch(weekStartDayProvider);
    final metrics = ref.watch(gridDensityMetricsProvider);
    final weekdays = presentWeekdays(
      widget.grid,
      startWeekday: startWeekday,
    );
    final isEmptyWeek =
        isEmptyWeekGrid(widget.grid, startWeekday: startWeekday);
    final colorScheme = Theme.of(context).colorScheme;

    var selectedDay = startWeekday;
    if (!isEmptyWeek) {
      selectedDay = _selectedWeekday ??
          defaultWeekdayForGrid(widget.grid, startWeekday: startWeekday);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < kNarrowDialogBreakpoint;
        final swipeContent = Consumer(
          builder: (context, ref, _) {
            final now = ref.watch(currentTimeProvider);
            return _buildSwipeWrapper(
              isCompact: isCompact,
              l10n: l10n,
              constraints: constraints,
              colorScheme: colorScheme,
              now: now,
              metrics: metrics,
              startWeekday: startWeekday,
              day: isCompact ? selectedDay : null,
            );
          },
        );

        if (isCompact) {
          return _buildKeyboardWrapper(
            isCompact: true,
            startWeekday: startWeekday,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWeekdayChips(
                  l10n: l10n,
                  weekdays: weekdays,
                  selectedDay: selectedDay,
                  chipHeight: metrics.weekdayChipHeight,
                ),
                Expanded(child: swipeContent),
              ],
            ),
          );
        }

        return _buildKeyboardWrapper(
          isCompact: false,
          startWeekday: startWeekday,
          child: swipeContent,
        );
      },
    );
  }

  Widget _buildTableHeader(
    BuildContext context, {
    required WeekGrid grid,
    required List<int> weekdays,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
    required Map<int, TableColumnWidth> columnWidths,
    required int startWeekday,
  }) {
    return Table(
      border: TableBorder.all(color: colorScheme.outlineVariant, width: 0.5),
      columnWidths: columnWidths,
      children: [
        _headerRow(
          context,
          grid,
          weekdays,
          colorScheme,
          l10n,
          startWeekday,
        ),
      ],
    );
  }

  Widget _buildDayTableBody(
    BuildContext context, {
    required WeekGrid grid,
    required int day,
    required ColorScheme colorScheme,
    required DateTime now,
    required AppLocalizations l10n,
    required double tableWidth,
    required GridDensityMetrics metrics,
  }) {
    return Table(
      border: TableBorder.all(color: colorScheme.outlineVariant, width: 0.5),
      columnWidths: {
        0: FixedColumnWidth(metrics.timeColumnWidth),
        1: FixedColumnWidth(tableWidth - metrics.timeColumnWidth),
      },
      children: [
        for (final timeLabel in grid.timeLabels)
          _dataRow(
            context,
            grid,
            timeLabel,
            [day],
            colorScheme,
            now,
            l10n,
            metrics,
          ),
      ],
    );
  }

  Widget _buildWeekTableBody(
    BuildContext context, {
    required WeekGrid grid,
    required List<int> weekdays,
    required ColorScheme colorScheme,
    required DateTime now,
    required AppLocalizations l10n,
    required double dayWidth,
    required GridDensityMetrics metrics,
  }) {
    return Table(
      border: TableBorder.all(color: colorScheme.outlineVariant, width: 0.5),
      columnWidths: {
        0: FixedColumnWidth(metrics.timeColumnWidth),
        for (var i = 1; i <= weekdays.length; i++) i: FixedColumnWidth(dayWidth),
      },
      children: [
        for (final timeLabel in grid.timeLabels)
          _dataRow(
            context,
            grid,
            timeLabel,
            weekdays,
            colorScheme,
            now,
            l10n,
            metrics,
          ),
      ],
    );
  }

  TableRow _headerRow(
    BuildContext context,
    WeekGrid grid,
    List<int> weekdays,
    ColorScheme colorScheme,
    AppLocalizations l10n,
    int startWeekday,
  ) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    return TableRow(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            l10n.gridTimeColumn,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
        ),
        for (final day in weekdays)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              children: [
                Text(
                  weekdayLabel(l10n, day),
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                Text(
                  _weekdayDate(grid, day, startWeekday),
                  style: textStyle?.copyWith(
                    color: colorScheme.onSurfaceVariant.withAlpha(150),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _weekdayDate(WeekGrid grid, int weekday, int startWeekday) {
    final order = orderedWeekdays(startWeekday: startWeekday);
    final index = order.indexOf(weekday);
    if (index < 0) {
      return '';
    }
    final date = grid.weekStart.add(Duration(days: index));
    return DateFormat('M/d').format(date);
  }

  TableRow _dataRow(
    BuildContext context,
    WeekGrid grid,
    String timeLabel,
    List<int> weekdays,
    ColorScheme colorScheme,
    DateTime now,
    AppLocalizations l10n,
    GridDensityMetrics metrics,
  ) {
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return TableRow(
      children: [
        Container(
          color: colorScheme.surfaceContainerHighest.withAlpha(120),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            timeLabel,
            style: textStyle?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
        for (final day in weekdays)
          _cellContent(
            context,
            grid.sessionsFor(day, timeLabel),
            colorScheme,
            l10n,
            metrics,
          ),
      ],
    );
  }

  Widget _cellContent(
    BuildContext context,
    List<CourseSession> sessions,
    ColorScheme colorScheme,
    AppLocalizations l10n,
    GridDensityMetrics metrics,
  ) {
    if (sessions.isEmpty) {
      return SizedBox(height: metrics.rowHeight);
    }
    return RepaintBoundary(
      child: SizedBox(
        height: metrics.rowHeight,
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final session in sessions)
                GridSessionChip(
                  key: ValueKey(session.id),
                  session: session,
                  colorScheme: colorScheme,
                  l10n: l10n,
                  metrics: metrics,
                  isSelected: _selectedSessionId == session.id,
                  onTap: () {
                    setState(() => _selectedSessionId = session.id);
                    SessionDetailSheet.show(context, session);
                  },
                  onMenu: (position) => SessionActionMenu.show(
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
                ),
            ],
          ),
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
    required this.metrics,
    required this.isSelected,
    required this.onTap,
    required this.onMenu,
  });

  final CourseSession session;
  final ColorScheme colorScheme;
  final AppLocalizations l10n;
  final GridDensityMetrics metrics;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(Offset? position) onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(currentTimeProvider);
    final overrides = ref.watch(courseColorOverridesProvider);
    final customColor = overrides[courseColorKey(session)];
    final isPast = isSessionPast(now, session.endAt);
    final isOngoing = isSessionOngoing(now, session.startAt, session.endAt);
    final highlightSoon =
        isSessionStartingSoon(now, session.startAt) && !isPast;
    late final Color bg;
    late final Color fg;
    if (isOngoing || highlightSoon) {
      bg = customColor?.withAlpha(220) ?? colorScheme.primaryContainer;
      fg = customColor == null
          ? colorScheme.onPrimaryContainer
          : contrastForegroundFor(customColor);
    } else if (isPast) {
      bg = customColor?.withAlpha(100) ?? colorScheme.surfaceContainerHighest;
      fg = customColor == null
          ? colorScheme.onSurfaceVariant.withAlpha(140)
          : contrastForegroundFor(customColor).withAlpha(140);
    } else {
      bg = customColor?.withAlpha(220) ??
          colorScheme.secondaryContainer.withAlpha(220);
      fg = customColor == null
          ? colorScheme.onSecondaryContainer
          : contrastForegroundFor(customColor);
    }

    final endTime =
        '${session.endAt.hour.toString().padLeft(2, '0')}:${session.endAt.minute.toString().padLeft(2, '0')}';

    final baseStyle = Theme.of(context).textTheme.labelSmall;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => onMenu(null),
      onSecondaryTapDown: (details) => onMenu(details.globalPosition),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.courseName,
              style: baseStyle?.copyWith(
                fontSize: metrics.courseNameFontSize,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${session.room} · ${l10n.gridUntilTime(endTime)}',
              style: baseStyle?.copyWith(
                fontSize: metrics.courseMetaFontSize,
                color: fg.withAlpha(180),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class GridSwipePreviousIntent extends Intent {
  const GridSwipePreviousIntent();
}

class GridSwipeNextIntent extends Intent {
  const GridSwipeNextIntent();
}
