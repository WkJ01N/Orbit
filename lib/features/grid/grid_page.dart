import 'package:flutter/material.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:flutter/services.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/features/grid/grid_selection.dart';
import 'package:orbit/features/grid/grid_delete_confirmation.dart';
import 'package:orbit/models/grid_action_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/core/widgets/skeleton_box.dart';
import 'package:orbit/features/grid/grid_batch_delete_dialog.dart';
import 'package:orbit/features/search/session_search_page.dart';
import 'package:orbit/features/session/session_add_action.dart';
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
    final selection = ref.watch(gridSelectionProvider);
    final interceptBack =
        selection.active && ref.watch(appNavIndexProvider) == AppTab.grid.index;

    // Only enable batch-delete when data is loaded and a grid is displayed.
    final canBatchDelete = sessionsAsync.hasValue && grid != null;

    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && interceptBack) cancelGridSelection(context, ref);
      },
      child: Focus(
        onKeyEvent: (_, event) {
          if (selection.active &&
              event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            cancelGridSelection(context, ref);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          appBar: BackgroundAppBar(
            child: _GridAppBar(
              selection: selection,
              onCancel: () => cancelGridSelection(context, ref),
              onSubmit: () => _submitManual(context, ref),
              onAdd: sessionsAsync.hasValue
                  ? () => showSessionAddAction(context)
                  : null,
              onBatchDelete: canBatchDelete
                  ? () async {
                      final manual = await showGridBatchDeleteDialog(
                        context,
                        ref,
                        displayedWeekStart: grid.weekStart,
                      );
                      if (manual && context.mounted) {
                        ref.read(gridSelectionProvider.notifier).enter();
                      }
                    }
                  : null,
              onSearch: () => SessionSearchPage.show(context),
            ),
          ),
          body: sessionsAsync.when(
            data: (sessions) {
              if (grid == null) {
                return BackgroundRegion(
                  region: BackgroundRegionId.content,
                  child: _EmptyState(onImport: () => _goToImport(context, ref)),
                );
              }
              return WeekGridView(
                grid: grid,
                sessions: sessions.where((s) => s.visible).toList(),
              );
            },
            loading: () => const _GridSkeleton(),
            error: (error, _) => ErrorState(
              message: l10n.gridLoadFailed('$error'),
              retryLabel: l10n.actionRetry,
              onRetry: () => ref.invalidate(sessionsProvider),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitManual(BuildContext context, WidgetRef ref) async {
    final selection = ref.read(gridSelectionProvider);
    if (selection.busy || selection.ids.isEmpty) return;
    final notifier = ref.read(gridSelectionProvider.notifier);
    notifier.setBusy(true);
    try {
      final targets =
          (await ref.read(scheduleRepositoryProvider).getAllSessions())
              .where((s) => selection.ids.contains(s.id))
              .toList();
      if (!context.mounted) return;
      notifier.replace(targets.map((s) => s.id).toSet());
      notifier.setBusy(false);
      if (targets.length != selection.ids.length) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text(GridActionText.of(context).changed)),
        );
      }
      if (targets.isEmpty) return;
      final deleted = await confirmGridDeletion(
        context,
        targets: targets,
        onSelectionChanged: notifier.replace,
      );
      if (deleted) notifier.exit();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.gridBatchDeleteFailed('$e'),
            ),
          ),
        );
      }
    } finally {
      if (context.mounted) notifier.setBusy(false);
    }
  }

  void _goToImport(BuildContext context, WidgetRef ref) {
    navigateToAppTab(ref, AppTab.import, context: context);
  }
}

/// A custom [AppBar] for the grid page that includes week navigation controls.
///
/// Implements [PreferredSizeWidget] so it can be used directly as
/// [Scaffold.appBar] without a [PreferredSize] wrapper.
class _GridAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GridAppBar({
    this.onAdd,
    this.onBatchDelete,
    this.onSearch,
    this.selection = const GridSelection(),
    this.onCancel,
    this.onSubmit,
  });
  final GridSelection selection;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  final VoidCallback? onAdd;
  final VoidCallback? onBatchDelete;
  final VoidCallback? onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (selection.active) {
      final text = GridActionText.of(context);
      final colors = Theme.of(context).colorScheme;
      return AppBar(
        leading: IconButton(
          key: const Key('grid-selection-cancel'),
          icon: const Icon(Icons.close),
          color: colors.primary,
          tooltip: text.cancelSelection,
          onPressed: selection.busy ? null : onCancel,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.chooseCourses),
            Text(
              text.selected(selection.ids.length),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              key: const Key('grid-selection-submit'),
              style: IconButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              tooltip: text.preview,
              icon: const Icon(Icons.check),
              onPressed: selection.busy || selection.ids.isEmpty
                  ? null
                  : onSubmit,
            ),
          ),
        ],
      );
    }
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
                    Expanded(child: Text(l10n.gridBatchDelete)),
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
