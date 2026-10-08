import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/services/strong_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'old settings get task defaults and malformed times are clamped safely',
    () {
      final old = StrongReminderSettings.fromJson({});
      expect(old.prepareSeconds, 15);
      expect(old.answerSeconds, 30);
      final bad = StrongReminderSettings.fromJson({
        'prepareSeconds': 'bad',
        'answerSeconds': double.nan,
      });
      expect(bad.prepareSeconds, 15);
      expect(bad.answerSeconds, 30);
      final bounds = StrongReminderSettings.fromJson({
        'prepareSeconds': 1000,
        'answerSeconds': 1,
      });
      expect(bounds.prepareSeconds, 60);
      expect(bounds.answerSeconds, 10);
      final value = old.copyWith(
        dismissTask: StrongDismissTask.sequence,
        prepareSeconds: 20,
        answerSeconds: 45,
      );
      expect(
        StrongReminderSettings.fromJson(value.toJson()).toJson(),
        value.toJson(),
      );
    },
  );
  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'narrow task preserves deadline after a wrong answer in $locale',
      (tester) async {
        if (!Platform.isWindows && !Platform.isAndroid) return;
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final deadline = DateTime.now().millisecondsSinceEpoch + 30000;
        var state = <String, dynamic>{
          'id': 'test',
          'phase': 'task',
          'expiresAt': deadline + 90000,
          'answerDeadline': deadline,
          'settings': {'dismissTask': 'sequence'},
          'progress': 0,
          'numbers': [6, 4, 2, 1, 5, 3],
          'records': [
            {
              'title': 'Reminder',
              'body': 'A101',
              'metadata': jsonEncode({
                'courseName': 'Mathematics',
                'courseStartAt': '2026-10-08T09:00:00',
                'courseEndAt': '2026-10-08T10:30:00',
              }),
            },
          ],
        };
        final answers = <int>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          StrongSessionService.channel,
          (call) async {
            if (call.method == 'strongAnswer') {
              final input = (call.arguments as Map)['answer'] as int;
              answers.add(input);
              final expected = (state['progress'] as int) % 6 + 1;
              state = {
                ...state,
                'wrong': input != expected,
                if (input == expected)
                  'progress': (state['progress'] as int) + 1,
              };
            }
            return jsonEncode(state);
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            StrongSessionService.channel,
            null,
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [strongSessionProvider.overrideWith((_) => state)],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const StrongConfirmationPage(),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Mathematics'), findsOneWidget);
        expect(find.textContaining('A101'), findsOneWidget);
        expect(find.textContaining('2026'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, '6'));
        await tester.pump();
        expect(state['progress'], 0);
        expect(state['answerDeadline'], deadline);
        expect(state['wrong'], true);
        await tester.tap(find.widgetWithText(FilledButton, '1'));
        await tester.pump();
        expect(answers, [6, 1]);
        expect(state['progress'], 1);
        expect(state['answerDeadline'], deadline);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
