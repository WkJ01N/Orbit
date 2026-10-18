import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/deadline/deadline_ui.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/deadline.dart';

class _ReuseDatabase implements AppDatabase {
  @override
  Future<List<Deadline>> getDeadlines({bool includeDeleted = false}) async => [
    Deadline(
      id: 'template',
      subject: 'Math',
      title: 'Archived template',
      dueAt: DateTime(2025),
      leadMinutes: const [60],
      completedAt: DateTime(2025),
      archivedAt: DateTime(2025),
      countsTowardStatistics: false,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'reuse resets statistics opt-out to checked and keeps the choice in batch mode',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(_ReuseDatabase()),
            sessionsProvider.overrideWith((_) async => []),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => showDeadlineEditor(c),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reuse an existing DDL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archived template'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((f) => f.controller?.text),
        contains('Archived template'),
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Batch'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(find.text('Weeks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('DDL editor fits a narrow screen and switches subjects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = DateTime(2026, 10, 1);
    final session = CourseSession(
      id: 'math-1',
      classType: 'Lecture',
      room: 'A1',
      date: date,
      weekday: date.weekday,
      courseName: 'Mathematics',
      courseCode: 'MATH101',
      section: '01',
      startAt: DateTime(2026, 10, 1, 9),
      endAt: DateTime(2026, 10, 1, 10),
      teachers: const [],
      faculty: '',
      semester: '2026',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionsProvider.overrideWith((ref) async => [session]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDeadlineEditor(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Add DDL'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('deadline-course-picker')));
    await tester.tap(find.byKey(const Key('deadline-course-picker')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('view-ended-courses')));
    await tester.tap(find.byKey(const Key('view-ended-courses')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mathematics').last);
    await tester.tap(find.text('Mathematics').last);
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller?.text, 'Mathematics');
    expect(fields.first.readOnly, isTrue);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('deadline-course-picker')));
    await tester.tap(find.byKey(const Key('deadline-course-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom subject').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).readOnly,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
