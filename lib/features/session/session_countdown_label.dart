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
      return Container(
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
      );
    }

    final parts = computeCountdownParts(now, session.startAt);
    final soon = isSessionStartingSoon(now, session.startAt);
    final label = l10n.countdownStartsIn(parts.days, parts.hours, parts.minutes);

    return Text(
      soon ? l10n.countdownSoon(label) : label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: soon ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontWeight: soon ? FontWeight.w700 : FontWeight.w500,
          ),
      textAlign: TextAlign.end,
    );
  }
}

bool shouldHighlightUpcomingCard(DateTime now, CourseSession session) {
  return isSessionOngoing(now, session.startAt, session.endAt) ||
      isSessionStartingSoon(now, session.startAt);
}
