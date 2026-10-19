import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/grid/grid_event_motion.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_quick_actions.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/settings_sync_codec.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CourseSession lesson(DateTime date) {
  final s = CourseSession(
    id: '',
    classType: 'Lecture',
    room: 'A1',
    date: date,
    weekday: date.weekday,
    courseName: 'Math',
    courseCode: 'M',
    section: '1',
    startAt: DateTime(date.year, date.month, date.day, 9),
    endAt: DateTime(date.year, date.month, date.day, 10),
    teachers: const [],
    faculty: '',
    semester: 'Old semester',
    semesterId: 'old',
  );
  return s.copyWith(id: s.computeId());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'presentation commits both queries together and keeps its successful snapshot on failure',
    () async {
      var courses = Completer<List<CourseSession>>(),
          deadlines = Completer<List<Deadline>>();
      final container = ProviderContainer(
        overrides: [
          sessionsProvider.overrideWith((ref) {
            ref.watch(scheduleRefreshProvider);
            return courses.future;
          }),
          deadlinesProvider.overrideWith((ref) {
            ref.watch(scheduleRefreshProvider);
            return deadlines.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(schedulePresentationProvider, (_, _) {});
      addTearDown(sub.close);
      final old = lesson(DateTime(2026, 10, 19));
      courses.complete([old]);
      deadlines.complete([]);
      await Future.wait([
        container.read(sessionsProvider.future),
        container.read(deadlinesProvider.future),
      ]);
      final before = container.read(schedulePresentationProvider)!;
      courses = Completer();
      deadlines = Completer();
      container.read(scheduleRefreshProvider.notifier).state++;
      expect(container.read(schedulePresentationProvider), same(before));
      courses.complete([old.copyWith(room: 'B2')]);
      await container.read(sessionsProvider.future);
      expect(container.read(schedulePresentationProvider), same(before));
      deadlines.complete([
        Deadline(
          id: 'ddl',
          subject: 'Math',
          title: 'Assignment',
          dueAt: DateTime(2026, 10, 20),
          leadMinutes: const [],
        ),
      ]);
      await container.read(deadlinesProvider.future);
      final after = container.read(schedulePresentationProvider)!;
      expect(after.sessions.single.room, 'B2');
      expect(after.deadlines.single.id, 'ddl');
      courses = Completer();
      deadlines = Completer();
      container.read(scheduleRefreshProvider.notifier).state++;
      container.read(schedulePresentationProvider);
      courses.completeError(StateError('simulated read failure'));
      deadlines.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sessionsProvider).hasError, isTrue);
      expect(container.read(schedulePresentationProvider), same(after));
    },
  );
  test(
    'quick action preferences round-trip through portable backup and stay out of cloud settings',
    () async {
      final service = SettingsService();
      final settings = const CourseQuickActionSettings()
          .swap(0, SessionAction.delete)
          .copyWith(enabled: false, edgeMode: QuickActionEdgeMode.floatInward);
      await service.saveCourseQuickActions(jsonEncode(settings.toJson()));
      final backup = await service.exportPortableSettings();
      expect(backup.localPreferences['course_quick_actions_v1'], isNotNull);
      expect(
        jsonEncode(SettingsSyncCodec.groups(backup)),
        isNot(contains('course_quick_actions_v1')),
      );
      await service.saveCourseQuickActions(
        jsonEncode(const CourseQuickActionSettings().toJson()),
      );
      await service.importPortableSettings(backup);
      final restored = CourseQuickActionSettings.fromJson(
        Map<String, dynamic>.from(
          jsonDecode((await service.loadCourseQuickActions())!) as Map,
        ),
      );
      expect(restored.enabled, isFalse);
      expect(restored.edgeMode, QuickActionEdgeMode.floatInward);
      expect(restored.positions.first, SessionAction.delete);
    },
  );
  test(
    'semester edits update scoped classes and stable statistics atomically',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final root = await Directory.systemTemp.createTemp(
        'orbit-v163-semester-',
      );
      final db = await AppDatabase.open(root.path);
      try {
        final one = lesson(DateTime(2025, 1, 1)),
            two = lesson(DateTime(2025, 1, 8));
        await db.upsertSessions([one, two]);
        await db.refreshStatistics();
        final repo = ScheduleRepository(db, XlsxParser());
        final result = await repo.updateCourseSeries(
          selected: one,
          changes: one.copyWith(
            semester: 'New semester',
            semesterId: 'new',
            startAt: DateTime(2025, 1, 1, 10),
            endAt: DateTime(2025, 1, 1, 11),
          ),
          scope: CourseOperationScope.all,
        );
        final courses = await db.getAllSessions();
        expect(courses.length, 2);
        expect(
          courses.every(
            (s) => s.semesterId == 'new' && s.semester == 'New semester',
          ),
          isTrue,
        );
        expect(result.identityChanges.keys, containsAll([one.id, two.id]));
        final records = (await db.statisticsRecords())
            .where((r) => r['kind'] == 'course')
            .toList();
        expect(records.length, 2);
        expect(
          records.every(
            (r) => r['semesterId'] == 'new' && r['semester'] == 'New semester',
          ),
          isTrue,
        );
        expect(
          records.every((r) => '${r['courseKey']}'.startsWith('New semester|')),
          isTrue,
        );
        expect(records.map((r) => r['id']).toSet().length, 2);
      } finally {
        await db.close();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'editing an identity-changing event crossfades in place and deletion retains a fading snapshot',
    (tester) async {
      final data = ValueNotifier<List<GridMotionEvent>>([
        const GridMotionEvent(
          id: 'old',
          signature: 'old',
          rect: Rect.fromLTWH(50, 40, 80, 60),
          child: Text('Old card'),
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: data,
              builder: (_, events, _) => GridEventMotion(
                events: events,
                viewport: const Rect.fromLTWH(0, 0, 400, 600),
                mode: CardEntranceMode.edge,
                identityChanges: const {'old': 'new'},
              ),
            ),
          ),
        ),
      );
      data.value = [
        const GridMotionEvent(
          id: 'new',
          signature: 'new',
          rect: Rect.fromLTWH(50, 140, 80, 60),
          child: Text('New card'),
        ),
      ];
      await tester.pump();
      expect(find.text('Old card'), findsOneWidget);
      expect(find.text('New card'), findsOneWidget);
      final incoming = find
          .ancestor(of: find.text('New card'), matching: find.byType(Transform))
          .first;
      expect(
        tester.widget<Transform>(incoming).transform.getTranslation().y,
        0,
        reason: 'Edits fade without insertion travel',
      );
      await tester.pumpAndSettle();
      expect(find.text('Old card'), findsNothing);
      data.value = [];
      await tester.pump();
      expect(find.text('New card'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      final fade = tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('New card'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(fade, greaterThan(0));
      expect(fade, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('New card'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      data.dispose();
    },
  );
  testWidgets(
    'changing the date viewport resets visual history without fake insertions or removals',
    (tester) async {
      final week = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: week,
            builder: (_, value, _) => GridEventMotion(
              viewportIdentity: value,
              viewport: const Rect.fromLTWH(0, 0, 400, 400),
              mode: CardEntranceMode.nearby,
              events: [
                GridMotionEvent(
                  id: 'week-$value',
                  signature: '$value',
                  rect: const Rect.fromLTWH(20, 20, 100, 80),
                  child: Text('week-$value'),
                ),
              ],
            ),
          ),
        ),
      );
      week.value = 1;
      await tester.pump();
      expect(find.text('week-0'), findsNothing);
      final card = find.text('week-1');
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: card, matching: find.byType(Opacity)).first,
            )
            .opacity,
        1,
      );
      expect(
        tester
            .widget<Transform>(
              find.ancestor(of: card, matching: find.byType(Transform)).first,
            )
            .transform
            .getTranslation()
            .y,
        0,
      );
      await tester.pumpWidget(const SizedBox());
      week.dispose();
    },
  );
  testWidgets(
    'new events use nearby travel while reduced motion displays the final state immediately',
    (tester) async {
      final data = ValueNotifier<List<GridMotionEvent>>([]);
      final reduced = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: reduced,
            builder: (_, reduce, _) => MediaQuery(
              data: MediaQueryData(disableAnimations: reduce),
              child: Scaffold(
                body: ValueListenableBuilder(
                  valueListenable: data,
                  builder: (_, events, _) => GridEventMotion(
                    events: events,
                    viewport: const Rect.fromLTWH(0, 0, 400, 600),
                    mode: CardEntranceMode.nearby,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      data.value = [
        const GridMotionEvent(
          id: 'added',
          signature: 'one',
          rect: Rect.fromLTWH(40, 80, 80, 60),
          child: Text('Added'),
        ),
      ];
      await tester.pump();
      final transform = find
          .ancestor(of: find.text('Added'), matching: find.byType(Transform))
          .first;
      expect(
        tester.widget<Transform>(transform).transform.getTranslation().y.abs(),
        48,
      );
      reduced.value = true;
      await tester.pump();
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('Added'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );
      expect(
        tester.widget<Transform>(transform).transform.getTranslation().y,
        0,
      );
      await tester.pumpWidget(const SizedBox());
      data.dispose();
      reduced.dispose();
    },
  );
}
