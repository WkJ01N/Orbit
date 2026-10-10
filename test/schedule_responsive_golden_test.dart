import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/grid/strong_grid_decoration.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/models/wake_text.dart';
import 'package:orbit/services/course_color_utils.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/grid_builder.dart';
import 'test_providers.dart';

class _GoldenScheduleSettingsNotifier extends ScheduleDisplaySettingsNotifier {
  _GoldenScheduleSettingsNotifier(this.initial);
  final ScheduleDisplaySettings initial;
  @override
  ScheduleDisplaySettings build() => initial;
}

class _GoldenDensityNotifier extends GridDensityNotifier {
  @override
  GridDensity build() => GridDensity.standard;
}

class _GoldenWeekStartNotifier extends WeekStartDayNotifier {
  @override
  int build() => DateTime.monday;
}

class _GoldenCourseColorsNotifier extends CourseColorOverridesNotifier {
  _GoldenCourseColorsNotifier(this.initial);
  final Map<String, Color> initial;
  @override
  Map<String, Color> build() => initial;
}

class _GoldenCurrentTimeNotifier extends CurrentTimeNotifier {
  @override
  DateTime build() => DateTime(2026, 8, 30, 12);
}

CourseSession _goldenSession({
  required DateTime date,
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
  required String name,
  required String code,
  required String room,
}) {
  final start = DateTime(
    date.year,
    date.month,
    date.day,
    startHour,
    startMinute,
  );
  final end = DateTime(date.year, date.month, date.day, endHour, endMinute);
  return CourseSession(
    id: CourseSession.buildId(
      date: date,
      courseCode: code,
      startAt: start,
      section: '01',
    ),
    classType: '课堂',
    room: room,
    date: date,
    weekday: date.weekday,
    courseName: name,
    courseCode: code,
    section: '01',
    startAt: start,
    endAt: end,
    teachers: const ['陈老师'],
    faculty: '工程学院',
    semester: '2026',
  );
}

List<CourseSession> _sessions() {
  final monday = DateTime(2026, 8, 24);
  return [
    _goldenSession(
      date: monday,
      startHour: 8,
      startMinute: 30,
      endHour: 9,
      endMinute: 15,
      name: '跨平台移动应用设计与实践',
      code: 'APP201',
      room: '科技楼 A-308',
    ),
    _goldenSession(
      date: monday,
      startHour: 10,
      startMinute: 0,
      endHour: 11,
      endMinute: 30,
      name: '高等数学 II',
      code: 'MATH202',
      room: '教学楼 B-105',
    ),
    _goldenSession(
      date: monday.add(const Duration(days: 1)),
      startHour: 9,
      startMinute: 0,
      endHour: 10,
      endMinute: 30,
      name: '大学物理实验',
      code: 'PHYS203',
      room: '实验中心 4-201',
    ),
    _goldenSession(
      date: monday.add(const Duration(days: 1)),
      startHour: 9,
      startMinute: 30,
      endHour: 10,
      endMinute: 15,
      name: '学术写作',
      code: 'WRIT101',
      room: '图书馆研讨室',
    ),
    _goldenSession(
      date: monday.add(const Duration(days: 2)),
      startHour: 14,
      startMinute: 0,
      endHour: 16,
      endMinute: 0,
      name: '软件工程项目管理',
      code: 'SE301',
      room: '创新中心 C-506',
    ),
    _goldenSession(
      date: monday.add(const Duration(days: 4)),
      startHour: 11,
      startMinute: 0,
      endHour: 12,
      endMinute: 0,
      name: '计算机网络',
      code: 'NET204',
      room: '教学楼 D-204',
    ),
  ];
}

Future<void> _pumpSchedule(
  WidgetTester tester, {
  required double width,
  String? golden,
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
  bool strong = false,
  bool variedColors = false,
  ScheduleDisplaySettings settings = const ScheduleDisplaySettings(),
  List<CourseSession>? courseSessions,
}) async {
  final sessions = courseSessions ?? _sessions();
  final weekStart = DateTime(2026, 8, 24);
  final grid = GridBuilder().buildWeekGrid(
    weekStart: weekStart,
    sessions: sessions,
  );
  await tester.binding.setSurfaceSize(Size(width, 760));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testProviderOverrides(),
        selectedScheduleDateProvider.overrideWith((ref) => weekStart),
        scheduleDisplaySettingsProvider.overrideWith(
          () => _GoldenScheduleSettingsNotifier(settings),
        ),
        gridDensityProvider.overrideWith(_GoldenDensityNotifier.new),
        weekStartDayProvider.overrideWith(_GoldenWeekStartNotifier.new),
        courseColorOverridesProvider.overrideWith(
          () => _GoldenCourseColorsNotifier({
            if (variedColors)
              for (var i = 0; i < sessions.length; i++)
                courseColorKey(sessions[i]): [
                  Colors.teal,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                ][i % 4],
          }),
        ),
        currentTimeProvider.overrideWith(_GoldenCurrentTimeNotifier.new),
        strongCourseIdsProvider.overrideWith(
          (_) async => strong ? sessions.map((s) => s.id).toSet() : <String>{},
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        locale: defaultLocale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RepaintBoundary(
            child: WeekGridView(grid: grid, sessions: sessions),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  if (golden != null) {
    await expectLater(find.byType(WeekGridView), matchesGoldenFile(golden));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('课程卡片使用统一的 8px 圆角', (tester) async {
    await _pumpSchedule(tester, width: 400, golden: 'goldens/schedule_400.png');

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(GridSessionChip).first,
            matching: find.byType(Material),
          )
          .first,
    );
    final shape = material.shape! as RoundedRectangleBorder;
    final radius = shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
    expect(radius, 8);
    final shortestCard = find.byWidgetPredicate(
      (widget) =>
          widget is GridSessionChip && widget.session.courseCode == 'APP201',
    );
    expect(
      find.descendant(of: shortestCard, matching: find.text('科技楼 A-308')),
      findsWidgets,
    );
    expect(
      find.descendant(of: shortestCard, matching: find.text('08:30 - 09:15')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('320dp compact week tolerates 200 percent text scaling', (
    tester,
  ) async {
    await _pumpSchedule(
      tester,
      width: 320,
      textScaler: const TextScaler.linear(2),
    );

    for (var day = 24; day <= 30; day++) {
      expect(find.byKey(Key('schedule-day-2026-8-$day')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 紧凑整周课表视觉基线', (tester) async {
    await _pumpSchedule(tester, width: 320, golden: 'goldens/schedule_320.png');
  }, skip: !Platform.isWindows);

  testWidgets('400dp 紧凑整周课表视觉基线', (tester) async {
    await _pumpSchedule(tester, width: 400, golden: 'goldens/schedule_400.png');
  }, skip: !Platform.isWindows);

  testWidgets('900dp 整周课表视觉基线', (tester) async {
    await _pumpSchedule(tester, width: 900, golden: 'goldens/schedule_900.png');
  }, skip: !Platform.isWindows);

  testWidgets('360dp 深色紧凑整周全部日期在屏幕内', (tester) async {
    await _pumpSchedule(
      tester,
      width: 360,
      brightness: Brightness.dark,
      golden: Platform.isWindows ? 'goldens/schedule_360_dark.png' : null,
    );
    for (var day = 24; day <= 30; day++) {
      final rect = tester.getRect(find.byKey(Key('schedule-day-2026-8-$day')));
      expect(rect.left, greaterThanOrEqualTo(54));
      expect(rect.right, lessThanOrEqualTo(360.001));
    }
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'strong grid visual baseline ${width.toInt()} ${brightness.name}',
        (tester) async {
          await _pumpSchedule(
            tester,
            width: width,
            strong: true,
            variedColors: true,
            brightness: brightness,
            golden:
                'goldens/schedule_strong_${width.toInt()}_${brightness.name}.png',
          );
          expect(find.byType(StrongCourseBadge), findsWidgets);
          expect(tester.takeException(), isNull);
        },
        skip: !Platform.isWindows,
      );
    }
  }

  testWidgets(
    'strong bells sit outside cards and tapping shows guidance only',
    (tester) async {
      await _pumpSchedule(tester, width: 900, strong: true, variedColors: true);
      final chip = find.byType(GridSessionChip).first;
      final session = tester.widget<GridSessionChip>(chip).session;
      final bell = find.byKey(ValueKey('grid-strong-bell-${session.id}'));
      final cardRect = tester.getRect(chip);
      final bellRect = tester.getRect(bell);
      expect(bellRect.size, const Size(14, 14));
      expect(bellRect.center.dx, closeTo(cardRect.center.dx, .001));
      expect(bellRect.bottom, closeTo(cardRect.top - 2, .001));
      expect(
        find.descendant(of: chip, matching: find.byType(StrongCourseBadge)),
        findsNothing,
      );
      final ink = tester.widget<Ink>(
        find.descendant(of: chip, matching: find.byType(Ink)).first,
      );
      final gradient =
          (ink.decoration! as BoxDecoration).gradient! as LinearGradient;
      final material = tester.widget<Material>(
        find.descendant(of: chip, matching: find.byType(Material)).first,
      );
      expect(
        gradient.colors.first,
        Color.alphaBlend(
          strongGridHighlight(Colors.teal).withValues(alpha: .25),
          material.color!,
        ),
      );
      final icon = tester.widget<Icon>(
        find.descendant(of: bell, matching: find.byType(Icon)),
      );
      expect(icon.color, strongGridHighlight(Colors.teal));
      await tester.tap(bell);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.textContaining(WakeText.of(tester.element(chip)).guide),
        findsOneWidget,
      );
      expect(tester.widget<GridSessionChip>(chip).isSelected, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden bell retains the gradient and strong reminder semantics',
    (tester) async {
      final courses = _sessions().take(1).toList();
      final first = courses.first;
      courses.add(
        first.copyWith(
          id: 'next',
          startAt: first.endAt,
          endAt: first.endAt.add(const Duration(minutes: 45)),
        ),
      );
      await _pumpSchedule(
        tester,
        width: 900,
        strong: true,
        courseSessions: courses,
      );
      final next = find.byWidgetPredicate(
        (w) => w is GridSessionChip && w.session.id == 'next',
      );
      expect(find.byKey(const ValueKey('grid-strong-bell-next')), findsNothing);
      expect(
        find.descendant(
          of: next,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Ink && (w.decoration as BoxDecoration?)?.gradient != null,
          ),
        ),
        findsOneWidget,
      );
      final label = WakeText.of(tester.element(next)).strong;
      final semantics = tester.widget<Semantics>(
        find.descendant(of: next, matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.label, contains(label));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 500.0, 900.0]) {
    for (final fit in [false, true]) {
      testWidgets(
        'strong adaptive $width fit=$fit preserves card text geometry',
        (tester) async {
          final settings = ScheduleDisplaySettings(
            narrowLayout: NarrowScheduleLayout.adaptive,
            fitToPage: fit,
          );
          Future<void> pump(bool strong) => _pumpSchedule(
            tester,
            width: width,
            strong: strong,
            settings: settings,
            textScaler: const TextScaler.linear(2),
          );
          await pump(false);
          final chip = find.byType(GridSessionChip).first;
          final before = tester.getRect(chip);
          final texts = find.descendant(of: chip, matching: find.byType(Text));
          final beforeText = [
            for (final element in texts.evaluate())
              tester.getRect(find.byWidget(element.widget)),
          ];
          await pump(true);
          expect(tester.getRect(chip), before);
          expect([
            for (final element in texts.evaluate())
              tester.getRect(find.byWidget(element.widget)),
          ], beforeText);
          expect(
            find.descendant(of: chip, matching: find.byType(StrongCourseBadge)),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('hover guidance and scrolling never leave a partial bell', (
    tester,
  ) async {
    await _pumpSchedule(tester, width: 900, strong: true);
    final chip = find.byType(GridSessionChip).first;
    final session = tester.widget<GridSessionChip>(chip).session;
    final bell = find.byKey(ValueKey('grid-strong-bell-${session.id}'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(bell));
    await tester.pump(const Duration(seconds: 1));
    final label = WakeText.of(tester.element(chip)).guide;
    expect(find.textContaining(label), findsOneWidget);
    await mouse.removePointer();
    await tester.pump(const Duration(seconds: 1));
    final body = find.byKey(const Key('schedule-timeline-body'));
    final localTop = tester.getRect(bell).top - tester.getRect(body).top;
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('schedule-vertical-body')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(localTop + 1);
    await tester.pump();
    expect(bell, findsNothing);
    expect(
      find.descendant(
        of: chip,
        matching: find.byWidgetPredicate(
          (w) => w is Ink && (w.decoration as BoxDecoration?)?.gradient != null,
        ),
      ),
      findsOneWidget,
    );
    scrollable.position.jumpTo(0);
    await tester.pump();
    expect(bell, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact large text and short fit cards keep their full text area',
    (tester) async {
      for (final fit in [false, true]) {
        await _pumpSchedule(
          tester,
          width: 320,
          strong: true,
          settings: ScheduleDisplaySettings(fitToPage: fit),
          textScaler: const TextScaler.linear(2),
        );
        for (final chip in find.byType(GridSessionChip).evaluate()) {
          expect(
            find.descendant(
              of: find.byWidget(chip.widget),
              matching: find.byType(StrongCourseBadge),
            ),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
