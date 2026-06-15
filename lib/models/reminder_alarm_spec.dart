/// Payload persisted for an Android [AndroidAlarmManager] one-shot reminder.
class ReminderAlarmSpec {
  const ReminderAlarmSpec({
    required this.alarmId,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.payload,
    required this.fireAt,
    this.bigText,
  });

  /// Same as [notificationId]; used as AlarmManager alarm id.
  final int alarmId;
  final int notificationId;
  final String title;
  final String body;
  final String payload;
  final DateTime fireAt;

  /// Optional expanded notification body for class-lead reminders.
  final String? bigText;

  Map<String, dynamic> toJson() {
    return {
      'alarmId': alarmId,
      'notificationId': notificationId,
      'title': title,
      'body': body,
      'payload': payload,
      'fireAt': fireAt.toIso8601String(),
      if (bigText != null) 'bigText': bigText,
    };
  }

  factory ReminderAlarmSpec.fromJson(Map<String, dynamic> json) {
    return ReminderAlarmSpec(
      alarmId: json['alarmId'] as int,
      notificationId: json['notificationId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      payload: json['payload'] as String,
      fireAt: DateTime.parse(json['fireAt'] as String),
      bigText: json['bigText'] as String?,
    );
  }
}
