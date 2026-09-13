import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/startup_service.dart';

export 'database_providers.dart';
export 'navigation_providers.dart';
export 'reminder_providers.dart';
export 'schedule_providers.dart';

final startupServiceProvider = Provider<StartupService>(
  (ref) => StartupService(ref.watch(settingsServiceProvider)),
);

typedef CurrentTimeTimerFactory =
    Timer Function(Duration delay, void Function() callback);

final currentTimeClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final currentTimeTimerFactoryProvider = Provider<CurrentTimeTimerFactory>(
  (ref) =>
      (delay, callback) => Timer(delay, callback),
);

Duration durationUntilNextMinute(DateTime now) {
  final minuteStart = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  );
  return minuteStart.add(const Duration(minutes: 1)).difference(now);
}

class CurrentTimeNotifier extends Notifier<DateTime> {
  Timer? _timer;
  bool _paused = false;

  @override
  DateTime build() {
    final now = ref.watch(currentTimeClockProvider)();
    ref.onDispose(() => _timer?.cancel());
    _scheduleNextTick(now);
    return now;
  }

  void syncNow() {
    _paused = false;
    final now = ref.read(currentTimeClockProvider)();
    state = now;
    _scheduleNextTick(now);
  }

  void pauseTicks() {
    _paused = true;
    _timer?.cancel();
  }

  void _scheduleNextTick(DateTime from) {
    _timer?.cancel();
    if (_paused) return;
    final createTimer = ref.read(currentTimeTimerFactoryProvider);
    _timer = createTimer(durationUntilNextMinute(from), () {
      final now = ref.read(currentTimeClockProvider)();
      state = now;
      _scheduleNextTick(now);
    });
  }
}

/// Shared wall-clock time, updated once per minute.
///
/// Prefer this over bare [DateTime.now()] in widgets that show time-sensitive
/// state (e.g. session Chip highlights, current-time indicator) so that the
/// entire widget tree stays in sync and only rebuilds once per minute.
final currentTimeProvider = NotifierProvider<CurrentTimeNotifier, DateTime>(
  CurrentTimeNotifier.new,
);
