import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/motion/page_entrance.dart';
import 'package:orbit/core/motion/category_entrance.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/core/motion/retained_page_switcher.dart';
import 'package:orbit/core/widgets/settings_group.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/providers/launch_providers.dart';

class _Enabled extends LaunchSettingsNotifier {
  @override
  LaunchSettings build() => const LaunchSettings(onPageSwitch: true);
}

void main() {
  testWidgets(
    'quick secondary-page reversal preserves the revealed page and full returns enter from the left',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [launchSettingsProvider.overrideWith(_Enabled.new)],
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [pageEntranceRoutes],
            home: const PageEntranceHost(
              key: Key('origin-host'),
              index: 1,
              active: true,
              startup: false,
              child: Scaffold(body: PageModule(child: Text('Origin'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final motion = tester
          .widget<ModuleEntranceScope>(
            find.descendant(
              of: find.byKey(const Key('origin-host')),
              matching: find.byType(ModuleEntranceScope),
            ),
          )
          .motion;
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Details')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      navigator.currentState!.pop();
      await tester.pump();
      expect(motion.pending, isFalse);
      expect(motion.prepared, isTrue);
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Details')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pump();
      expect(motion.pending, isFalse);
      expect(motion.effectiveDirection, -1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'category waves are independent and adopt a new main-page entrance without stale callbacks',
    (tester) async {
      final clock = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 600),
        value: 1,
      );
      final parent = ModuleEntrance(clock);
      final index = ValueNotifier(0);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [launchSettingsProvider.overrideWith(_Enabled.new)],
          child: MaterialApp(
            home: ModuleEntranceScope(
              motion: parent,
              child: ValueListenableBuilder<int>(
                valueListenable: index,
                builder: (context, value, _) => RetainedPageSwitcher(
                  index: value,
                  itemCount: 3,
                  keyPrefix: 'category-probe',
                  duration: const Duration(milliseconds: 220),
                  builder: (context, page, transition) => CategoryEntranceHost(
                    transition: transition,
                    child: Scaffold(
                      body: PageModule(
                        child: SizedBox(
                          key: Key('category-row-$page'),
                          width: 100,
                          height: 70,
                          child: Text('Category $page'),
                        ),
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
      index.value = 1;
      await tester.pump();
      ModuleEntrance motion(int page) => tester
          .widget<ModuleEntranceScope>(
            find
                .descendant(
                  of: find.byKey(ValueKey('category-probe-$page')),
                  matching: find.byType(ModuleEntranceScope),
                )
                .first,
          )
          .motion;
      expect(motion(1).pending, isFalse);
      expect(parent.pending, isFalse);
      expect(clock.value, 1);
      await tester.pump(const Duration(milliseconds: 112));
      expect(motion(1).pending, isFalse);
      await tester.pump(const Duration(milliseconds: 70));
      final before = motion(1).clock.value;
      index.value = 0;
      await tester.pump();
      expect(motion(1).clock.value, before);
      index.value = 2;
      await tester.pump();
      parent.reset(fromDirection: -1);
      parent.start(const Rect.fromLTWH(0, 0, 800, 600));
      await tester.pump();
      expect(motion(2).effectiveDirection, -1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      parent.dispose();
      clock.dispose();
      index.dispose();
    },
  );
  testWidgets(
    'rapid reversals keep every visible page at its painted opacity and position',
    (tester) async {
      final index = ValueNotifier(0);
      addTearDown(index.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [launchSettingsProvider.overrideWith(_Enabled.new)],
          child: MaterialApp(
            home: ValueListenableBuilder<int>(
              valueListenable: index,
              builder: (context, value, _) => RetainedPageSwitcher(
                index: value,
                itemCount: 3,
                keyPrefix: 'probe',
                builder: (context, page, transition) => PageEntranceHost(
                  index: page,
                  active: transition.active,
                  startup: false,
                  navigation: transition.animation,
                  direction: transition.direction,
                  continuing: transition.continuing,
                  navigationEpoch: transition.epoch,
                  child: Scaffold(
                    body: PageModule(
                      child: SizedBox(
                        key: Key('content-$page'),
                        width: 150,
                        height: 80,
                        child: Text('Page $page'),
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
      double opacity(int page) => tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byKey(ValueKey('probe-$page')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      index.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final alpha = opacity(0),
          position = tester.getTopLeft(find.byKey(const Key('content-0')));
      expect(alpha, inExclusiveRange(0.0, 1.0));
      index.value = 0;
      await tester.pump();
      expect(opacity(0), closeTo(alpha, .0001));
      expect(tester.getTopLeft(find.byKey(const Key('content-0'))), position);
      await tester.pump(const Duration(milliseconds: 50));
      final before = [opacity(0), opacity(1)];
      index.value = 2;
      await tester.pump();
      expect(opacity(0), closeTo(before[0], .0001));
      expect(opacity(1), closeTo(before[1], .0001));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-2')).hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('content-0')).hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings surface and first row use the same entrance without double movement',
    (tester) async {
      final clock = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 600),
        value: 1,
      );
      final motion = ModuleEntrance(clock);
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleEntranceScope(
            motion: motion,
            child: const Scaffold(
              body: SettingsGroup(
                title: 'Group',
                children: [
                  PageModule(
                    child: SizedBox(
                      key: Key('row'),
                      height: 80,
                      width: double.infinity,
                      child: Text('Setting'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final surface = find.descendant(
        of: find.byWidgetPredicate((w) => w is PageModule && w.surface),
        matching: find.byType(Card),
      );
      final rowFinal = tester.getTopLeft(find.byKey(const Key('row')));
      final surfaceFinal = tester.getTopLeft(surface);
      motion.reset(fromDirection: 1);
      motion.start(const Rect.fromLTWH(0, 0, 800, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      final rowTravel =
          tester.getTopLeft(find.byKey(const Key('row'))) - rowFinal;
      final surfaceTravel = tester.getTopLeft(surface) - surfaceFinal;
      expect(rowTravel.dx, inExclusiveRange(0, 12));
      expect(surfaceTravel.dx, closeTo(rowTravel.dx, .001));
      expect(rowTravel.dy, 0);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      motion.dispose();
      clock.dispose();
    },
  );

  testWidgets(
    'late asynchronous modules do not finish or rewind modules already playing',
    (tester) async {
      final clock = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 600),
        value: 1,
      );
      final motion = ModuleEntrance(clock);
      final loaded = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleEntranceScope(
            motion: motion,
            child: ValueListenableBuilder<bool>(
              valueListenable: loaded,
              builder: (context, value, _) => Column(
                children: [
                  const PageModule(
                    child: SizedBox(key: Key('first'), width: 100, height: 50),
                  ),
                  if (value)
                    const PageModule(child: SizedBox(width: 100, height: 50)),
                ],
              ),
            ),
          ),
        ),
      );
      motion.reset(fromDirection: 1);
      motion.start(const Rect.fromLTWH(0, 0, 800, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final before = tester.getTopLeft(find.byKey(const Key('first')));
      loaded.value = true;
      await tester.pump();
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('first'))).dx,
        closeTo(before.dx, .001),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      motion.dispose();
      clock.dispose();
      loaded.dispose();
    },
  );
}
