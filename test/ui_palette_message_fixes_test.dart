import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_color_utilities/hct/hct.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/core/widgets/settings_choice_tile.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/features/settings/theme_scheme_page.dart';
import 'package:orbit/features/settings/strong_reminder_page.dart';
import 'package:orbit/features/settings/custom_reminders_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/providers/app_providers.dart';

class _FixedReminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
}

double hueDistance(Color a, Color b) {
  final delta = (Hct.fromInt(a.toARGB32()).hue - Hct.fromInt(b.toARGB32()).hue)
      .abs();
  return delta > 180 ? 360 - delta : delta;
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'every colorful preset generates distinct accessible roles from several seeds',
    () {
      for (final seed in [
        kDefaultThemeColor,
        Colors.blue,
        Colors.red,
        Colors.grey,
      ]) {
        for (final scheme in AppColorScheme.values) {
          final settings = MulticolorSettings(
            enabled: true,
            primary: seed,
            scheme: scheme,
          );
          final seeds = presetRoleSeeds(seed, scheme);
          for (final brightness in Brightness.values) {
            final c = settings.colors(brightness);
            final roles = [c.primary, c.secondary, c.tertiary];
            if (scheme == AppColorScheme.neutral ||
                scheme == AppColorScheme.monochrome) {
              for (final role in roles) {
                expect(Hct.fromInt(role.toARGB32()).chroma, lessThan(12));
              }
            } else {
              for (var i = 0; i < 3; i++) {
                expect(
                  hueDistance(roles[i], seeds[i]),
                  lessThan(6),
                  reason: '$scheme $brightness role $i',
                );
                for (var j = i + 1; j < 3; j++) {
                  expect(
                    hueDistance(roles[i], roles[j]),
                    greaterThan(22),
                    reason: '$scheme $brightness',
                  );
                }
              }
            }
            for (final pair in [
              (c.primary, c.onPrimary),
              (c.secondary, c.onSecondary),
              (c.tertiary, c.onTertiary),
              (c.primaryContainer, c.onPrimaryContainer),
              (c.secondaryContainer, c.onSecondaryContainer),
              (c.tertiaryContainer, c.onTertiaryContainer),
              (c.surface, c.onSurface),
            ]) {
              expect(
                contrast(pair.$1, pair.$2),
                greaterThanOrEqualTo(4.5),
                reason: '$scheme $brightness',
              );
            }
            expect(
              MulticolorSettings.fromJson(settings.toJson()).colors(brightness),
              c,
            );
            final actual = brightness == Brightness.light
                ? AppTheme.light(multicolor: settings)
                : AppTheme.dark(multicolor: settings);
            expect(actual.colorScheme, c);
          }
        }
      }
    },
  );

  test(
    'preset hue offsets and saved seed survive custom editing and reload',
    () {
      const initial = MulticolorSettings(
        enabled: true,
        primary: Colors.blue,
        scheme: AppColorScheme.rainbow,
      );
      final edited = initial
          .withRoleColor(0, Colors.orange)
          .withRoleColor(1, Colors.pink);
      final restored = MulticolorSettings.fromJson(edited.toJson());
      final preset = restored.copyWith(
        scheme: AppColorScheme.rainbow,
        clearCustom: true,
      );
      expect(preset.primary.toARGB32(), Colors.blue.toARGB32());
      expect(preset.colors(Brightness.light), initial.colors(Brightness.light));
      expect(
        preset.palette.map((e) => e.toJson()).toList(),
        initial.palette.map((e) => e.toJson()).toList(),
      );
      final legacy = MulticolorSettings.fromJson({
        'enabled': true,
        'primary': Colors.red.toARGB32(),
        'scheme': 'content',
      });
      expect(legacy.primary.toARGB32(), Colors.red.toARGB32());
      expect(legacy.isCustom, false);
    },
  );

  for (final closing in [
    'close',
    'timeout',
    'action',
    'programmatic',
    'swipe',
  ]) {
    testWidgets('message visibly enters and exits through $closing', (
      tester,
    ) async {
      late ScaffoldMessengerState messenger;
      var acted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      messenger.showAppSnackBar(
        SnackBar(
          content: const Text('message'),
          action: closing == 'action'
              ? SnackBarAction(label: 'Undo', onPressed: () => acted = true)
              : null,
        ),
      );
      messenger.showAppSnackBar(const SnackBar(content: Text('next')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final opacityFinder = find.ancestor(
        of: find.text('message'),
        matching: find.byType(Opacity),
      );
      final firstOpacity = tester.widget<Opacity>(opacityFinder).opacity;
      expect(firstOpacity, allOf(greaterThan(0), lessThan(1)));
      final entryY = tester.getTopLeft(find.text('message')).dy;
      await tester.pumpAndSettle();
      final settledY = tester.getTopLeft(find.text('message')).dy;
      expect(entryY, greaterThan(settledY));
      expect(tester.widget<Opacity>(opacityFinder).opacity, 1);
      if (closing == 'close') {
        await tester.tap(find.byIcon(Icons.close));
      } else if (closing == 'timeout') {
        await tester.pump(const Duration(seconds: 4));
      } else if (closing == 'action') {
        await tester.tap(find.text('Undo'));
      } else if (closing == 'programmatic') {
        messenger.hideCurrentSnackBar();
      } else {
        await tester.drag(find.text('message'), const Offset(0, 200));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      if (closing != 'swipe') {
        expect(find.text('message'), findsOneWidget);
        expect(
          tester.widget<Opacity>(opacityFinder).opacity,
          allOf(greaterThan(0), lessThan(1)),
        );
        expect(
          tester.getTopLeft(find.text('message')).dy,
          greaterThan(settledY),
        );
        expect(find.text('next'), findsNothing);
      }
      await tester.pumpAndSettle();
      expect(find.text('message'), findsNothing);
      expect(find.text('next'), findsOneWidget);
      expect(acted, closing == 'action');
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 360.0, 1100.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'choice descriptions keep their space at $width and text scale $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SettingsChoiceTile(
                    title: const Text('课程配色 / Course colors'),
                    subtitle: const Text(
                      'Choose unified colors or automatic course colors. 选择统一颜色或自动课程分色。',
                    ),
                    trailing: DropdownButton<int>(
                      value: 0,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('自动分色')),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (width < 480 || scale > 1.3) {
            expect(
              tester.getTopLeft(find.byType(DropdownButton<int>)).dy,
              greaterThan(
                tester
                    .getBottomLeft(
                      find.text(
                        'Choose unified colors or automatic course colors. 选择统一颜色或自动课程分色。',
                      ),
                    )
                    .dy,
              ),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final width in [320.0, 360.0, 1100.0]) {
    for (final locale in [
      const Locale('en'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    ]) {
      testWidgets(
        'settings and secondary pages fit $width $locale at large text',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          Future<void> show(Widget page) async {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  reminderSettingsProvider.overrideWith(_FixedReminders.new),
                  sessionsProvider.overrideWith((ref) async => []),
                ],
                child: MaterialApp(
                  theme: AppTheme.light(),
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(1.6)),
                    child: child!,
                  ),
                  home: page,
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          await show(const SettingsPage());
          for (var category = 0; category < 4; category++) {
            await tester.tap(find.byKey(Key('settings-category-$category')));
            await tester.pumpAndSettle();
            final scroll = find.descendant(
              of: find.byKey(Key('settings-category-content-$category')),
              matching: find.byType(Scrollable),
            );
            await tester.drag(scroll, const Offset(0, -1400));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'category $category',
            );
          }
          for (final page in [
            const ThemeSchemePage(),
            const StrongReminderPage(initial: StrongReminderSettings()),
            const CustomRemindersPage(),
            const CustomReminderEditor(),
          ]) {
            await show(page);
            expect(
              tester.takeException(),
              isNull,
              reason: '${page.runtimeType}',
            );
            if (find.byType(Scrollable).evaluate().isNotEmpty) {
              final scroll = find.byType(Scrollable).first;
              await tester.drag(scroll, const Offset(0, -1400));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${page.runtimeType} scrolled',
              );
            }
          }
        },
      );
    }
  }
}
