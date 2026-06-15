import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/core/widgets/skeleton_box.dart';
import 'package:orbit/features/grid/grid_batch_delete_dialog.dart';
import 'package:orbit/features/search/session_search_page.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/features/grid/grid_week_picker.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/providers/app_providers.dart';

class GridPage extends ConsumerWidget {
  const GridPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sessionsAsync = ref.watch(sessionsProvider);
    final grid = ref.watch(weekGridProvider);

    // Only enable batch-delete when data is loaded and a grid is displayed.
    final canBatchDelete = sessionsAsync.hasValue && grid != null;

    return Scaffold(
      appBar: _GridAppBar(
        weekStart: grid?.weekStart,
        onPrevWeek: () => _navigateWeek(ref, -7),
        onNextWeek: () => _navigateWeek(ref, 7),
        onSelectWeek: (weekStart) {
          ref.read(selectedWeekStartProvider.notifier).state = weekStart;
        },
        onGoToCurrentWeek: () => _goToCurrentWeek(ref),
        onBatchDelete: canBatchDelete
            ? () => showGridBatchDeleteDialog(
                  context,
                  ref,
                  displayedWeekStart: grid.weekStart,
                )
            : null,
        onSearch: () => SessionSearchPage.show(context),
      ),
      body: sessionsAsync.when(
        data: (_) {
          if (grid == null) {
            return _EmptyState(onImport: () => _goToImport(ref));
          }
          return WeekGridView(grid: grid);
        },
        loading: () => const _GridSkeleton(),
        error: (error, _) => ErrorState(
          message: l10n.gridLoadFailed('$error'),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(sessionsProvider),
        ),
      ),
      floatingActionButton: sessionsAsync.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => SessionEditSheet.showCreate(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.addSession),
            )
          : null,
    );
  }

  void _navigateWeek(WidgetRef ref, int days) {
    final displayed = ref.read(weekGridProvider)?.weekStart;
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

/// A custom [AppBar] for the grid page that includes week navigation controls.
///
/// Implements [PreferredSizeWidget] so it can be used directly as
/// [Scaffold.appBar] without a [PreferredSize] wrapper.
class _GridAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GridAppBar({
    required this.weekStart,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onSelectWeek,
    required this.onGoToCurrentWeek,
    this.onBatchDelete,
    this.onSearch,
  });

  final DateTime? weekStart;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onSelectWeek;
  final VoidCallback onGoToCurrentWeek;
  final VoidCallback? onBatchDelete;
  final VoidCallback? onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AppBar(
      titleSpacing: 0,
      // Batch-delete button lives in the leading slot when available.
      leading: onBatchDelete != null
          ? IconButton(
              icon: Icon(
                Icons.delete_sweep,
                color: theme.colorScheme.error,
              ),
              tooltip: l10n.gridBatchDelete,
              onPressed: onBatchDelete,
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevWeek,
            tooltip: l10n.gridPrevWeek,
          ),
          Flexible(
            child: weekStart != null
                ? GridWeekPicker(
                    weekStart: weekStart!,
                    onChanged: onSelectWeek,
                  )
                : Text(
                    l10n.gridTitle,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextWeek,
            tooltip: l10n.gridNextWeek,
          ),
        ],
      ),
      actions: [
        if (onSearch != null)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onSearch,
            tooltip: l10n.searchSessions,
          ),
        IconButton(
          icon: const Icon(Icons.today),
          onPressed: onGoToCurrentWeek,
          tooltip: l10n.gridThisWeek,
        ),
      ],
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
      subtitle: l10n.gridImportHint,
      action: FilledButton.icon(
        onPressed: onImport,
        icon: const Icon(Icons.upload_file),
        label: Text(l10n.gridImportNow),
      ),
    );
  }
}

/// Skeleton loading placeholder that mirrors the rough shape of the grid.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const rowHeight = 64.0;
    const timeColWidth = 52.0;
    const cols = 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Container(
          height: 40,
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const SizedBox(width: timeColWidth),
              for (var i = 0; i < cols; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: SkeletonBox(height: 14, radius: 4),
                  ),
                ),
            ],
          ),
        ),
        // Data rows
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                for (var row = 0; row < 8; row++)
                  SizedBox(
                    height: rowHeight,
                    child: Row(
                      children: [
                        SizedBox(
                          width: timeColWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 20,
                            ),
                            child: SkeletonBox(height: 12, radius: 4),
                          ),
                        ),
                        for (var col = 0; col < cols; col++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: col == 1 && (row == 1 || row == 3)
                                  ? SkeletonBox(height: rowHeight - 8, radius: 8)
                                  : col == 3 && row == 2
                                      ? SkeletonBox(
                                          height: rowHeight - 8,
                                          radius: 8,
                                        )
                                      : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
