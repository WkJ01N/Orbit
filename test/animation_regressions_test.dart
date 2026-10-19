import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/background/background_routes.dart';
import 'package:orbit/core/motion/category_entrance.dart';
import 'package:orbit/core/motion/page_entrance.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/core/motion/retained_page_switcher.dart';
import 'package:orbit/core/widgets/notification_permission_banner.dart';
import 'package:orbit/features/import/import_plan_editor.dart';
import 'package:orbit/features/settings/launch_settings_page.dart';
import 'package:orbit/features/settings/settings_appearance_section.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:orbit/providers/permission_providers.dart';
import 'package:orbit/services/notification_permission_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Launch extends LaunchSettingsNotifier {
  _Launch([this.speed = PageTransitionSpeed.standard]);
  final PageTransitionSpeed speed;
  @override
  LaunchSettings build() => LaunchSettings(
    onStartup: false,
    pageTransitionStyle: PageTransitionStyle.fluid,
    pageTransitionSpeed: speed,
  );
}

class _ControlledSettings extends SettingsService {
  final writes = <Map<String, dynamic>>[];
  final gates = <Completer<void>>[];
  @override
  Future<void> saveLocalJson(String key, Map<String, dynamic> value) {
    writes.add(value);
    final gate = Completer<void>();
    gates.add(gate);
    return gate.future;
  }
}

class _Configuration extends ImportConfigurationNotifier {
  _Configuration(this.ready);
  final Future<ImportConfiguration> ready;
  @override
  Future<ImportConfiguration> build() => ready;
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

Future<List<int>> _pixel(WidgetTester tester) async {
  final box = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('pixels')),
  );
  final image = (await tester.runAsync(() => box.toImage()))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final offset = (100 * image.width + 100) * 4;
  final pixel = [for (var c = 0; c < 4; c++) bytes.getUint8(offset + c)];
  image.dispose();
  return pixel;
}

double _moduleX(WidgetTester tester, Finder child) =>
    tester.getTopLeft(child).dx;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'partial route reversal starts from current composed opacity rather than elapsed forward distance',
    (tester) async {
      final clock = AnimationController(
        vsync: tester,
        value: 1,
        duration: const Duration(milliseconds: 600),
      );
      final navigation = AnimationController(
        vsync: tester,
        value: .25,
        duration: const Duration(milliseconds: 360),
      );
      final motion = ModuleEntrance(clock);
      final opacity = ValueNotifier(.42);
      await tester.pumpWidget(
        _app(
          RepaintBoundary(
            key: const Key('pixels'),
            child: ColoredBox(
              color: Colors.black,
              child: ValueListenableBuilder(
                valueListenable: opacity,
                builder: (_, alpha, _) => Opacity(
                  opacity: alpha,
                  child: ModuleEntranceScope(
                    motion: motion,
                    child: const PageModule(
                      child: ColoredBox(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final before = await _pixel(tester);
      motion.pause();
      motion.follow(
        navigation,
        duration: const Duration(milliseconds: 360),
        fromDirection: -1,
        reverse: true,
        continuing: true,
        visibility: opacity.value,
      );
      motion.start(const Rect.fromLTWH(0, 0, 800, 600));
      opacity.value = 1;
      navigation.reverse();
      await tester.pump();
      expect(await _pixel(tester), before);
      await tester.pump(const Duration(milliseconds: 45));
      expect((await _pixel(tester)).first, inExclusiveRange(before.first, 256));
      await tester.pump(const Duration(milliseconds: 45));
      expect((await _pixel(tester)).first, 255);
      await tester.pumpWidget(const SizedBox());
      motion.dispose();
      clock.dispose();
      navigation.dispose();
      opacity.dispose();
    },
  );

  test(
    'failed preference updates retain later edits and serialize without stale fields',
    () async {
      final service = _ControlledSettings();
      final container = ProviderContainer(
        overrides: [
          launchSettingsProvider.overrideWith(_Launch.new),
          settingsServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(launchSettingsProvider.notifier);
      final first = notifier.update((s) => s.copyWith(brandEnabled: false));
      final failed = expectLater(first, throwsStateError);
      final second = notifier.update((s) => s.copyWith(onResume: true));
      expect(container.read(launchSettingsProvider).brandEnabled, isFalse);
      expect(container.read(launchSettingsProvider).onResume, isTrue);
      await Future<void>.delayed(Duration.zero);
      service.gates.first.completeError(StateError('disk full'));
      await failed;
      await Future<void>.delayed(Duration.zero);
      expect(container.read(launchSettingsProvider).brandEnabled, isTrue);
      expect(container.read(launchSettingsProvider).onResume, isTrue);
      expect(service.writes.last['brandEnabled'], isTrue);
      expect(service.writes.last['onResume'], isTrue);
      service.gates.last.complete();
      await second;
    },
  );

  testWidgets(
    'compact pages fade in and visible reversals preserve composited pixels',
    (tester) async {
      final selected = ValueNotifier(0);
      await tester.pumpWidget(
        _app(
          RepaintBoundary(
            key: const Key('pixels'),
            child: ValueListenableBuilder(
              valueListenable: selected,
              builder: (_, value, _) => RetainedPageSwitcher(
                index: value,
                itemCount: 3,
                builder: (_, page, _) => ColoredBox(
                  color: [Colors.red, Colors.blue, Colors.green][page],
                ),
              ),
            ),
          ),
        ),
      );
      selected.value = 1;
      await tester.pump();
      double alpha(int page) => tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byKey(ValueKey('retained-page-$page')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(alpha(1), 0);
      await tester.pump(const Duration(milliseconds: 80));
      expect(alpha(1), inExclusiveRange(0, 1));
      final before = await _pixel(tester);
      selected.value = 0;
      await tester.pump();
      expect(await _pixel(tester), before);
      selected.value = 2;
      await tester.pump();
      expect(await _pixel(tester), before);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      selected.dispose();
    },
  );

  for (final speed in PageTransitionSpeed.values) {
    testWidgets(
      '${speed.name}: editing style never remounts or hides the visible animation settings',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(700, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer(
          overrides: [
            launchSettingsProvider.overrideWith(() => _Launch(speed)),
          ],
        );
        final navigator = GlobalKey<NavigatorState>();
        final routes = BackgroundRouteObserver()
          ..mainPage = (() => BackgroundPage.settings)
          ..settingsSnapshot = () => const BackgroundSettings();
        final refresh = ValueNotifier(0);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ValueListenableBuilder(
              valueListenable: refresh,
              builder: (_, _, _) => MaterialApp(
                navigatorKey: navigator,
                navigatorObservers: [routes, pageEntranceRoutes],
                locale: const Locale('en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ThemeData(
                  pageTransitionsTheme: PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android: BackgroundPageTransitionsBuilder(
                        platform: TargetPlatform.android,
                        fluidDuration: () {
                          final s = container.read(launchSettingsProvider);
                          return s.onPageSwitch ? s.transitionDuration : null;
                        },
                      ),
                    },
                  ),
                ),
                builder: (_, child) =>
                    BackgroundRouteBinding(routes: routes, child: child!),
                home: const Scaffold(body: Text('Origin')),
              ),
            ),
          ),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const LaunchSettingsPage()),
        );
        await tester.pumpAndSettle();
        final state = tester.state(find.byType(LaunchSettingsPage));
        final firstSwitch = tester.element(find.byType(SwitchListTile).first);
        final firstPosition = tester.getTopLeft(
          find.byType(SwitchListTile).first,
        );
        Future<void> select(PageTransitionStyle style) async {
          tester
              .widget<DropdownButton<PageTransitionStyle>>(
                find.byType(DropdownButton<PageTransitionStyle>),
              )
              .onChanged!(style);
          refresh.value++;
          await tester.pump();
          await tester.pumpAndSettle();
        }

        for (var cycle = 0; cycle < 2; cycle++) {
          await select(PageTransitionStyle.compact);
          await select(PageTransitionStyle.fluid);
          expect(tester.state(find.byType(LaunchSettingsPage)), same(state));
          expect(
            tester.element(find.byType(SwitchListTile).first),
            same(firstSwitch),
          );
          expect(
            tester.getTopLeft(find.byType(SwitchListTile).first),
            firstPosition,
          );
          expect(
            container.read(launchSettingsProvider).pageTransitionSpeed,
            speed,
          );
          final motion = tester
              .widget<ModuleEntranceScope>(
                find.byType(ModuleEntranceScope).last,
              )
              .motion;
          expect(motion.pending, isFalse);
          expect(motion.progress, 1);
        }
        // Controls remain enabled while the first write is still awaiting disk.
        final switches = tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .toList();
        switches[0].onChanged!(!switches[0].value);
        switches[1].onChanged!(!switches[1].value);
        await tester.pump();
        expect(
          tester
              .widgetList<SwitchListTile>(find.byType(SwitchListTile))
              .every((s) => s.onChanged != null),
          isTrue,
        );
        await tester.pumpAndSettle();
        if (speed == PageTransitionSpeed.standard) {
          Future<void> gesture(
            String method, [
            Map<String, dynamic>? arguments,
          ]) async {
            await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              'flutter/backgesture',
              const StandardMethodCodec().encodeMethodCall(
                MethodCall(method, arguments),
              ),
              (_) {},
            );
            await tester.pump();
          }

          final route =
              ModalRoute.of(tester.element(find.byType(LaunchSettingsPage)))!
                  as PageRoute<dynamic>;
          await gesture('startBackGesture', {
            'touchOffset': [5.0, 300.0],
            'progress': 0.0,
            'swipeEdge': 0,
          });
          expect(route.popGestureInProgress, isTrue);
          await gesture('updateBackGestureProgress', {
            'touchOffset': [100.0, 300.0],
            'progress': .35,
            'swipeEdge': 0,
          });
          await gesture('cancelBackGesture');
          await tester.pumpAndSettle();
          expect(route.isCurrent, isTrue);
          expect(tester.state(find.byType(LaunchSettingsPage)), same(state));
          expect(
            tester.element(find.byType(SwitchListTile).first),
            same(firstSwitch),
          );
          expect(
            tester.getTopLeft(find.byType(SwitchListTile).first),
            firstPosition,
          );
          expect(tester.takeException(), isNull);
        }
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(
          Duration(milliseconds: (speed.milliseconds * .25).round()),
        );
        final routeOpacity = tester
            .widgetList<Opacity>(
              find.ancestor(
                of: find.byType(LaunchSettingsPage),
                matching: find.byType(Opacity),
              ),
            )
            .last;
        expect(routeOpacity.opacity, lessThan(.6));
        await tester.pumpAndSettle();
        expect(find.byType(LaunchSettingsPage), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        routes.dispose();
        refresh.dispose();
        container.dispose();
      },
    );
  }

  testWidgets(
    'permission tiles, palette colors and semester content receive actual paint motion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final clock = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 600),
        value: 1,
      );
      final motion = ModuleEntrance(clock);
      final config = Completer<ImportConfiguration>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importConfigurationProvider.overrideWith(
              () => _Configuration(config.future),
            ),
            notificationPermissionProvider.overrideWith(
              (ref) async => NotificationPermissionState.allowed,
            ),
          ],
          child: _app(
            ModuleEntranceScope(
              motion: motion,
              child: const Scaffold(
                body: Column(
                  children: [
                    NotificationPermissionSettingsTiles(),
                    SettingsAppearanceSection(),
                    Expanded(child: ImportPlansPage()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      config.complete(
        ImportConfiguration(
          semesters: [
            SemesterPlan(
              id: 's',
              name: 'Autumn',
              firstWeekMonday: DateTime(2026, 10, 12),
            ),
          ],
          periodTimes: const [
            PeriodTimePlan(id: 'p', name: 'Morning', periods: []),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final permission = find.byType(ListTile).first;
      final palette = find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_ColorSwatch')
          .first;
      final semester = find.text('Autumn');
      final row = find.text('Morning');
      final targets = [permission, palette, semester, row];
      final completed = [
        for (final target in targets) _moduleX(tester, target),
      ];
      motion.reset(fromDirection: 1);
      motion.start(const Rect.fromLTWH(0, 0, 900, 1600));
      await tester.pump();
      for (var i = 0; i < targets.length; i++) {
        expect(_moduleX(tester, targets[i]), closeTo(completed[i] + 12, .01));
      }
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < targets.length; i++) {
        expect(
          _moduleX(tester, targets[i]),
          inExclusiveRange(completed[i], completed[i] + 12),
        );
      }
      await tester.pumpAndSettle();
      for (var i = 0; i < targets.length; i++) {
        expect(_moduleX(tester, targets[i]), closeTo(completed[i], .01));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      motion.dispose();
      clock.dispose();
    },
  );

  testWidgets(
    'categories at the top preserve frozen modules through parent resets and reversal',
    (tester) async {
      final selected = ValueNotifier(0);
      final parentClock = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 600),
        value: 1,
      );
      final parent = ModuleEntrance(parentClock);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [launchSettingsProvider.overrideWith(_Launch.new)],
          child: _app(
            ModuleEntranceScope(
              motion: parent,
              child: ValueListenableBuilder(
                valueListenable: selected,
                builder: (_, value, _) => RetainedPageSwitcher(
                  index: value,
                  itemCount: 3,
                  fluid: true,
                  duration: const Duration(milliseconds: 360),
                  builder: (_, page, transition) => CategoryEntranceHost(
                    transition: transition,
                    child: ListView(
                      key: PageStorageKey('scroll-$page'),
                      children: [
                        for (var row = 0; row < 30; row++)
                          PageModule(
                            child: SizedBox(
                              key: Key('cat-$page-$row'),
                              height: 70,
                              child: Text('$page-$row'),
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
      );
      await tester.pumpAndSettle();
      // Restore a cached category at scroll offset zero after visiting its bottom.
      final list = find.byKey(const PageStorageKey('scroll-0'));
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(0, 900));
      await tester.pumpAndSettle();
      selected.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 85));
      final outgoing = find.byKey(const Key('cat-1-0'));
      final before = tester.getTopLeft(outgoing);
      selected.value = 2;
      await tester.pump();
      expect(tester.getTopLeft(outgoing), before);
      parent.reset(fromDirection: -1);
      parent.start(const Rect.fromLTWH(0, 0, 800, 600));
      await tester.pump();
      expect(tester.getTopLeft(outgoing), before);
      selected.value = 1;
      await tester.pump();
      expect(tester.getTopLeft(outgoing), before);
      await tester.pumpAndSettle();
      expect(outgoing.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      parent.dispose();
      parentClock.dispose();
      selected.dispose();
    },
  );
}
