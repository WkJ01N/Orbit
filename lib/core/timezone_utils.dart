import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void configureReminderTimezone() {
  tz_data.initializeTimeZones();
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

String _etcLocationName(int offsetHours) {
  if (offsetHours == 0) {
    return 'UTC';
  }
  final sign = offsetHours > 0 ? '-' : '+';
  return 'Etc/GMT$sign${offsetHours.abs()}';
}
