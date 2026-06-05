import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/schedule_summary_service.dart';

class AlarmIntentService {
  Future<AlarmIntentResult> setTomorrowFirstClassAlarm({
    required List<CourseSession> allSessions,
    required ReminderSettings settings,
    required String alarmLabel,
  }) async {
    if (!Platform.isAndroid) {
      return AlarmIntentResult.unsupportedPlatform;
    }

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final summary = summarizeDay(allSessions, tomorrow);
    if (!summary.hasClasses || summary.firstSessionStart == null) {
      return AlarmIntentResult.noClassTomorrow;
    }

    final alarmAt = summary.firstSessionStart!
        .subtract(Duration(minutes: settings.systemAlarmLeadMinutes));

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.HOUR': alarmAt.hour,
          'android.intent.extra.alarm.MINUTES': alarmAt.minute,
          'android.intent.extra.alarm.MESSAGE': alarmLabel,
          'android.intent.extra.alarm.SKIP_UI': false,
        },
      );
      await intent.launch();
      return AlarmIntentResult.success;
    } catch (_) {
      return AlarmIntentResult.failed;
    }
  }
}

enum AlarmIntentResult {
  success,
  failed,
  unsupportedPlatform,
  noClassTomorrow,
}
