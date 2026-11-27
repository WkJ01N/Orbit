import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/routing/notification_listener.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/notification_providers.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/wemust_launcher.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Launcher extends WemustLauncher {
  @override
  bool get supported => true;
}

class _UnsupportedLauncher extends WemustLauncher {
  @override
  bool get supported => false;
}

class _UnusedDatabase implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends ScheduleRepository {
  _Repository() : super(_UnusedDatabase(), XlsxParser());
  @override
  Future<CourseSession?> getSessionById(String id) async => switch (id) {
    'example' => _session,
    'exam' => _session.copyWith(id: 'exam', kind: SessionKind.exam),
    _ => null,
  };
}

class _Scheduler extends ReminderScheduler {
  _Scheduler() : super.forTesting();
  @override
  Future<String?> getLaunchNotificationPayload() async => null;
}

class _Reminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
}

final _session = CourseSession(
  id: 'example',
  classType: '',
  room: 'A101',
  date: DateTime(2026, 10, 17),
  weekday: 6,
  courseName: 'Mathematics',
  courseCode: 'MATH101',
  section: '1',
  startAt: DateTime(2026, 10, 17, 9),
  endAt: DateTime(2026, 10, 17, 10),
  teachers: const [],
  faculty: '',
  semester: '',
);

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> showNotifications(
    WidgetTester tester, {
    String? initial,
    DateTime Function()? clock,
    required Future<String> Function(bool timetable) onOpen,
  }) async {
    const window = MethodChannel('window_manager');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(window, (_) async => false);
    messenger.setMockMethodCallHandler(WemustLauncher.channel, (call) async {
      return onOpen(call.arguments['timetable'] as bool);
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(window, null);
      messenger.setMockMethodCallHandler(WemustLauncher.channel, null);
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(_Repository()),
          reminderSchedulerProvider.overrideWithValue(_Scheduler()),
          reminderSettingsProvider.overrideWith(_Reminders.new),
          currentTimeClockProvider.overrideWithValue(
            clock ?? () => _session.startAt,
          ),
          strongCourseIdsProvider.overrideWith((ref) async => {}),
          wemustLauncherProvider.overrideWithValue(_Launcher()),
          foregroundReminderMaintenanceSupportedProvider.overrideWithValue(
            false,
          ),
          pendingNotificationPayloadProvider.overrideWith((ref) => initial),
        ],
        child: _app(
          const OrbitNotificationListener(child: Scaffold(body: Text('ready'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(OrbitNotificationListener)),
      listen: false,
    );
  }

  for (final cold in [true, false]) {
    testWidgets(
      'check-in tap opens once with its return sheet ready (cold=$cold)',
      (tester) async {
        final calls = <bool>[];
        final container = await showNotifications(
          tester,
          initial: cold ? 'checkin_example' : null,
          onOpen: (timetable) async {
            expect(find.byType(SessionDetailSheet), findsOneWidget);
            expect(find.text(_session.courseName), findsOneWidget);
            calls.add(timetable);
            return 'linkLaunched';
          },
        );
        final tap = container.read(notificationTapHandlerProvider);
        if (!cold) {
          expect(calls, isEmpty);
          tap(jsonEncode({'session': 'checkin_example'}));
          tap('checkin_example');
          await tester.pumpAndSettle();
        }
        expect(calls, [true]);
        expect(container.read(pendingNotificationPayloadProvider), isNull);
        expect(find.byKey(const Key('wemust-open-timetable')), findsOneWidget);
        tap(jsonEncode({'session': 'checkin_example'}));
        tap('checkin_example');
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(calls, [true]);
        expect(find.byType(SessionDetailSheet), findsOneWidget);
        expect(find.byKey(const Key('wemust-open-app')), findsNothing);
        Navigator.of(tester.element(find.byType(SessionDetailSheet))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(SessionDetailSheet), findsNothing);
        tap('checkin_example');
        await tester.pumpAndSettle();
        expect(calls, [true, true]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dismissed in [false, true]) {
    testWidgets(
      'tap waits for the visible return route and foreground (dismissed=$dismissed)',
      (tester) async {
        final calls = <bool>[];
        final container = await showNotifications(
          tester,
          onOpen: (timetable) async {
            calls.add(timetable);
            return 'linkLaunched';
          },
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        container.read(notificationTapHandlerProvider)('checkin_example');
        await tester.pumpAndSettle();
        final sheet = find.byType(SessionDetailSheet);
        expect(sheet, findsOneWidget);
        expect(calls, isEmpty);
        if (dismissed) {
          Navigator.of(tester.element(sheet)).pop();
          await tester.pumpAndSettle();
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(calls, dismissed ? isEmpty : equals([true]));
      },
    );
  }

  testWidgets(
    'ordinary notification and manual detail open the timetable only on tap',
    (tester) async {
      final calls = <bool>[];
      await showNotifications(
        tester,
        initial: 'example',
        clock: () => _session.startAt.add(const Duration(minutes: 10)),
        onOpen: (timetable) async {
          calls.add(timetable);
          return 'linkLaunched';
        },
      );
      expect(calls, isEmpty);
      final sheet = find.byType(SessionDetailSheet);
      final navigator = Navigator.of(tester.element(sheet));
      navigator.pop();
      await tester.pumpAndSettle();
      unawaited(
        SessionDetailSheet.show(tester.element(find.text('ready')), _session),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      final button = find.byKey(const Key('wemust-open-timetable'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, [true]);
    },
  );

  testWidgets(
    'manual entry follows the hour around class start on an open sheet',
    (tester) async {
      var now = _session.startAt.subtract(const Duration(days: 1));
      final container = await showNotifications(
        tester,
        clock: () => now,
        onOpen: (_) => fail('Changing course status must not launch WeMust'),
      );
      unawaited(
        SessionDetailSheet.show(tester.element(find.text('ready')), _session),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('wemust-open-timetable'));
      final clock = container.read(currentTimeProvider.notifier);
      expect(button, findsNothing);

      now = _session.startAt.subtract(const Duration(minutes: 30, seconds: 1));
      clock.syncNow();
      await tester.pump();
      expect(button, findsNothing);
      now = _session.startAt.subtract(const Duration(minutes: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(button, findsOneWidget);

      now = _session.startAt.subtract(const Duration(seconds: 1));
      clock.syncNow();
      await tester.pump();
      expect(button, findsOneWidget);
      now = _session.startAt;
      await tester.pump(const Duration(seconds: 1));
      expect(button, findsOneWidget);
      now = _session.startAt.add(const Duration(minutes: 29, seconds: 59));
      clock.syncNow();
      await tester.pump();
      expect(button, findsOneWidget);
      now = _session.startAt.add(const Duration(minutes: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(button, findsNothing);
      now = _session.endAt.add(const Duration(minutes: 1));
      clock.syncNow();
      await tester.pump();
      expect(button, findsNothing);
      expect(find.byType(SessionDetailSheet), findsOneWidget);
    },
  );

  testWidgets('stale check-in for an exam or missing course never launches', (
    tester,
  ) async {
    final calls = <bool>[];
    final container = await showNotifications(
      tester,
      initial: 'checkin_missing',
      clock: () => _session.startAt.subtract(const Duration(minutes: 10)),
      onOpen: (timetable) async {
        calls.add(timetable);
        return 'linkLaunched';
      },
    );
    expect(find.byType(SessionDetailSheet), findsNothing);
    container.read(notificationTapHandlerProvider)('checkin_exam');
    await tester.pumpAndSettle();
    expect(find.byType(SessionDetailSheet), findsOneWidget);
    expect(find.byKey(const Key('wemust-open-timetable')), findsNothing);
    expect(calls, isEmpty);
  });

  for (final checkInOpen in [false, true]) {
    testWidgets(
      'failed link offers a manual fallback (checkInOpen=$checkInOpen)',
      (tester) async {
        final calls = <bool>[];
        final pending = Completer<String>();
        await showNotifications(
          tester,
          initial: 'checkin_example',
          clock: () =>
              _session.startAt.add(Duration(minutes: checkInOpen ? 5 : 31)),
          onOpen: (timetable) {
            calls.add(timetable);
            return timetable ? pending.future : Future.value('appLaunched');
          },
        );
        final button = find.byKey(const Key('wemust-open-timetable'));
        if (checkInOpen) {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pump();
        } else {
          expect(button, findsNothing);
        }
        expect(calls, [true]);
        pending.complete('timetableUnavailable');
        await tester.pumpAndSettle();
        final fallback = find.byKey(const Key('wemust-open-app'));
        expect(
          find.textContaining('could not open the timetable link'),
          findsOneWidget,
        );
        expect(calls, [true]);
        await tester.ensureVisible(fallback);
        await tester.tap(fallback);
        await tester.pumpAndSettle();
        expect(calls, [true, false]);
        expect(find.byType(SessionDetailSheet), findsOneWidget);
      },
    );
  }

  for (final result in ['notInstalled', 'failed']) {
    testWidgets('check-in failure $result leaves an explanation and retry', (
      tester,
    ) async {
      var attempts = 0;
      await showNotifications(
        tester,
        initial: 'checkin_example',
        clock: () => _session.startAt.add(const Duration(minutes: 31)),
        onOpen: (timetable) async {
          expect(timetable, isTrue);
          return ++attempts == 1 ? result : 'linkLaunched';
        },
      );
      final message = result == 'notInstalled'
          ? 'WeMust is not installed.'
          : 'Could not open WeMust.';
      expect(find.textContaining(message), findsOneWidget);
      expect(find.byKey(const Key('wemust-open-app')), findsNothing);
      expect(find.byKey(const Key('wemust-open-timetable')), findsNothing);
      final retry = find.widgetWithText(TextButton, 'Retry');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(retry, findsNothing);
      expect(find.textContaining(message), findsNothing);
    });
  }

  testWidgets(
    'unsupported platform hides the action even for a check-in notification',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            strongCourseIdsProvider.overrideWith((ref) async => {}),
            wemustLauncherProvider.overrideWithValue(_UnsupportedLauncher()),
            currentTimeClockProvider.overrideWithValue(
              () => _session.startAt.subtract(const Duration(minutes: 10)),
            ),
          ],
          child: _app(
            Scaffold(
              body: SessionDetailSheet(
                session: _session,
                fromCheckInReminder: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wemust-open-timetable')), findsNothing);
    },
  );

  test('platform refusal returns a recoverable failure', () async {
    testerMessenger(MethodCall call) async =>
        throw PlatformException(code: 'denied');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(WemustLauncher.channel, testerMessenger);
    addTearDown(
      () => messenger.setMockMethodCallHandler(WemustLauncher.channel, null),
    );
    expect(await _Launcher().open(), WemustLaunchResult.failed);
  });
}
