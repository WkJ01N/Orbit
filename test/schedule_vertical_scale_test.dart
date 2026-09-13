import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/grid_builder.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedSettings extends ScheduleDisplaySettingsNotifier {
  _FixedSettings(this.initial);
  final ScheduleDisplaySettings initial;
  @override
  ScheduleDisplaySettings build() => initial;
}

class _FixedDensity extends GridDensityNotifier {
  _FixedDensity(this.initial);
  final GridDensity initial;
  @override
  GridDensity build() => initial;
}

class _FixedTime extends CurrentTimeNotifier {
  @override
  DateTime build() => DateTime(2026, 8, 24, 12);
}

class _FixedReminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
}

class _FixedLocale extends LocaleNotifier {
  @override
  Locale build() => const Locale('en');
}

class _DelayedSettingsService extends SettingsService {
  final initialLoad = Completer<ScheduleDisplaySettings>();
  final firstSave = Completer<void>();
  final saved = <ScheduleDisplaySettings>[];

  @override
  Future<ScheduleDisplaySettings> loadScheduleDisplaySettings() =>
      initialLoad.future;

  @override
  Future<void> saveScheduleDisplaySettings(
    ScheduleDisplaySettings settings,
  ) async {
    saved.add(settings);
    if (saved.length == 1) await firstSave.future;
  }
}

CourseSession _session(
  String id,
  int start,
  int end, {
  String name = 'Course',
  DateTime? onDate,
}) {
  final date = onDate ?? DateTime(2026, 8, 24);
  return CourseSession(
    id: id,
    classType: 'Class',
    room: 'Room A101',
    date: date,
    weekday: DateTime.monday,
    courseName: name,
    courseCode: id,
    section: '01',
    startAt: date.add(Duration(minutes: start)),
    endAt: date.add(Duration(minutes: end)),
    teachers: const ['Teacher'],
    faculty: 'Faculty',
    semester: '2026',
  );
}

Future<ProviderContainer> _pumpGrid(
  WidgetTester tester, {
  double width = 400,
  double height = 520,
  ScheduleDisplaySettings settings = const ScheduleDisplaySettings(),
  GridDensity density = GridDensity.standard,
  List<CourseSession>? sessions,
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
}) async {
  SharedPreferences.setMockInitialValues({});
  final courses =
      sessions ??
      [
        _session('morning', 8 * 60, 12 * 60),
        _session('evening', 18 * 60, 22 * 60),
      ];
  final baseTheme = brightness == Brightness.light
      ? AppTheme.light()
      : AppTheme.dark();
  // Ahem's fixed-width digits otherwise wrap inside the unchanged time rail.
  // Keep ordinary fixtures below that artificial limit; the large-text case
  // separately verifies the readable minimum with a doubled text scale.
  final theme = baseTheme.copyWith(
    textTheme: baseTheme.textTheme.copyWith(
      labelSmall: baseTheme.textTheme.labelSmall?.copyWith(fontSize: 9),
    ),
  );
  final container = ProviderContainer(
    overrides: [
      selectedScheduleDateProvider.overrideWith((ref) => DateTime(2026, 8, 24)),
      scheduleDisplaySettingsProvider.overrideWith(
        () => _FixedSettings(settings),
      ),
      gridDensityProvider.overrideWith(() => _FixedDensity(density)),
      currentTimeProvider.overrideWith(_FixedTime.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WeekGridView(
            key: UniqueKey(),
            grid: GridBuilder().buildWeekGrid(
              weekStart: DateTime(2026, 8, 24),
              sessions: courses,
            ),
            sessions: courses,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.descendant(
          of: find.byKey(const Key('adjacent-page-current')),
          matching: find.byKey(const Key('schedule-vertical-body')),
        ),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

double _minuteHeight(WidgetTester tester) {
  Finder label(int minute) => find.descendant(
    of: find.byKey(const Key('adjacent-page-current')),
    matching: find.byKey(Key('schedule-time-label-$minute')),
  );
  return (tester.getTopLeft(label(720)).dy - tester.getTopLeft(label(480)).dy) /
      240;
}

Finder _chip(String id, {bool skipOffstage = true}) => find.byWidgetPredicate(
  (widget) => widget is GridSessionChip && widget.session.id == id,
  skipOffstage: skipOffstage,
);

void main() {
  testWidgets(
    'adaptive single and multi-day layouts use identical fit geometry',
    (tester) async {
      for (final width in [320.0, 500.0]) {
        await _pumpGrid(
          tester,
          width: width,
          settings: const ScheduleDisplaySettings(
            fitToPage: true,
            narrowLayout: NarrowScheduleLayout.adaptive,
          ),
        );
        expect(_position(tester).maxScrollExtent, closeTo(0, .001));
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'adaptive preserves the top time on resize and resets to 08 on week navigation',
    (tester) async {
      final container = await _pumpGrid(
        tester,
        height: 520,
        settings: const ScheduleDisplaySettings(fitToPage: true),
        sessions: [
          _session('early', 420, 480),
          _session('late', 1320, 1440),
          _session('next-early', 420, 480, onDate: DateTime(2026, 8, 31)),
          _session('next-late', 1320, 1440, onDate: DateTime(2026, 8, 31)),
        ],
      );
      final oldPpm = _minuteHeight(tester);
      _position(tester).jumpTo(16 + oldPpm * 90);
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(400, 720));
      await tester.pumpAndSettle();
      final newPpm = _minuteHeight(tester);
      expect((_position(tester).pixels - 16) / newPpm, closeTo(90, .001));
      container.read(selectedWeekStartProvider.notifier).state = DateTime(
        2026,
        8,
        31,
      );
      container.read(selectedScheduleDateProvider.notifier).state = DateTime(
        2026,
        8,
        31,
      );
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, closeTo(60 * newPpm, .001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('adaptive neighboring week starts at 08 during the swipe', (
    tester,
  ) async {
    await _pumpGrid(
      tester,
      settings: const ScheduleDisplaySettings(fitToPage: true),
      sessions: [
        _session('early', 420, 480),
        _session('late', 1320, 1440),
        _session('next-early', 360, 480, onDate: DateTime(2026, 8, 31)),
        _session('next-late', 1320, 1440, onDate: DateTime(2026, 8, 31)),
      ],
    );
    _position(tester).jumpTo(_position(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    final next = find.descendant(
      of: find.byKey(const Key('adjacent-page-next')),
      matching: find.byKey(const Key('schedule-time-label-480')),
    );
    final nextBody = find.descendant(
      of: find.byKey(const Key('adjacent-page-next')),
      matching: find.byKey(const Key('schedule-vertical-body')),
    );
    expect(
      tester.getTopLeft(next).dy + 8 - tester.getTopLeft(nextBody).dy,
      closeTo(16, .001),
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('overlapping tiny targets offer all courses for selection', (
    tester,
  ) async {
    await _pumpGrid(
      tester,
      width: 320,
      height: 360,
      settings: const ScheduleDisplaySettings(fitToPage: true),
      sessions: [
        _session('first', 480, 485, name: 'First tiny'),
        _session('second', 490, 495, name: 'Second tiny'),
      ],
    );
    final chip = find.byWidgetPredicate(
      (w) => w is GridSessionChip && w.session.id == 'first',
    );
    await tester.tapAt(tester.getCenter(chip));
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.textContaining('First tiny'), findsWidgets);
    expect(find.textContaining('Second tiny'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 500.0, 1100.0]) {
    for (final density in GridDensity.values) {
      testWidgets(
        'adaptive fits 08–22 with equal padding at $width / $density',
        (tester) async {
          await _pumpGrid(
            tester,
            width: width,
            density: density,
            settings: const ScheduleDisplaySettings(
              fitToPage: true,
              verticalScalePercent: 150,
            ),
          );
          final position = _position(tester);
          expect(position.maxScrollExtent, closeTo(0, .01));
          final viewport = tester.getRect(
            find.byKey(const Key('schedule-vertical-body')),
          );
          final morning =
              tester
                  .getTopLeft(find.byKey(const Key('schedule-time-label-480')))
                  .dy +
              8;
          final evening =
              tester
                  .getTopLeft(find.byKey(const Key('schedule-time-label-1320')))
                  .dy +
              8;
          expect(morning - viewport.top, closeTo(16, .01));
          expect(viewport.bottom - evening, closeTo(16, .01));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'adaptive extends beyond 08–22 and starts at 08; tiny courses do not overflow',
    (tester) async {
      await _pumpGrid(
        tester,
        width: 320,
        height: 360,
        textScaler: TextScaler.linear(2),
        settings: const ScheduleDisplaySettings(fitToPage: true),
        sessions: [
          _session(
            'early',
            420,
            425,
            name: 'Extremely long early course title',
          ),
          _session('late', 1380, 1410),
          _session('normal', 480, 600),
        ],
      );
      final position = _position(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      final viewport = tester.getRect(
        find.byKey(const Key('schedule-vertical-body')),
      );
      final morning =
          tester
              .getTopLeft(find.byKey(const Key('schedule-time-label-480')))
              .dy +
          8;
      expect(morning - viewport.top, closeTo(16, .01));
      expect(tester.takeException(), isNull);
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('adjacent previews and navigation retain the selected scale', (
    tester,
  ) async {
    final courses = [
      for (final week in [-1, 0, 1])
        _session(
          'week-$week',
          8 * 60,
          22 * 60,
          onDate: DateTime(2026, 8, 24).add(Duration(days: week * 7)),
        ),
    ];
    final container = await _pumpGrid(tester, sessions: courses);
    await container
        .read(scheduleDisplaySettingsProvider.notifier)
        .setVerticalScalePercent(75);
    await tester.pumpAndSettle();
    for (final week in [-1, 0, 1]) {
      expect(
        tester.getSize(_chip('week-$week', skipOffstage: false)).height,
        closeTo(840 * 0.75 - 4, 0.001),
      );
    }
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(container.read(selectedScheduleDateProvider), DateTime(2026, 8, 31));
    expect(
      tester.getSize(_chip('week-1')).height,
      closeTo(840 * 0.75 - 4, 0.001),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('current time marker aligns immediately after a scale change', (
    tester,
  ) async {
    final container = await _pumpGrid(tester, width: 900);
    await container
        .read(scheduleDisplaySettingsProvider.notifier)
        .setVerticalScalePercent(50);
    await tester.pump();
    expect(
      tester.getCenter(find.byKey(const Key('schedule-current-time-line'))).dy,
      closeTo(
        tester.getTopLeft(find.byKey(const Key('schedule-time-label-720'))).dy +
            8,
        0.001,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test(
    'normalization handles defaults, invalid values, bounds and 5% rounding',
    () {
      for (final pair in <(Object?, int)>[
        (null, 100),
        ('75', 100),
        (double.nan, 100),
        (double.infinity, 100),
        (-20, 50),
        (999, 150),
        (53, 55),
        (73.0, 75),
        (75, 75),
      ]) {
        expect(
          ScheduleDisplaySettings.normalizeVerticalScalePercent(pair.$1),
          pair.$2,
        );
      }
      expect(const ScheduleDisplaySettings().verticalScalePercent, 100);
      expect(
        const ScheduleDisplaySettings(
          verticalScalePercent: 75,
        ).copyWith(showEmptyDays: false).verticalScalePercent,
        75,
      );
    },
  );

  test(
    'local persistence survives a new service and defaults old/invalid settings',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        (await SettingsService().loadScheduleDisplaySettings())
            .verticalScalePercent,
        100,
      );
      await SettingsService().saveScheduleDisplaySettings(
        const ScheduleDisplaySettings(
          verticalScalePercent: 75,
          showEmptyDays: false,
        ),
      );
      final reloaded = await SettingsService().loadScheduleDisplaySettings();
      expect(reloaded.verticalScalePercent, 75);
      expect(reloaded.showEmptyDays, isFalse);
      SharedPreferences.setMockInitialValues({
        'schedule_vertical_scale_percent': 'invalid',
      });
      expect(
        (await SettingsService().loadScheduleDisplaySettings())
            .verticalScalePercent,
        100,
      );
    },
  );

  test(
    'late initial load cannot overwrite edits and saves stay ordered',
    () async {
      final service = _DelayedSettingsService();
      final container = ProviderContainer(
        overrides: [settingsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(scheduleDisplaySettingsProvider.notifier);
      final first = notifier.setVerticalScalePercent(50);
      final last = notifier.setVerticalScalePercent(150);
      final neighbor = notifier.setShowEmptyDays(false);
      expect(
        container.read(scheduleDisplaySettingsProvider).verticalScalePercent,
        150,
      );
      service.initialLoad.complete(
        const ScheduleDisplaySettings(verticalScalePercent: 125),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(scheduleDisplaySettingsProvider).verticalScalePercent,
        150,
      );
      expect(service.saved.map((settings) => settings.verticalScalePercent), [
        50,
      ]);
      service.firstSave.complete();
      await Future.wait([first, last, neighbor]);
      expect(service.saved.map((settings) => settings.verticalScalePercent), [
        50,
        150,
        150,
      ]);
      expect(service.saved.last.showEmptyDays, isFalse);
    },
  );

  test(
    'backup round trip and import retain scale in the current backup version',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();
      await service.saveScheduleDisplaySettings(
        const ScheduleDisplaySettings(verticalScalePercent: 65),
      );
      final snapshot = await service.exportPortableSettings();
      final backupService = ScheduleBackupService();
      final backup = backupService.decodeBackup(
        backupService.encodeToJson(const [], settings: snapshot),
      );
      expect(backup.version, 4);
      expect(backup.settings!.scheduleDisplay.verticalScalePercent, 65);
      await service.saveScheduleDisplaySettings(
        const ScheduleDisplaySettings(),
      );
      await service.importPortableSettings(backup.settings!);
      expect(
        (await SettingsService().loadScheduleDisplaySettings())
            .verticalScalePercent,
        65,
      );

      final json = snapshot.toJson();
      final display = json['scheduleDisplay'] as Map<String, dynamic>;
      display.remove('verticalScalePercent');
      // Decode the original portable shape with its optional field removed.
      for (final value in <Object?>[null, 'bad', 28, 175, 73]) {
        if (value != null) display['verticalScalePercent'] = value;
        final restored = PortableSettings.fromJson(json);
        expect(
          restored.scheduleDisplay.verticalScalePercent,
          ScheduleDisplaySettings.normalizeVerticalScalePercent(value),
        );
      }
    },
  );

  for (final layout in <(String, double, NarrowScheduleLayout)>[
    ('single day', 320, NarrowScheduleLayout.adaptive),
    ('multiple days', 600, NarrowScheduleLayout.adaptive),
    ('compact week', 400, NarrowScheduleLayout.compactWeek),
    ('full week', 900, NarrowScheduleLayout.compactWeek),
  ]) {
    for (final density in GridDensity.values) {
      testWidgets(
        '${layout.$1}, ${density.name}: all geometry uses 50/100/150%',
        (tester) async {
          final container = await _pumpGrid(
            tester,
            width: layout.$2,
            density: density,
            settings: ScheduleDisplaySettings(narrowLayout: layout.$3),
          );
          final baseline = _minuteHeight(tester);
          final baseCardHeight = tester.getSize(_chip('morning')).height;
          final baseWidth = tester.getSize(_chip('morning')).width;
          final headerHeight = tester
              .getSize(find.byKey(const Key('schedule-day-2026-8-24')))
              .height;
          final notifier = container.read(
            scheduleDisplaySettingsProvider.notifier,
          );
          for (final percent in [50, 100, 150]) {
            await notifier.setVerticalScalePercent(percent);
            await tester.pumpAndSettle();
            expect(
              _minuteHeight(tester),
              closeTo(baseline * percent / 100, 0.001),
            );
            expect(
              tester.getSize(_chip('morning')).height + 4,
              closeTo((baseCardHeight + 4) * percent / 100, 0.001),
            );
            expect(tester.getSize(_chip('morning')).width, baseWidth);
            expect(
              tester
                  .getSize(find.byKey(const Key('schedule-day-2026-8-24')))
                  .height,
              headerHeight,
            );
            final line = tester.widget<AnimatedPositioned>(
              find.byKey(const Key('schedule-current-time-line')),
            );
            expect(
              line.top,
              closeTo(
                kScheduleTimelineTopInset + 240 * _minuteHeight(tester) - 9,
                0.001,
              ),
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  testWidgets(
    'scale keeps the viewport top time and clamps when shrinking at the end',
    (tester) async {
      final container = await _pumpGrid(tester, width: 900, height: 400);
      final position = _position(tester);
      position.jumpTo(250);
      await tester.pumpAndSettle();
      final minuteAtTop =
          (position.pixels - kScheduleTimelineTopInset) / _minuteHeight(tester);
      final notifier = container.read(scheduleDisplaySettingsProvider.notifier);
      for (final percent in [50, 150]) {
        await notifier.setVerticalScalePercent(percent);
        await tester.pumpAndSettle();
        expect(
          (position.pixels - kScheduleTimelineTopInset) / _minuteHeight(tester),
          closeTo(minuteAtTop, 0.001),
        );
      }
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await notifier.setVerticalScalePercent(50);
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compression keeps short overlapping names and large time labels readable',
    (tester) async {
      final courses = [
        _session('short-a', 8 * 60, 8 * 60 + 15, name: 'Very long course name'),
        _session(
          'short-b',
          8 * 60,
          8 * 60 + 20,
          name: 'Second overlapping course',
        ),
        _session('evening', 18 * 60, 22 * 60),
      ];
      for (final width in [320.0, 900.0]) {
        await _pumpGrid(
          tester,
          width: width,
          sessions: courses,
          settings: const ScheduleDisplaySettings(verticalScalePercent: 50),
          textScaler: const TextScaler.linear(2),
          brightness: Brightness.dark,
        );
        final name = find.descendant(
          of: _chip('short-a'),
          matching: find.text('Very long course name'),
        );
        final text = tester.widget<Text>(name);
        final painter = TextPainter(
          text: TextSpan(text: text.data, style: text.style),
          textScaler: const TextScaler.linear(2),
          textDirection: TextDirection.ltr,
          maxLines: width < 840 ? 1 : null,
        )..layout(maxWidth: tester.getSize(name).width);
        expect(
          tester.getSize(_chip('short-a')).height,
          greaterThanOrEqualTo(painter.height + (width < 840 ? 6 : 10)),
        );
        expect(_minuteHeight(tester), greaterThan(0.5));
        final labelHeight = tester
            .getSize(find.byKey(const Key('schedule-time-label-720')))
            .height;
        expect(
          _minuteHeight(tester) * 60,
          greaterThanOrEqualTo(labelHeight + 8),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'a compressed short time axis fills the viewport without stretching time',
    (tester) async {
      await _pumpGrid(
        tester,
        height: 1000,
        sessions: [_session('short-range', 8 * 60, 9 * 60)],
        settings: const ScheduleDisplaySettings(verticalScalePercent: 50),
      );
      expect(_position(tester).maxScrollExtent, 0);
      expect(_minuteHeight(tester), closeTo(0.5, 0.001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings slider exposes bounds, saves changes, resets and accepts keyboard',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(_FixedLocale.new),
            reminderSettingsProvider.overrideWith(_FixedReminders.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-1')));
      await tester.pumpAndSettle();
      final sliderFinder = find.byKey(
        const Key('schedule-vertical-scale-slider'),
      );
      await tester.ensureVisible(sliderFinder);
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.min, 50);
      expect(slider.max, 150);
      expect(slider.divisions, 20);
      expect(slider.value, 100);
      final rect = tester.getRect(sliderFinder);
      await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));
      await tester.pumpAndSettle();
      final changed = tester.widget<Slider>(sliderFinder).value.round();
      expect(changed, lessThan(100));
      expect(changed % 5, 0);
      expect(
        (await SettingsService().loadScheduleDisplaySettings())
            .verticalScalePercent,
        changed,
      );
      final focus = tester.widget<FocusableActionDetector>(
        find
            .descendant(
              of: sliderFinder,
              matching: find.byType(FocusableActionDetector),
            )
            .first,
      );
      focus.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(sliderFinder).value, changed + 5);
      final fitSwitch = find.byKey(const Key('schedule-fit-to-page'));
      await tester.ensureVisible(fitSwitch);
      await tester.pumpAndSettle();
      await tester.tap(fitSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(sliderFinder).onChanged, isNull);
      expect(tester.widget<Slider>(sliderFinder).value, changed + 5);
      expect(
        (await SettingsService().loadScheduleDisplaySettings()).fitToPage,
        isTrue,
      );
      await tester.tap(fitSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(sliderFinder).value, changed + 5);
      expect(tester.widget<Slider>(sliderFinder).onChanged, isNotNull);
      await tester.tap(fitSwitch);
      await tester.pumpAndSettle();
      final reset = find.byKey(const Key('schedule-vertical-scale-reset'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(sliderFinder).value, 100);
      expect(
        (await SettingsService().loadScheduleDisplaySettings())
            .verticalScalePercent,
        100,
      );
      expect(tester.widget<TextButton>(reset).onPressed, isNull);
      expect(
        (await SettingsService().loadScheduleDisplaySettings()).fitToPage,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
