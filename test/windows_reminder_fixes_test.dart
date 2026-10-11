import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/features/settings/strong_reminder_page.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/services/reminder_audio_service.dart';
import 'package:orbit/services/strong_session_service.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'strong_task_options_test.dart' show app;

class _Database implements AppDatabase {
  @override
  Future<void> saveStrongSession(
    String id,
    int expiry,
    Map<String, dynamic> state,
  ) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [320.0, 700.0]) {
    for (var count = 4; count <= 25; count++) {
      testWidgets(
        '$count numbers center the final row at width $width and keep positions',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final state = <String, dynamic>{
            'id': 'grid',
            'phase': 'task',
            'expiresAt': DateTime.now().millisecondsSinceEpoch + 120000,
            'answerDeadline': DateTime.now().millisecondsSinceEpoch + 120000,
            'settings': {'dismissTask': 'mixed'},
            'tasks': [
              {
                'type': 'sequence',
                'numbers': List.generate(count, (i) => count - i),
              },
            ],
            'taskIndex': 0,
            'taskProgress': 0,
            'records': [],
          };
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            StrongSessionService.channel,
            (_) async => jsonEncode({...state, 'wrong': true}),
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(StrongSessionService.channel, null),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [strongSessionProvider.overrideWith((_) => state)],
              child: app(const StrongConfirmationPage(), scale: 1.7),
            ),
          );
          await tester.pumpAndSettle();
          final rects = [
            for (var n = count; n >= 1; n--)
              tester.getRect(find.byKey(Key('strong-number-$n'))),
          ];
          for (final rect in rects) {
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
          }
          final lastRow = rects
              .where((r) => (r.top - rects.last.top).abs() < 1)
              .toList();
          final firstRow = rects
              .where((r) => (r.top - rects.first.top).abs() < 1)
              .toList();
          expect(
            (lastRow.first.left + lastRow.last.right) / 2,
            closeTo((firstRow.first.left + firstRow.last.right) / 2, 0.1),
          );
          await tester.ensureVisible(find.byKey(Key('strong-number-$count')));
          await tester.tap(find.byKey(Key('strong-number-$count')));
          await tester.pumpAndSettle();
          // An incorrect answer must retain the generated order.
          final after = [
            for (var n = count; n >= 1; n--)
              tester.getTopLeft(find.byKey(Key('strong-number-$n'))).dx,
          ];
          expect(after, rects.map((r) => r.left).toList());
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'Windows only opens questions on an explicit request and does not reopen after closing',
    (tester) async {
      if (!Platform.isWindows) return;
      final state = <String, dynamic>{
        'id': 'explicit',
        'phase': 'ringing',
        'openRequest': 0,
        'opened': false,
        'expiresAt': DateTime.now().millisecondsSinceEpoch + 120000,
        'records': [],
        'settings': {},
      };
      var opens = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        StrongSessionService.windows,
        (call) async {
          if (call.method == 'strongOpen') {
            opens++;
            state['openRequest'] = opens;
            state['opened'] = true;
            state['phase'] = 'ready';
          }
          return jsonEncode(state);
        },
      );
      const window = MethodChannel('window_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        window,
        (call) async => call.method == 'isVisible',
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          StrongSessionService.windows,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          window,
          null,
        );
      });
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(_Database())],
          child: MaterialApp(
            navigatorKey: nav,
            home: const Scaffold(body: Text('Schedule')),
            builder: (context, child) =>
                StrongReminderHost(navigatorKey: nav, child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(StrongConfirmationPage), findsNothing);
      expect(opens, 0);
      await tester.tap(find.text('Open and answer'));
      await tester.pumpAndSettle();
      expect(find.byType(StrongConfirmationPage), findsOneWidget);
      expect(opens, 1);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(StrongConfirmationPage), findsNothing);
      await tester.tap(find.text('Open and answer'));
      await tester.pumpAndSettle();
      expect(opens, 2);
      expect(find.byType(StrongConfirmationPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'Windows rejects native decoder errors and removes the staged audio',
    () async {
      if (!Platform.isWindows) return;
      final dir = await Directory.systemTemp.createTemp('orbit_audio_failure_');
      final oldDirectory = ReminderAudioService.supportDirectory;
      ReminderAudioService.supportDirectory = () async => dir;
      String? decodedPath;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(StrongSessionService.windows, (call) async {
            if (call.method == 'validateAudio') {
              decodedPath = (call.arguments as Map)['path'];
              throw PlatformException(code: 'audio_invalid');
            }
            return null;
          });
      try {
        final bytes = await File('C:/Windows/Media/Alarm01.wav').readAsBytes();
        await expectLater(
          ReminderAudioService.importBytes('中文 audio.wav', bytes),
          throwsA(isA<PlatformException>()),
        );
        expect(decodedPath, isNotNull);
        expect(await File(decodedPath!).exists(), isFalse);
        expect(
          await (await ReminderAudioService.audioDirectory()).list().toList(),
          isEmpty,
        );
      } finally {
        ReminderAudioService.supportDirectory = oldDirectory;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(StrongSessionService.windows, null);
        await dir.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'Windows audio preview uses the selected file, stops on demand and on leaving settings',
    (tester) async {
      if (!Platform.isWindows) return;
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        StrongSessionService.windows,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          StrongSessionService.windows,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: app(
            const StrongReminderPage(
              showTargets: false,
              initial: StrongReminderSettings(
                sound: ReminderSound(
                  kind: 'file',
                  value: '中文 sound.mp3',
                  name: '中文 sound.mp3',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Preview (up to 10 seconds)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Preview (up to 10 seconds)'));
      await tester.pumpAndSettle();
      expect(find.text('Stop preview'), findsOneWidget);
      expect((calls.last.arguments as Map)['sound']['value'], '中文 sound.mp3');
      await tester.tap(find.text('Stop preview'));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'stopPreview');
      await tester.tap(find.text('Preview (up to 10 seconds)'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(calls.last.method, 'stopPreview');
      expect(tester.takeException(), isNull);
    },
  );
}
