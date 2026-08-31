enum ReminderScheduleBlockReason { notificationsDenied, exactAlarmsDenied }

class ReminderScheduleReport {
  const ReminderScheduleReport({
    required this.expected,
    required this.scheduled,
    required this.pending,
    required this.failed,
    this.usedInexactFallback = false,
    this.blockReason,
  });

  final int expected;
  final int scheduled;
  final int pending;
  final int failed;
  final bool usedInexactFallback;
  final ReminderScheduleBlockReason? blockReason;

  bool get isBlocked => blockReason != null;
  bool get verificationFailed => expected > 0 && pending == 0;

  static const empty = ReminderScheduleReport(
    expected: 0,
    scheduled: 0,
    pending: 0,
    failed: 0,
  );
}

enum ReminderTestFailure {
  notificationsDenied,
  exactAlarmsDenied,
  schedulingFailed,
}

class ReminderTestResult {
  const ReminderTestResult.success({this.fireAt})
    : succeeded = true,
      failure = null;

  const ReminderTestResult.failure(this.failure)
    : succeeded = false,
      fireAt = null;

  final bool succeeded;
  final DateTime? fireAt;
  final ReminderTestFailure? failure;
}
