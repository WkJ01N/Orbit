import 'dart:ffi';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/windows_notification_worker.dart';

WindowsNotificationBackend _nativeBackend() => NativeWindowsNotificationBackend(
  initializationSettings: const WindowsInitializationSettings(
    appName: 'Orbit Reminder Test',
    appUserModelId: 'com.must.orbit.reminder-test',
    guid: '8f8d9c2a-4b1e-4f6a-9c3d-2e1f0a9b8c7d',
  ),
);

void main() {
  test(
    'native Windows queue accepts strong audio and acknowledgement XML',
    () async {
      final ole = DynamicLibrary.open('ole32.dll');
      final kernel = DynamicLibrary.open('kernel32.dll');
      final allocate = kernel
          .lookupFunction<
            Pointer<Void> Function(Uint32, IntPtr),
            Pointer<Void> Function(int, int)
          >('LocalAlloc');
      final free = kernel
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>),
            Pointer<Void> Function(Pointer<Void>)
          >('LocalFree');
      final increment = ole
          .lookupFunction<
            Int32 Function(Pointer<Pointer<Void>>),
            int Function(Pointer<Pointer<Void>>)
          >('CoIncrementMTAUsage');
      final decrement = ole
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('CoDecrementMTAUsage');
      final cookie = allocate(0, sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
      final worker = WindowsNotificationWorker(backendFactory: _nativeBackend);
      const id = 3000001;
      var registered = false;
      try {
        expect(increment(cookie), greaterThanOrEqualTo(0));
        await worker.initialize();
        registered = true;
        await worker.schedule(
          ReminderAlarmSpec(
            alarmId: id,
            notificationId: id,
            fireAt: DateTime.now().add(const Duration(minutes: 15)),
            title: 'Course & reminder',
            body: '<Preview>',
            payload: 'session',
            ruleId: 'rule',
            sessionId: 'session',
            acknowledgeLabel: 'Acknowledge',
            stopLabel: 'Stop',
            strong: const StrongReminderSettings(enabled: true),
          ),
        );
        expect(await worker.pendingIds(), contains(id));
        await worker.cancel(id);
        expect(await worker.pendingIds(), isNot(contains(id)));
      } finally {
        if (registered) await worker.cancel(id);
        worker.dispose();
        decrement(cookie.value);
        free(cookie.cast<Void>());
      }
    },
    skip:
        !Platform.isWindows ||
        Platform.environment['ORBIT_NATIVE_REMINDER_SMOKE'] != '1',
  );
}
