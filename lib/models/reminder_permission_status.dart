class ReminderPermissionStatus {
  const ReminderPermissionStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsEnabled;

  bool get allGranted => notificationsEnabled && exactAlarmsEnabled;

  static const unknown = ReminderPermissionStatus(
    notificationsEnabled: false,
    exactAlarmsEnabled: false,
  );
}
