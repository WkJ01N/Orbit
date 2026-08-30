import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ScheduleSettingsNotifier extends ScheduleDisplaySettingsNotifier {
  @override
  ScheduleDisplaySettings build() => const ScheduleDisplaySettings();
}

class _DensityNotifier extends GridDensityNotifier {
  @override
  GridDensity build() => GridDensity.standard;
}

class _CurrentTimeNotifier extends CurrentTimeNotifier {
  @override
  DateTime build() => DateTime(2026, 8, 24, 12);
}

CourseSession _session(DateTime date, String code) {
  final start = DateTime(date.year, date.month, date.day, 8);
  final end = DateTime(date.year, date.month, date.day, 18);
  return CourseSession(
    id: CourseSession.buildId(
      date: date,
      courseCode: code,
      startAt: start,
      section: '01',
    ),
    classType: 'Class',
    room: 'A101',
    date: date,
    weekday: date.weekday,
    courseName: 'Course $code',
    courseCode: code,
    section: '01',
    startAt: start,
    endAt: end,
    teachers: const ['Teacher'],
    faculty: 'Faculty',
    semester: '2026',
  );
}

void main() {
  testWidgets('课表箭头和键盘使用动画且保留纵向滚动位置', (tester) async {
    final monday = DateTime(2026, 8, 24);
    final sessions = [
      for (var day = 0; day < 5; day++)
        _session(monday.add(Duration(days: day)), 'C$day'),
    ];
    final container = ProviderContainer(
      overrides: [
        selectedScheduleDateProvider.overrideWith((ref) => monday),
        scheduleDisplaySettingsProvider.overrideWith(
          _ScheduleSettingsNotifier.new,
        ),
        gridDensityProvider.overrideWith(_DensityNotifier.new),
        currentTimeProvider.overrideWith(_CurrentTimeNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(320, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
            body: WeekGridView(
              grid: GridBuilder().buildWeekGrid(
                weekStart: monday,
                sessions: sessions,
              ),
              sessions: sessions,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final currentPage = find.byKey(const Key('adjacent-page-current'));
    final currentScrollable = find.descendant(
      of: currentPage,
      matching: find.byType(Scrollable),
    );
    await tester.drag(currentScrollable, const Offset(0, -180));
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(currentScrollable)
        .position
        .pixels;
    expect(before, greaterThan(0));

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(selectedScheduleDateProvider), monday);
    await tester.pumpAndSettle();
    expect(
      container.read(selectedScheduleDateProvider),
      monday.add(const Duration(days: 1)),
    );
    final after = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('adjacent-page-current')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    expect(after, closeTo(before, 0.1));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      container.read(selectedScheduleDateProvider),
      monday.add(const Duration(days: 2)),
    );
  });
}
