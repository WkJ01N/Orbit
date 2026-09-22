import 'package:orbit/providers/course_color_providers.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/core/widgets/section_header.dart';
import 'package:orbit/core/widgets/skeleton_box.dart';
import 'package:orbit/features/search/session_search_page.dart';
import 'package:orbit/features/deadline/deadline_ui.dart';
import 'package:orbit/features/session/session_action_menu.dart';
import 'package:orbit/features/session/session_add_action.dart';
import 'package:orbit/features/session/session_countdown.dart';
import 'package:orbit/features/session/session_countdown_label.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/features/upcoming/upcoming_scroll_to_top.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/course_color_utils.dart';

enum SessionGroupKind { today, tomorrow, thisWeek, later }

class UpcomingPage extends ConsumerWidget {
  const UpcomingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final upcomingAsync = ref.watch(upcomingSessionsProvider);
    final deadlines =
        ref.watch(deadlinesProvider).valueOrNull ?? const <Deadline>[];

    return Scaffold(
      appBar: AppBar(
        leading: upcomingAsync.hasValue
            ? IconButton(
                key: const Key('upcoming-add-session'),
                icon: const Icon(Icons.add, size: 21),
                tooltip: l10n.addSession,
                onPressed: () => showSessionAddAction(context),
              )
            : null,
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
          if (sessions.isEmpty && deadlines.isEmpty) {
            return const _EmptyState();
          }
          final groups = _groupSessions(sessions);
          return _UpcomingList(groups: groups, deadlines: deadlines);
        },
        loading: () => const _UpcomingSkeleton(),
        error: (error, _) => ErrorState(
          message: l10n.upcomingLoadFailed('$error'),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(upcomingSessionsProvider),
        ),
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
        result.add(
          _SessionGroup(
            kind: kind,
            laterDate: kind == SessionGroupKind.later ? laterLabelDate : null,
            sessions: list,
          ),
        );
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

class _WeekHeaderItem extends _FlatItem {
  _WeekHeaderItem(this.monday);
  final DateTime monday;
}

class _DeadlineItem extends _FlatItem {
  _DeadlineItem(this.deadline);
  final Deadline deadline;
}

// ---------------------------------------------------------------------------
// List widget — fully flat lazy sliver list with a per-minute time refresh
// ---------------------------------------------------------------------------

class _UpcomingList extends StatefulWidget {
  const _UpcomingList({required this.groups, required this.deadlines});

  final List<_SessionGroup> groups;
  final List<Deadline> deadlines;

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
    final locale = Localizations.localeOf(context).toString();

    // Flatten groups into a single list so course cards remain truly lazy.
    final items = <_FlatItem>[];
    if (widget.deadlines.isNotEmpty) {
      items.add(_HeaderItem(DeadlineText.of(context).ddl));
      for (final deadline in widget.deadlines.where((d) => !d.completed)) {
        items.add(_DeadlineItem(deadline));
      }
      if (widget.deadlines.any((d) => d.completed)) {
        items.add(_HeaderItem(DeadlineText.of(context).completed));
        for (final deadline in widget.deadlines.where((d) => d.completed)) {
          items.add(_DeadlineItem(deadline));
        }
      }
    }
    final seenWeeks = <DateTime>{};
    for (final group in widget.groups) {
      items.add(_HeaderItem(_groupLabel(l10n, group)));
      for (final session in group.sessions) {
        final date = DateTime(
          session.date.year,
          session.date.month,
          session.date.day,
        );
        final monday = date.subtract(Duration(days: date.weekday - 1));
        if (seenWeeks.add(monday)) {
          items.add(_WeekHeaderItem(monday));
        }
        items.add(_SessionItem(session));
      }
    }

    return UpcomingScrollToTop(
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return switch (item) {
            _HeaderItem(:final label) => SectionHeader(title: label),
            _WeekHeaderItem(:final monday) => _WeekMarker(
              monday: monday,
              label: l10n.upcomingWeekMonday(
                DateFormat.yMd(locale).format(monday),
              ),
            ),
            _SessionItem(:final session) => _SessionCard(
              session: session,
              now: _now,
            ),
            _DeadlineItem(:final deadline) => DeadlineListTile(
              deadline: deadline,
            ),
          };
        },
      ),
    );
  }
}

class _WeekMarker extends StatelessWidget {
  const _WeekMarker({required this.label, required this.monday});

  final String label;
  final DateTime monday;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: Key(
        'upcoming-week-marker-${monday.year}-${monday.month}-${monday.day}',
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 2),
      child: Row(
        children: [
          Icon(
            Icons.calendar_view_week_outlined,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    final overrides = ref.watch(courseColorOverridesProvider);
    final themeStyle = appThemeStyleOf(context);
    final displaySettings = ref.watch(scheduleDisplaySettingsProvider);
    final multi = ref.watch(multicolorSettingsProvider);
    final accent = resolvedCourseColor(
      palette: multi.enabled ? multi.palette : const [],
      session: session,
      automaticColorId: themeStyle == AppThemeStyle.colorful
          ? ref.watch(
              resolvedAutomaticCourseColorIdsProvider,
            )[automaticCourseColorKey(session)]
          : null,
      colorScheme: colorScheme,
      themeStyle: themeStyle,
      override: overrides[courseColorKey(session)],
    );
    final isPast = isSessionPast(now, session.endAt);
    final isOngoing = isSessionOngoing(now, session.startAt, session.endAt);
    final highlight = shouldHighlightUpcomingCard(now, session);

    final startLabel =
        '${session.startAt.hour.toString().padLeft(2, '0')}:${session.startAt.minute.toString().padLeft(2, '0')}';
    final endLabel =
        '${session.endAt.hour.toString().padLeft(2, '0')}:${session.endAt.minute.toString().padLeft(2, '0')}';

    return Card(
      color: courseCardSurface(
        accent: accent,
        colorScheme: colorScheme,
        themeStyle: themeStyle,
        highlighted: highlight,
        isPast: isPast,
      ),
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
                        ? accent
                        : isPast
                        ? colorScheme.outlineVariant
                        : accent,
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isPast ? colorScheme.onSurfaceVariant : null,
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (session.teachers.isNotEmpty)
                        Text(
                          session.teachers.join('、'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 112,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (displaySettings.showUpcomingCourseDate) ...[
                        Text(
                          _upcomingDateLabel(
                            context,
                            session,
                            displaySettings.upcomingDateDisplay,
                          ),
                          key: Key('upcoming-course-date-${session.id}'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Center(
                        child: SessionCountdownLabel(
                          session: session,
                          now: now,
                          centered: true,
                        ),
                      ),
                    ],
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

String _upcomingDateLabel(
  BuildContext context,
  CourseSession session,
  UpcomingDateDisplay display,
) {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).toString();
  final date = DateFormat.Md(locale).format(session.date);
  final weekday = weekdayLabel(l10n, session.date.weekday);
  return switch (display) {
    UpcomingDateDisplay.dateAndWeekday => '$date $weekday',
    UpcomingDateDisplay.dateOnly => date,
    UpcomingDateDisplay.weekdayOnly => weekday,
  };
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
