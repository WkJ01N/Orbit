enum ReminderResyncBannerKind { verify, partial, error, maintenance, strong }

ReminderResyncBannerKind? reminderResyncBannerKind(String? error) {
  if (error == null) {
    return null;
  }
  if (error == 'verify') {
    return ReminderResyncBannerKind.verify;
  }
  if (error == 'maintenance') return ReminderResyncBannerKind.maintenance;
  if (error == 'strong') return ReminderResyncBannerKind.strong;
  if (error.startsWith('partial:')) {
    return ReminderResyncBannerKind.partial;
  }
  return ReminderResyncBannerKind.error;
}

int? reminderPartialFailureCount(String? error) {
  if (error == null || !error.startsWith('partial:')) {
    return null;
  }
  return int.tryParse(error.substring('partial:'.length));
}
