import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/core/widgets/skeleton_box.dart';
import 'package:orbit/features/grid/grid_batch_delete_dialog.dart';
import 'package:orbit/features/search/session_search_page.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
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
        onAdd: sessionsAsync.hasValue
            ? () => SessionEditSheet.showCreate(context)
            : null,
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
        data: (sessions) {
          if (grid == null) {
            return _EmptyState(onImport: () => _goToImport(ref));
          }
          return WeekGridView(grid: grid, sessions: sessions);
        },
        loading: () => const _GridSkeleton(),
        error: (error, _) => ErrorState(
          message: l10n.gridLoadFailed('$error'),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(sessionsProvider),
        ),
      ),
    );
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
  const _GridAppBar({this.onAdd, this.onBatchDelete, this.onSearch});

  final VoidCallback? onAdd;
  final VoidCallback? onBatchDelete;
  final VoidCallback? onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      leading: onAdd == null
          ? null
          : IconButton(
              key: const Key('grid-add-session'),
              icon: const Icon(Icons.add, size: 21),
              tooltip: l10n.addSession,
              onPressed: onAdd,
            ),
      title: Text(l10n.gridTitle),
      actions: [
        if (onSearch != null)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onSearch,
            tooltip: l10n.searchSessions,
          ),
        if (onBatchDelete != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            onSelected: (value) {
              if (value == 'delete') onBatchDelete?.call();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_sweep_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.gridBatchDelete),
                  ],
                ),
              ),
            ],
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
class _GridSkeleton extends ConsumerWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = ref.watch(gridDensityMetricsProvider);
    const cols = 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: metrics.tableHeaderExtent,
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              SizedBox(width: metrics.timeColumnWidth),
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
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                for (var row = 0; row < 8; row++)
                  SizedBox(
                    height: metrics.rowHeight,
                    child: Row(
                      children: [
                        SizedBox(
                          width: metrics.timeColumnWidth,
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
                                  ? SkeletonBox(
                                      height: metrics.rowHeight - 8,
                                      radius: 8,
                                    )
                                  : col == 3 && row == 2
                                  ? SkeletonBox(
                                      height: metrics.rowHeight - 8,
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
