import 'dart:async';

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

class _CurrentTimeNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final timer = Timer.periodic(const Duration(minutes: 1), (_) {
      state = DateTime.now();
    });
    ref.onDispose(timer.cancel);
    return DateTime.now();
  }
}

/// Shared wall-clock time, updated once per minute.
///
/// Prefer this over bare [DateTime.now()] in widgets that show time-sensitive
/// state (e.g. session Chip highlights, current-time indicator) so that the
/// entire widget tree stays in sync and only rebuilds once per minute.
final currentTimeProvider = NotifierProvider<_CurrentTimeNotifier, DateTime>(
  _CurrentTimeNotifier.new,
);
