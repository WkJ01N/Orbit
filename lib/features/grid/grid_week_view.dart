import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';
import 'package:orbit/features/grid/grid_pager_cache.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/session/current_time_indicator.dart';
import 'package:orbit/features/session/session_action_menu.dart';
import 'package:orbit/features/session/session_countdown.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_models.dart';
import 'package:orbit/providers/app_providers.dart';

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
  final _headerScrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _horizontalAtStart = true;
  bool _horizontalAtEnd = true;

  static const _rowHeight = 64.0;
  static const _timeColumnWidth = 52.0;

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
    _headerScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WeekGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grid.weekStart == widget.grid.weekStart) {
      return;
    }

    if (_crossWeekDirection != null) {
      final weekdays = presentWeekdays(widget.grid);
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

    setState(() => _selectedWeekday = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateHorizontalScrollEdges();
      }
    });
  }

  void _updateHorizontalScrollEdges() {
    if (!_horizontalScrollController.hasClients) {
      return;
    }
    final position = _horizontalScrollController.position;
    if (_headerScrollController.hasClients &&
        _headerScrollController.offset != position.pixels) {
      _headerScrollController.jumpTo(position.pixels);
    }
    final atStart = position.pixels <= position.minScrollExtent + 0.5;
    final atEnd = position.pixels >= position.maxScrollExtent - 0.5;
    if (atStart != _horizontalAtStart || atEnd != _horizontalAtEnd) {
      setState(() {
        _horizontalAtStart = atStart;
        _horizontalAtEnd = atEnd;
      });
    }
  }

  GridPagerSlot _currentDaySlot() {
    final day = _selectedWeekday ?? defaultWeekdayForGrid(widget.grid);
    return GridPagerSlot(grid: widget.grid, day: day);
  }

  void _handleSettledToNext({required bool isCompact}) {
    if (isCompact) {
      final next = computeNextDaySlot(_currentDaySlot());
      if (next == null) {
        return;
      }
      _applyNavigatedSlot(next, forward: true);
      return;
    }
    ref.read(selectedWeekStartProvider.notifier).state = weekStartFor(
      widget.grid.weekStart.add(const Duration(days: 7)),
    );
  }

  void _handleSettledToPrevious({required bool isCompact}) {
    if (isCompact) {
      final previous = computePreviousDaySlot(_currentDaySlot());
      if (previous == null) {
        return;
      }
      _applyNavigatedSlot(previous, forward: false);
      return;
    }
    ref.read(selectedWeekStartProvider.notifier).state = weekStartFor(
      widget.grid.weekStart.subtract(const Duration(days: 7)),
    );
  }

  void _applyNavigatedSlot(GridPagerSlot target, {required bool forward}) {
    if (target.weekStart != weekStartFor(widget.grid.weekStart)) {
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
                _handleSettledToPrevious(isCompact: isCompact);
                return null;
              },
            ),
            GridSwipeNextIntent: CallbackAction<GridSwipeNextIntent>(
              onInvoke: (_) {
                _handleSettledToNext(isCompact: isCompact);
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );
  }

  bool _isCurrentWeekFor(WeekGrid grid) {
    return weekStartFor(DateTime.now()) == weekStartFor(grid.weekStart);
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
  }) {
    if (weekdays.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
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
    int? day,
  }) {
    if (isEmptyWeekGrid(grid)) {
      return _buildEmptyWeekBody(l10n);
    }

    if (isCompact) {
      final selectedDay = day ?? defaultWeekdayForGrid(grid);
      final tableWidth = constraints.maxWidth;
      final columnWidths = <int, TableColumnWidth>{
        0: const FixedColumnWidth(52),
        1: FixedColumnWidth(tableWidth - 52),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTableHeader(
            context,
            grid: grid,
            weekdays: [selectedDay],
            colorScheme: colorScheme,
            l10n: l10n,
            columnWidths: columnWidths,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: CurrentTimeIndicator(
                grid: grid,
                isCurrentWeek: _isCurrentWeekFor(grid),
                rowHeight: _rowHeight,
                headerHeight: 0,
                timeColumnWidth: _timeColumnWidth,
                child: _buildDayTableBody(
                  context,
                  grid: grid,
                  day: selectedDay,
                  colorScheme: colorScheme,
                  now: now,
                  l10n: l10n,
                  tableWidth: tableWidth,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final weekdays = presentWeekdays(grid);
    final dayWidth =
        ((constraints.maxWidth - 52) / weekdays.length).clamp(72.0, 160.0);
    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(52),
      for (var i = 1; i <= weekdays.length; i++) i: FixedColumnWidth(dayWidth),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _headerScrollController,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: _buildTableHeader(
              context,
              grid: grid,
              weekdays: weekdays,
              colorScheme: colorScheme,
              l10n: l10n,
              columnWidths: columnWidths,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: CurrentTimeIndicator(
                  grid: grid,
                  isCurrentWeek: _isCurrentWeekFor(grid),
                  rowHeight: _rowHeight,
                  headerHeight: 0,
                  timeColumnWidth: _timeColumnWidth,
                  child: _buildWeekTableBody(
                    context,
                    grid: grid,
                    weekdays: weekdays,
                    colorScheme: colorScheme,
                    now: now,
                    l10n: l10n,
                    dayWidth: dayWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeWrapper({
    required bool isCompact,
    required AppLocalizations l10n,
    required BoxConstraints constraints,
    required ColorScheme colorScheme,
    required DateTime now,
    int? day,
  }) {
    return AdjacentPagePager(
      onSwipeToPrevious: () => _handleSettledToPrevious(isCompact: isCompact),
      onSwipeToNext: () => _handleSettledToNext(isCompact: isCompact),
      canSwipePrevious: isCompact ? null : () => _horizontalAtStart,
      canSwipeNext: isCompact ? null : () => _horizontalAtEnd,
      child: _buildPageContent(
        grid: widget.grid,
        l10n: l10n,
        constraints: constraints,
        isCompact: isCompact,
        colorScheme: colorScheme,
        now: now,
        day: day,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekdays = presentWeekdays(widget.grid);
    final isEmptyWeek = isEmptyWeekGrid(widget.grid);

    var selectedDay = DateTime.monday;
    if (!isEmptyWeek) {
      selectedDay = _selectedWeekday ?? defaultWeekdayForGrid(widget.grid);
      if (!weekdays.contains(selectedDay)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _selectedWeekday = weekdays.first);
          }
        });
      }
    }

    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < kNarrowDialogBreakpoint;
        final swipeContent = _buildSwipeWrapper(
          isCompact: isCompact,
          l10n: l10n,
          constraints: constraints,
          colorScheme: colorScheme,
          now: now,
          day: isCompact ? selectedDay : null,
        );

        if (isCompact) {
          return _buildKeyboardWrapper(
            isCompact: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWeekdayChips(
                  l10n: l10n,
                  weekdays: weekdays,
                  selectedDay: selectedDay,
                ),
                Expanded(child: swipeContent),
              ],
            ),
          );
        }

        return _buildKeyboardWrapper(
          isCompact: false,
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
  }) {
    return Table(
      border: TableBorder.all(color: colorScheme.outlineVariant, width: 0.5),
      columnWidths: columnWidths,
      children: [
        _headerRow(context, grid, weekdays, colorScheme, l10n),
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
  }) {
    return Table(
      border: TableBorder.all(color: colorScheme.outlineVariant, width: 0.5),
      columnWidths: {
        0: const FixedColumnWidth(52),
        1: FixedColumnWidth(tableWidth - 52),
      },
      children: [
        for (final timeLabel in grid.timeLabels)
          _dataRow(context, grid, timeLabel, [day], colorScheme, now, l10n),
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
  }) {
    return Table(
      border: TableBorder.all(color: colorScheme.outlineVariant, width: 0.5),
      columnWidths: {
        0: const FixedColumnWidth(52),
        for (var i = 1; i <= weekdays.length; i++) i: FixedColumnWidth(dayWidth),
      },
      children: [
        for (final timeLabel in grid.timeLabels)
          _dataRow(context, grid, timeLabel, weekdays, colorScheme, now, l10n),
      ],
    );
  }

  TableRow _headerRow(
    BuildContext context,
    WeekGrid grid,
    List<int> weekdays,
    ColorScheme colorScheme,
    AppLocalizations l10n,
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
                  _weekdayDate(grid, day),
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

  String _weekdayDate(WeekGrid grid, int weekday) {
    final date = grid.weekStart.add(Duration(days: weekday - 1));
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
            now,
            l10n,
          ),
      ],
    );
  }

  Widget _cellContent(
    BuildContext context,
    List<CourseSession> sessions,
    ColorScheme colorScheme,
    DateTime now,
    AppLocalizations l10n,
  ) {
    if (sessions.isEmpty) {
      return const SizedBox(height: 64);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final session in sessions)
          GridSessionChip(
            session: session,
            colorScheme: colorScheme,
            now: now,
            l10n: l10n,
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
    );
  }
}

class GridSessionChip extends StatelessWidget {
  const GridSessionChip({
    super.key,
    required this.session,
    required this.colorScheme,
    required this.now,
    required this.l10n,
    required this.isSelected,
    required this.onTap,
    required this.onMenu,
  });

  final CourseSession session;
  final ColorScheme colorScheme;
  final DateTime now;
  final AppLocalizations l10n;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(Offset? position) onMenu;

  @override
  Widget build(BuildContext context) {
    final isPast = isSessionPast(now, session.endAt);
    final isOngoing = isSessionOngoing(now, session.startAt, session.endAt);
    final highlightSoon =
        isSessionStartingSoon(now, session.startAt) && !isPast;
    late final Color bg;
    late final Color fg;
    if (isOngoing || highlightSoon) {
      bg = colorScheme.primaryContainer;
      fg = colorScheme.onPrimaryContainer;
    } else if (isPast) {
      bg = colorScheme.surfaceContainerHighest;
      fg = colorScheme.onSurfaceVariant.withAlpha(140);
    } else {
      bg = colorScheme.secondaryContainer.withAlpha(220);
      fg = colorScheme.onSecondaryContainer;
    }

    final endTime =
        '${session.endAt.hour.toString().padLeft(2, '0')}:${session.endAt.minute.toString().padLeft(2, '0')}';

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
          children: [
            Text(
              session.courseName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${session.room} · ${l10n.gridUntilTime(endTime)}',
              style: TextStyle(fontSize: 9, color: fg.withAlpha(180)),
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
