import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/features/settings/settings_category_viewport.dart';
import 'package:orbit/core/motion/category_entrance.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/core/motion/retained_page_switcher.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Reminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
}

class _Motion extends LaunchSettingsNotifier {
  _Motion(this.settings);
  final LaunchSettings settings;
  @override
  LaunchSettings build() => settings;
}

Finder _category(int category, {bool skipOffstage = true}) => find.byKey(
  Key('settings-category-content-$category'),
  skipOffstage: skipOffstage,
);
Finder _stretch(int category, {bool skipOffstage = true}) => find.descendant(
  of: _category(category, skipOffstage: skipOffstage),
  matching: find.byType(StretchEffect, skipOffstage: skipOffstage),
  skipOffstage: skipOffstage,
);

Future<void> _pump(
  WidgetTester tester,
  LaunchSettings settings, {
  bool reduced = false,
  bool enabled = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        launchSettingsProvider.overrideWith(() => _Motion(settings)),
        launchAnimationsEnabledProvider.overrideWithValue(enabled),
        reminderSettingsProvider.overrideWith(_Reminders.new),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android, useMaterial3: true),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final settings in [
    const LaunchSettings(onStartup: false),
    for (final speed in PageTransitionSpeed.values)
      LaunchSettings(
        onStartup: false,
        pageTransitionStyle: PageTransitionStyle.fluid,
        pageTransitionSpeed: speed,
      ),
  ]) {
    final style = settings.pageTransitionStyle;
    for (final bottom in [false, true]) {
      for (final held in [false, true]) {
        testWidgets(
          '${style.name}/${settings.pageTransitionSpeed.name}: ${bottom ? 'bottom' : 'top'} ${held ? 'held' : 'released'} stretch recedes while category fades',
          (tester) async {
            await _pump(tester, settings);
            final scrollable = find
                .descendant(of: _category(0), matching: find.byType(Scrollable))
                .first;
            final state = tester.state<ScrollableState>(scrollable);
            if (bottom) {
              state.position.jumpTo(state.position.maxScrollExtent);
              await tester.pumpAndSettle();
            }
            final offset = state.position.pixels;
            final pointer = await tester.startGesture(
              tester.getCenter(scrollable),
              pointer: 1,
            );
            await pointer.moveBy(Offset(0, bottom ? -170 : 170));
            await tester.pump(const Duration(milliseconds: 16));
            await pointer.moveBy(Offset(0, bottom ? -90 : 90));
            await tester.pump(const Duration(milliseconds: 16));
            final before = tester
                .widget<StretchEffect>(_stretch(0))
                .stretchStrength
                .abs();
            expect(
              before,
              greaterThan(.001),
              reason: 'Switch while genuinely stretched, without pumpAndSettle',
            );
            if (!held) {
              await pointer.up();
              await tester.pump(const Duration(milliseconds: 16));
            }
            final atSwitch = tester
                .widget<StretchEffect>(_stretch(0))
                .stretchStrength
                .abs();
            await tester.tap(
              find.byKey(const Key('settings-category-1')),
              pointer: 2,
            );
            await tester.pump();
            expect(tester.state(scrollable), same(state));
            expect(
              TickerMode.valuesOf(tester.element(_stretch(0))).enabled,
              isTrue,
              reason:
                  'Keep the live stretch spring ticking until fade finishes',
            );
            await tester
                .pump(); // First spring tick after outgoing drag cleanup.
            await tester.pump(const Duration(milliseconds: 48));
            expect(
              tester.widget<StretchEffect>(_stretch(0)).stretchStrength.abs(),
              lessThan(atSwitch),
            );
            expect(
              state.position.isScrollingNotifier.value,
              isFalse,
              reason:
                  'The old drag must not keep controlling an inactive category',
            );
            expect(state.position.pixels, closeTo(offset, .01));
            if (held) await pointer.up();
            await tester.pumpAndSettle();
            expect(_category(0), findsNothing);
            expect(
              TickerMode.valuesOf(
                tester.element(_stretch(0, skipOffstage: false)),
              ).enabled,
              isFalse,
            );
            await tester.tap(find.byKey(const Key('settings-category-0')));
            await tester.pumpAndSettle();
            expect(tester.state(scrollable), same(state));
            expect(state.position.pixels, closeTo(offset, .01));
            expect(
              tester.widget<StretchEffect>(_stretch(0)).stretchStrength,
              closeTo(0, .0001),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final reduced in [false, true]) {
    testWidgets(
      '${reduced ? 'reduced motion' : 'disabled animations'}: changing category ends the held drag immediately',
      (tester) async {
        await _pump(
          tester,
          const LaunchSettings(onPageSwitch: true),
          reduced: reduced,
          enabled: reduced,
        );
        final scrollable = find
            .descendant(of: _category(0), matching: find.byType(Scrollable))
            .first;
        final state = tester.state<ScrollableState>(scrollable);
        final gesture = await tester.startGesture(
          tester.getCenter(scrollable),
          pointer: 1,
        );
        await gesture.moveBy(const Offset(0, 120));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 90));
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('settings-category-1')),
          pointer: 2,
        );
        await tester.pump();
        await tester.pump();
        expect(_category(0), findsNothing);
        expect(_category(1), findsOneWidget);
        expect(state.position.isScrollingNotifier.value, isFalse);
        expect(
          TickerMode.valuesOf(
            tester.element(_stretch(0, skipOffstage: false)),
          ).enabled,
          isFalse,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'other retained switchers still mute outgoing tickers by default',
    (tester) async {
      final selected = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: selected,
            builder: (_, index, _) => RetainedPageSwitcher(
              index: index,
              itemCount: 2,
              builder: (_, page, _) =>
                  SizedBox(key: ValueKey('default-page-$page')),
            ),
          ),
        ),
      );
      selected.value = 1;
      await tester.pump();
      expect(
        TickerMode.valuesOf(
          tester.element(find.byKey(const ValueKey('default-page-0'))),
        ).enabled,
        isFalse,
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      selected.dispose();
    },
  );

  testWidgets(
    'live stretched layers remain painted through reversal and three-category interruption',
    (tester) async {
      final selected = ValueNotifier(0);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            launchSettingsProvider.overrideWith(
              () => _Motion(
                const LaunchSettings(onStartup: false, onPageSwitch: true),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              body: RepaintBoundary(
                key: const Key('stretch-pixels'),
                child: ValueListenableBuilder(
                  valueListenable: selected,
                  builder: (_, page, _) => RetainedPageSwitcher(
                    index: page,
                    itemCount: 3,
                    fluid: true,
                    keepOutgoingTickers: true,
                    duration: const Duration(milliseconds: 360),
                    builder: (_, category, transition) => CategoryEntranceHost(
                      transition: transition,
                      child: SettingsCategoryViewport(
                        key: ValueKey('viewport-$category'),
                        active: transition.active,
                        scrollKey: PageStorageKey('pixel-scroll-$category'),
                        children: [
                          for (var i = 0; i < 30; i++)
                            PageModule(
                              child: SizedBox(
                                height: 80,
                                child: ColoredBox(
                                  color: [
                                    Colors.blue,
                                    Colors.red,
                                    Colors.green,
                                  ][category],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<List<int>> pixel() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('stretch-pixels')),
        );
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final data = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        final offset = (200 * image.width + 100) * 4;
        final result = [for (var c = 0; c < 4; c++) data.getUint8(offset + c)];
        image.dispose();
        return result;
      }

      final gesture = await tester.startGesture(const Offset(100, 300));
      await gesture.moveBy(const Offset(0, 140));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      final stretch = find.descendant(
        of: find.byKey(const ValueKey('viewport-0')),
        matching: find.byType(StretchEffect),
      );
      expect(
        tester.widget<StretchEffect>(stretch).stretchStrength.abs(),
        greaterThan(.001),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .descendant(
              of: find.byKey(const ValueKey('viewport-0')),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      final before = await pixel();
      selected.value = 1;
      await tester.pump();
      expect(
        await pixel(),
        before,
        reason: 'No blank frame when the live stretch starts exiting',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 48));
      final blend = await pixel();
      expect(blend[0], greaterThan(before[0]));
      expect(
        blend[2],
        greaterThan(0),
        reason: 'Outgoing blue content still contributes during fade',
      );
      selected.value = 0;
      await tester.pump();
      expect(
        await pixel(),
        blend,
        reason: 'Reversal preserves actual composited pixels',
      );
      expect(
        tester.renderObject<RenderRepaintBoundary>(
          find
              .descendant(
                of: find.byKey(const ValueKey('viewport-0')),
                matching: find.byType(RepaintBoundary),
              )
              .first,
        ),
        same(boundary),
      );
      selected.value = 2;
      await tester.pump();
      expect(await pixel(), blend);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(await pixel(), [76, 175, 80, 255]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      selected.dispose();
    },
  );
}
