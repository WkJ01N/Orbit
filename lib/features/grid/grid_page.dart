import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/features/grid/grid_batch_delete_dialog.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/grid/grid_week_picker.dart';
import 'package:orbit/features/session/current_time_indicator.dart';
import 'package:orbit/features/session/session_action_menu.dart';
import 'package:orbit/features/session/session_countdown.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_models.dart';
import 'package:orbit/providers/app_providers.dart';
class GridPage extends ConsumerWidget {
  const GridPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final weekGridAsync = ref.watch(weekGridProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: weekGridAsync.when(
          data: (grid) => _GridAppBar(
            weekStart: grid?.weekStart,
            onPrevWeek: () => _navigateWeek(ref, -7),
            onNextWeek: () => _navigateWeek(ref, 7),
            onSelectWeek: (weekStart) {
              ref.read(selectedWeekStartProvider.notifier).state = weekStart;
            },
            onGoToCurrentWeek: () => _goToCurrentWeek(ref),
            onBatchDelete: grid == null
                ? null
                : () => showGridBatchDeleteDialog(
                      context,
                      ref,
                      displayedWeekStart: grid.weekStart,
                    ),
          ),
          loading: () => _GridAppBar(
            weekStart: null,
            onPrevWeek: () => _navigateWeek(ref, -7),
            onNextWeek: () => _navigateWeek(ref, 7),
            onSelectWeek: (weekStart) {
              ref.read(selectedWeekStartProvider.notifier).state = weekStart;
            },
            onGoToCurrentWeek: () => _goToCurrentWeek(ref),
          ),
          error: (_, _) => _GridAppBar(
            weekStart: null,
            onPrevWeek: () => _navigateWeek(ref, -7),
            onNextWeek: () => _navigateWeek(ref, 7),
            onSelectWeek: (weekStart) {
              ref.read(selectedWeekStartProvider.notifier).state = weekStart;
            },
            onGoToCurrentWeek: () => _goToCurrentWeek(ref),
          ),
        ),
      ),
      body: weekGridAsync.when(
        data: (grid) {
          if (grid == null) {
            return _EmptyState(onImport: () => _goToImport(ref));
          }
          return _WeekGridView(grid: grid);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: l10n.gridLoadFailed('$error'),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(weekGridProvider),
        ),
      ),
    );
  }

  void _navigateWeek(WidgetRef ref, int days) {
    final displayed = ref.read(weekGridProvider).value?.weekStart;
    final base = displayed ?? weekStartFor(DateTime.now());
    ref.read(selectedWeekStartProvider.notifier).state =
        weekStartFor(base.add(Duration(days: days)));
  }

  void _goToCurrentWeek(WidgetRef ref) {
    ref.read(selectedWeekStartProvider.notifier).state =
        weekStartFor(DateTime.now());
  }

  void _goToImport(WidgetRef ref) {
    navigateToAppTab(ref, AppTab.import);
  }
}

class _GridAppBar extends StatelessWidget {
  const _GridAppBar({
    required this.weekStart,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onSelectWeek,
    required this.onGoToCurrentWeek,
    this.onBatchDelete,
  });

  final DateTime? weekStart;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onSelectWeek;
  final VoidCallback onGoToCurrentWeek;
  final VoidCallback? onBatchDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Material(
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      elevation: theme.appBarTheme.elevation ?? 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (onBatchDelete != null)
                Positioned(
                  left: 4,
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_sweep,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: l10n.gridBatchDelete,
                    onPressed: onBatchDelete,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: onPrevWeek,
                    tooltip: l10n.gridPrevWeek,
                  ),
                  if (weekStart != null)
                    GridWeekPicker(
                      weekStart: weekStart!,
                      onChanged: onSelectWeek,
                    )
                  else
                    Text(
                      l10n.gridTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: onNextWeek,
                    tooltip: l10n.gridNextWeek,
                  ),
                ],
              ),
              Positioned(
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.today),
                  onPressed: onGoToCurrentWeek,
                  tooltip: l10n.gridThisWeek,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekGridView extends ConsumerStatefulWidget {
  const _WeekGridView({required this.grid});

  final WeekGrid grid;

  @override
  ConsumerState<_WeekGridView> createState() => _WeekGridViewState();
}

class _WeekGridViewState extends ConsumerState<_WeekGridView> {
  int? _selectedWeekday;
  String? _selectedSessionId;

  static const _rowHeight = 64.0;
  static const _headerHeight = 52.0;
  static const _timeColumnWidth = 52.0;

  bool get _isCurrentWeek {
    final now = DateTime.now();
    return weekStartFor(now) == weekStartFor(widget.grid.weekStart);
  }
  List<int> _presentWeekdays() {
    final presentWeekdays = <int>{};
    for (final key in widget.grid.cells.keys) {
      presentWeekdays.add(int.parse(key.split('|').first));
    }
    return ([1, 2, 3, 4, 5, 6, 7]
          ..removeWhere((d) => !presentWeekdays.contains(d)))
        .toList();
  }

  int _defaultWeekday(List<int> weekdays) {
    if (weekdays.isEmpty) {
      return DateTime.monday;
    }
    final today = DateTime.now().weekday;
    if (weekdays.contains(today)) {
      return today;
    }
    return weekdays.first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekdays = _presentWeekdays();

    if (weekdays.isEmpty || widget.grid.timeLabels.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        title: l10n.gridNoSessionsThisWeek,
        subtitle: l10n.gridNoSessionsThisWeekSubtitle,
        action: OutlinedButton.icon(
          onPressed: () => navigateToAppTab(ref, AppTab.import),
          icon: const Icon(Icons.upload_file),
          label: Text(l10n.gridImportNow),
        ),
      );
    }

    final selectedDay = _selectedWeekday ?? _defaultWeekday(weekdays);
    if (!weekdays.contains(selectedDay)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedWeekday = weekdays.first);
        }
      });
    }

    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < kNarrowDialogBreakpoint;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: weekdays.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final day = weekdays[index];
                    final selected = day == (_selectedWeekday ?? selectedDay);
                    return ChoiceChip(
                      label: Text(weekdayLabel(l10n, day)),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _selectedWeekday = day);
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: CurrentTimeIndicator(
                    grid: widget.grid,
                    isCurrentWeek: _isCurrentWeek,
                    rowHeight: _rowHeight,
                    headerHeight: _headerHeight,
                    timeColumnWidth: _timeColumnWidth,
                    child: _buildDayTable(
                      context,
                      day: _selectedWeekday ?? selectedDay,
                      colorScheme: colorScheme,
                      now: now,
                      l10n: l10n,
                      tableWidth: constraints.maxWidth,
                    ),
                  ),
                ),
              ),            ],
          );
        }

        final dayWidth =
            ((constraints.maxWidth - 52) / weekdays.length).clamp(72.0, 160.0);

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: CurrentTimeIndicator(
                grid: widget.grid,
                isCurrentWeek: _isCurrentWeek,
                rowHeight: _rowHeight,
                headerHeight: _headerHeight,
                timeColumnWidth: _timeColumnWidth,
                child: _buildWeekTable(
                  context,
                  weekdays: weekdays,
                  colorScheme: colorScheme,
                  now: now,
                  l10n: l10n,
                  dayWidth: dayWidth,
                ),
              ),
            ),
          ),
        );      },
    );
  }

  Widget _buildDayTable(
    BuildContext context, {
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
        _headerRow(context, [day], colorScheme, l10n),
        for (final timeLabel in widget.grid.timeLabels)
          _dataRow(context, timeLabel, [day], colorScheme, now, l10n),
      ],
    );
  }

  Widget _buildWeekTable(
    BuildContext context, {
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
        _headerRow(context, weekdays, colorScheme, l10n),
        for (final timeLabel in widget.grid.timeLabels)
          _dataRow(context, timeLabel, weekdays, colorScheme, now, l10n),
      ],
    );
  }

  TableRow _headerRow(
    BuildContext context,
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
          child: Text(l10n.gridTimeColumn, style: textStyle, textAlign: TextAlign.center),
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
                  _weekdayDate(day),
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

  String _weekdayDate(int weekday) {
    final date = widget.grid.weekStart.add(Duration(days: weekday - 1));
    return DateFormat('M/d').format(date);
  }

  TableRow _dataRow(
    BuildContext context,
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
            widget.grid.sessionsFor(day, timeLabel),
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
          _SessionChip(
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
          ),      ],
    );
  }
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({
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
    Color bg;
    Color fg;
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
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyState(
      icon: Icons.calendar_today_outlined,
      title: l10n.gridEmptyTitle,
      subtitle: l10n.gridEmptySubtitle,
      action: FilledButton.icon(
        onPressed: onImport,
        icon: const Icon(Icons.upload_file),
        label: Text(l10n.gridImportNow),
      ),
    );
  }
}
