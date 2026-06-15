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

    final arguments = <String, dynamic>{
      'android.intent.extra.alarm.HOUR': alarmAt.hour,
      'android.intent.extra.alarm.MINUTES': alarmAt.minute,
      'android.intent.extra.alarm.MESSAGE': alarmLabel,
      'android.intent.extra.alarm.SKIP_UI': false,
    };

    // Try the standard SET_ALARM intent first, then fall back to known OEM
    // clock packages (e.g. OriginOS / Vivo on iQOO) whose clock app may not
    // advertise the generic action.
    final candidates = <AndroidIntent>[
      AndroidIntent(action: _setAlarmAction, arguments: arguments),
      for (final package in _oemClockPackages)
        AndroidIntent(
          action: _setAlarmAction,
          package: package,
          arguments: arguments,
        ),
    ];

    for (final intent in candidates) {
      try {
        final canResolve = await intent.canResolveActivity() ?? false;
        if (!canResolve) {
          continue;
        }
        await intent.launch();
        return AlarmIntentResult.success;
      } catch (_) {
        // Try the next candidate.
      }
    }

    // Last resort: attempt the generic intent even if resolution was reported
    // as unavailable, since some OEMs answer the launch but not the query.
    try {
      await AndroidIntent(action: _setAlarmAction, arguments: arguments)
          .launch();
      return AlarmIntentResult.success;
    } catch (_) {
      return AlarmIntentResult.failed;
    }
  }

  static const _setAlarmAction = 'android.intent.action.SET_ALARM';

  static const _oemClockPackages = <String>[
    'com.vivo.alarmclock',
    'com.android.BBKClock',
    'com.android.deskclock',
    'com.google.android.deskclock',
  ];
}

enum AlarmIntentResult {
  success,
  failed,
  unsupportedPlatform,
  noClassTomorrow,
}
