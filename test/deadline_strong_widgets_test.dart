import 'package:orbit/features/reminder/strong_badge.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/deadline/deadline_ui.dart';
import 'package:orbit/features/deadline/deadline_strong_host.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/grid/grid_page.dart';
import 'package:orbit/features/import/import_page.dart';
import 'package:orbit/features/upcoming/upcoming_page.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/models/deadline_strong_text.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/grid_builder.dart';
import 'package:orbit/services/strong_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Display extends ScheduleDisplaySettingsNotifier {
  _Display(this.initial);
  final ScheduleDisplaySettings initial;
  @override
  ScheduleDisplaySettings build() => initial;
  void apply(ScheduleDisplaySettings value) {
    state = value;
  }
}

class _Time extends CurrentTimeNotifier {
  @override
  DateTime build() => DateTime.now();
}

class _Reminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
  @override
  void scheduleResync() {}
  @override
  Future<int> resyncReminders() async => 0;
}

class _Database implements AppDatabase {
  _Database(this.values);
  List<Deadline> values;
  List<Deadline> saved = [];
  Map<String, Set<int>>? disabled;
  bool fail = false;
  @override
  Future<List<Deadline>> getDeadlines({bool includeDeleted = false}) async =>
      values;
  @override
  Future<void> saveDeadlines(List<Deadline> d) async {
    saved = d;
  }

  @override
  Future<void> disableDeadlineReminders(
    Map<String, Set<int>> selections, {
    DateTime? now,
  }) async {
    if (fail) throw StateError('offline disk');
    disabled = {for (final e in selections.entries) e.key: Set.of(e.value)};
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Deadline _ddl(String id, {bool strong = false, bool completed = false}) =>
    Deadline(
      id: id,
      subject: 'Math',
      title: 'Project $id',
      dueAt: DateTime.now().add(const Duration(days: 2)),
      leadMinutes: const [1440, 180, 60],
      strongReminderEnabled: strong,
      completedAt: completed ? DateTime.now() : null,
    );
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Widget home,
  List<Deadline> deadlines = const [],
  _Database? db,
  ScheduleDisplaySettings display = const ScheduleDisplaySettings(),
  int tab = 0,
  double width = 400,
  double height = 800,
  double scale = 1,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      currentTimeProvider.overrideWith(_Time.new),
      appDatabaseProvider.overrideWithValue(db ?? _Database(deadlines)),
      sessionsProvider.overrideWith((_) async => []),
      upcomingSessionsProvider.overrideWith((_) async => []),
      deadlinesProvider.overrideWith((_) async => deadlines),
      strongCourseIdsProvider.overrideWith((_) async => {}),
      reminderSettingsProvider.overrideWith(_Reminders.new),
      scheduleDisplaySettingsProvider.overrideWith(() => _Display(display)),
      appNavIndexProvider.overrideWith((_) => tab),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          StrongSessionService.windows,
          (call) async => jsonEncode({'events': []}),
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StrongSessionService.windows, null),
  );
  testWidgets(
    'reuse copies per-time strong choices but restores disabled slots for a new batch',
    (tester) async {
      final source = _ddl('template', strong: true).copyWith(
        strongLeadMinutes: [1440],
        disabledReminderLeadMinutes: [1440],
        completedAt: DateTime.now(),
        countsTowardStatistics: false,
      );
      final db = _Database([source]);
      await _pump(
        tester,
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => showDeadlineEditor(c),
              child: const Text('Open'),
            ),
          ),
        ),
        db: db,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reuse an existing DDL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Project template'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('deadline-strong-enabled')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('deadline-strong-enabled')))
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('deadline-strong-lead-1440')))
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('deadline-strong-lead-60')))
            .value,
        isFalse,
      );
      expect(find.byKey(const Key('deadline-restore-reminders')), findsNothing);
      await tester.ensureVisible(find.text('Batch'));
      await tester.tap(find.text('Batch'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Preview and create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();
      expect(db.saved, hasLength(12));
      expect(
        db.saved.every(
          (d) =>
              d.strongReminderEnabled &&
              d.strongLeadMinutes!.single == 1440 &&
              d.disabledReminderLeadMinutes.isEmpty &&
              !d.completed &&
              d.countsTowardStatistics,
        ),
        isTrue,
      );
      expect(db.saved.map((d) => d.id).toSet().length, 12);
      expect(source.disabledReminderLeadMinutes, [1440]);
      expect(source.countsTowardStatistics, isFalse);
    },
  );
  testWidgets(
    'custom 180/181 times initialize individually and remembered overrides survive deselection',
    (tester) async {
      await _pump(
        tester,
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => showDeadlineEditor(c),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final custom = find.byType(TextField).last;
      for (final m in [180, 181]) {
        await tester.ensureVisible(custom);
        await tester.enterText(custom, '$m');
        await tester.tap(find.byIcon(Icons.add).last);
        await tester.pumpAndSettle();
      }
      final master = find.byKey(const Key('deadline-strong-enabled'));
      await tester.ensureVisible(master);
      await tester.tap(master);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('deadline-strong-lead-180')))
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('deadline-strong-lead-181')))
            .value,
        isFalse,
      );
      final strong = find.byKey(const Key('deadline-strong-lead-180'));
      await tester.ensureVisible(strong);
      await tester.tap(strong);
      await tester.pumpAndSettle();
      final preset = find.widgetWithText(FilterChip, '3h');
      await tester.ensureVisible(preset);
      await tester.tap(preset);
      await tester.pumpAndSettle();
      await tester.tap(preset);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(strong).value, isFalse);
    },
  );
  testWidgets(
    'future management lists only triggered tasks and supports cancellation, scoped save and retry',
    (tester) async {
      final db = _Database([_ddl('a', strong: true), _ddl('b')]);
      final events = [
        {'id': 'receipt', 'deadlineId': 'a', 'leadMinutes': 1440},
      ];
      final container = await _pump(
        tester,
        db: db,
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => showDeadlineReminderManagement(c, events),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Math · Project a'), findsOneWidget);
      expect(find.text('Math · Project b'), findsNothing);
      final slot = find.byKey(const Key('future-reminder-a-60'));
      await tester.tap(slot);
      await tester.pump();
      await tester.tap(slot);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Turn off selected reminders'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(slot);
      await tester.pump();
      db.fail = true;
      await tester.tap(find.text('Turn off selected reminders'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not update reminders. Please retry.'),
        findsOneWidget,
      );
      db.fail = false;
      await tester.tap(find.text('Turn off selected reminders'));
      await tester.pumpAndSettle();
      expect(db.disabled, {
        'a': {60},
      });
      expect(container.read(deadlineStrongHandledProvider), {'receipt'});
    },
  );
  for (final width in [400.0, 1000.0]) {
    for (final hideUpcoming in [false, true]) {
      for (final hideImport in [false, true]) {
        {
          testWidgets(
            'stable navigation $width upcoming=$hideUpcoming import=$hideImport',
            (tester) async {
              final container = await _pump(
                tester,
                home: const AppShell(),
                width: width,
                display: ScheduleDisplaySettings(
                  hideUpcomingPage: hideUpcoming,
                  hideImportPage: hideImport,
                ),
              );
              final labels = width == 400
                  ? tester
                        .widgetList<NavigationDestination>(
                          find.descendant(
                            of: find.byType(NavigationBar),
                            matching: find.byType(NavigationDestination),
                          ),
                        )
                        .map((d) => d.label)
                        .toList()
                  : tester
                        .widgetList<Text>(
                          find.descendant(
                            of: find.byType(NavigationRail),
                            matching: find.byType(Text),
                          ),
                        )
                        .map((d) => d.data!)
                        .toList();
              expect(labels, [
                'Schedule',
                if (!hideUpcoming) 'Upcoming',
                if (!hideImport) 'Import',
                'Settings',
              ]);
              await tester.tap(find.byIcon(Icons.settings_outlined).last);
              await tester.pumpAndSettle();
              expect(
                container.read(appNavIndexProvider),
                AppTab.settings.index,
              );
              expect(find.byType(SettingsPage), findsOneWidget);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
  testWidgets(
    'hiding current page returns to grid and explicit import opens an independent route',
    (tester) async {
      final container = await _pump(
        tester,
        home: const AppShell(),
        tab: AppTab.upcoming.index,
      );
      expect(find.byType(UpcomingPage), findsOneWidget);
      (container.read(scheduleDisplaySettingsProvider.notifier) as _Display)
          .apply(
            const ScheduleDisplaySettings(
              hideUpcomingPage: true,
              hideImportPage: true,
            ),
          );
      await tester.pumpAndSettle();
      expect(container.read(appNavIndexProvider), AppTab.grid.index);
      expect(find.byType(GridPage), findsOneWidget);
      await tester.tap(find.text('Import now'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ImportPage>(find.byType(ImportPage)).showBackButton,
        isTrue,
      );
      expect(find.byType(BackButton), findsOneWidget);
      expect(container.read(appNavIndexProvider), AppTab.grid.index);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(GridPage), findsOneWidget);
      (container.read(scheduleDisplaySettingsProvider.notifier) as _Display)
          .apply(const ScheduleDisplaySettings());
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(4),
      );
    },
  );
  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'large-font editor restores disabled reminders ${locale.toLanguageTag()}',
      (tester) async {
        final source = _ddl(
          'restore',
          strong: true,
        ).copyWith(disabledReminderLeadMinutes: [180, 60]);
        final db = _Database([source]);
        await _pump(
          tester,
          width: 320,
          height: 700,
          scale: 1.7,
          locale: locale,
          db: db,
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showDeadlineEditor(c, deadline: source),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final restore = find.byKey(const Key('deadline-restore-reminders'));
        await tester.ensureVisible(restore);
        await tester.pumpAndSettle();
        await tester.tap(restore);
        await tester.pumpAndSettle();
        expect(restore, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(DeadlineText(locale).save));
        await tester.pumpAndSettle();
        expect(db.saved.single.disabledReminderLeadMinutes, isEmpty);
        expect(db.saved.single.strongReminderEnabled, isTrue);
        expect(source.disabledReminderLeadMinutes, [180, 60]);
        final events = [
          {'id': 'restore-event', 'deadlineId': source.id},
        ];
        final c = tester.element(find.text('Open'));
        showDeadlineReminderManagement(c, events);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(DeadlineStrongText(locale).closeAll));
        await tester.pumpAndSettle();
        expect(db.disabled!['restore'], {1440});
        expect(tester.takeException(), isNull);
      },
    );
    for (final brightness in Brightness.values) {
      {
        testWidgets(
          'full date cell hit preserves header and strong badges ${locale.toLanguageTag()} $brightness',
          (tester) async {
            final a = _ddl('a', strong: true);
            final b = Deadline(
              id: 'b',
              subject: 'Math',
              title: 'Normal task',
              dueAt: a.dueAt.add(const Duration(days: 1)),
              leadMinutes: const [60],
            );
            final monday = a.dueAt.subtract(
              Duration(days: a.dueAt.weekday - 1),
            );
            final container = await _pump(
              tester,
              width: 320,
              height: 700,
              scale: 1.7,
              locale: locale,
              brightness: brightness,
              deadlines: [a, b],
              home: Scaffold(
                body: WeekGridView(
                  grid: GridBuilder().buildWeekGrid(
                    weekStart: monday,
                    sessions: [],
                  ),
                ),
              ),
            );
            container.read(selectedScheduleDateProvider.notifier).state =
                monday;
            await tester.pumpAndSettle();
            final button = find.byKey(
              Key(
                'deadline-day-${a.dueAt.year}-${a.dueAt.month}-${a.dueAt.day}',
              ),
            );
            expect(button.hitTestable(), findsOneWidget);
            final rect = tester.getRect(button);
            expect(
              tester
                  .getSize(
                    find.descendant(
                      of: find.byKey(const Key('adjacent-page-current')),
                      matching: find.byKey(const Key('schedule-date-header')),
                    ),
                  )
                  .height,
              58,
            );
            final col = tester.getRect(
              find.byKey(
                Key(
                  'schedule-day-${a.dueAt.year}-${a.dueAt.month}-${a.dueAt.day}',
                ),
              ),
            );
            expect(rect.height, col.height);
            expect(rect.top, col.top);
            expect(rect.width, greaterThanOrEqualTo(col.width - 1));
            expect(rect.left, greaterThanOrEqualTo(col.left));
            expect(rect.right, lessThanOrEqualTo(col.right));
            final label = find.descendant(
              of: button,
              matching: find.text('DDL 1'),
            );
            expect(
              tester.widget<Text>(label).style!.fontWeight,
              FontWeight.w700,
            );
            for (final position in [
              Offset(rect.left + 2, rect.top + 2),
              rect.center,
              Offset(rect.right - 2, rect.bottom - 2),
            ]) {
              await tester.tapAt(position);
              await tester.pumpAndSettle();
              expect(find.byKey(const Key('deadline-a')), findsOneWidget);
              Navigator.of(
                tester.element(find.byKey(const Key('deadline-a'))),
              ).pop();
              await tester.pumpAndSettle();
            }
            await tester.tapAt(Offset(rect.left + 2, rect.bottom - 2));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('deadline-a')), findsOneWidget);
            expect(
              find.byIcon(Icons.notifications_active_outlined),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const Key('deadline-a')));
            await tester.pumpAndSettle();
            expect(
              find.byIcon(Icons.notifications_active_outlined),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
