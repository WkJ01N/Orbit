import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/error_state.dart';
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

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: sessionsAsync.when(
          data: (_) => _GridAppBar(
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
            onSearch: () => SessionSearchPage.show(context),
          ),
          loading: () => _GridAppBar(
            weekStart: grid?.weekStart,
            onPrevWeek: () => _navigateWeek(ref, -7),
            onNextWeek: () => _navigateWeek(ref, 7),
            onSelectWeek: (weekStart) {
              ref.read(selectedWeekStartProvider.notifier).state = weekStart;
            },
            onGoToCurrentWeek: () => _goToCurrentWeek(ref),
            onSearch: () => SessionSearchPage.show(context),
          ),
          error: (_, _) => _GridAppBar(
            weekStart: grid?.weekStart,
            onPrevWeek: () => _navigateWeek(ref, -7),
            onNextWeek: () => _navigateWeek(ref, 7),
            onSelectWeek: (weekStart) {
              ref.read(selectedWeekStartProvider.notifier).state = weekStart;
            },
            onGoToCurrentWeek: () => _goToCurrentWeek(ref),
            onSearch: () => SessionSearchPage.show(context),
          ),
        ),
      ),
      body: sessionsAsync.when(
        data: (_) {
          if (grid == null) {
            return _EmptyState(onImport: () => _goToImport(ref));
          }
          return WeekGridView(grid: grid);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: l10n.gridLoadFailed('$error'),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(sessionsProvider),
        ),
      ),
      floatingActionButton: sessionsAsync.maybeWhen(
        data: (_) => FloatingActionButton.extended(
          onPressed: () => SessionEditSheet.showCreate(context),
          icon: const Icon(Icons.add),
          label: Text(l10n.addSession),
        ),
        orElse: () => null,
      ),
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

class _GridAppBar extends StatelessWidget {
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                ),
              ),
            ],
          ),
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
      subtitle: l10n.gridImportHint,
      action: FilledButton.icon(
        onPressed: onImport,
        icon: const Icon(Icons.upload_file),
        label: Text(l10n.gridImportNow),
      ),
    );
  }
}
