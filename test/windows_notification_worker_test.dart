import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/windows_notification_worker.dart';

class _Backend implements WindowsNotificationBackend {
  void Function(String?)? onTap;
  final ids = <int>[];

  @override
  Future<void> initialize(void Function(String?) callback) async {
    onTap = callback;
  }

  @override
  Future<List<int>> pendingIds() async {
    // Simulate the synchronous Windows notification RPC, not an async delay.
    sleep(const Duration(milliseconds: 400));
    return List.of(ids);
  }

  @override
  Future<void> cancel(int id) async {
    if (id == 13) throw StateError('simulated RPC failure');
    ids.remove(id);
  }

  @override
  Future<void> schedule(ReminderAlarmSpec spec) async {
    ids.add(spec.notificationId);
  }

  @override
  Future<void> show(int id, String title, String body, String payload) async {
    onTap?.call(payload);
  }

  @override
  Future<String?> launchPayload() async => 'launch-course';
}

class _FailedBackend extends _Backend {
  @override
  Future<void> initialize(void Function(String?) callback) async {
    throw StateError('initialization unavailable');
  }
}

class _FailedQueryBackend extends _Backend {
  @override
  Future<List<int>> pendingIds() async => throw StateError('query unavailable');
}

ReminderAlarmSpec _spec(int id) => ReminderAlarmSpec(
  alarmId: id,
  notificationId: id,
  title: 'Course',
  body: 'Room',
  payload: 'course-$id',
  fireAt: DateTime.now().add(const Duration(hours: 1)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Windows queues only the earliest 3000 and persists every remaining send',
    () async {
      if (!Platform.isWindows) return;
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('orbit_capacity_test_');
      final db = await AppDatabase.open(dir.path);
      final worker = WindowsNotificationWorker(backendFactory: _Backend.new);
      try {
        final scheduler = ReminderScheduler.forTesting(windows: worker)
          ..database = db;
        final now = DateTime.now();
        final start = now.add(const Duration(hours: 2));
        final sessions = [
          for (var i = 0; i < 32; i++)
            CourseSession(
              id: 's$i',
              classType: 'Lecture',
              room: 'A',
              date: DateTime(start.year, start.month, start.day),
              weekday: start.weekday,
              courseName: 'Course',
              courseCode: 'C',
              section: 'A',
              startAt: start,
              endAt: start.add(const Duration(hours: 1)),
              teachers: [],
              faculty: 'F',
              semester: 'S',
            ),
        ];
        await scheduler.rescheduleAll(
          upcomingSessions: sessions,
          allSessions: sessions,
          settings: ReminderSettings(
            nextDaySummaryEnabled: false,
            checkInReminderEnabled: false,
            customRules: [
              CustomReminderRule(
                id: 'r',
                name: 'Rule',
                activeFrom: now,
                sendCount: 100,
                intervalSeconds: 1,
              ),
            ],
          ),
          copy: notificationCopyFor(const Locale('en')),
          requestPermissions: false,
        );
        expect(await worker.pendingIds(), hasLength(3000));
        final rows = await db.reminderSchedules();
        expect(rows, hasLength(3232));
        expect(rows.where((row) => row['queued'] == 1), hasLength(3000));
        expect(rows.where((row) => row['queued'] == 0), hasLength(232));
        expect(
          rows.where((row) => row['rule_id'] == '@builtin'),
          hasLength(32),
        );
        expect(scheduler.lastScheduleFailureCount, 0);
      } finally {
        worker.dispose();
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'Windows scheduler uses worker for course scheduling and verification',
    () async {
      if (!Platform.isWindows) return;
      final worker = WindowsNotificationWorker(backendFactory: _Backend.new);
      addTearDown(worker.dispose);
      final scheduler = ReminderScheduler.forTesting(windows: worker);
      final start = DateTime.now().add(const Duration(hours: 2));
      final session = CourseSession(
        id: 'course',
        classType: 'class',
        room: 'A101',
        date: DateTime(start.year, start.month, start.day),
        weekday: start.weekday,
        courseName: 'Course',
        courseCode: 'TEST',
        section: '1',
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        teachers: [],
        faculty: '',
        semester: '',
      );
      await scheduler.rescheduleAll(
        upcomingSessions: [session],
        allSessions: [session],
        settings: const ReminderSettings(
          enabled: true,
          checkInReminderEnabled: false,
          nextDaySummaryEnabled: false,
        ),
        copy: NotificationCopy.fromL10n(lookupL10n(const Locale('en'))),
      );
      expect(scheduler.lastScheduleReport.expected, 1);
      expect(scheduler.lastPendingCount, 1);
      expect(scheduler.lastScheduleFailureCount, 0);
      await scheduler.cancelScheduledCourseReminders();
      expect(await worker.pendingIds(), isEmpty);
    },
  );

  test(
    'Windows cancellation propagates query failure instead of brute force RPCs',
    () async {
      if (!Platform.isWindows) return;
      final worker = WindowsNotificationWorker(
        backendFactory: _FailedQueryBackend.new,
      );
      addTearDown(worker.dispose);
      final scheduler = ReminderScheduler.forTesting(windows: worker);
      await expectLater(
        scheduler.cancelScheduledCourseReminders(),
        throwsStateError,
      );
    },
  );

  test(
    'blocking notification RPC leaves the UI event loop responsive',
    () async {
      final worker = WindowsNotificationWorker(backendFactory: _Backend.new);
      addTearDown(worker.dispose);
      await worker.initialize();
      var heartbeats = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        heartbeats++;
      });
      addTearDown(timer.cancel);
      expect(await worker.pendingIds(), isEmpty);
      expect(heartbeats, greaterThanOrEqualTo(3));
    },
  );

  test(
    'live Windows activation is not replayed as a startup payload',
    () async {
      if (!Platform.isWindows) return;
      final worker = WindowsNotificationWorker(backendFactory: _Backend.new);
      final scheduler = ReminderScheduler.forTesting(windows: worker);
      try {
        var taps = 0;
        scheduler.registerNotificationTapHandler((_) => taps++);
        await scheduler.ensurePluginInitialized();
        await worker.show(1, 'Title', 'Body', 'launch-course');
        await Future<void>.delayed(Duration.zero);
        expect(taps, 1);
        expect(await scheduler.getLaunchNotificationPayload(), isNull);
      } finally {
        worker.dispose();
      }
    },
  );

  test(
    'one worker preserves ordering and forwards notification taps',
    () async {
      final worker = WindowsNotificationWorker(backendFactory: _Backend.new);
      addTearDown(worker.dispose);
      await Future.wait([worker.initialize(), worker.initialize()]);
      final tap = Completer<String?>();
      worker.onNotificationTap = tap.complete;
      await Future.wait([worker.schedule(_spec(1)), worker.schedule(_spec(2))]);
      await worker.cancel(1);
      expect(await worker.pendingIds(), [2]);
      expect(await worker.launchPayload(), 'launch-course');
      await worker.show(7, 'Title', 'Body', 'selected-course');
      expect(await tap.future, 'selected-course');
    },
  );

  test(
    'failed request does not poison subsequent notification operations',
    () async {
      final worker = WindowsNotificationWorker(backendFactory: _Backend.new);
      addTearDown(worker.dispose);
      await expectLater(worker.cancel(13), throwsStateError);
      await worker.schedule(_spec(3));
      expect(await worker.pendingIds(), [3]);
    },
  );

  test('initialization failure completes callers instead of hanging', () async {
    final worker = WindowsNotificationWorker(
      backendFactory: _FailedBackend.new,
    );
    addTearDown(worker.dispose);
    await expectLater(worker.initialize(), throwsStateError);
  });
}
