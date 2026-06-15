import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/core/widgets/section_header.dart';
import 'package:orbit/core/widgets/skeleton_box.dart';
import 'package:orbit/features/search/session_search_page.dart';
import 'package:orbit/features/session/session_action_menu.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/features/session/session_countdown.dart';
import 'package:orbit/features/session/session_countdown_label.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';

enum SessionGroupKind { today, tomorrow, thisWeek, later }

class UpcomingPage extends ConsumerWidget {
  const UpcomingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final upcomingAsync = ref.watch(upcomingSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.upcomingTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.searchSessions,
            onPressed: () => SessionSearchPage.show(context),
          ),
        ],
      ),
      body: upcomingAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const _EmptyState();
          }
          final groups = _groupSessions(sessions);
          return _UpcomingList(groups: groups);
        },
        loading: () => const _UpcomingSkeleton(),
        error: (error, _) => ErrorState(
          message: l10n.upcomingLoadFailed('$error'),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(upcomingSessionsProvider),
        ),
      ),
      // Show FAB only when data is available, matching GridPage behaviour.
      floatingActionButton: upcomingAsync.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => SessionEditSheet.showCreate(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.addSession),
            )
          : null,
    );
  }

  List<_SessionGroup> _groupSessions(List<CourseSession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(Duration(days: 7 - today.weekday));

    final groups = <SessionGroupKind, List<CourseSession>>{};
    final laterLabelDate = weekEnd.add(const Duration(days: 1));

    for (final session in sessions) {
      final sessionDate = DateTime(
        session.date.year,
        session.date.month,
        session.date.day,
      );
      final SessionGroupKind kind;
      if (sessionDate == today) {
        kind = SessionGroupKind.today;
      } else if (sessionDate == tomorrow) {
        kind = SessionGroupKind.tomorrow;
      } else if (!sessionDate.isAfter(weekEnd)) {
        kind = SessionGroupKind.thisWeek;
      } else {
        kind = SessionGroupKind.later;
      }
      groups.putIfAbsent(kind, () => []).add(session);
    }

    const order = [
      SessionGroupKind.today,
      SessionGroupKind.tomorrow,
      SessionGroupKind.thisWeek,
      SessionGroupKind.later,
    ];
    final result = <_SessionGroup>[];
    for (final kind in order) {
      final list = groups[kind];
      if (list != null) {
        result.add(_SessionGroup(
          kind: kind,
          laterDate: kind == SessionGroupKind.later ? laterLabelDate : null,
          sessions: list,
        ));
        groups.remove(kind);
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _SessionGroup {
  const _SessionGroup({
    required this.kind,
    required this.sessions,
    this.laterDate,
  });

  final SessionGroupKind kind;
  final DateTime? laterDate;
  final List<CourseSession> sessions;
}

// ---------------------------------------------------------------------------
// Flat list items (header vs. session card)
// ---------------------------------------------------------------------------

sealed class _FlatItem {}

class _HeaderItem extends _FlatItem {
  _HeaderItem(this.label);
  final String label;
}

class _SessionItem extends _FlatItem {
  _SessionItem(this.session);
  final CourseSession session;
}

// ---------------------------------------------------------------------------
// List widget — fully flat ListView.builder with a per-minute time refresh
// ---------------------------------------------------------------------------

class _UpcomingList extends StatefulWidget {
  const _UpcomingList({required this.groups});

  final List<_SessionGroup> groups;

  @override
  State<_UpcomingList> createState() => _UpcomingListState();
}

class _UpcomingListState extends State<_UpcomingList> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _groupLabel(AppLocalizations l10n, _SessionGroup group) {
    switch (group.kind) {
      case SessionGroupKind.today:
        return l10n.groupToday;
      case SessionGroupKind.tomorrow:
        return l10n.groupTomorrow;
      case SessionGroupKind.thisWeek:
        return l10n.groupThisWeek;
      case SessionGroupKind.later:
        final date = group.laterDate ?? DateTime.now();
        return l10n.groupLater(DateFormat('M/d').format(date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Flatten groups into a single list so ListView.builder is truly lazy.
    final items = <_FlatItem>[];
    for (final group in widget.groups) {
      items.add(_HeaderItem(_groupLabel(l10n, group)));
      for (final session in group.sessions) {
        items.add(_SessionItem(session));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          _HeaderItem(:final label) => SectionHeader(title: label),
          _SessionItem(:final session) =>
            _SessionCard(session: session, now: _now),
        };
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Session card — no IntrinsicHeight; left colour bar has a fixed height
// ---------------------------------------------------------------------------

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.now});

  final CourseSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPast = isSessionPast(now, session.endAt);
    final isOngoing = isSessionOngoing(now, session.startAt, session.endAt);
    final highlight = shouldHighlightUpcomingCard(now, session);

    final startLabel =
        '${session.startAt.hour.toString().padLeft(2, '0')}:${session.startAt.minute.toString().padLeft(2, '0')}';
    final endLabel =
        '${session.endAt.hour.toString().padLeft(2, '0')}:${session.endAt.minute.toString().padLeft(2, '0')}';

    return Card(
      color: highlight ? colorScheme.primaryContainer.withAlpha(80) : null,
      child: GestureDetector(
        onLongPress: () => SessionActionMenu.show(
          context: context,
          ref: ref,
          session: session,
        ),
        onSecondaryTapDown: (details) => SessionActionMenu.show(
          context: context,
          ref: ref,
          session: session,
          position: details.globalPosition,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => SessionDetailSheet.show(context, session),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Fixed-height colour bar — no IntrinsicHeight needed.
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isOngoing
                        ? colorScheme.primary
                        : isPast
                            ? colorScheme.outlineVariant
                            : colorScheme.secondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        session.courseName,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: isPast
                                      ? colorScheme.onSurfaceVariant
                                      : null,
                                  decoration: isPast
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$startLabel – $endLabel  ·  ${session.room}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      ),
                      if (session.teachers.isNotEmpty)
                        Text(
                          session.teachers.join('、'),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: Center(
                    child: SessionCountdownLabel(session: session, now: now),
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

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyState(
      icon: Icons.check_circle_outline,
      title: l10n.upcomingEmptyTitle,
      subtitle: l10n.upcomingEmptySubtitle,
      action: OutlinedButton(
        onPressed: () => navigateToAppTab(ref, AppTab.grid),
        child: Text(l10n.upcomingGoToGrid),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading screen
// ---------------------------------------------------------------------------

class _UpcomingSkeleton extends StatelessWidget {
  const _UpcomingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SkeletonSection(cardCount: 3),
        _SkeletonSection(cardCount: 2),
      ],
    );
  }
}

class _SkeletonSection extends StatelessWidget {
  const _SkeletonSection({required this.cardCount});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SkeletonBox(height: 14, width: 80, radius: 4),
        ),
        for (var i = 0; i < cardCount; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SkeletonBox(width: 4, height: 52, radius: 2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 14, radius: 4),
                        const SizedBox(height: 8),
                        SkeletonBox(height: 12, width: 160, radius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SkeletonBox(width: 60, height: 32, radius: 8),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
