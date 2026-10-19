import 'package:orbit/models/typography_settings.dart';
import 'package:orbit/providers/typography_providers.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/motion/launch_motion.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/features/grid/grid_event_motion.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/features/settings/launch_settings_page.dart';
import 'package:orbit/features/grid/grid_week_picker.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:orbit/providers/notification_providers.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Display extends ScheduleDisplaySettingsNotifier {
  _Display(this.value);
  final ScheduleDisplaySettings value;
  @override
  ScheduleDisplaySettings build() => value;
}

class _Reminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
}

class _Clock extends CurrentTimeNotifier {
  _Clock([this.now]);
  final DateTime? now;
  @override
  DateTime build() => now ?? DateTime(2026, 10, 12, 10);
}

class _LaunchSettings extends LaunchSettingsNotifier {
  _LaunchSettings(this.value);
  final LaunchSettings value;
  @override
  LaunchSettings build() => value;
}

List<CourseSession> _courses() => [
  for (var day = 0; day < 5; day++)
    for (var i = 0; i < 3; i++)
      CourseSession(
        id: 'course-$day-$i',
        classType: '',
        room: 'A101',
        date: DateTime(2026, 10, 12 + day),
        weekday: day + 1,
        courseName: 'Course $day',
        courseCode: 'C$day',
        section: '1',
        startAt: DateTime(2026, 10, 12 + day, 9 + i * 3),
        endAt: DateTime(2026, 10, 12 + day, 11 + i * 3),
        teachers: const [],
        faculty: '',
        semester: '',
      ),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Size size = const Size(400, 800),
  TypographySettings typography = const TypographySettings(),
  bool enabled = true,
  bool reduced = false,
  bool hideUpcoming = false,
  bool hideImport = false,
  bool onPageSwitch = false,
  bool fitToPage = true,
  String? payload,
  bool strong = false,
  Future<List<CourseSession>>? data,
  CardEntranceMode mode = CardEntranceMode.edge,
  String? iconPath,
  DateTime? now,
  Widget child = const AppShell(),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      typographySnapshotProvider.overrideWithValue(typography),
      launchAnimationsEnabledProvider.overrideWithValue(enabled),
      launchSettingsProvider.overrideWith(
        () => _LaunchSettings(
          LaunchSettings(
            cardEntrance: mode,
            iconPath: iconPath,
            onPageSwitch: onPageSwitch,
          ),
        ),
      ),
      reminderSettingsProvider.overrideWith(_Reminders.new),
      scheduleDisplaySettingsProvider.overrideWith(
        () => _Display(
          ScheduleDisplaySettings(
            hideUpcomingPage: hideUpcoming,
            hideImportPage: hideImport,
            fitToPage: fitToPage,
          ),
        ),
      ),
      currentTimeProvider.overrideWith(() => _Clock(now)),
      selectedScheduleDateProvider.overrideWith(
        (ref) => DateTime(2026, 10, 12),
      ),
      selectedWeekStartProvider.overrideWith((ref) => DateTime(2026, 10, 12)),
      sessionsProvider.overrideWith((ref) => data ?? Future.value(_courses())),
      upcomingSessionsProvider.overrideWith(
        (ref) => data ?? Future.value(_courses()),
      ),
      deadlinesProvider.overrideWith((ref) async => []),
      strongCourseIdsProvider.overrideWith((ref) async => {'course-0-0'}),
      pendingNotificationPayloadProvider.overrideWith((ref) => payload),
      strongConfirmationVisibleProvider.overrideWith((ref) => strong),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.light().copyWith(
          textTheme: AppTheme.light().textTheme.copyWith(
            labelSmall: const TextStyle(fontSize: 9),
          ),
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: OrbitLaunchHost(child: child),
      ),
    ),
  );
  await tester.pump();
  return container;
}

LaunchMotion _motion(WidgetTester tester) => tester
    .widget<LaunchMotionScope>(find.byType(LaunchMotionScope).first)
    .motion;

Future<void> _ready(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    if (_motion(tester).timeline.isAnimating || _motion(tester).finished) {
      await tester.pump();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  fail('Startup resources did not finish preparing');
}

void main() {
  testWidgets(
    'returning to grid uses a single immediate transition for chrome and cards',
    (tester) async {
      final container = await _pump(
        tester,
        onPageSwitch: true,
        mode: CardEntranceMode.nearby,
      );
      await _ready(tester);
      await tester.pumpAndSettle();
      final finalAdd = tester.getTopLeft(
        find.byKey(const Key('grid-add-session')),
      );
      container.read(appNavIndexProvider.notifier).state = 1;
      await tester.pumpAndSettle();
      container.read(appNavIndexProvider.notifier).state = 0;
      await tester.pump();
      final scope = find
          .descendant(
            of: find.byKey(const ValueKey('app-destination-0')),
            matching: find.byType(ModuleEntranceScope),
          )
          .first;
      final modules = tester.widget<ModuleEntranceScope>(scope).motion;
      final launchScope = find
          .descendant(
            of: find.byKey(const ValueKey('app-destination-0')),
            matching: find.byType(LaunchMotionScope),
          )
          .first;
      final motion = tester.widget<LaunchMotionScope>(launchScope).motion;
      expect(modules.pending, isFalse);
      expect(motion.fluid, isTrue);
      final transitionStart = tester.getTopLeft(
        find.byKey(const Key('grid-add-session')),
      );
      expect(transitionStart.dx, closeTo(finalAdd.dx - 12, .01));
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester.getTopLeft(find.byKey(const Key('grid-add-session'))).dx,
        inExclusiveRange(finalAdd.dx - 26, finalAdd.dx),
      );
      final cards = tester
          .widgetList<LaunchCard>(
            find.descendant(
              of: find.byKey(const Key('adjacent-page-current')),
              matching: find.byType(LaunchCard),
            ),
          )
          .toList();
      expect(cards, isNotEmpty);
      expect(cards.every((card) => card.spec == null), isTrue);
      await tester.pump(const Duration(milliseconds: 280));
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('grid-add-session'))),
        finalAdd,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'week navigation never animates a newly constructed viewport as inserted courses',
    (tester) async {
      final first = _courses();
      final second = first
          .map(
            (s) => s.copyWith(
              id: '${s.id}-next',
              date: s.date.add(const Duration(days: 7)),
              startAt: s.startAt.add(const Duration(days: 7)),
              endAt: s.endAt.add(const Duration(days: 7)),
            ),
          )
          .toList();
      final container = await _pump(
        tester,
        onPageSwitch: true,
        data: Future.value([...first, ...second]),
      );
      await _ready(tester);
      await tester.pumpAndSettle();
      final pager = tester.widget<AdjacentPagePager>(
        find.byType(AdjacentPagePager),
      );
      final navigation = pager.controller!.animateToNext();
      await tester.pumpAndSettle();
      await navigation;
      final motions = tester.widgetList<GridEventMotion>(
        find.byType(GridEventMotion),
      );
      expect(motions, isNotEmpty);
      expect(motions.every((m) => !m.animateInitial), isTrue);
      final nowVisible = tester.widgetList<GridSessionChip>(
        find.descendant(
          of: find.byKey(const Key('adjacent-page-current')),
          matching: find.byType(GridSessionChip),
        ),
      );
      expect(nowVisible.any((s) => s.session.id.endsWith('-next')), isTrue);
      container.read(selectedScheduleDateProvider.notifier).state = DateTime(
        2026,
        10,
        12,
      );
      await tester.pump();
      expect(
        tester
            .widgetList<GridEventMotion>(find.byType(GridEventMotion))
            .every((m) => !m.animateInitial),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'dropdown and today animate target cards and time marker; arrows never do',
    (tester) async {
      final date = DateTime.now();
      final now = DateTime(date.year, date.month, date.day, 10, 30);
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final shift = monday.difference(DateTime(2026, 10, 12));
      final sessions = [
        for (var week = 0; week < 3; week++)
          for (final s in _courses())
            s.copyWith(
              id: '${s.id}-w$week',
              date: s.date.add(shift + Duration(days: week * 7)),
              startAt: s.startAt.add(shift + Duration(days: week * 7)),
              endAt: s.endAt.add(shift + Duration(days: week * 7)),
            ),
      ];
      await _pump(tester, now: now, data: Future.value(sessions));
      await _ready(tester);
      await tester.pumpAndSettle();
      LaunchMotion pageMotion() => tester
          .widget<LaunchMotionScope>(
            find
                .descendant(
                  of: find.byKey(const Key('adjacent-page-current')),
                  matching: find.byType(LaunchMotionScope),
                )
                .first,
          )
          .motion;
      final picker = tester.widget<GridWeekPicker>(find.byType(GridWeekPicker));
      picker.onChanged(monday.add(const Duration(days: 7)));
      await tester.pump();
      await tester.pump();
      expect(pageMotion().cards.value, lessThan(1));
      expect(pageMotion().timeline.isCompleted, isTrue);
      final marker = find.descendant(
        of: find.byKey(const Key('adjacent-page-current')),
        matching: find.byKey(const Key('schedule-current-time-line')),
      );
      expect(
        tester.widgetList<LaunchCard>(
          find.descendant(of: marker, matching: find.byType(LaunchCard)),
        ),
        isEmpty,
      );
      await tester.pumpAndSettle();
      final finished = pageMotion();
      tester
          .widget<GridWeekPicker>(find.byType(GridWeekPicker))
          .onChanged(monday.add(const Duration(days: 7)));
      await tester.pump();
      expect(pageMotion(), same(finished));
      await tester.tap(find.byIcon(Icons.chevron_right).hitTestable().last);
      await tester.pumpAndSettle();
      expect(pageMotion().finished, isTrue);
      expect(
        tester
            .widgetList<GridEventMotion>(find.byType(GridEventMotion))
            .every((e) => !e.animateInitial),
        isTrue,
      );
      final todayButton = find.byIcon(Icons.today_outlined).hitTestable();
      expect(todayButton, findsOneWidget);
      await tester.tap(todayButton);
      await tester.pump();
      await tester.pump();
      expect(pageMotion().cards.value, lessThan(1));
      expect(pageMotion().timeline.isCompleted, isTrue);
      final markerCard = tester.widget<LaunchCard>(
        find.descendant(of: marker, matching: find.byType(LaunchCard)).first,
      );
      expect(markerCard.spec, isNotNull);
      expect(markerCard.travel!.distance, greaterThan(0));
      final initialMarkerPosition = tester.getTopLeft(marker);
      final movingLine = find
          .descendant(of: marker, matching: find.byType(Transform))
          .first;
      final firstTranslation = tester
          .widget<Transform>(movingLine)
          .transform
          .getTranslation()
          .length;
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        tester.widget<Transform>(movingLine).transform.getTranslation().length,
        lessThan(firstTranslation),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(marker), initialMarkerPosition);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'grid replay retains its timetable state, layout cache and scroll position',
    (tester) async {
      final container = await _pump(
        tester,
        onPageSwitch: true,
        fitToPage: false,
      );
      await _ready(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      final state = tester.state<WeekGridViewState>(find.byType(WeekGridView));
      final theme = Theme.of(tester.element(find.byType(WeekGridView)));
      final body = find
          .descendant(
            of: find.byKey(const Key('adjacent-page-current')),
            matching: find.byKey(const Key('schedule-vertical-body')),
          )
          .first;
      final scroll = tester.widget<SingleChildScrollView>(body).controller!;
      final offset = scroll.position.maxScrollExtent.clamp(0.0, 100.0);
      scroll.jumpTo(offset);
      await tester.pump();
      container.read(appNavIndexProvider.notifier).state = 1;
      await tester.pumpAndSettle();
      container.read(appNavIndexProvider.notifier).state = 0;
      await tester.pumpAndSettle();
      expect(
        tester.state<WeekGridViewState>(find.byType(WeekGridView)),
        same(state),
      );
      expect(scroll.offset, closeTo(offset, .1));
      expect(Theme.of(tester.element(find.byType(WeekGridView))), theme);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'startup system font is isolated from interface font and icon stays visible at first frame',
    (tester) async {
      await _pump(
        tester,
        typography: const TypographySettings(
          appFontId: 'huninn',
          launchFontId: 'system',
        ),
      );
      final wordmark = find.descendant(
        of: find.byKey(const Key('orbit-launch-brand')),
        matching: find.text('Orbit'),
      );
      final style = tester.widget<Text>(wordmark).style!;
      expect(style.inherit, isFalse);
      expect(
        style.fontFamily,
        FontCatalog.systemFamily(defaultTargetPlatform, const Locale('en')),
      );
      expect(style.fontFamily, isNot(FontCatalog.family('huninn')));
      final icon = find.descendant(
        of: find.byKey(const Key('orbit-launch-brand')),
        matching: find.byType(LaunchIcon),
      );
      expect(icon, findsOneWidget);
      // Opacity ancestors contain only the opaque brand layer, not a hidden icon.
      for (final widget in tester.widgetList<Opacity>(
        find.ancestor(of: icon, matching: find.byType(Opacity)),
      )) {
        expect(widget.opacity, 1);
      }
      expect(tester.getCenter(icon).dy, closeTo(400, 1));
    },
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'directions are balanced per column and globally, starts are staggered and bounded',
    () {
      final columns = {
        for (var column = 0; column < 7; column++)
          column: [for (var i = 0; i < column + 1; i++) '$column-$i'],
      };
      for (var seed = 0; seed < 100; seed++) {
        final plan = planCardEntrances(columns, random: Random(seed));
        for (final ids in [...columns.values, plan.keys.toList()]) {
          final above = ids.where((id) => plan[id]!.fromAbove).length;
          expect((above - (ids.length - above)).abs(), lessThanOrEqualTo(1));
        }
        expect(plan.values.map((s) => s.delayMs).toSet().length, plan.length);
        expect(
          plan.values.every((s) => s.delayMs >= 0 && s.delayMs <= 140),
          isTrue,
        );
        final again = planCardEntrances(columns, random: Random(seed));
        expect(plan.keys, again.keys);
        expect(
          plan.values.map((s) => s.fromAbove),
          again.values.map((s) => s.fromAbove),
        );
      }
    },
  );

  test(
    'edge offsets place a whole card outside the scrolled viewport; nearby is 48px',
    () {
      const rect = Rect.fromLTWH(54, 500, 120, 80);
      const viewport = Rect.fromLTWH(54, 400, 400, 600);
      for (final above in [true, false]) {
        final spec = CardEntranceSpec(fromAbove: above, delayMs: 0);
        final offset = cardEntranceOffset(
          rect: rect,
          viewport: viewport,
          spec: spec,
          mode: CardEntranceMode.edge,
        );
        final start = rect.shift(Offset(0, offset));
        expect(start.overlaps(viewport), isFalse);
        expect(
          above ? start.bottom < viewport.top : start.top > viewport.bottom,
          isTrue,
        );
        expect(
          cardEntranceOffset(
            rect: rect,
            viewport: viewport,
            spec: spec,
            mode: CardEntranceMode.nearby,
          ).abs(),
          48,
        );
      }
    },
  );

  for (final mode in CardEntranceMode.values) {
    testWidgets(
      '${mode.name}: timetable, bells and visible red line enter once and end within budget',
      (tester) async {
        final container = await _pump(tester, mode: mode);
        await _ready(tester);
        expect(find.byKey(const Key('orbit-launch-brand')), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 220));
        final wrappers = tester
            .widgetList<LaunchCard>(find.byType(LaunchCard))
            .where((w) => w.spec != null)
            .toList();
        expect(wrappers.length, greaterThan(2));
        expect(wrappers.any((w) => w.child is GridSessionChip), isTrue);
        final marker = find.byKey(const Key('schedule-current-time-line'));
        expect(marker, findsOneWidget);
        expect(
          tester
              .widget<LaunchCard>(
                find.descendant(of: marker, matching: find.byType(LaunchCard)),
              )
              .spec,
          isNotNull,
        );
        final courseWrapper = wrappers.firstWhere(
          (w) => w.child is GridSessionChip,
        );
        final bellWrapper = wrappers.firstWhere(
          (w) => w.child.key == const ValueKey('grid-strong-bell-course-0-0'),
        );
        final cardWrapper = wrappers.firstWhere(
          (w) =>
              w.child is GridSessionChip &&
              (w.child as GridSessionChip).session.id == 'course-0-0',
        );
        expect(bellWrapper.spec, same(cardWrapper.spec));
        expect(bellWrapper.offset, cardWrapper.offset);
        if (mode == CardEntranceMode.nearby) {
          expect(courseWrapper.offset.abs(), 48);
        }
        await tester.pump(const Duration(milliseconds: 280));
        expect(find.byKey(const Key('orbit-launch-brand')), findsNothing);
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump(const Duration(milliseconds: 650));
        expect(_motion(tester).cardsComplete, isTrue);
        final oldSpec = cardWrapper.spec;
        container.read(currentTimeProvider.notifier).state = DateTime(
          2026,
          10,
          12,
          10,
          1,
        );
        await tester.pump();
        final updated = tester
            .widgetList<LaunchCard>(find.byType(LaunchCard))
            .firstWhere(
              (w) =>
                  w.child is GridSessionChip &&
                  (w.child as GridSessionChip).session.id == 'course-0-0',
            );
        expect(updated.spec, same(oldSpec));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'slow data does not hold brand; cards animate once data becomes ready',
    (tester) async {
      final data = Completer<List<CourseSession>>();
      await _pump(tester, data: data.future);
      await _ready(tester);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byKey(const Key('orbit-launch-brand')), findsNothing);
      expect(_motion(tester).canClaimGrid, isTrue);
      data.complete(_courses());
      await tester.pump();
      await tester.pump();
      expect(_motion(tester).canClaimGrid, isFalse);
      await tester.pump(const Duration(milliseconds: 650));
      expect(_motion(tester).cardsComplete, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final scenario in ['hidden', 'reduced', 'notification', 'strong']) {
    testWidgets('$scenario bypasses decorative animation', (tester) async {
      await _pump(
        tester,
        enabled: scenario != 'hidden',
        reduced: scenario == 'reduced',
        payload: scenario == 'notification' ? 'course' : null,
        strong: scenario == 'strong',
      );
      expect(find.byKey(const Key('orbit-launch-brand')), findsNothing);
      expect(_motion(tester).finished, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final count in [2, 3, 4]) {
    testWidgets('$count bottom destinations animate as complete buttons', (
      tester,
    ) async {
      await _pump(tester, hideUpcoming: count < 4, hideImport: count == 2);
      await _ready(tester);
      final destinations = find.byType(NavigationDestination);
      expect(destinations, findsNWidgets(count));
      final reveals = tester
          .widgetList<LaunchReveal>(
            find.ancestor(
              of: destinations,
              matching: find.byType(LaunchReveal),
            ),
          )
          .toList();
      expect(reveals.map((r) => r.startMs), [
        for (var i = 0; i < count; i++) 480 + i * 35,
      ]);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'wide layout animates rail and switching tabs cancels the entrance',
    (tester) async {
      final container = await _pump(tester, size: const Size(1100, 800));
      await _ready(tester);
      expect(find.byType(NavigationRail), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 550));
      container.read(appNavIndexProvider.notifier).state = 3;
      await tester.pump();
      expect(_motion(tester).finished, isTrue);
      container.read(appNavIndexProvider.notifier).state = 0;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('orbit-launch-brand')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('settings preview uses isolated navigation and sample data', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      enabled: false,
      child: const LaunchSettingsPage(),
    );
    container.read(appNavIndexProvider.notifier).state = 3;
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('launch-preview')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('launch-preview')));
    await tester.pumpAndSettle();
    expect(find.byType(GridSessionChip), findsWidgets);
    expect(container.read(appNavIndexProvider), 3);
    expect(
      container.read(sessionsProvider).valueOrNull,
      isNot(
        contains(predicate<CourseSession>((s) => s.id.startsWith('preview-'))),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'hidden time marker has no entrance and moving paint is clipped below dates',
    (tester) async {
      await _pump(tester, now: DateTime(2026, 10, 12, 23));
      await _ready(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('schedule-current-time-line')), findsNothing);
      final clip = find
          .ancestor(
            of: find.byKey(const Key('schedule-vertical-body')),
            matching: find.byType(ClipRect),
          )
          .first;
      final header = tester.getRect(
        find.byKey(const Key('schedule-date-header')),
      );
      expect(tester.getRect(clip).top, closeTo(header.bottom, 0.01));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('pause/resume finishes the startup without replay', (
    tester,
  ) async {
    await _pump(tester);
    await _ready(tester);
    await tester.pump(const Duration(milliseconds: 180));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(_motion(tester).finished, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('orbit-launch-brand')), findsNothing);
    expect(_motion(tester).canClaimGrid, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'missing custom image falls back to bundled icon and cannot stall launch',
    (tester) async {
      await _pump(tester, iconPath: 'missing-orbit-launch-icon.png');
      await _ready(tester);
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .any(
              (w) =>
                  (w.image is AssetImage &&
                      (w.image as AssetImage).assetName == orbitIconAsset) ||
                  (w.image is ResizeImage &&
                      (w.image as ResizeImage).imageProvider is AssetImage &&
                      ((w.image as ResizeImage).imageProvider as AssetImage)
                              .assetName ==
                          orbitIconAsset),
            ),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byKey(const Key('orbit-launch-brand')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'empty first result consumes the entrance without delaying brand exit',
    (tester) async {
      final container = await _pump(
        tester,
        data: Future.value([]),
        onPageSwitch: true,
      );
      await _ready(tester);
      expect(_motion(tester).canClaimGrid, isFalse);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byKey(const Key('orbit-launch-brand')), findsNothing);
      expect(find.byType(GridSessionChip), findsNothing);
      container.read(appNavIndexProvider.notifier).state = 1;
      await tester.pumpAndSettle();
      container.read(appNavIndexProvider.notifier).state = 0;
      await tester.pump();
      final empty = find.descendant(
        of: find.byKey(const ValueKey('app-destination-0')),
        matching: find.byType(EmptyState),
      );
      expect(
        tester
            .widgetList<PageModule>(
              find.ancestor(of: empty, matching: find.byType(PageModule)),
            )
            .any((module) => module.enabled),
        isTrue,
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'local presentation settings persist and tolerate unknown modes',
    () async {
      final service = SettingsService();
      await service.saveLocalJson(
        'launch_presentation_v1',
        const LaunchSettings(
          iconPath: 'icon.png',
          cardEntrance: CardEntranceMode.nearby,
        ).toJson(),
      );
      final loaded = LaunchSettings.fromJson(
        await SettingsService().loadLocalJson('launch_presentation_v1'),
      );
      expect(loaded.iconPath, 'icon.png');
      expect(loaded.cardEntrance, CardEntranceMode.nearby);
      expect(
        LaunchSettings.fromJson({'cardEntrance': 'future'}).cardEntrance,
        CardEntranceMode.edge,
      );
    },
  );
}
