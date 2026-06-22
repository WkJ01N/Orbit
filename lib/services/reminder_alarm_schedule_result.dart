import 'package:orbit/models/reminder_alarm_spec.dart';

class ReminderAlarmScheduleResult {
  const ReminderAlarmScheduleResult({
    required this.scheduled,
    required this.failedSpecs,
  });

  final int scheduled;
  final List<ReminderAlarmSpec> failedSpecs;

  int get failed => failedSpecs.length;
}
