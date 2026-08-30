import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/grid_builder.dart';
import 'test_providers.dart';

class _GoldenScheduleSettingsNotifier extends ScheduleDisplaySettingsNotifier {
  @override
  ScheduleDisplaySettings build() => const ScheduleDisplaySettings();
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
  @override
  Map<String, Color> build() => const {};
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
  required String golden,
}) async {
  final sessions = _sessions();
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
          _GoldenScheduleSettingsNotifier.new,
        ),
        gridDensityProvider.overrideWith(_GoldenDensityNotifier.new),
        weekStartDayProvider.overrideWith(_GoldenWeekStartNotifier.new),
        courseColorOverridesProvider.overrideWith(
          _GoldenCourseColorsNotifier.new,
        ),
        currentTimeProvider.overrideWith(_GoldenCurrentTimeNotifier.new),
      ],
      child: MaterialApp(
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
  await expectLater(find.byType(WeekGridView), matchesGoldenFile(golden));
}

void main() {
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
  });

  testWidgets('320dp 单日课表视觉基线', (tester) async {
    await _pumpSchedule(tester, width: 320, golden: 'goldens/schedule_320.png');
  });

  testWidgets('400dp 三日课表视觉基线', (tester) async {
    await _pumpSchedule(tester, width: 400, golden: 'goldens/schedule_400.png');
  });

  testWidgets('900dp 整周课表视觉基线', (tester) async {
    await _pumpSchedule(tester, width: 900, golden: 'goldens/schedule_900.png');
  });
}
