/// AlarmManager / notification id ranges used across Orbit.
///
/// Class-lead and check-in ids must stay aligned between
/// [ReminderScheduler] and [buildReminderAlarmSpecs].
const classLeadAlarmBase = 1;
const checkInAlarmBase = 500000;
const checkInAlarmLimit = 1000000;
const nextDaySummaryAlarmBase = 1000000;

/// System alarms — kept outside course reminder ranges.
const maintenanceAlarmId = 2000000;
const backgroundTestAlarmId = 2000001;
