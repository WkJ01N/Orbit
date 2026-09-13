import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/core/widgets/reminder_template_field.dart';
import 'package:orbit/features/import/import_format_help.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/services/course_color_utils.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child, {bool reduce = false}) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: child),
  ),
);

class _DelayedSchemeService extends SettingsService {
  final loaded = Completer<AppColorScheme>();
  @override
  Future<AppColorScheme> loadColorScheme() => loaded.future;
  @override
  Future<void> saveColorScheme(AppColorScheme scheme) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'late preference loading cannot overwrite a new palette selection',
    () async {
      final service = _DelayedSchemeService();
      final container = ProviderContainer(
        overrides: [settingsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      expect(container.read(colorSchemeProvider), AppColorScheme.original);
      await container
          .read(colorSchemeProvider.notifier)
          .setScheme(AppColorScheme.expressive);
      service.loaded.complete(AppColorScheme.original);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(colorSchemeProvider), AppColorScheme.expressive);
    },
  );
  test('weekday filters are concise in all supported languages', () {
    expect(
      lookupL10n(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ).reminderFilterWeekdays,
      '周一|周二|周三|周四|周五|周六|周日',
    );
    expect(
      lookupL10n(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ).reminderFilterWeekdays,
      '週一|週二|週三|週四|週五|週六|週日',
    );
    expect(
      lookupL10n(const Locale('en')).reminderFilterWeekdays,
      'Mon|Tue|Wed|Thu|Fri|Sat|Sun',
    );
  });
  test(
    'more than eight courses have stable, distinct automatic colors in both themes',
    () {
      final keys = List.generate(150, (i) => 'course-$i');
      final ids = allocateCourseColorIds({
        'legacy-a': 2,
        'legacy-b': 2,
        'invalid': -1,
      }, keys);
      expect(ids['legacy-a'], 2);
      expect(ids.values.toSet().length, ids.length);
      for (final brightness in Brightness.values) {
        final colors = ids.values.map(
          (id) => automaticColorForId(id, brightness),
        );
        expect(colors.map((c) => c.toARGB32()).toSet().length, ids.length);
        for (final color in colors) {
          final fg = contrastForegroundFor(color);
          final a = color.computeLuminance(), b = fg.computeLuminance();
          expect(
            (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
      final grown = allocateCourseColorIds(ids, [
        ...keys.reversed,
        'new-course',
      ]);
      for (final e in ids.entries) {
        expect(grown[e.key], e.value);
      }
      final removed = allocateCourseColorIds(grown, ['course-1']);
      expect(removed, grown);
    },
  );

  test(
    'thousands of imported identities do not exhaust a single hue circle',
    () {
      final ids = allocateCourseColorIds(
        {},
        List.generate(3000, (i) => 'large-$i'),
      );
      expect(ids.length, 3000);
      for (final brightness in Brightness.values) {
        expect(
          ids.values
              .map((id) => automaticColorForId(id, brightness).toARGB32())
              .toSet()
              .length,
          3000,
        );
      }
    },
  );
  test(
    'new preferences and backup fields round trip; legacy clock fields are ignored',
    () async {
      final service = SettingsService();
      await service.saveColorScheme(AppColorScheme.expressive);
      await service.saveAutomaticCourseColorIds({'A': 9, 'B': 12});
      await service.saveScheduleDisplaySettings(
        const ScheduleDisplaySettings(
          fitToPage: true,
          verticalScalePercent: 75,
        ),
      );
      final snapshot = await service.exportPortableSettings();
      final restored = PortableSettings.fromJson(snapshot.toJson());
      expect(restored.colorScheme, 'expressive');
      expect(restored.automaticCourseColorIds, {'A': 9, 'B': 12});
      expect(restored.scheduleDisplay.fitToPage, isTrue);
      expect(
        restored
            .withReminders(const ReminderSettings())
            .toJson()['colorScheme'],
        'expressive',
      );
      await service.importPortableSettings(restored);
      expect(
        (await service.loadScheduleDisplaySettings()).verticalScalePercent,
        75,
      );
      final legacy = snapshot.toJson()
        ..remove('colorScheme')
        ..remove('automaticCourseColorIds');
      (legacy['scheduleDisplay'] as Map).remove('fitToPage');
      (legacy['reminders'] as Map)['systemAlarmEnabled'] = true;
      final old = PortableSettings.fromJson(legacy);
      expect(old.colorScheme, 'original');
      expect(old.scheduleDisplay.fitToPage, isFalse);
      expect(
        (old.toJson()['reminders'] as Map).containsKey('systemAlarmEnabled'),
        isFalse,
      );
    },
  );
  test('all automatic schemes expose accessible light surface text', () {
    for (final scheme in AppColorScheme.values) {
      for (final seed in kThemePresetColors) {
        final c = AppTheme.light(seed: seed, scheme: scheme).colorScheme;
        for (final pair in [
          (c.surfaceContainerLow, c.onSurface),
          (c.primaryContainer, c.onPrimaryContainer),
          (c.secondaryContainer, c.onSecondaryContainer),
          (c.tertiaryContainer, c.onTertiaryContainer),
        ]) {
          final a = pair.$1.computeLuminance(), b = pair.$2.computeLuminance();
          expect(
            (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    }
    expect(
      AppTheme.dark().colorScheme,
      ColorScheme.fromSeed(
        seedColor: kDefaultThemeColor,
        brightness: Brightness.dark,
      ),
    );
  });
  testWidgets('variable button replaces selected text and preserves caret', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Hello WORLD!');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ReminderTemplateField(
          controller: controller,
          label: 'Body',
          variables: const ['course', 'room'],
          multiline: true,
        ),
      ),
    );
    controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
    await tester.tap(find.byTooltip('{course}'));
    await tester.pump();
    expect(controller.text, 'Hello {course}!');
    expect(controller.selection.baseOffset, 14);
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.minLines, 1);
    expect(input.maxLines, 5);
    expect(input.textAlignVertical, TextAlignVertical.top);
  });
  testWidgets('temporary messages animate, queue, and actions still time out', (
    tester,
  ) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            messenger = ScaffoldMessenger.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    messenger.showAppSnackBar(const SnackBar(content: Text('first')));
    messenger.showAppSnackBar(
      SnackBar(
        content: const Text('second'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final motion = tester
        .widget<SnackBar>(find.byWidgetPredicate((w) => w is SnackBar))
        .animation!;
    expect(motion.value, allOf(greaterThan(0), lessThan(1)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    expect(
      tester
          .widget<SnackBar>(find.byWidgetPredicate((w) => w is SnackBar))
          .persist,
      isFalse,
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('second'), findsNothing);
  });

  testWidgets(
    'actions cancel their timer without dismissing the next message',
    (tester) async {
      late ScaffoldMessengerState messenger;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (ctx) {
              messenger = ScaffoldMessenger.of(ctx);
              return const SizedBox();
            },
          ),
        ),
      );
      messenger.showAppSnackBar(
        SnackBar(
          content: const Text('old'),
          action: SnackBarAction(
            label: 'Act',
            onPressed: () =>
                messenger.showAppSnackBar(const SnackBar(content: Text('new'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Act'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('new'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('new'), findsNothing);
    },
  );
  testWidgets(
    'reduced motion disables both message and format help transitions',
    (tester) async {
      late ScaffoldMessengerState messenger;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (ctx) {
              messenger = ScaffoldMessenger.of(ctx);
              return const SingleChildScrollView(child: ImportFormatHelp());
            },
          ),
          reduce: true,
        ),
      );
      await tester.tap(find.text('Schedule file format'));
      await tester.pump();
      expect(
        tester
            .widget<SizeTransition>(find.byType(SizeTransition))
            .sizeFactor
            .value,
        1,
      );
      await tester.tap(find.text('Schedule file format'));
      await tester.pump();
      expect(
        tester
            .widget<SizeTransition>(find.byType(SizeTransition))
            .sizeFactor
            .value,
        0,
      );
      messenger.showAppSnackBar(const SnackBar(content: Text('instant')));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(of: find.text('instant'), matching: find.byType(Opacity)),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('instant'), findsNothing);
    },
  );
  testWidgets('format help reverses its height animation without snapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const SingleChildScrollView(child: ImportFormatHelp())),
    );
    await tester.tap(find.text('Schedule file format'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final transition = tester.widget<SizeTransition>(
      find.byType(SizeTransition),
    );
    final halfway = transition.sizeFactor.value;
    expect(halfway, allOf(greaterThan(0), lessThan(1)));
    await tester.tap(find.text('Schedule file format'));
    await tester.pump();
    expect(
      tester
          .widget<SizeTransition>(find.byType(SizeTransition))
          .sizeFactor
          .value,
      closeTo(halfway, .01),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SizeTransition>(find.byType(SizeTransition))
          .sizeFactor
          .value,
      0,
    );
    expect(tester.takeException(), isNull);
  });
}
