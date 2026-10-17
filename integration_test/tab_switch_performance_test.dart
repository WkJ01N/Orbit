import 'package:orbit/data/database/row_decoders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('profile switching with large upcoming lists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final count in [200, 1000, 5000]) {
      final now = DateTime.now();
      final samples = List.generate(count, (i) {
        final date = DateTime(
          now.year,
          now.month,
          now.day,
        ).add(Duration(days: i ~/ 8));
        return CourseSession(
          id: 'sample-$i',
          classType: '',
          room: 'A101',
          date: date,
          weekday: date.weekday,
          courseName: 'Course ${i % 20}',
          courseCode: 'C${i % 20}',
          section: '1',
          startAt: date.add(Duration(hours: 8 + i % 8)),
          endAt: date.add(Duration(hours: 9 + i % 8)),
          teachers: const [],
          faculty: '',
          semester: '',
        );
      });
      final rows = samples.map((e) => e.toMap()).toList();
      final container = ProviderContainer(
        overrides: [
          sessionsProvider.overrideWith((ref) async => samples),
          upcomingSessionsProvider.overrideWith(
            (ref) async => const bool.fromEnvironment('ORBIT_PROFILE_ROWS')
                ? await decodeCourseRows(rows)
                : samples,
          ),
          deadlinesProvider.overrideWith((ref) async => []),
          strongCourseIdsProvider.overrideWith((ref) async => {}),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.watchPerformance(() async {
        for (var i = 0; i < 20; i++) {
          container.read(appNavIndexProvider.notifier).state = i.isEven ? 1 : 0;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
      }, reportKey: 'courses_$count');
      debugPrint(
        'ORBIT_TAB_PROFILE $count: ${Map.fromEntries((binding.reportData!['courses_$count'] as Map).entries.where((e) => e.value is num))}',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });
}
