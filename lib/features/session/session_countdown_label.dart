import 'package:flutter/material.dart';
import 'package:orbit/features/session/session_countdown.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';

class SessionCountdownLabel extends StatelessWidget {
  const SessionCountdownLabel({
    super.key,
    required this.session,
    required this.now,
  });

  final CourseSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (isSessionPast(now, session.endAt)) {
      return const SizedBox.shrink();
    }

    if (isSessionOngoing(now, session.startAt, session.endAt)) {
      // Vertically center the badge so it lines up with the card's accent bar.
      return Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            l10n.inClass,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      );
    }

    final parts = computeCountdownParts(now, session.startAt);
    final soon = isSessionStartingSoon(now, session.startAt);
    final label = l10n.countdownStartsIn(parts.days, parts.hours, parts.minutes);

    if (soon) {
      // Show the "soon" prefix and the countdown on separate lines so a long
      // Chinese countdown does not wrap awkwardly inside the narrow column.
      final style = Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(l10n.countdownSoonLabel, style: style, textAlign: TextAlign.end),
          Text(
            label,
            style: style,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
      textAlign: TextAlign.end,
    );
  }
}

bool shouldHighlightUpcomingCard(DateTime now, CourseSession session) {
  return isSessionOngoing(now, session.startAt, session.endAt) ||
      isSessionStartingSoon(now, session.startAt);
}
