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
import 'package:orbit/features/session/wemust_check_in_action.dart';
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

class _UnusedDatabase implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends ScheduleRepository {
  _Repository() : super(_UnusedDatabase(), XlsxParser());
  @override
  Future<CourseSession?> getSessionById(String id) async =>
      id == 'example' ? _session : null;
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

  testWidgets('only check-in notifications show entry, at cold and hot startup', (
    tester,
  ) async {
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
    for (final cold in [true, false]) {
      for (final checkin in [true, false]) {
        final payload = checkin ? 'checkin_example' : 'example';
        final container = ProviderContainer(
          overrides: [
            scheduleRepositoryProvider.overrideWithValue(_Repository()),
            reminderSchedulerProvider.overrideWithValue(_Scheduler()),
            reminderSettingsProvider.overrideWith(_Reminders.new),
            strongCourseIdsProvider.overrideWith((ref) async => {}),
            wemustLauncherProvider.overrideWithValue(_Launcher()),
            pendingNotificationPayloadProvider.overrideWith(
              (ref) => cold ? payload : null,
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _app(
              const OrbitNotificationListener(
                child: Scaffold(body: Text('ready')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!cold) {
          // Native/custom notification wrappers must preserve the legacy prefix.
          container.read(notificationTapHandlerProvider)(
            jsonEncode({'session': payload}),
          );
          await tester.pumpAndSettle();
        }
        expect(find.byType(SessionDetailSheet), findsOneWidget);
        expect(
          tester
              .widget<SessionDetailSheet>(find.byType(SessionDetailSheet))
              .fromCheckInReminder,
          checkin,
        );
        expect(
          find.byKey(const Key('wemust-open-timetable')),
          checkin ? findsOneWidget : findsNothing,
        );
        expect(container.read(pendingNotificationPayloadProvider), isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
  });

  testWidgets(
    'accepted link retains app fallback; pending tap cannot launch twice',
    (tester) async {
      final calls = <MethodCall>[];
      final pending = Completer<String>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        WemustLauncher.channel,
        (call) {
          calls.add(call);
          return calls.length == 1
              ? pending.future
              : Future.value('appLaunched');
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          WemustLauncher.channel,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wemustLauncherProvider.overrideWithValue(_Launcher())],
          child: _app(const Scaffold(body: WemustCheckInAction())),
        ),
      );
      final button = find.byKey(const Key('wemust-open-timetable'));
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(calls.length, 1);
      pending.complete('linkLaunched');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wemust-open-app')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wemust-open-app')));
      await tester.pumpAndSettle();
      expect(calls.last.arguments, {'timetable': false});
      expect(find.textContaining('open Class Timetable'), findsWidgets);
    },
  );

  for (final result in ['notInstalled', 'failed', 'appLaunched']) {
    testWidgets('launch outcome $result is explained', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        WemustLauncher.channel,
        (_) async => result,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          WemustLauncher.channel,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wemustLauncherProvider.overrideWithValue(_Launcher())],
          child: _app(const Scaffold(body: WemustCheckInAction())),
        ),
      );
      await tester.tap(find.byKey(const Key('wemust-open-timetable')));
      await tester.pumpAndSettle();
      final message = switch (result) {
        'notInstalled' => 'WeMust is not installed.',
        'failed' => 'Could not open WeMust. Please open it manually.',
        _ => 'open Class Timetable',
      };
      expect(find.textContaining(message), findsWidgets);
    });
  }

  testWidgets('unsupported desktop hides the action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wemustLauncherProvider.overrideWithValue(WemustLauncher())],
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
  });

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
