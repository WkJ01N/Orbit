enum ReminderResyncBannerKind { verify, partial, error }

ReminderResyncBannerKind? reminderResyncBannerKind(String? error) {
  if (error == null) {
    return null;
  }
  if (error == 'verify') {
    return ReminderResyncBannerKind.verify;
  }
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
