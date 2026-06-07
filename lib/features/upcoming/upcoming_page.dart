import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/core/widgets/section_header.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: l10n.upcomingLoadFailed('$error'),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(upcomingSessionsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => SessionEditSheet.showCreate(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.addSession),
      ),
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
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.groups.length,
      itemBuilder: (context, index) {
        final group = widget.groups[index];
        return _GroupSection(
          label: _groupLabel(l10n, group),
          sessions: group.sessions,
          now: _now,
        );
      },
    );
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
        final formatted = DateFormat('M/d').format(date);
        return l10n.groupLater(formatted);
    }
  }
}

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

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.label,
    required this.sessions,
    required this.now,
  });

  final String label;
  final List<CourseSession> sessions;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: label),
        for (final session in sessions)
          _SessionCard(session: session, now: now),
      ],
    );
  }
}

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
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.courseName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isPast ? colorScheme.onSurfaceVariant : null,
                            decoration:
                                isPast ? TextDecoration.lineThrough : null,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$startLabel – $endLabel  ·  ${session.room}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (session.teachers.isNotEmpty)
                      Text(
                        session.teachers.join('、'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  width: 88,
                  child: SessionCountdownLabel(session: session, now: now),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

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
