import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit/core/motion/launch_motion.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Display extends ScheduleDisplaySettingsNotifier {
  @override
  ScheduleDisplaySettings build() =>
      const ScheduleDisplaySettings(fitToPage: true);
}

class _Time extends CurrentTimeNotifier {
  @override
  DateTime build() => DateTime(2026, 10, 12, 10);
}

class _Launch extends LaunchSettingsNotifier {
  _Launch(this.mode);
  final CardEntranceMode mode;
  @override
  LaunchSettings build() => LaunchSettings(cardEntrance: mode);
}

/// Profile the production entrance without opening the user's database,
/// changing preferences, or initializing notification/account services.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('profile fresh launch with a dense timetable in both modes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final samples = [
      for (var day = 0; day < 7; day++)
        for (var item = 0; item < 7; item++)
          CourseSession(
            id: '$day-$item',
            classType: '',
            room: 'A101',
            date: DateTime(2026, 10, 12 + day),
            weekday: day + 1,
            courseName: 'Orbit ${day + 1}',
            courseCode: 'C$day',
            section: '1',
            startAt: DateTime(2026, 10, 12 + day, 8 + item * 2),
            endAt: DateTime(2026, 10, 12 + day, 9 + item * 2, 30),
            teachers: const [],
            faculty: '',
            semester: '',
          ),
    ];
    for (final mode in CardEntranceMode.values) {
      await binding.watchPerformance(() async {
        for (var cycle = 0; cycle < 3; cycle++) {
          final container = ProviderContainer(
            overrides: [
              launchSettingsProvider.overrideWith(() => _Launch(mode)),
              scheduleDisplaySettingsProvider.overrideWith(_Display.new),
              currentTimeProvider.overrideWith(_Time.new),
              selectedScheduleDateProvider.overrideWith(
                (ref) => DateTime(2026, 10, 12),
              ),
              selectedWeekStartProvider.overrideWith(
                (ref) => DateTime(2026, 10, 12),
              ),
              sessionsProvider.overrideWith((ref) async => samples),
              deadlinesProvider.overrideWith((ref) async => []),
              strongCourseIdsProvider.overrideWith(
                (ref) async => {'0-0', '2-2', '4-4'},
              ),
            ],
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('${mode.name}-$cycle'),
                theme: AppTheme.light(),
                locale: const Locale('en'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: const OrbitLaunchHost(child: AppShell()),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1600));
          expect(find.byKey(const Key('orbit-launch-brand')), findsNothing);
          expect(find.byType(GridSessionChip), findsWidgets);
          final scope = tester.widget<LaunchMotionScope>(
            find.byType(LaunchMotionScope).first,
          );
          expect(scope.motion.cardsComplete, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        }
      }, reportKey: mode.name);
      final report = binding.reportData![mode.name] as Map;
      expect(report['frame_count'], greaterThan(60));
      final summary = Map.fromEntries(
        report.entries.where((e) => e.value is num),
      );
      debugPrint('ORBIT_LAUNCH_PROFILE ${mode.name}: $summary');
    }
  });
}
