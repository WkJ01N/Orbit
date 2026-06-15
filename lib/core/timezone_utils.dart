import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Configures [tz.local] for reminder scheduling. Prefers the device IANA
/// timezone name; falls back to a fixed-offset [Etc/GMT] location.
Future<void> configureReminderTimezone() async {
  tz_data.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
    return;
  } catch (_) {
    // Fall through to offset-based location.
  }
  final offsetHours = DateTime.now().timeZoneOffset.inHours;
  final locationName = _etcLocationName(offsetHours);
  try {
    tz.setLocalLocation(tz.getLocation(locationName));
  } catch (_) {
    try {
      tz.setLocalLocation(tz.UTC);
    } catch (_) {
      // timezone already initialized
    }
  }
}

/// Builds a [tz.TZDateTime] from a local wall-clock [DateTime] using [tz.local].
tz.TZDateTime reminderAtToTzDateTime(DateTime reminderAt) {
  return tz.TZDateTime(
    tz.local,
    reminderAt.year,
    reminderAt.month,
    reminderAt.day,
    reminderAt.hour,
    reminderAt.minute,
    reminderAt.second,
  );
}

/// Whether [reminderAt] falls within [horizon] of [now] (inclusive of now).
bool isWithinNearTermHorizon(
  DateTime reminderAt,
  DateTime now,
  Duration horizon,
) {
  final delay = reminderAt.difference(now);
  return !delay.isNegative && delay <= horizon;
}

String _etcLocationName(int offsetHours) {
  if (offsetHours == 0) {
    return 'UTC';
  }
  final sign = offsetHours > 0 ? '-' : '+';
  return 'Etc/GMT$sign${offsetHours.abs()}';
}
