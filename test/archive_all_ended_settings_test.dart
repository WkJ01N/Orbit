import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/settings/settings_data_section.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/orbit_feature_text.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'archive_and_first_class_test.dart' show sampleClass;
import 'orbit_optimization_widgets_test.dart' show app;

class _ArchiveRepository implements ScheduleRepository {
  List<CourseSession> ended = [
    sampleClass('past', DateTime.now().subtract(const Duration(days: 1))),
  ];
  List<String>? archivedIds;
  bool? hide;
  DateTime? previewTime;
  DateTime? archiveTime;
  bool fail = false;

  @override
  Future<List<CourseSession>> getUnarchivedEndedSessions({DateTime? at}) async {
    previewTime = at;
    return ended;
  }

  @override
  Future<int> archiveEndedSessions({
    List<String>? sessionIds,
    bool hide = true,
    DateTime? at,
  }) async {
    if (fail) throw StateError('database unavailable');
    archivedIds = sessionIds;
    this.hide = hide;
    archiveTime = at;
    return sessionIds!.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reminders extends ReminderSettingsNotifier {
  int resyncs = 0;
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
  @override
  void scheduleResync() => resyncs++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openSettings(
    WidgetTester tester,
    _ArchiveRepository repository,
    _Reminders reminders, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: SingleChildScrollView(child: SettingsDataSection()),
        ),
        locale: locale,
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(repository),
          reminderSettingsProvider.overrideWith(() => reminders),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text(OrbitFeatureText(locale).archiveAllEnded),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'settings bulk archive confirms count and default hide in $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _ArchiveRepository();
        final reminders = _Reminders();
        final text = OrbitFeatureText(locale);
        await openSettings(tester, repository, reminders, locale: locale);
        await tester.tap(find.text(text.archiveAllEnded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(text.count(1)), findsOneWidget);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(FilledButton, text.archive));
        await tester.pumpAndSettle();
        expect(repository.archivedIds, ['past']);
        expect(repository.hide, isTrue);
        expect(repository.archiveTime, repository.previewTime);
        expect(reminders.resyncs, 1);
        expect(find.text(text.archivedClasses(1)), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'bulk archive can retain visibility and cancellation writes nothing',
    (tester) async {
      final repository = _ArchiveRepository();
      final reminders = _Reminders();
      const text = OrbitFeatureText(Locale('en'));
      await openSettings(tester, repository, reminders);
      await tester.tap(find.text(text.archiveAllEnded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.archivedIds, isNull);
      expect(reminders.resyncs, 0);
      await tester.tap(find.text(text.archiveAllEnded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, text.archive));
      await tester.pumpAndSettle();
      expect(repository.hide, isFalse);
      expect(reminders.resyncs, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'no eligible classes shows feedback without opening confirmation',
    (tester) async {
      final repository = _ArchiveRepository()..ended = [];
      final reminders = _Reminders();
      const text = OrbitFeatureText(Locale('en'));
      await openSettings(tester, repository, reminders);
      await tester.tap(find.text(text.archiveAllEnded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(text.noEndedToArchive), findsOneWidget);
      expect(repository.archivedIds, isNull);
      expect(reminders.resyncs, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed bulk archive reports failure and permits retry', (
    tester,
  ) async {
    final repository = _ArchiveRepository()..fail = true;
    final reminders = _Reminders();
    const text = OrbitFeatureText(Locale('en'));
    await openSettings(tester, repository, reminders);
    await tester.tap(find.text(text.archiveAllEnded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, text.archive));
    await tester.pumpAndSettle();
    expect(find.text(text.failed), findsOneWidget);
    expect(reminders.resyncs, 0);
    repository.fail = false;
    await tester.tap(find.text(text.archiveAllEnded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, text.archive));
    await tester.pumpAndSettle();
    expect(repository.archivedIds, ['past']);
    expect(reminders.resyncs, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
