import 'package:orbit/core/motion/page_module.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/motion/page_entrance.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/settings/typography_settings_page.dart';
import 'package:orbit/features/statistics/statistics_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/models/typography_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:orbit/providers/typography_providers.dart';
import 'package:orbit/services/font_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Launch extends LaunchSettingsNotifier {
  _Launch(this.value);
  final LaunchSettings value;
  @override
  LaunchSettings build() => value;
}

class _Configuration extends ImportConfigurationNotifier {
  @override
  Future<ImportConfiguration> build() async => const ImportConfiguration();
}

class _Fonts extends FontService {
  @override
  Future<void> load(String id, Map<String, ImportedFont> imports) async {}
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
  home: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final enabled in [false, true]) {
    testWidgets(
      'page switching only replays when explicitly enabled: $enabled',
      (tester) async {
        final active = ValueNotifier(false);
        final navigation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 360),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              launchSettingsProvider.overrideWith(
                () => _Launch(LaunchSettings(onPageSwitch: enabled)),
              ),
            ],
            child: app(
              ValueListenableBuilder(
                valueListenable: active,
                builder: (_, visible, _) => PageEntranceHost(
                  index: 1,
                  startup: false,
                  active: visible,
                  navigation: navigation,
                  child: const Text('Page'),
                ),
              ),
            ),
          ),
        );
        double opacity() => tester
            .widget<ModuleEntranceScope>(find.byType(ModuleEntranceScope).first)
            .motion
            .progress;
        expect(opacity(), 1);
        active.value = true;
        await tester.pump();
        expect(opacity(), enabled ? lessThan(.1) : 1);
        navigation.forward();
        await tester.pump(const Duration(milliseconds: 280));
        expect(opacity(), enabled ? lessThan(1) : 1);
        await tester.pumpAndSettle();
        expect(opacity(), 1);
        await tester.pumpWidget(const SizedBox());
        active.dispose();
        navigation.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('inactive/resumed does not replay; real background/resume does', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          launchSettingsProvider.overrideWith(
            () => _Launch(const LaunchSettings(onResume: true)),
          ),
        ],
        child: app(
          const PageEntranceHost(
            index: 2,
            active: true,
            startup: false,
            child: Text('Import'),
          ),
        ),
      ),
    );
    double opacity() => tester
        .widget<ModuleEntranceScope>(find.byType(ModuleEntranceScope).first)
        .motion
        .progress;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(opacity(), 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(opacity(), lessThan(.1));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'return from subpage prepares before transition and ignores dialogs',
    (tester) async {
      late BuildContext pageContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            launchSettingsProvider.overrideWith(
              () => _Launch(const LaunchSettings(onPageSwitch: true)),
            ),
          ],
          child: app(
            PageEntranceHost(
              index: 3,
              active: true,
              startup: false,
              child: Builder(
                builder: (c) {
                  pageContext = c;
                  return const Text('Settings');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double opacity() => tester
          .widget<ModuleEntranceScope>(find.byType(ModuleEntranceScope).first)
          .motion
          .progress;
      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(content: Text('Dialog')),
      );
      await tester.pumpAndSettle();
      Navigator.pop(pageContext);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      Navigator.push<void>(
        pageContext,
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Subpage')),
        ),
      );
      await tester.pumpAndSettle();
      Navigator.pop(pageContext);
      await tester.pump();
      expect(opacity(), 0);
      await tester.pump(
        pageEntranceRoutes.returnDelay + const Duration(milliseconds: 1),
      );
      await tester.pump();
      expect(opacity(), 1);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fallback order is numbered, editable and capped at three', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          typographySnapshotProvider.overrideWithValue(
            const TypographySettings(
              fallbackFontIds: ['rounded', 'huninn', 'maiyuan'],
            ),
          ),
          fontServiceProvider.overrideWithValue(_Fonts()),
        ],
        child: app(const FallbackFontsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Add fallback font'), findsNothing);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
    expect(find.text('Add fallback font'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'statistics summary creates five rows and full list builds lazily',
    (tester) async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      late Directory root;
      late AppDatabase db;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('orbit-v162-ui-');
        db = await AppDatabase.open(root.path);
      });
      SharedPreferences.setMockInitialValues({'statistics_semester_v1': 'all'});
      final start = DateTime.now().subtract(const Duration(days: 1));
      await tester.runAsync(
        () => db.upsertSessions([
          for (var i = 0; i < 100; i++)
            CourseSession(
              id: 'c$i',
              classType: '',
              room: 'A1',
              date: start,
              weekday: start.weekday,
              courseName: 'Course $i',
              courseCode: 'C$i',
              section: '1',
              startAt: start.add(Duration(minutes: i)),
              endAt: start.add(Duration(minutes: i + 1)),
              teachers: const [],
              faculty: '',
              semester: 'Term',
            ),
        ]),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            importConfigurationProvider.overrideWith(_Configuration.new),
          ],
          child: app(const StatisticsPage()),
        ),
      );
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        if (find.text('View all').evaluate().isNotEmpty) break;
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('View all'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Course 99'), findsOneWidget);
      expect(find.text('Course 95'), findsOneWidget);
      expect(find.text('Course 94'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(find.byType(FinishedCoursesPage), findsOneWidget);
      expect(find.text('Course 99'), findsOneWidget);
      expect(find.text('Course 0'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await db.close();
        await root.delete(recursive: true);
      });
    },
  );
}
