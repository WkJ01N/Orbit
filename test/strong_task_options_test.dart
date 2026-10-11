import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/features/settings/strong_reminder_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/settings_sync_codec.dart';
import 'package:orbit/services/strong_session_service.dart';

Widget app(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

void main() {
  test(
    'new task options default, clamp and survive portable backup and sync encoding',
    () {
      final old = StrongReminderSettings.fromJson({});
      expect(old.mixedRounds, 2);
      expect(old.sequenceNumberCount, 6);
      expect(old.arithmeticDifficulty, ArithmeticDifficulty.medium);
      expect(old.arithmeticAnswerMode, ArithmeticAnswerMode.input);
      for (final count in [4, 6, 25]) {
        for (final rounds in [1, 2, 10]) {
          final value = old.copyWith(
            dismissTask: StrongDismissTask.mixed,
            mixedRounds: rounds,
            sequenceNumberCount: count,
            arithmeticDifficulty: ArithmeticDifficulty.hard,
            arithmeticAnswerMode: ArithmeticAnswerMode.choice6,
          );
          expect(
            StrongReminderSettings.fromJson(value.toJson()).toJson(),
            value.toJson(),
          );
          final portable = PortableSettings.fromJson({
            'reminders': {'strong': value.toJson()},
            'scheduleDisplay': <String, dynamic>{},
            'courseColorOverrides': <String, dynamic>{},
          });
          final backup = ScheduleBackupService();
          final restored = backup
              .decodeBackup(backup.encodeToJson([], settings: portable))
              .settings!;
          expect(restored.reminders.strong.toJson(), value.toJson());
          final legacyMerge = SettingsSyncCodec.merge(
            restored,
            const SyncEntity(
              type: SyncEntityType.settingGroup,
              id: 'strong',
              payload: {
                'strong': {'enabled': true},
              },
            ),
          );
          expect(legacyMerge.reminders.strong.sequenceNumberCount, count);
          expect(legacyMerge.reminders.strong.mixedRounds, rounds);
          expect(
            legacyMerge.reminders.strong.arithmeticDifficulty,
            ArithmeticDifficulty.hard,
          );
          expect(
            legacyMerge.reminders.strong.arithmeticAnswerMode,
            ArithmeticAnswerMode.choice6,
          );
          final encoded =
              SettingsSyncCodec.groups(restored)['strong']!['strong'] as Map;
          for (final key in [
            'mixedRounds',
            'sequenceNumberCount',
            'arithmeticDifficulty',
            'arithmeticAnswerMode',
          ]) {
            expect(encoded[key], value.toJson()[key]);
          }
        }
      }
      final invalid = StrongReminderSettings.fromJson({
        'mixedRounds': 100,
        'sequenceNumberCount': -1,
        'arithmeticDifficulty': 'invalid',
        'arithmeticAnswerMode': 'invalid',
      });
      expect(invalid.mixedRounds, 10);
      expect(invalid.sequenceNumberCount, 4);
      expect(invalid.arithmeticDifficulty, ArithmeticDifficulty.medium);
      expect(invalid.arithmeticAnswerMode, ArithmeticAnswerMode.input);
      expect(
        StrongReminderSettings.fromJson({
          'mixedRounds': double.nan,
          'sequenceNumberCount': 'bad',
        }).sequenceNumberCount,
        6,
      );
    },
  );

  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'mixed task renders choices and 25 ordered numbers at large text in $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final deadline = DateTime.now().millisecondsSinceEpoch + 120000;
        final tasks = [
          {
            'type': 'arithmetic',
            'a': 99,
            'b': 99,
            'operator': 'multiply',
            'choices': [9801, 9800, 9901],
          },
          {
            'type': 'sequence',
            'numberCount': 25,
            'numbers': List.generate(25, (i) => 25 - i),
          },
          {
            'type': 'arithmetic',
            'a': 750,
            'b': 125,
            'operator': 'subtract',
            'choices': [625, 624, 626, 627, 628, 629],
          },
        ];
        var state = <String, dynamic>{
          'id': 'mixed',
          'phase': 'task',
          'expiresAt': deadline + 10000,
          'answerDeadline': deadline,
          'tasks': tasks,
          'taskIndex': 0,
          'taskProgress': 0,
          'progress': 0,
          'records': [],
        };
        final answers = <int>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          StrongSessionService.channel,
          (call) async {
            if (call.method == 'strongAnswer') {
              final input = (call.arguments as Map)['answer'] as int;
              answers.add(input);
              if (state['taskIndex'] == 0) {
                state = {
                  ...state,
                  'wrong': input != 9801,
                  if (input == 9801) 'taskIndex': 1,
                };
              } else if (state['taskIndex'] == 1) {
                final step = state['taskProgress'] as int;
                state = {
                  ...state,
                  'wrong': input != step + 1,
                  if (input == step + 1) 'taskProgress': step + 1,
                  if (input == 25) 'taskIndex': 2,
                };
              }
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
            child: app(
              const StrongConfirmationPage(),
              locale: locale,
              scale: 1.7,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('99 × 99 = ?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('strong-choice-9800')));
        await tester.pumpAndSettle();
        expect(state['taskIndex'], 0);
        expect(state['answerDeadline'], deadline);
        await tester.tap(find.byKey(const Key('strong-choice-9801')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('strong-number-25')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('strong-number-25'))).height,
          greaterThanOrEqualTo(48),
        );
        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.byKey(const Key('strong-number-1')),
          250,
          scrollable: scrollable,
        );
        await tester.tap(find.byKey(const Key('strong-number-1')));
        await tester.pumpAndSettle();
        expect(state['taskProgress'], 1);
        expect(state['taskIndex'], 1);
        expect(state['tasks'], tasks);
        expect(answers, [9800, 9801, 1]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'mixed settings save independent options at large text in $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        StrongReminderSettings? saved;
        await tester.pumpWidget(
          ProviderScope(
            child: app(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await Navigator.push<StrongReminderSettings>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StrongReminderPage(
                          showTargets: false,
                          initial: StrongReminderSettings(
                            dismissTask: StrongDismissTask.mixed,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
              locale: locale,
              scale: 1.7,
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final count = tester.widget<DropdownButtonFormField<int>>(
          find.byKey(const Key('strong-number-count')),
        );
        count.onChanged!(25);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const Key('strong-arithmetic-difficulty')),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        tester
            .widget<DropdownButtonFormField<ArithmeticDifficulty>>(
              find.byKey(const Key('strong-arithmetic-difficulty')),
            )
            .onChanged!(ArithmeticDifficulty.hard);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const Key('strong-arithmetic-answer-mode')),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        tester
            .widget<DropdownButtonFormField<ArithmeticAnswerMode>>(
              find.byKey(const Key('strong-arithmetic-answer-mode')),
            )
            .onChanged!(ArithmeticAnswerMode.choice6);
        await tester.pump();
        await tester.tap(
          find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(TextButton),
              )
              .last,
        );
        await tester.pumpAndSettle();
        expect(saved?.dismissTask, StrongDismissTask.mixed);
        expect(saved?.sequenceNumberCount, 25);
        expect(saved?.arithmeticDifficulty, ArithmeticDifficulty.hard);
        expect(saved?.arithmeticAnswerMode, ArithmeticAnswerMode.choice6);
        expect(saved?.mixedRounds, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('hard arithmetic submits a four digit manual answer', (
    tester,
  ) async {
    final deadline = DateTime.now().millisecondsSinceEpoch + 120000;
    final state = {
      'id': 'manual',
      'phase': 'task',
      'expiresAt': deadline,
      'answerDeadline': deadline,
      'tasks': [
        {
          'type': 'arithmetic',
          'a': 99,
          'b': 99,
          'operator': 'multiply',
          'choices': [],
        },
      ],
      'taskIndex': 0,
      'records': [],
    };
    int? submitted;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      StrongSessionService.channel,
      (call) async {
        if (call.method == 'strongAnswer') {
          submitted = (call.arguments as Map)['answer'] as int;
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
        child: app(const StrongConfirmationPage()),
      ),
    );
    for (final digit in ['9', '8', '0', '1']) {
      await tester.tap(find.byKey(Key('strong-key-$digit')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('strong-key-✓')));
    await tester.pump();
    expect(submitted, 9801);
    expect(tester.takeException(), isNull);
  });
}
