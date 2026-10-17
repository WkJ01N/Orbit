import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'refreshing identical empty deadlines preserves the existing course grid',
    () async {
      SharedPreferences.setMockInitialValues({});
      final date = DateTime(2026, 10, 19);
      final session = CourseSession(
        id: 'one',
        classType: '',
        room: 'A101',
        date: date,
        weekday: 1,
        courseName: 'Math',
        courseCode: 'M',
        section: '1',
        startAt: date.add(const Duration(hours: 9)),
        endAt: date.add(const Duration(hours: 10)),
        teachers: const [],
        faculty: '',
        semester: '',
      );
      final container = ProviderContainer(
        overrides: [
          sessionsProvider.overrideWith((ref) async => [session]),
          deadlinesProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionsProvider.future);
      await container.read(deadlinesProvider.future);
      final before = container.read(weekGridProvider);
      expect(before, isNotNull);
      await container.refresh(deadlinesProvider.future);
      expect(identical(before, container.read(weekGridProvider)), isTrue);
    },
  );
  testWidgets(
    'rapid tab switches preserve the upcoming scroll position and lazy rows',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now();
      final samples = List.generate(1000, (i) {
        final date = DateTime(now.year, now.month, now.day + i ~/ 8);
        return CourseSession(
          id: 'row-$i',
          classType: '',
          room: 'A',
          date: date,
          weekday: date.weekday,
          courseName: 'Math',
          courseCode: 'M',
          section: '1',
          startAt: date.add(Duration(hours: 9 + i % 8)),
          endAt: date.add(Duration(hours: 10 + i % 8)),
          teachers: const [],
          faculty: '',
          semester: '',
        );
      });
      final container = ProviderContainer(
        overrides: [
          sessionsProvider.overrideWith((ref) async => samples),
          upcomingSessionsProvider.overrideWith((ref) async => samples),
          deadlinesProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      container.read(appNavIndexProvider.notifier).state = 1;
      await tester.pumpAndSettle();
      final view = tester.widget<CustomScrollView>(
        find.byKey(const Key('upcoming-scroll-view')),
      );
      view.controller!.jumpTo(500);
      await tester.pumpAndSettle();
      final offset = view.controller!.offset;
      for (final index in [0, 1, 0, 1]) {
        container.read(appNavIndexProvider.notifier).state = index;
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      final returned = tester.widget<CustomScrollView>(
        find.byKey(const Key('upcoming-scroll-view')),
      );
      expect(returned.controller!.offset, closeTo(offset, 1));
      expect(find.byType(Card).evaluate().length, lessThan(60));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
