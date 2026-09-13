import 'package:orbit/models/custom_reminder_rule.dart';

/// Platform-neutral payload used to schedule a local notification.
class ReminderAlarmSpec {
  const ReminderAlarmSpec({
    required this.alarmId,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.payload,
    required this.fireAt,
    this.bigText,
    this.ruleId,
    this.sessionId,
    this.sendIndex = 1,
    this.originalFireAt,
    this.catchUp = false,
    this.strong = const StrongReminderSettings(),
    this.acknowledgeLabel = 'Acknowledge',
    this.stopLabel = 'Stop',
  });

  /// Kept aligned with [notificationId] for stable persisted identifiers.
  final int alarmId;
  final int notificationId;
  final String title;
  final String body;
  final String payload;
  final DateTime fireAt;

  /// Optional expanded notification body for class-lead reminders.
  final String? bigText;
  final String? ruleId;
  final String? sessionId;
  final int sendIndex;
  final DateTime? originalFireAt;
  final bool catchUp;
  final StrongReminderSettings strong;
  final String acknowledgeLabel;
  final String stopLabel;

  Map<String, dynamic> toJson() {
    return {
      'alarmId': alarmId,
      'notificationId': notificationId,
      'title': title,
      'body': body,
      'payload': payload,
      'fireAt': fireAt.toIso8601String(),
      if (bigText != null) 'bigText': bigText,
      'ruleId': ruleId,
      'sessionId': sessionId,
      'sendIndex': sendIndex,
      'originalFireAt': originalFireAt?.toIso8601String(),
      'catchUp': catchUp,
      'strong': strong.toJson(),
      'acknowledgeLabel': acknowledgeLabel,
      'stopLabel': stopLabel,
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
      ruleId: json['ruleId'] as String?,
      sessionId: json['sessionId'] as String?,
      sendIndex: json['sendIndex'] as int? ?? 1,
      originalFireAt: DateTime.tryParse(
        json['originalFireAt'] as String? ?? '',
      ),
      catchUp: json['catchUp'] == true,
      strong: StrongReminderSettings.fromJson(
        json['strong'] as Map<String, dynamic>? ?? {},
      ),
      acknowledgeLabel: json['acknowledgeLabel'] as String? ?? 'Acknowledge',
      stopLabel: json['stopLabel'] as String? ?? 'Stop',
    );
  }
}
