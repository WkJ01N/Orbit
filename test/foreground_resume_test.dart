import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/providers/notification_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/routing/notification_listener.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/reminder_scheduler.dart';

class _Scheduler extends ReminderScheduler {
  _Scheduler() : super.forTesting();
  int checks = 0;
  int launchReads = 0;
  @override
  Future<bool> shouldResyncOnForeground() async {
    checks++;
    return true;
  }

  @override
  Future<String?> getLaunchNotificationPayload() async {
    launchReads++;
    return null;
  }
}

class _Reminders extends ReminderSettingsNotifier {
  int syncs = 0;
  Completer<int>? running;
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
  @override
  Future<int> resyncReminders() {
    syncs++;
    return (running = Completer<int>()).future;
  }
}

void main() {
  testWidgets(
    'notification payload supplied at hidden startup is handled once',
    (tester) async {
      const window = MethodChannel('window_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        window,
        (_) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          window,
          null,
        ),
      );
      final scheduler = _Scheduler();
      final container = ProviderContainer(
        overrides: [
          pendingNotificationPayloadProvider.overrideWith((ref) => 'next_day'),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          reminderSettingsProvider.overrideWith(_Reminders.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: OrbitNotificationListener(
              child: Scaffold(body: Text('ready')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(appNavIndexProvider), AppTab.upcoming.index);
      expect(container.read(pendingNotificationPayloadProvider), isNull);
      expect(scheduler.launchReads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('restore paints first and coalesces repeated foreground work', (
    tester,
  ) async {
    final scheduler = _Scheduler();
    final reminders = _Reminders();
    final container = ProviderContainer(
      overrides: [
        reminderSchedulerProvider.overrideWithValue(scheduler),
        reminderSettingsProvider.overrideWith(() => reminders),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: OrbitNotificationListener(child: Scaffold(body: Text('ready'))),
        ),
      ),
    );
    await tester.pump();
    void lifecycle(AppLifecycleState state) =>
        tester.binding.handleAppLifecycleStateChanged(state);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('ready'), findsOneWidget);
    expect(scheduler.checks, 0);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 350));
    expect(scheduler.checks, 1);
    expect(reminders.syncs, 1);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));
    expect(scheduler.checks, 1);
    expect(reminders.syncs, 1);
    reminders.running!.complete(0);
    await tester.pump();
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    lifecycle(AppLifecycleState.hidden);
    await tester.pump(const Duration(milliseconds: 400));
    expect(scheduler.checks, 1);
    // A visible unfocused window still updates its time after leaving hidden.
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(scheduler.checks, 1);
    expect(tester.takeException(), isNull);
    container.dispose();
  });
}
