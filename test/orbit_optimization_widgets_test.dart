import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/archive/archive_page.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/features/session/batch_session_edit_sheet.dart';
import 'package:orbit/features/settings/strong_reminder_page.dart';
import 'package:orbit/features/upcoming/upcoming_page.dart';
import 'package:orbit/features/grid/grid_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/archive_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'archive_and_first_class_test.dart' show sampleClass;

Widget app(
  Widget home, {
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: [
    deadlinesProvider.overrideWith((ref) async => []),
    allDeadlinesProvider.overrideWith((ref) async => []),
    ...overrides,
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'expired cached courses remain until pull refresh and empty lists can refresh again',
    (tester) async {
      var queries = 0;
      final ended = sampleClass(
        'ended',
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      await tester.pumpWidget(
        app(
          const UpcomingPage(),
          overrides: [
            upcomingSessionsProvider.overrideWith((ref) async {
              queries++;
              return queries == 1 ? [ended] : [];
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mathematics'), findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Mathematics'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(queries, 2);
      expect(find.text('Mathematics'), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(queries, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed manual refresh preserves the previous course list', (
    tester,
  ) async {
    var queries = 0;
    await tester.pumpWidget(
      app(
        const UpcomingPage(),
        overrides: [
          upcomingSessionsProvider.overrideWith((ref) async {
            if (++queries > 1) throw StateError('offline');
            return [
              sampleClass(
                'future',
                DateTime.now().add(const Duration(days: 1)),
              ),
            ];
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('Mathematics'), findsOneWidget);
    expect(
      find.text('Refresh failed. Your previous list is retained.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('entering the cached Upcoming tab queries again', (tester) async {
    var queries = 0;
    await tester.pumpWidget(
      app(
        const UpcomingPage(),
        overrides: [
          upcomingSessionsProvider.overrideWith((ref) async {
            queries++;
            return <CourseSession>[];
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UpcomingPage)),
    );
    container.read(appNavIndexProvider.notifier).state = 1;
    await tester.pumpAndSettle();
    expect(queries, 2);
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets('archive settings fit a 320px screen in $locale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(const ArchiveSettingsPage(), locale: locale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('grouped archive opens lazily loaded individual class history', (
    tester,
  ) async {
    final now = DateTime.now();
    final sessions = [
      sampleClass('a', now).copyWith(archivedAt: now),
      sampleClass(
        'b',
        now.subtract(const Duration(days: 1)),
      ).copyWith(archivedAt: now),
    ];
    await tester.pumpWidget(
      app(
        const ArchivePage(),
        overrides: [sessionsProvider.overrideWith((ref) async => sessions)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mathematics'), findsOneWidget);
    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    expect(find.text('Mathematics'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('single class form fills archived source and locks identity', (
    tester,
  ) async {
    final archived = sampleClass(
      'old',
      DateTime.now().subtract(const Duration(days: 5)),
    ).copyWith(archivedAt: DateTime.now(), archiveHidden: true);
    await tester.pumpWidget(
      app(
        const Scaffold(body: SessionEditSheet()),
        overrides: [
          sessionsProvider.overrideWith((ref) async => [archived]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose existing course'));
    await tester.pumpAndSettle();
    expect(find.text('Archived courses'), findsOneWidget);
    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller!.text, 'Mathematics');
    expect(fields.first.readOnly, isTrue);
    expect(fields[1].controller!.text, 'A1');
    expect(fields[1].readOnly, isFalse);
    await tester.tap(find.text('New course'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).readOnly,
      isFalse,
    );
  });

  testWidgets('batch class form can select an existing course', (tester) async {
    final course = sampleClass('old', DateTime.now());
    await tester.pumpWidget(
      app(
        const Scaffold(body: BatchSessionEditSheet()),
        overrides: [
          sessionsProvider.overrideWith((ref) async => [course]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose existing course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller!.text, 'Mathematics');
    expect(fields.first.readOnly, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabled first-class settings fit a narrow English screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        const StrongReminderPage(
          initial: StrongReminderSettings(onlyFirstClass: true),
        ),
        overrides: [sessionsProvider.overrideWith((ref) async => [])],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('First timetable period'),
      240,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('First timetable period'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed visible archived DDL renders even without courses', (
    tester,
  ) async {
    final now = DateTime.now();
    final ddl = Deadline(
      id: 'd',
      subject: 'Math',
      title: 'Task',
      dueAt: now,
      leadMinutes: const [60],
      completedAt: now,
      archivedAt: now,
    );
    await tester.pumpWidget(
      app(
        const GridPage(),
        overrides: [
          sessionsProvider.overrideWith((ref) async => []),
          deadlinesProvider.overrideWith((ref) async => [ddl]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find
          .byKey(Key('deadline-day-${now.year}-${now.month}-${now.day}'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'manual order and grouped/individual orders are independently persisted',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(archiveSettingsProvider.future);
      await Future.wait([
        container.read(archiveSettingsProvider.notifier).change({
          'groupCourses': false,
        }),
        container.read(archiveSettingsProvider.notifier).change({
          'orders': {
            'groups': ['c'],
            'sessions': ['s'],
            'ddl': ['d'],
          },
        }),
      ]);
      final saved = await container
          .read(settingsServiceProvider)
          .loadArchiveSettings();
      expect(saved.groupCourses, isFalse);
      expect(saved.orders, {
        'groups': ['c'],
        'sessions': ['s'],
        'ddl': ['d'],
      });
      expect(saved.courseSort, ArchiveSort.archivedAt);
    },
  );
}
