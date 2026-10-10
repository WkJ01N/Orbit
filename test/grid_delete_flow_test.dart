import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/grid/grid_delete_confirmation.dart';
import 'package:orbit/features/grid/grid_delete_targets.dart';
import 'package:orbit/features/grid/grid_page.dart';
import 'package:orbit/features/grid/grid_selection.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'archive_and_first_class_test.dart' show sampleClass;

class _Repository implements ScheduleRepository {
  _Repository(this.sessions);
  List<CourseSession> sessions;
  final deleted = <String>[];
  bool fail = false;
  int submissions = 0;
  Completer<void>? gate;
  @override
  Future<List<CourseSession>> getAllSessions() async => [...sessions];
  @override
  Future<List<CourseSession>> getUpcomingSessions({DateTime? from}) async => [];
  @override
  Future<int> deleteSessionIds(Iterable<String> ids) async {
    submissions++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('delete failed');
    final chosen = sessions.where((s) => ids.contains(s.id)).toList();
    deleted.addAll(chosen.map((s) => s.id));
    sessions.removeWhere((s) => ids.contains(s.id));
    return chosen.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Settings extends ScheduleDisplaySettingsNotifier {
  @override
  ScheduleDisplaySettings build() =>
      const ScheduleDisplaySettings(fitToPage: true);
}

class _Time extends CurrentTimeNotifier {
  @override
  DateTime build() => DateTime(2026, 8, 24, 12);
}

class _Reminders extends ReminderSettingsNotifier {
  _Reminders(this.failures);
  final int failures;
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
  @override
  Future<int> resyncReminders() async => failures;
  @override
  void scheduleResync() {}
}

final _monday = DateTime(2026, 8, 24);
List<CourseSession> _courses() => [
  sampleClass(
    'a',
    _monday.add(const Duration(hours: 8)),
  ).copyWith(courseCode: 'CS1', courseName: 'Course A'),
  sampleClass(
    'b',
    _monday.add(const Duration(hours: 10)),
  ).copyWith(courseCode: 'CS2', courseName: 'Course B'),
  sampleClass(
    'next',
    _monday.add(const Duration(days: 7, hours: 8)),
  ).copyWith(courseCode: 'CS1', courseName: 'Course A'),
];

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Repository repository, {
  Widget? child,
  double width = 400,
  double scale = 1,
  Locale locale = const Locale('en'),
  int rescheduleFailures = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      scheduleRepositoryProvider.overrideWithValue(repository),
      sessionsProvider.overrideWith((ref) async {
        ref.watch(scheduleRefreshProvider);
        return repository.getAllSessions();
      }),
      deadlinesProvider.overrideWith((_) async => []),
      selectedScheduleDateProvider.overrideWith((_) => _monday),
      selectedWeekStartProvider.overrideWith((_) => _monday),
      scheduleDisplaySettingsProvider.overrideWith(_Settings.new),
      currentTimeProvider.overrideWith(_Time.new),
      strongCourseIdsProvider.overrideWith((_) async => {}),
      reminderSettingsProvider.overrideWith(
        () => _Reminders(rescheduleFailures),
      ),
    ],
  );
  addTearDown(container.dispose);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 760);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(Size(width, 760));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child ?? const GridPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _chip(String id) => find.descendant(
  of: find.byKey(const Key('adjacent-page-current')),
  matching: find.byWidgetPredicate(
    (w) => w is GridSessionChip && w.session.id == id,
  ),
);
double _borderWidth(WidgetTester tester, String id) =>
    (tester
                .widget<Material>(
                  find
                      .descendant(
                        of: _chip(id),
                        matching: find.byType(Material),
                      )
                      .first,
                )
                .shape!
            as RoundedRectangleBorder)
        .side
        .width;

Future<void> _tapChoice(
  WidgetTester tester,
  Finder tile, {
  double delta = 120,
}) async {
  if (tile.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      tile,
      delta,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final checkbox = find
      .descendant(of: tile, matching: find.byType(Checkbox))
      .first;
  await tester.ensureVisible(checkbox);
  await tester.pumpAndSettle();
  await tester.tap(checkbox);
  await tester.pumpAndSettle();
}

Future<void> _tapChip(WidgetTester tester, String id) async {
  final enlarged = find.byKey(ValueKey('grid-fit-target-$id'));
  await tester.tap(enlarged.evaluate().isNotEmpty ? enlarged : _chip(id));
  await tester.pumpAndSettle();
}

Future<void> _mode(WidgetTester tester, String key) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(PopupMenuItem<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'detail dismissal clears selection and navigation does not reuse a selected frame',
    (tester) async {
      final container = await _pump(tester, _Repository(_courses()));
      await _tapChip(tester, 'a');
      await tester.pumpAndSettle();
      expect(find.byType(SessionDetailSheet), findsOneWidget);
      expect(tester.widget<GridSessionChip>(_chip('a')).isSelected, isTrue);
      Navigator.of(tester.element(find.byType(SessionDetailSheet))).pop();
      await tester.pumpAndSettle();
      expect(tester.widget<GridSessionChip>(_chip('a')).isSelected, isFalse);
      expect(_borderWidth(tester, 'a'), 1);
      await tester.tap(find.byIcon(Icons.chevron_right));
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        for (final element in find.byType(GridSessionChip).evaluate()) {
          expect((element.widget as GridSessionChip).isSelected, isFalse);
          expect(
            element.widget.key,
            ValueKey((element.widget as GridSessionChip).session.id),
          );
        }
      }
      await tester.pumpAndSettle();
      expect(
        container.read(selectedScheduleDateProvider),
        _monday.add(const Duration(days: 7)),
      );
      expect(_borderWidth(tester, 'next'), 1);
    },
  );

  testWidgets(
    'manual selection toggles, survives pages and requires cancellation confirmation',
    (tester) async {
      final container = await _pump(tester, _Repository(_courses()));
      await _mode(tester, 'delete-manually');
      expect(find.text('Select courses'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('grid-selection-submit')))
            .onPressed,
        isNull,
      );
      await _tapChip(tester, 'a');
      await tester.pumpAndSettle();
      expect(find.byType(SessionDetailSheet), findsNothing);
      expect(container.read(gridSelectionProvider).ids, {'a'});
      expect(_borderWidth(tester, 'a'), 2);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await _tapChip(tester, 'next');
      await tester.pumpAndSettle();
      expect(container.read(gridSelectionProvider).ids, {'a', 'next'});
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(_borderWidth(tester, 'a'), 2);
      final pager = find.byType(AdjacentPagePager);
      final drag = await tester.startGesture(tester.getCenter(pager));
      await drag.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 250));
      await drag.up();
      await tester.pumpAndSettle();
      expect(container.read(gridSelectionProvider).ids, {'a', 'next'});
      await tester.longPress(find.byKey(const ValueKey('grid-fit-target-a')));
      await tester.pumpAndSettle();
      expect(container.read(gridSelectionProvider).ids, {'a', 'next'});
      await tester.tap(find.byKey(const Key('grid-selection-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Keep selecting'), findsOneWidget);
      await tester.tap(find.text('Keep selecting'));
      await tester.pumpAndSettle();
      expect(container.read(gridSelectionProvider).active, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Keep selecting'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel selection'));
      await tester.pumpAndSettle();
      expect(container.read(gridSelectionProvider).active, isFalse);
    },
  );

  testWidgets(
    'preview unchecks persist and only confirmed IDs are deleted despite reminder failures',
    (tester) async {
      final repository = _Repository(_courses());
      final container = await _pump(tester, repository, rescheduleFailures: 1);
      await _mode(tester, 'delete-manually');
      await _tapChip(tester, 'a');
      await _tapChip(tester, 'b');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-selection-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Classes to delete'));
      await tester.pumpAndSettle();
      await _tapChoice(tester, find.byKey(const ValueKey('delete-preview-b')));
      await tester.pumpAndSettle();
      expect(container.read(gridSelectionProvider).ids, {'a'});
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(gridSelectionProvider).ids, {'a'});
      await tester.tap(find.byKey(const Key('grid-selection-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-delete-confirm')));
      await tester.pumpAndSettle();
      expect(repository.deleted, ['a']);
      expect(container.read(gridSelectionProvider).active, isFalse);
      expect(find.byWidgetPredicate((w) => w is SnackBar), findsOneWidget);
    },
  );

  testWidgets(
    'failed delete retains selection and duplicate submit is blocked',
    (tester) async {
      final repository = _Repository(_courses())..fail = true;
      final container = await _pump(tester, repository);
      await _mode(tester, 'delete-manually');
      await _tapChip(tester, 'a');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-selection-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-delete-confirm')));
      await tester.pumpAndSettle();
      expect(repository.deleted, isEmpty);
      expect(container.read(gridSelectionProvider).ids, {'a'});
      repository.fail = false;
      repository.gate = Completer<void>();
      await tester.tap(find.byKey(const Key('grid-delete-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('grid-delete-confirm')));
      await tester.pump();
      expect(
        repository.submissions,
        2,
      ); // One failed attempt and one active retry.
      expect(container.read(gridSelectionProvider).busy, isTrue);
      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(repository.deleted, ['a']);
    },
  );

  testWidgets(
    'snapshot changes require an updated preview and a second confirmation',
    (tester) async {
      final repository = _Repository(_courses());
      await _pump(
        tester,
        repository,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmGridDeletion(
                context,
                targets: [repository.sessions.first],
                onSelectionChanged: (_) {},
              ),
              child: const Text('Preview'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      repository.sessions[0] = repository.sessions[0].copyWith(
        startAt: _monday.add(const Duration(hours: 8, minutes: 15)),
      );
      await tester.tap(find.byKey(const Key('grid-delete-confirm')));
      await tester.pumpAndSettle();
      expect(repository.submissions, 0);
      expect(find.textContaining('Classes have changed'), findsOneWidget);
      await tester.tap(find.byKey(const Key('grid-delete-confirm')));
      await tester.pumpAndSettle();
      expect(repository.deleted, ['a']);
    },
  );

  testWidgets(
    'course deletion includes other weeks and archives only when explicitly enabled',
    (tester) async {
      final courses = _courses();
      courses.add(
        courses.first.copyWith(
          id: 'archive',
          archivedAt: _monday,
          archiveHidden: true,
        ),
      );
      final repository = _Repository(courses);
      await _pump(tester, repository);
      await _mode(tester, 'delete-by-course');
      final key = gridDeleteCourseKey(courses.first);
      await _tapChoice(tester, find.byKey(ValueKey('delete-course-$key')));
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 classes?'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        -120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('Delete 3 classes?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('grid-delete-preview')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-delete-confirm')));
      await tester.pumpAndSettle();
      expect(repository.deleted.toSet(), {'a', 'next', 'archive'});
    },
  );

  testWidgets(
    'time boundary is opt-in and changing courses clears its choice',
    (tester) async {
      final courses = _courses();
      courses.add(
        courses.first.copyWith(
          id: 'cross',
          startAt: _monday.subtract(const Duration(minutes: 30)),
          endAt: _monday.add(const Duration(minutes: 30)),
        ),
      );
      await _pump(tester, _Repository(courses), width: 900);
      await _mode(tester, 'delete-by-range');
      final key = gridDeleteCourseKey(courses.first);
      final course = find.byKey(ValueKey('delete-course-$key'));
      await tester.ensureVisible(course);
      await _tapChoice(tester, course);
      await tester.pumpAndSettle();
      final crossing = find.byKey(const ValueKey('delete-boundary-cross'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        crossing,
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.widget<CheckboxListTile>(crossing).value, isFalse);
      await _tapChoice(tester, crossing);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(crossing).value, isTrue);
      await _tapChoice(tester, course, delta: -120);
      await tester.pumpAndSettle();
      await _tapChoice(tester, course);
      await tester.scrollUntilVisible(
        crossing,
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(crossing).value, isFalse);
    },
  );

  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'manual header supports ${locale.toLanguageTag()} large text and Esc',
      (tester) async {
        final container = await _pump(
          tester,
          _Repository(_courses()),
          width: 320,
          scale: 1.7,
          locale: locale,
        );
        container.read(gridSelectionProvider.notifier).enter();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(container.read(gridSelectionProvider).active, isFalse);
      },
    );
  }
  testWidgets(
    'leaving the grid through app navigation uses the same cancellation guard',
    (tester) async {
      final container = await _pump(
        tester,
        _Repository(_courses()),
        child: const AppShell(),
      );
      await _mode(tester, 'delete-manually');
      await _tapChip(tester, 'a');
      await tester.tap(find.byIcon(Icons.schedule_outlined).last);
      await tester.pumpAndSettle();
      expect(find.text('Keep selecting'), findsOneWidget);
      await tester.tap(find.text('Keep selecting'));
      await tester.pumpAndSettle();
      expect(container.read(appNavIndexProvider), 0);
      expect(container.read(gridSelectionProvider).ids, {'a'});
      await tester.tap(find.byIcon(Icons.schedule_outlined).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel selection'));
      await tester.pumpAndSettle();
      expect(container.read(appNavIndexProvider), 1);
      expect(container.read(gridSelectionProvider).active, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unselected ongoing cards have a plain frame in multi-select mode',
    (tester) async {
      final courses = _courses();
      courses[0] = courses[0].copyWith(
        startAt: _monday.add(const Duration(hours: 11)),
        endAt: _monday.add(const Duration(hours: 13)),
      );
      final container = await _pump(tester, _Repository(courses));
      expect(_borderWidth(tester, 'a'), 2);
      container.read(gridSelectionProvider.notifier).enter();
      await tester.pumpAndSettle();
      expect(_borderWidth(tester, 'a'), 1);
      await _tapChip(tester, 'a');
      expect(_borderWidth(tester, 'a'), 2);
      await _tapChip(tester, 'a');
      expect(_borderWidth(tester, 'a'), 1);
    },
  );

  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'course delete form and expanded preview fit ${locale.toLanguageTag()} at large text',
      (tester) async {
        final repository = _Repository(_courses());
        await _pump(tester, repository, width: 320, scale: 1.7, locale: locale);
        await _mode(tester, 'delete-by-course');
        await _tapChoice(
          tester,
          find.byKey(
            ValueKey(
              'delete-course-${gridDeleteCourseKey(repository.sessions.first)}',
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('grid-delete-preview')));
        await tester.pumpAndSettle();
        final heading = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(ListTile),
            )
            .first;
        await tester.ensureVisible(heading);
        await tester.pumpAndSettle();
        await tester.tap(heading);
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxListTile), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
