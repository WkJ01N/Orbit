import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/motion/page_entrance.dart';
import 'package:orbit/core/background/background_routes.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/core/motion/retained_page_switcher.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/providers/launch_providers.dart';

class _Fluid extends LaunchSettingsNotifier {
  @override
  LaunchSettings build() => const LaunchSettings(onPageSwitch: true);
}

void main() {
  test('old switches migrate and new style/speed survive serialization', () {
    expect(
      LaunchSettings.fromJson({}).pageTransitionStyle,
      PageTransitionStyle.compact,
    );
    expect(
      LaunchSettings.fromJson({'onPageSwitch': true}).pageTransitionStyle,
      PageTransitionStyle.fluid,
    );
    for (final style in PageTransitionStyle.values) {
      for (final speed in PageTransitionSpeed.values) {
        final value = LaunchSettings.fromJson(
          LaunchSettings(
            pageTransitionStyle: style,
            pageTransitionSpeed: speed,
          ).toJson(),
        );
        expect(value.pageTransitionStyle, style);
        expect(value.pageTransitionSpeed, speed);
        expect(
          value.toJson()['onPageSwitch'],
          style == PageTransitionStyle.fluid,
        );
      }
    }
    expect(
      LaunchSettings.fromJson({
        'onPageSwitch': true,
        'pageTransitionStyle': 'future',
        'pageTransitionSpeed': 'future',
      }).pageTransitionSpeed,
      PageTransitionSpeed.standard,
    );
  });

  testWidgets(
    'compact revisits paint the outgoing page above the cached destination',
    (tester) async {
      final index = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: const Key('capture'),
            child: ValueListenableBuilder(
              valueListenable: index,
              builder: (_, value, _) => RetainedPageSwitcher(
                index: value,
                itemCount: 2,
                builder: (_, page, _) =>
                    ColoredBox(color: page == 0 ? Colors.blue : Colors.red),
              ),
            ),
          ),
        ),
      );
      index.value = 1;
      await tester.pumpAndSettle();
      index.value = 0;
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final pixel = (100 * image.width + 100) * 4;
      expect(
        bytes.getUint8(pixel),
        244,
      ); // Material red, not the cached blue page.
      expect(bytes.getUint8(pixel + 2), 54);
      image.dispose();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      index.dispose();
    },
  );

  for (final speed in PageTransitionSpeed.values) {
    testWidgets(
      '${speed.name}: modules start immediately and finish with the navigation clock',
      (tester) async {
        final index = ValueNotifier(0);
        final duration = Duration(milliseconds: speed.milliseconds);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [launchSettingsProvider.overrideWith(_Fluid.new)],
            child: MaterialApp(
              home: ValueListenableBuilder(
                valueListenable: index,
                builder: (_, value, _) => RetainedPageSwitcher(
                  index: value,
                  itemCount: 3,
                  fluid: true,
                  duration: duration,
                  builder: (_, page, transition) => PageEntranceHost(
                    index: page,
                    active: transition.active,
                    startup: transition.epoch == 0,
                    transition: transition,
                    navigation: transition.animation,
                    navigationEpoch: transition.epoch,
                    direction: transition.direction,
                    continuing: transition.continuing,
                    child: Column(
                      children: [
                        for (var row = 0; row < 3; row++)
                          PageModule(
                            child: SizedBox(
                              key: Key('row-$page-$row'),
                              width: 100,
                              height: 50,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        index.value = 1;
        await tester.pump();
        final row = find.byKey(const Key('row-1-0'));
        final first = tester.getTopLeft(row);
        await tester.pump(
          Duration(milliseconds: (speed.milliseconds * .2).round()),
        );
        final moving = tester.getTopLeft(row);
        expect(moving.dx, lessThan(first.dx));
        expect(moving.dx, greaterThan(first.dx - 12));
        index.value = 2;
        await tester.pump();
        final reverse = tester.getTopLeft(find.byKey(const Key('row-2-0')));
        await tester.pump(const Duration(milliseconds: 25));
        index.value = 1;
        final before = tester.getTopLeft(row);
        await tester.pump();
        expect(tester.getTopLeft(row).dx, closeTo(before.dx, .001));
        await tester.pump(duration);
        await tester.pump();
        for (var rowIndex = 0; rowIndex < 3; rowIndex++) {
          expect(
            tester.getTopLeft(find.byKey(Key('row-1-$rowIndex'))).dx,
            closeTo(first.dx - 12, .001),
          );
        }
        expect(reverse.dx.isFinite, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        index.dispose();
      },
    );
  }

  testWidgets(
    'late modules finish with the transition without rewinding visible rows',
    (tester) async {
      final local = AnimationController(
        vsync: tester,
        value: 1,
        duration: const Duration(milliseconds: 600),
      );
      final navigation = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 360),
      );
      final motion = ModuleEntrance(local);
      final loaded = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleEntranceScope(
            motion: motion,
            child: ValueListenableBuilder(
              valueListenable: loaded,
              builder: (_, ready, _) => Column(
                children: [
                  const PageModule(
                    child: SizedBox(
                      key: Key('first-late'),
                      width: 100,
                      height: 50,
                    ),
                  ),
                  if (ready)
                    const PageModule(
                      child: SizedBox(
                        key: Key('last-late'),
                        width: 100,
                        height: 50,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      motion.follow(
        navigation,
        duration: const Duration(milliseconds: 360),
        fromDirection: 1,
      );
      motion.start(const Rect.fromLTWH(0, 0, 800, 600));
      navigation.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final before = tester.getTopLeft(find.byKey(const Key('first-late')));
      loaded.value = true;
      await tester.pump();
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('first-late'))).dx,
        closeTo(before.dx, .001),
      );
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('last-late'))).dx,
        closeTo(350, .001),
      );
      await tester.pumpWidget(const SizedBox());
      motion.dispose();
      local.dispose();
      navigation.dispose();
      loaded.dispose();
    },
  );

  testWidgets(
    'fluid secondary routes share navigation progress and preserve quick reversal',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final routes = BackgroundRouteObserver();
      routes.mainPage = () => BackgroundPage.upcoming;
      routes.settingsSnapshot = () => const BackgroundSettings();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [launchSettingsProvider.overrideWith(_Fluid.new)],
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [routes, pageEntranceRoutes],
            theme: ThemeData(
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: BackgroundPageTransitionsBuilder(
                    platform: TargetPlatform.android,
                    fluidDuration: () => const Duration(milliseconds: 360),
                  ),
                },
              ),
            ),
            builder: (_, child) =>
                BackgroundRouteBinding(routes: routes, child: child!),
            home: const PageEntranceHost(
              index: 1,
              active: true,
              startup: false,
              child: Scaffold(
                body: PageModule(
                  child: SizedBox(key: Key('origin'), width: 100, height: 50),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(find.byKey(const Key('origin')));
      PageRoute<void> details() => MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: PageModule(
            child: SizedBox(key: Key('details'), width: 100, height: 50),
          ),
        ),
      );
      final route = details();
      navigator.currentState!.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(route.transitionDuration.inMilliseconds, 360);
      expect(
        tester.getTopLeft(find.byKey(const Key('details'))).dx,
        inExclusiveRange(0, 12),
      );
      navigator.currentState!.pop();
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const Key('origin'))), origin);
      await tester.pumpAndSettle();
      navigator.currentState!.push(details());
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('origin'))).dx,
        closeTo(origin.dx - 12, .001),
      );
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const Key('origin'))), origin);
      await tester.pumpWidget(const SizedBox());
      routes.dispose();
    },
  );
}
