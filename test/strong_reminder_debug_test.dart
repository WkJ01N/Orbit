import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/reminder_id_ranges.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/windows_notification_worker.dart';
import 'package:orbit/services/strong_session_service.dart';

class _RecordingBackend implements WindowsNotificationBackend {
  _RecordingBackend(this.path);
  final String path;
  final ids = <int>[];
  @override
  Future<void> initialize(void Function(String?) onTap) async {}
  @override
  Future<List<int>> pendingIds() async => ids;
  @override
  Future<void> cancel(int id) async {
    ids.remove(id);
  }

  @override
  Future<void> schedule(ReminderAlarmSpec spec) async {
    ids.add(spec.notificationId);
    await File(path).writeAsString(jsonEncode(spec.toJson()));
  }

  @override
  Future<void> show(int id, String title, String body, String payload) async {}
  @override
  Future<String?> launchPayload() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final enabled in [true, false]) {
    test(
      'Windows strong debug waits for correlated playback${enabled ? " and notification" : " without notification permission"}',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'orbit_native_receipt_',
        );
        final path = '${dir.path}/scheduled.json';
        final worker = WindowsNotificationWorker(
          backendFactory: () => _RecordingBackend(path),
        );
        final scheduler = ReminderScheduler.forTesting(windows: worker);
        var polls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(StrongSessionService.windows, (
              call,
            ) async {
              if (call.method == 'scheduleStrong') {
                await File(path).writeAsString(call.arguments as String);
                return null;
              }
              if (call.method == 'notificationsEnabled') return enabled;
              if (call.method == 'strongDiagnostics') {
                final key =
                    (jsonDecode(await File(path).readAsString()) as Map)['key'];
                polls++;
                final receipt = {
                  'trigger': {'key': key},
                  'audio': {'key': key, 'ok': polls > 2},
                  if (enabled) 'toast': {'key': key, 'ok': true},
                };
                return jsonEncode(
                  enabled
                      ? {
                          // Another concurrent reminder may replace the latest global receipt.
                          'toast': {'key': 'another reminder', 'ok': true},
                          'instances': {key: receipt},
                        }
                      : receipt,
                );
              }
              return null;
            });
        try {
          final result = await scheduler.testStrongReminder(
            title: 'Test',
            body: 'Body',
            copy: NotificationCopy.fromL10n(lookupL10n(const Locale('en'))),
            strong: const StrongReminderSettings(),
          );
          expect(result.succeeded, isTrue);
          expect(polls, 3);
        } finally {
          await scheduler.stopStrongTests();
          worker.dispose();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(StrongSessionService.windows, null);
          await dir.delete(recursive: true);
        }
      },
      skip: !Platform.isWindows,
    );
  }
  test(
    'Windows debug rejects a queued reminder with no actual playback receipt',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'orbit_missing_receipt_',
      );
      final path = '${dir.path}/scheduled.json';
      final worker = WindowsNotificationWorker(
        backendFactory: () => _RecordingBackend(path),
      );
      final scheduler = ReminderScheduler.forTesting(windows: worker);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(StrongSessionService.windows, (call) async {
            if (call.method == 'scheduleStrong') {
              await File(path).writeAsString(call.arguments as String);
              return null;
            }
            if (call.method == 'notificationsEnabled') return true;
            if (call.method == 'strongDiagnostics') {
              return jsonEncode({
                'workerAlive': true,
                'trigger': {'key': 'another reminder'},
                'toast': {'ok': true},
                'audio': {'ok': true},
              });
            }
            return null;
          });
      try {
        final result = await scheduler.testStrongReminder(
          title: 'Test',
          body: 'Body',
          copy: NotificationCopy.fromL10n(lookupL10n(const Locale('en'))),
          strong: const StrongReminderSettings(),
        );
        expect(result.succeeded, isFalse);
        expect(await File(path).exists(), isTrue);
      } finally {
        await scheduler.stopStrongTests();
        worker.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(StrongSessionService.windows, null);
        await dir.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
  test(
    'strong test bypasses global filters, retains audio and uses independent IDs',
    () async {
      final dir = await Directory.systemTemp.createTemp('orbit_strong_test_');
      final path = '${dir.path}/scheduled.json';
      final worker = WindowsNotificationWorker(
        backendFactory: () => _RecordingBackend(path),
      );
      final scheduler = ReminderScheduler.forTesting(windows: worker);
      const original = StrongReminderSettings(
        enabled: false,
        onlyFirstClass: true,
        courseScope: ReminderCourseScope.sessions,
        courseKeys: [],
        soundEnabled: false,
        durationSeconds: 5,
        windowsSound: 4,
      );
      try {
        final result = await scheduler.testStrongReminder(
          title: 'Test',
          body: 'Body',
          copy: NotificationCopy.fromL10n(lookupL10n(const Locale('en'))),
          strong: original,
        );
        expect(result.succeeded, isTrue);
        final spec = ReminderAlarmSpec.fromJson(
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>,
        );
        expect(spec.notificationId, strongTestNotificationId);
        expect(isCourseReminderNotificationId(spec.notificationId), isFalse);
        expect(spec.strong.enabled, isTrue);
        expect(spec.strong.soundEnabled, isFalse);
        expect(spec.strong.windowsSound, 4);
        expect(spec.strong.durationSeconds, 5);
        expect(original.enabled, isFalse);
        expect(windowsReminderXml(spec), contains('<audio silent="true"/>'));
        await scheduler.stopStrongTests();
        expect(await worker.pendingIds(), isEmpty);
      } finally {
        await scheduler.stopStrongTests();
        worker.dispose();
        await dir.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
}
