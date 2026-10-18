import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/motion/page_entrance.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/core/motion/launch_motion.dart';
import 'package:orbit/features/session/course_history_list.dart';
import 'package:orbit/features/session/course_quick_action_bar.dart';
import 'package:orbit/features/session/quick_action_layout.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/features/session/semester_field.dart';
import 'package:orbit/features/settings/course_quick_action_settings_page.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_quick_actions.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:orbit/providers/quick_action_providers.dart';
import 'package:orbit/services/course_catalog.dart';
import 'package:orbit/services/semester_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CourseSession sample(
  String id,
  DateTime start, {
  String semester = '2026 autumn',
  SessionKind kind = SessionKind.course,
  DateTime? deletedAt,
}) => CourseSession(
  id: id,
  classType: 'Lecture',
  room: 'A101',
  date: DateUtils.dateOnly(start),
  weekday: start.weekday,
  courseName: 'Mathematics',
  courseCode: 'MATH101',
  section: '1',
  startAt: start,
  endAt: start.add(const Duration(hours: 1)),
  teachers: const ['Teacher'],
  faculty: '',
  semester: semester,
  kind: kind,
  deletedAt: deletedAt,
);

class _Quick extends CourseQuickActionsNotifier {
  _Quick(this.settings);
  final CourseQuickActionSettings settings;
  @override
  CourseQuickActionSettings build() => settings;
}

class _Launch extends LaunchSettingsNotifier {
  @override
  LaunchSettings build() => const LaunchSettings(onPageSwitch: true);
}

class _Config extends ImportConfigurationNotifier {
  @override
  Future<ImportConfiguration> build() async => const ImportConfiguration();
}

class _Reminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async =>
      const ReminderSettings(enabled: false);
}

Future<void> captureUi(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('ORBIT_CAPTURE_V163')) return;
  final shadowsDisabled = debugDisableShadows;
  debugDisableShadows = false;
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('v163-capture')),
    );
    final result = await boundary.toImage();
    final bytes = await result.toByteData(format: ui.ImageByteFormat.png);
    await File(
      'build/v163-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    result.dispose();
  });
  debugDisableShadows = shadowsDisabled;
}

Widget app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  navigatorObservers: [pageEntranceRoutes],
  builder: (_, child) =>
      RepaintBoundary(key: const Key('v163-capture'), child: child!),
  home: child,
);

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('ORBIT_CAPTURE_V163') ||
        !Platform.isWindows) {
      return;
    }
    final font = await File('C:/Windows/Fonts/simhei.ttf').readAsBytes();
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.sublistView(font)))).load();
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final icons = await File(
      '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
    'semester field includes statistics-only semesters and keeps their identity',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? selectedId;
      final container = ProviderContainer(
        overrides: [
          importConfigurationProvider.overrideWith(_Config.new),
          sessionsProvider.overrideWith((_) async => []),
          formSemesterRecordsProvider.overrideWith(
            (_) async => [
              {
                'kind': 'course',
                'semester': '2025 Autumn archive',
                'semesterId': 'historic-stable-id',
                'startAt': '2025-10-18T09:00:00',
              },
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(
            Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Column(
                  children: [
                    SemesterField(
                      controller: controller,
                      onSelected: (id) => selectedId = id,
                    ),
                    TextButton(
                      onPressed: () {
                        final semester = resolveFormSemester(
                          ref,
                          controller.text,
                          DateTime(2026, 10, 18),
                          id: selectedId,
                        );
                        expect(semester.id, 'historic-stable-id');
                        expect(semester.name, '2025 Autumn archive');
                      },
                      child: const Text('Resolve'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<SemesterInfo>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025 Autumn archive'));
      await tester.pumpAndSettle();
      expect(controller.text, '2025 Autumn archive');
      await tester.tap(find.text('Resolve'));
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'course history groups whole courses by semester and ignores exams/deleted future rows',
    () {
      final now = DateTime(2026, 10, 18, 12);
      final ended = sample(
        'ended',
        now.subtract(const Duration(days: 7)),
        semester: '2026 spring',
      );
      final past = sample('past', now.subtract(const Duration(days: 1)));
      final future = sample('future', now.add(const Duration(days: 1)));
      final exam = sample(
        'exam',
        now.add(const Duration(days: 20)),
        semester: '2026 spring',
        kind: SessionKind.exam,
      );
      final deleted = sample(
        'deleted',
        now.add(const Duration(days: 1)),
        semester: '2026 spring',
        deletedAt: now,
      );
      final catalog = CourseCatalog([ended, past, future, exam, deleted], now);
      expect(catalog.isEnded(ended), isTrue);
      expect(catalog.isEnded(past), isFalse);
      expect(catalog.isEnded(future), isFalse);
      expect(catalog.isEnded(exam), isFalse);
    },
  );
  test(
    'quick action positions stay a permutation and damaged preferences recover',
    () {
      const defaults = CourseQuickActionSettings();
      final swapped = defaults.swap(0, SessionAction.delete);
      expect(swapped.positions[0], SessionAction.delete);
      expect(swapped.positions[2], SessionAction.edit);
      expect(swapped.positions.toSet().length, 4);
      expect(
        CourseQuickActionSettings.fromJson({
          'positions': ['edit', 'edit', 'note', 'delete'],
        }).positions,
        defaults.positions,
      );
      expect(
        CourseQuickActionSettings.fromJson(swapped.toJson()).positions,
        swapped.positions,
      );
    },
  );
  const viewport = Rect.fromLTWH(0, 0, 400, 800);
  testWidgets(
    'an open course selector reclassifies a course after its last class ends',
    (tester) async {
      var now = DateTime(2026, 10, 18, 12);
      final course = sample('ending', now);
      final catalog = CourseCatalog([course], now, clock: () => now);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: CourseHistoryList<CourseSession>(
              items: [course],
              isEnded: catalog.isEnded,
              itemBuilder: (_, s) => ListTile(title: Text(s.courseName)),
            ),
          ),
        ),
      );
      expect(find.text('Mathematics'), findsOneWidget);
      now = now.add(const Duration(hours: 2));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Mathematics'), findsNothing);
      await tester.tap(find.byKey(const Key('view-ended-courses')));
      await tester.pump();
      expect(find.text('Mathematics'), findsOneWidget);
    },
  );
  final placements = <String, Rect>{
    'center': const Rect.fromLTWH(160, 330, 80, 100),
    'right': const Rect.fromLTWH(320, 330, 80, 100),
    'left': const Rect.fromLTWH(0, 330, 80, 100),
    'top': const Rect.fromLTWH(160, 0, 80, 100),
    'bottom': const Rect.fromLTWH(160, 700, 80, 100),
    'topLeft': const Rect.fromLTWH(0, 0, 80, 100),
    'topRight': const Rect.fromLTWH(320, 0, 80, 100),
    'bottomLeft': const Rect.fromLTWH(0, 700, 80, 100),
    'bottomRight': const Rect.fromLTWH(320, 700, 80, 100),
  };
  for (final placement in placements.entries) {
    test(
      'quick action geometry selects each visible target at ${placement.key}',
      () {
        final layout = QuickActionLayout(
          viewport: viewport,
          source: placement.value,
          settings: const CourseQuickActionSettings(),
        );
        expect(layout.cells.map((c) => c.action).toSet().length, 4);
        expect(layout.hitTest(placement.value.center), isNull);
        for (final cell in layout.cells) {
          expect(viewport.contains(cell.slot.center), isTrue);
          expect(
            layout.hitTest(cell.slot.center)?.action,
            cell.action,
            reason: '${placement.key}: ${cell.action} at ${cell.slot.center}',
          );
        }
      },
    );
  }
  test('paired quick actions light distinct portions of the same edge', () {
    final layout = QuickActionLayout(
      viewport: viewport,
      source: placements['right']!,
      settings: const CourseQuickActionSettings(),
    );
    final left = layout.cells.where((c) => c.edges.single.side == 3).toList()
      ..sort((a, b) => a.edges.single.start.compareTo(b.edges.single.start));
    expect(left.length, 2);
    expect(
      left.first.edges.single.end,
      closeTo(left.last.edges.single.start, .01),
    );
    expect(left.first.slot.size, left.last.slot.size);
  });
  test('float inward lifts a corner card and preserves four directions', () {
    final layout = QuickActionLayout(
      viewport: viewport,
      source: placements['bottomRight']!,
      settings: const CourseQuickActionSettings(
        edgeMode: QuickActionEdgeMode.floatInward,
      ),
    );
    expect(layout.card.center.dx, lessThan(layout.source.center.dx));
    expect(layout.card.center.dy, lessThan(layout.source.center.dy));
    expect(layout.card.width, greaterThan(layout.source.width));
    for (final cell in layout.cells) {
      expect(layout.hitTest(cell.slot.center)?.action, cell.action);
    }
  });
  testWidgets(
    'historical choices remain lazy and folded until explicitly opened',
    (tester) async {
      var builtHistory = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: CourseHistoryList<int>(
              items: List.generate(1000, (i) => i),
              isEnded: (i) => i > 1,
              itemBuilder: (_, i) {
                if (i > 1) builtHistory++;
                return ListTile(title: Text('Choice $i'));
              },
            ),
          ),
        ),
      );
      expect(builtHistory, 0);
      await tester.tap(find.byKey(const Key('view-ended-courses')));
      await tester.pump();
      expect(builtHistory, greaterThan(0));
      expect(builtHistory, lessThan(30));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'destination is hidden from its first frame and starts at navigation midpoint',
    (tester) async {
      final nav = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 260),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [launchSettingsProvider.overrideWith(_Launch.new)],
          child: app(
            PageEntranceHost(
              index: 1,
              active: true,
              startup: false,
              navigation: nav,
              child: const Scaffold(body: PageModule(child: Text('Module'))),
            ),
          ),
        ),
      );
      double opacity() => tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byType(PageEntranceHost),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(opacity(), 0);
      nav.value = .49;
      await tester.pump();
      expect(opacity(), 0);
      nav.value = .5;
      await tester.pump();
      final motion = tester
          .widget<ModuleEntranceScope>(find.byType(ModuleEntranceScope))
          .motion;
      expect(motion.pending, isFalse);
      expect(motion.clock.value, 0);
      await tester.pump(const Duration(milliseconds: 210));
      expect(motion.clock.value, greaterThan(0));
      await tester.pumpAndSettle();
      expect(motion.clock.value, 1);
      await tester.pumpWidget(const SizedBox());
      nav.dispose();
    },
  );

  testWidgets(
    'module hit testing follows its painted position during entrance',
    (tester) async {
      final nav = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 260),
      );
      var taps = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [launchSettingsProvider.overrideWith(_Launch.new)],
          child: app(
            PageEntranceHost(
              index: 1,
              active: true,
              startup: false,
              navigation: nav,
              child: Scaffold(
                body: Center(
                  child: PageModule(
                    child: SizedBox(
                      key: const Key('moving-hit'),
                      width: 4,
                      height: 4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      nav.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const Key('moving-hit'))) +
            const Offset(.2, 1),
      );
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox());
      nav.dispose();
    },
  );

  testWidgets(
    'launch wrappers preserve editable state across pending, replay and finished phases',
    (tester) async {
      final first = LaunchMotion(
        vsync: tester,
        settings: const LaunchSettings(),
      )..finish();
      final replay = LaunchMotion(
        vsync: tester,
        settings: const LaunchSettings(),
        startup: false,
      );
      final last = LaunchMotion(vsync: tester, settings: const LaunchSettings())
        ..finish();
      final motion = ValueNotifier(first);
      final prepared = ValueNotifier(false);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: ValueListenableBuilder(
              valueListenable: motion,
              builder: (_, current, _) => LaunchMotionScope(
                motion: current,
                child: ValueListenableBuilder(
                  valueListenable: prepared,
                  builder: (_, ready, _) => Column(
                    children: [
                      LaunchReveal(
                        child: const TextField(key: Key('stable-reveal')),
                      ),
                      LaunchCard(
                        pending: !ready,
                        spec: ready
                            ? const CardEntranceSpec(
                                fromAbove: true,
                                delayMs: 0,
                              )
                            : null,
                        child: const TextField(key: Key('stable-card')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final revealState = tester.state(find.byKey(const Key('stable-reveal')));
      final cardState = tester.state(find.byKey(const Key('stable-card')));
      await tester.enterText(
        find.byKey(const Key('stable-card')),
        'Draft note',
      );
      motion.value = replay;
      await tester.pump();
      expect(
        tester.state(find.byKey(const Key('stable-reveal'))),
        same(revealState),
      );
      expect(
        tester.state(find.byKey(const Key('stable-card'))),
        same(cardState),
      );
      prepared.value = true;
      await tester.pump();
      motion.value = last;
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byKey(const Key('stable-reveal'))),
        same(revealState),
      );
      expect(
        tester.state(find.byKey(const Key('stable-card'))),
        same(cardState),
      );
      expect(find.text('Draft note'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      motion.dispose();
      prepared.dispose();
      first.dispose();
      replay.dispose();
      last.dispose();
    },
  );

  testWidgets(
    'quick action settings swap positions and persist the enable switch',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          courseQuickActionsProvider.overrideWith(
            () => _Quick(const CourseQuickActionSettings()),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(const CourseQuickActionSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(
        container.read(courseQuickActionsProvider).positions[0],
        SessionAction.delete,
      );
      expect(
        container.read(courseQuickActionsProvider).positions[2],
        SessionAction.edit,
      );
      await captureUi(tester, 'quick-settings');
      await tester.tap(find.byKey(const Key('course-quick-actions-enabled')));
      await tester.pumpAndSettle();
      expect(container.read(courseQuickActionsProvider).enabled, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'course_quick_actions_v1',
        ),
        contains('"enabled":false'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone settings indicator moves continuously and retargets midflight',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reminderSettingsProvider.overrideWith(_Reminders.new)],
          child: app(const SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      final start = tester
          .getTopLeft(find.byKey(const Key('settings-category-indicator-0')))
          .dx;
      await tester.tap(find.byKey(const Key('settings-category-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final middle = tester
          .getTopLeft(find.byKey(const Key('settings-category-indicator-1')))
          .dx;
      expect(middle, greaterThan(start));
      expect(middle, lessThan(start + 100));
      await tester.tap(find.byKey(const Key('settings-category-3')));
      await tester.pump();
      expect(
        tester
            .getTopLeft(find.byKey(const Key('settings-category-indicator-3')))
            .dx,
        closeTo(middle, .01),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const Key('settings-category-indicator-3')))
            .dx,
        closeTo(start + 300, .01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  Future<ProviderContainer> quickApp(
    WidgetTester tester, {
    bool floating = false,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = sample('source', DateTime(2026, 10, 19, 9));
    final container = ProviderContainer(
      overrides: [
        courseQuickActionsProvider.overrideWith(
          () => _Quick(
            CourseQuickActionSettings(
              edgeMode: floating
                  ? QuickActionEdgeMode.floatInward
                  : QuickActionEdgeMode.merge,
            ),
          ),
        ),
        sessionsProvider.overrideWith((ref) async => [session]),
        importConfigurationProvider.overrideWith(_Config.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(
          Scaffold(
            body: CourseQuickActionViewport(
              child: Align(
                alignment: floating ? Alignment.bottomRight : Alignment.center,
                child: SizedBox(
                  width: 80,
                  height: 100,
                  child: CourseQuickActionGesture(
                    session: session,
                    onFallback: () {},
                    child: const ColoredBox(
                      key: Key('quick-source'),
                      color: Colors.blue,
                      child: Text('Course'),
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
    return container;
  }

  testWidgets(
    'sliding during deployment highlights an action and release opens edit',
    (tester) async {
      final container = await quickApp(tester);
      expect(
        MediaQuery.sizeOf(
          tester.element(find.byType(CourseQuickActionGesture)),
        ).width,
        400,
      );
      final point = tester.getCenter(find.byKey(const Key('quick-source')));
      final gesture = await tester.startGesture(point);
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pump();
      expect(container.read(activeQuickActionCourseProvider), 'source');
      expect(find.byKey(const Key('course-quick-action-edit')), findsOneWidget);
      await gesture.moveTo(point - const Offset(0, 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final item = tester.widget<Material>(
        find.byKey(const Key('course-quick-action-edit')),
      );
      expect(
        item.color,
        isNot(
          Theme.of(
            tester.element(find.byKey(const Key('course-quick-action-edit'))),
          ).colorScheme.surfaceContainerHigh,
        ),
      );
      await captureUi(tester, 'quick-bar');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(SessionEditSheet), findsOneWidget);
      Navigator.pop(tester.element(find.byType(SessionEditSheet)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('course-quick-action-edit')), findsNothing);
      expect(container.read(activeQuickActionCourseProvider), isNull);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'floating the card under a stationary finger never commits an action',
    (tester) async {
      final container = await quickApp(tester, floating: true);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('quick-source'))),
      );
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pump(const Duration(milliseconds: 400));
      await captureUi(tester, 'quick-floating');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(SessionEditSheet), findsNothing);
      expect(container.read(activeQuickActionCourseProvider), isNull);
      expect(find.byKey(const Key('course-quick-action-edit')), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
