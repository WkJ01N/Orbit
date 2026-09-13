import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/core/widgets/notification_permission_banner.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/settings/custom_reminders_page.dart';
import 'package:orbit/features/settings/theme_scheme_page.dart';
import 'package:orbit/features/upcoming/upcoming_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/course_color_providers.dart';
import 'package:orbit/providers/permission_providers.dart';
import 'package:orbit/services/course_color_utils.dart';
import 'package:orbit/services/custom_reminder_planner.dart';
import 'package:orbit/services/grid_builder.dart';
import 'package:orbit/services/notification_permission_service.dart';
import 'package:orbit/services/reminder_alarm_planner.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/strong_reminder_resolver.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/features/settings/strong_reminder_page.dart';
import 'package:material_color_utilities/hct/hct.dart';
import 'package:shared_preferences/shared_preferences.dart';

CourseSession course(String id, {String? code, DateTime? day}) {
  final date =
      day ?? DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));
  return CourseSession(
    id: id,
    classType: 'Class',
    room: 'A101',
    date: date,
    weekday: date.weekday,
    courseName: id,
    courseCode: code ?? id,
    section: '1',
    startAt: date.add(const Duration(hours: 10)),
    endAt: date.add(const Duration(hours: 12)),
    teachers: const [],
    faculty: '',
    semester: '',
  );
}

Widget app(
  Widget child, {
  ThemeData? theme,
  GlobalKey<NavigatorState>? navigator,
  TransitionBuilder? builder,
}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  navigatorKey: navigator,
  builder: builder,
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

class PermissionService extends NotificationPermissionService {
  NotificationPermissionState status = NotificationPermissionState.denied;
  int opened = 0;
  @override
  Future<NotificationPermissionState> query() async => status;
  @override
  Future<void> openSettings() async {
    opened++;
  }
}

class DelayedMulticolorService extends SettingsService {
  final loading = Completer<MulticolorSettings>();
  final saved = <MulticolorSettings>[];
  @override
  Future<MulticolorSettings> loadMulticolorSettings() => loading.future;
  @override
  Future<void> saveMulticolorSettings(MulticolorSettings value) async {
    saved.add(value);
  }
}

class FixedTimeNotifier extends CurrentTimeNotifier {
  @override
  DateTime build() => DateTime.now();
}

class FixedReminderNotifier extends ReminderSettingsNotifier {
  int resyncs = 0;
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
  @override
  Future<int> resyncReminders() async => ++resyncs;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'custom theme roles preserve chosen hues and survive reload independently',
    () {
      var value = const MulticolorSettings(enabled: true);
      final chosen = [Colors.blue, Colors.green, Colors.purple];
      for (var role = 0; role < 3; role++) {
        value = value.withRoleColor(role, chosen[role]);
      }
      final restored = MulticolorSettings.fromJson(value.toJson());
      expect(restored.isCustom, true);
      for (final brightness in Brightness.values) {
        final colors = restored.colors(brightness);
        final generated = [colors.primary, colors.secondary, colors.tertiary];
        for (var role = 0; role < 3; role++) {
          final distance =
              (Hct.fromInt(generated[role].toARGB32()).hue -
                      Hct.fromInt(chosen[role].toARGB32()).hue)
                  .abs();
          expect(distance > 180 ? 360 - distance : distance, lessThan(5));
        }
      }
      final preset = restored.copyWith(
        scheme: AppColorScheme.expressive,
        clearCustom: true,
      );
      expect(preset.isCustom, false);
      expect(
        preset.colors(Brightness.light),
        const MulticolorSettings(
          enabled: true,
          scheme: AppColorScheme.expressive,
        ).colors(Brightness.light),
      );
    },
  );

  test('multicolor uses independent seeds and complete contrast pairs', () {
    const multi = MulticolorSettings(
      enabled: true,
      primary: Colors.blue,
      secondary: Colors.orange,
      tertiary: Colors.pink,
      scheme: AppColorScheme.fidelity,
    );
    for (final brightness in Brightness.values) {
      final a = brightness == Brightness.light
          ? AppTheme.light(seed: Colors.red, multicolor: multi)
          : AppTheme.dark(seed: Colors.red, multicolor: multi);
      final b = brightness == Brightness.light
          ? AppTheme.light(seed: Colors.green, multicolor: multi)
          : AppTheme.dark(seed: Colors.green, multicolor: multi);
      expect(a.colorScheme, b.colorScheme);
      expect(a.colorScheme, multi.colors(brightness));
      final pairs = [
        (a.colorScheme.primary, a.colorScheme.onPrimary),
        (a.colorScheme.secondary, a.colorScheme.onSecondary),
        (a.colorScheme.tertiary, a.colorScheme.onTertiary),
        (a.colorScheme.secondaryContainer, a.colorScheme.onSecondaryContainer),
        (a.colorScheme.tertiaryContainer, a.colorScheme.onTertiaryContainer),
      ];
      for (final pair in pairs) {
        final x = pair.$1.computeLuminance(), y = pair.$2.computeLuminance();
        expect(
          ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
    expect(
      AppTheme.light(
        seed: Colors.red,
        multicolor: multi.copyWith(enabled: false),
      ).colorScheme,
      AppTheme.light(seed: Colors.red).colorScheme,
    );
  });
  test(
    'old theme migrates once and single edits cannot change multicolor',
    () async {
      SharedPreferences.setMockInitialValues({
        'theme_color': Colors.blue.toARGB32(),
        'color_scheme': 'rainbow',
      });
      final service = SettingsService();
      final migrated = await service.loadMulticolorSettings();
      expect(migrated.enabled, true);
      expect(migrated.primary.toARGB32(), Colors.blue.toARGB32());
      expect(migrated.scheme, AppColorScheme.rainbow);
      await service.saveMulticolorSettings(migrated);
      await service.saveThemeColor(Colors.red);
      expect(
        (await service.loadMulticolorSettings()).primary.toARGB32(),
        Colors.blue.toARGB32(),
      );
      await service.savePermissionWarningIgnored(true);
      final backup = await service.exportPortableSettings();
      expect(backup.toJson(), isNot(contains('notification_warning_ignored')));
      expect(backup.multicolor!.toJson(), migrated.toJson());
    },
  );
  test(
    'late load cannot overwrite edits and rapid edits persist in order',
    () async {
      final service = DelayedMulticolorService();
      final container = ProviderContainer(
        overrides: [settingsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.read(multicolorSettingsProvider);
      final notifier = container.read(multicolorSettingsProvider.notifier);
      final a = notifier.setValue(
        const MulticolorSettings(enabled: true, primary: Colors.red),
      );
      final b = notifier.setValue(
        const MulticolorSettings(enabled: true, primary: Colors.blue),
      );
      service.loading.complete(const MulticolorSettings());
      await Future.wait([a, b]);
      expect(container.read(multicolorSettingsProvider).primary, Colors.blue);
      expect(service.saved.last.primary, Colors.blue);
    },
  );
  test(
    'palette reorder preserves assignments and edits affect only a slot',
    () {
      const palette = [
        PaletteColor(12, Colors.blue),
        PaletteColor(13, Colors.orange),
      ];
      final saved = {'a': 12, 'b': 13};
      expect(
        allocateCourseColorIds(saved, [
          'a',
          'b',
        ], palette: palette.reversed.toList()),
        saved,
      );
      for (final brightness in Brightness.values) {
        final old = automaticColorForId(13, brightness, palette: palette);
        expect(
          automaticColorForId(
            13,
            brightness,
            palette: const [
              PaletteColor(12, Colors.green),
              PaletteColor(13, Colors.orange),
            ],
          ),
          old,
        );
        expect(
          automaticColorForId(
            12,
            brightness,
            palette: const [PaletteColor(13, Colors.orange)],
          ),
          isNot(automaticColorForId(12, brightness, palette: palette)),
        );
      }
      final decoded = MulticolorSettings.fromJson({
        'palette': [
          {'id': 12, 'color': Colors.blue.toARGB32()},
          {'id': 12, 'color': Colors.red.toARGB32()},
          {'id': 15, 'color': Colors.blue.toARGB32()},
        ],
        'nextId': 1,
      });
      expect(decoded.palette.length, 1);
      expect(decoded.nextId, greaterThan(12));
    },
  );
  test(
    'concurrent course edits preserve other overrides and default reset',
    () async {
      SharedPreferences.setMockInitialValues({
        'course_color_overrides': jsonEncode({'old': Colors.orange.toARGB32()}),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(courseColorOverridesProvider.notifier);
      await Future.wait([
        notifier.setColor('a', Colors.blue),
        notifier.setColor('b', Colors.red),
      ]);
      await notifier.clearColor('a');
      expect(
        container
            .read(courseColorOverridesProvider)
            .map((k, v) => MapEntry(k, v.toARGB32())),
        {'old': Colors.orange.toARGB32(), 'b': Colors.red.toARGB32()},
      );
      expect(
        (await SettingsService().loadCourseColorOverrides()).map(
          (k, v) => MapEntry(k, v.toARGB32()),
        ),
        {'old': Colors.orange.toARGB32(), 'b': Colors.red.toARGB32()},
      );
    },
  );
  test('strong defaults keep legacy behavior; empty selections stay empty', () {
    final old = StrongReminderSettings.fromJson({'enabled': true});
    expect(old.types.length, 4);
    expect(old.ruleIds, isNull);
    expect(old.courseScope, ReminderCourseScope.all);
    final empty = old.copyWith(
      types: {},
      ruleIds: {},
      courseScope: ReminderCourseScope.sessions,
      courseKeys: [],
    );
    final restored = StrongReminderSettings.fromJson(empty.toJson());
    expect(restored.types, isEmpty);
    expect(restored.ruleIds, isEmpty);
    expect(restored.courseKeys, isEmpty);
    expect(
      resolveStrongReminder(
        global: restored,
        type: StrongReminderType.classLead,
        session: course('a'),
      ).enabled,
      false,
    );
  });
  test('strong course and rule filters apply only to inheritance', () {
    final a = course('a'), b = course('b');
    final global = StrongReminderSettings(
      enabled: true,
      types: {StrongReminderType.custom},
      ruleIds: {'selected'},
      courseScope: ReminderCourseScope.series,
      courseKeys: [CourseSeriesKey.fromSession(a).value],
    );
    final rule = CustomReminderRule(
      id: 'selected',
      name: 'Rule',
      activeFrom: DateTime(2020),
    );
    expect(
      resolveStrongReminder(
        global: global,
        type: StrongReminderType.custom,
        session: a,
        rule: rule,
      ).enabled,
      true,
    );
    expect(
      resolveStrongReminder(
        global: global,
        type: StrongReminderType.custom,
        session: b,
        rule: rule,
      ).enabled,
      false,
    );
    expect(
      resolveStrongReminder(
        global: global,
        type: StrongReminderType.custom,
        session: a,
        rule: rule.copyWith(id: 'other'),
      ).enabled,
      false,
    );
    expect(
      resolveStrongReminder(
        global: global.copyWith(enabled: false),
        type: StrongReminderType.custom,
        session: b,
        rule: rule.copyWith(strength: ReminderStrength.strong),
      ).enabled,
      true,
    );
    expect(
      resolveStrongReminder(
        global: global,
        type: StrongReminderType.custom,
        session: a,
        rule: rule.copyWith(strength: ReminderStrength.normal),
      ).enabled,
      false,
    );
  });
  test('course edits retain strong ranges via aliases and memberships', () {
    final edited = course('new-id', code: 'new-code');
    const aliases = {'old-id': 'stable', 'new-id': 'stable'};
    const memberships = {
      'stable': ['code:old-code|section:1'],
    };
    const sessions = StrongReminderSettings(
      enabled: true,
      courseScope: ReminderCourseScope.sessions,
      courseKeys: ['old-id'],
    );
    expect(matchesStrongCourse(sessions, edited, aliases: aliases), true);
    expect(
      matchesStrongCourse(
        sessions.copyWith(
          courseScope: ReminderCourseScope.series,
          courseKeys: ['code:old-code|section:1'],
        ),
        edited,
        aliases: aliases,
        memberships: memberships,
      ),
      true,
    );
  });
  test(
    'edited strong course selections normalize for picker and backup',
    () async {
      final edited = course('new-id', code: 'new-code');
      const aliases = {'old-id': 'stable', 'new-id': 'stable'};
      const memberships = {
        'stable': ['code:old-code|section:1'],
      };
      expect(
        normalizeReminderCourseKeys(
          scope: ReminderCourseScope.sessions,
          keys: ['old-id'],
          sessions: [edited],
          aliases: aliases,
          keepHistorical: false,
        ),
        ['new-id'],
      );
      expect(
        normalizeReminderCourseKeys(
          scope: ReminderCourseScope.series,
          keys: ['code:old-code|section:1'],
          sessions: [edited],
          aliases: aliases,
          memberships: memberships,
          keepHistorical: false,
        ),
        [CourseSeriesKey.fromSession(edited).value],
      );
      final base = await SettingsService().exportPortableSettings();
      final settings = base.withReminders(
        ReminderSettings(
          strong: const StrongReminderSettings(
            enabled: true,
            courseScope: ReminderCourseScope.sessions,
            courseKeys: ['old-id'],
          ),
        ),
      );
      final encoded = await ScheduleBackupService().encodeWithAudio(
        [edited],
        settings,
        sessionAliases: aliases,
        seriesMemberships: memberships,
      );
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = PortableSettings.fromJson(
        json['settings'] as Map<String, dynamic>,
      );
      expect(restored.reminders.strong.courseKeys, ['new-id']);
      expect(restored.reminders.strong.enabled, true);
    },
  );
  testWidgets(
    'strong scope editor saves type, rule and course selections on narrow screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      StrongReminderSettings? result;
      final a = course('a');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) async => [a]),
            reminderSettingsProvider.overrideWith(FixedReminderNotifier.new),
          ],
          child: app(
            Builder(
              builder: (ctx) => TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await Navigator.push<StrongReminderSettings>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const StrongReminderPage(
                        initial: StrongReminderSettings(enabled: true),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Before class'));
      await tester.ensureVisible(
        find.text('All inherited rules, including future rules'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('All inherited rules, including future rules'),
      );
      final scope = find.byType(DropdownButtonFormField<ReminderCourseScope>);
      await tester.ensureVisible(scope);
      await tester.pumpAndSettle();
      await tester.tap(scope);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Individual sessions').last);
      await tester.pumpAndSettle();
      final chooseCourses = find.widgetWithText(ListTile, 'Course range');
      await tester.ensureVisible(chooseCourses);
      await tester.pumpAndSettle();
      await tester.tap(chooseCourses);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder-course-a')));
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result!.types, isNot(contains(StrongReminderType.classLead)));
      expect(result!.ruleIds, isEmpty);
      expect(result!.courseScope, ReminderCourseScope.sessions);
      expect(result!.courseKeys, ['a']);
      expect(tester.takeException(), isNull);
    },
  );
  test('summary uses selected target-day courses, not notification day', () {
    final a = course('a', day: DateTime(2026, 10, 2)),
        b = course('b', day: DateTime(2026, 10, 3));
    final global = StrongReminderSettings(
      enabled: true,
      courseScope: ReminderCourseScope.sessions,
      courseKeys: ['a'],
    );
    expect(
      resolveStrongReminder(
        global: global,
        type: StrongReminderType.summary,
        summarySessions: [a, b],
      ).enabled,
      true,
    );
    expect(
      resolveStrongReminder(
        global: global,
        type: StrongReminderType.summary,
        summarySessions: [b],
      ).enabled,
      false,
    );
    expect(
      resolveStrongReminder(
        global: global,
        type: StrongReminderType.summary,
      ).enabled,
      false,
    );
    final settings = ReminderSettings(strong: global);
    final specs = buildNextDaySummaryAlarmSpecs(
      allSessions: [a, b],
      settings: settings,
      now: DateTime(2026, 10, 1),
      copy: notificationCopyFor(const Locale('en')),
    );
    expect(specs.first.strong.enabled, true);
    expect(specs[1].strong.enabled, false);
  });
  test('preview and catch-up use the same effective strength', () {
    final a = course('a', day: DateTime(2026, 10, 1));
    final rule = CustomReminderRule(
      id: 'rule',
      name: 'Rule',
      activeFrom: DateTime(2020),
      sendCount: 2,
      intervalSeconds: 3600,
    );
    final specs = planCustomReminders(
      sessions: [a],
      rules: [rule],
      strong: const StrongReminderSettings(enabled: true, types: {}),
      now: DateTime(2026, 10, 1, 9, 50),
    );
    expect(specs.any((s) => s.catchUp), true);
    expect(specs.every((s) => !s.strong.enabled), true);
  });
  testWidgets(
    'permission warning covers secondary pages and requires confirmation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = PermissionService();
      final nav = GlobalKey<NavigatorState>();
      final container = ProviderContainer(
        overrides: [
          notificationPermissionServiceProvider.overrideWithValue(service),
          reminderSettingsProvider.overrideWith(FixedReminderNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(
            const Text('Home'),
            navigator: nav,
            builder: (_, child) =>
                NotificationPermissionHost(navigatorKey: nav, child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification-ignore')), findsOneWidget);
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Secondary')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.byKey(const Key('notification-ignore')), findsOneWidget);
      await tester.tap(find.byKey(const Key('notification-ignore')));
      await tester.pumpAndSettle();
      expect(find.text('Ignore the notification warning?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(permissionWarningIgnoredProvider).value, false);
      await tester.tap(find.byKey(const Key('notification-ignore')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm ignore'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification-ignore')), findsNothing);
      expect(await SettingsService().loadPermissionWarningIgnored(), true);
      service.status = NotificationPermissionState.allowed;
      container.invalidate(notificationPermissionProvider);
      await tester.pumpAndSettle();
      expect(
        container.read(reminderSettingsProvider.notifier),
        isA<FixedReminderNotifier>().having((n) => n.resyncs, 'resyncs', 1),
      );
      service.status = NotificationPermissionState.denied;
      container.invalidate(notificationPermissionProvider);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification-ignore')), findsNothing);
      await container
          .read(permissionWarningIgnoredProvider.notifier)
          .setIgnored(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification-ignore')), findsOneWidget);
      await tester.tap(find.byKey(const Key('notification-open')));
      await tester.pumpAndSettle();
      expect(service.opened, 1);
      service.status = NotificationPermissionState.failed;
      container.invalidate(notificationPermissionProvider);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification-ignore')), findsNothing);
      service.status = NotificationPermissionState.allowed;
      container.invalidate(notificationPermissionProvider);
      await tester.pumpAndSettle();
      expect(
        container.read(reminderSettingsProvider.notifier),
        isA<FixedReminderNotifier>().having((n) => n.resyncs, 'resyncs', 2),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('custom rules have an app-bar add and an empty-state add', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderSettingsProvider.overrideWith(FixedReminderNotifier.new),
        ],
        child: app(const CustomRemindersPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom-reminder-add')), findsOneWidget);
    expect(find.byKey(const Key('custom-reminder-empty-add')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
  testWidgets(
    'both course pages read distinct series colors and reset correctly',
    (tester) async {
      final a = course('Physics', code: 'PHYS'),
          b = course('Math', code: 'MATH');
      final ids = {
        automaticCourseColorKey(a): 0,
        automaticCourseColorKey(b): 1,
      };
      final container = ProviderContainer(
        overrides: [
          sessionsProvider.overrideWith((ref) async => [a, b]),
          upcomingSessionsProvider.overrideWith((ref) async => [a, b]),
          resolvedAutomaticCourseColorIdsProvider.overrideWithValue(ids),
          currentTimeProvider.overrideWith(FixedTimeNotifier.new),
          reminderSettingsProvider.overrideWith(FixedReminderNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      for (final page in [
        const UpcomingPage(),
        WeekGridView(
          grid: GridBuilder().buildWeekGrid(
            weekStart: a.date,
            sessions: [a, b],
          ),
          sessions: [a, b],
        ),
      ]) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: app(
              page,
              theme: AppTheme.light(style: AppThemeStyle.colorful),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Finder accent(Color c) => find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.color == c ||
                  w.decoration is BoxDecoration &&
                      (w.decoration as BoxDecoration).color == c),
        );
        expect(accent(automaticColorForId(0, Brightness.light)), findsWidgets);
        expect(accent(automaticColorForId(1, Brightness.light)), findsWidgets);
        await container
            .read(courseColorOverridesProvider.notifier)
            .setColor(courseColorKey(a), Colors.red);
        await tester.pumpAndSettle();
        expect(accent(Colors.red), findsWidgets);
        await container
            .read(courseColorOverridesProvider.notifier)
            .clearColor(courseColorKey(a));
        await tester.pumpAndSettle();
        expect(accent(automaticColorForId(0, Brightness.light)), findsWidgets);
        expect(accent(automaticColorForId(1, Brightness.light)), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'multicolor panel supports arbitrary colors and rejects duplicates',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(const ThemeSchemePage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('palette-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('palette-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '#00796B');
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(container.read(multicolorSettingsProvider).palette.length, 8);
      expect(find.text('This color is already in the palette'), findsOneWidget);
      await tester.tap(find.byKey(const Key('palette-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '#123456');
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(container.read(multicolorSettingsProvider).palette.length, 9);
      expect(
        container.read(multicolorSettingsProvider).palette.last.color,
        const Color(0xFF123456),
      );
    },
  );
  testWidgets('close button animates out before advancing message queue', (
    tester,
  ) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            messenger = ScaffoldMessenger.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    messenger.showAppSnackBar(const SnackBar(content: Text('first')));
    messenger.showAppSnackBar(const SnackBar(content: Text('second')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final widget = tester.widget<SnackBar>(
      find.byWidgetPredicate((w) => w is SnackBar),
    );
    expect(widget.animation!.status, AnimationStatus.reverse);
    expect(widget.animation!.value, inExclusiveRange(0.0, 1.0));
    expect(find.text('first'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });
  testWidgets(
    'new drag interrupts settling continuously and prevents stale commits',
    (tester) async {
      var page = 0;
      final controller = AdjacentPagePagerController();
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, update) => SizedBox(
              width: 400,
              height: 400,
              child: AdjacentPagePager(
                controller: controller,
                pageKey: page,
                previousChild: Text('Page ${page - 1}'),
                nextChild: Text('Page ${page + 1}'),
                onSwipeToPrevious: () => update(() => page--),
                onSwipeToNext: () => update(() => page++),
                child: Text('Page $page'),
              ),
            ),
          ),
        ),
      );
      final first = await tester.startGesture(const Offset(300, 200));
      await first.moveBy(const Offset(-140, 0));
      await tester.pump();
      await first.up();
      await tester.pump(const Duration(milliseconds: 30));
      final second = await tester.startGesture(const Offset(200, 200));
      await second.moveBy(const Offset(40, 0));
      await tester.pump();
      final before = tester
          .widget<Transform>(find.byKey(const Key('adjacent-page-current')))
          .transform
          .storage[12];
      await second.moveBy(const Offset(30, 0));
      await tester.pump();
      final after = tester
          .widget<Transform>(find.byKey(const Key('adjacent-page-current')))
          .transform
          .storage[12];
      expect(after - before, closeTo(30, .1));
      await second.up();
      await tester.pumpAndSettle();
      expect(page, inInclusiveRange(-1, 1));
      expect(tester.takeException(), isNull);
      final next = controller.animateToNext();
      await tester.pumpAndSettle();
      await next;
    },
  );
}
