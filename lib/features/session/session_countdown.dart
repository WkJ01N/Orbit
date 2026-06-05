class SessionCountdownParts {
  const SessionCountdownParts({
    required this.days,
    required this.hours,
    required this.minutes,
  });

  final int days;
  final int hours;
  final int minutes;
}

const sessionSoonThreshold = Duration(minutes: 30);

SessionCountdownParts computeCountdownParts(DateTime from, DateTime target) {
  var remaining = target.difference(from);
  if (remaining.isNegative) {
    remaining = Duration.zero;
  }
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  return SessionCountdownParts(days: days, hours: hours, minutes: minutes);
}

bool isSessionOngoing(DateTime now, DateTime startAt, DateTime endAt) {
  return !endAt.isBefore(now) && startAt.isBefore(now);
}

bool isSessionStartingSoon(DateTime now, DateTime startAt) {
  if (!startAt.isAfter(now)) {
    return false;
  }
  return startAt.difference(now) <= sessionSoonThreshold;
}

bool isSessionPast(DateTime now, DateTime endAt) {
  return endAt.isBefore(now);
}
