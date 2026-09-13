import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/providers/app_providers.dart';

class _ControlledTimer implements Timer {
  _ControlledTimer(this.callback);

  final void Function() callback;
  bool _active = true;

  void fire() {
    if (_active) callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

void main() {
  test('durationUntilNextMinute aligns to the system minute boundary', () {
    expect(
      durationUntilNextMinute(DateTime(2026, 8, 31, 10, 12, 42, 250)),
      const Duration(seconds: 17, milliseconds: 750),
    );
    expect(
      durationUntilNextMinute(DateTime(2026, 8, 31, 10, 12)),
      const Duration(minutes: 1),
    );
  });

  test('current time notifier realigns after each tick and sync', () {
    var now = DateTime(2026, 8, 31, 10, 12, 42);
    final delays = <Duration>[];
    final timers = <_ControlledTimer>[];
    final container = ProviderContainer(
      overrides: [
        currentTimeClockProvider.overrideWithValue(() => now),
        currentTimeTimerFactoryProvider.overrideWithValue((delay, callback) {
          delays.add(delay);
          final timer = _ControlledTimer(callback);
          timers.add(timer);
          return timer;
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(currentTimeProvider), now);
    expect(delays.last, const Duration(seconds: 18));

    now = DateTime(2026, 8, 31, 10, 13);
    timers.last.fire();
    expect(container.read(currentTimeProvider), now);
    expect(delays.last, const Duration(minutes: 1));

    now = DateTime(2026, 8, 31, 11, 4, 25);
    container.read(currentTimeProvider.notifier).syncNow();
    expect(container.read(currentTimeProvider), now);
    expect(delays.last, const Duration(seconds: 35));
  });

  test('hidden app stops ticking and catches up once on restore', () {
    var now = DateTime(2026, 9, 12, 8);
    final timers = <_ControlledTimer>[];
    final container = ProviderContainer(
      overrides: [
        currentTimeClockProvider.overrideWithValue(() => now),
        currentTimeTimerFactoryProvider.overrideWithValue((delay, callback) {
          final timer = _ControlledTimer(callback);
          timers.add(timer);
          return timer;
        }),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(currentTimeProvider), now);
    final notifier = container.read(currentTimeProvider.notifier);
    notifier.pauseTicks();
    expect(timers.single.isActive, isFalse);
    now = DateTime(2026, 9, 13, 12, 34, 20);
    timers.single.fire();
    expect(container.read(currentTimeProvider), DateTime(2026, 9, 12, 8));
    notifier.syncNow();
    expect(container.read(currentTimeProvider), now);
    expect(timers.length, 2);
    expect(timers.last.isActive, isTrue);
  });
}
