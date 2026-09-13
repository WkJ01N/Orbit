/// Alarm and notification id ranges used across Orbit.
///
/// Class-lead and check-in ids must stay aligned between
/// [ReminderScheduler] and [buildReminderAlarmSpecs].
const classLeadAlarmBase = 1;
const checkInAlarmBase = 500000;
const checkInAlarmLimit = 1000000;
const nextDaySummaryAlarmBase = 1000000;
const nextDaySummaryAlarmLimit = nextDaySummaryAlarmBase + 30;

/// Background maintenance and diagnostics — outside course reminder ranges.
const maintenanceAlarmId = 2000000;
const backgroundTestNotificationId = 2000001;
const immediateTestNotificationId = 2000002;

bool isCourseReminderNotificationId(int id) {
  return (id >= classLeadAlarmBase && id < checkInAlarmLimit) ||
      (id >= nextDaySummaryAlarmBase && id < nextDaySummaryAlarmLimit) ||
      id >= 3000000;
}
