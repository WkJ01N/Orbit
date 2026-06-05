import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/alarm_intent_service.dart';
import 'package:orbit/services/startup_service.dart';

export 'database_providers.dart';
export 'navigation_providers.dart';
export 'reminder_providers.dart';
export 'schedule_providers.dart';

final alarmIntentServiceProvider =
    Provider<AlarmIntentService>((ref) => AlarmIntentService());

final startupServiceProvider = Provider<StartupService>(
  (ref) => StartupService(ref.watch(settingsServiceProvider)),
);
