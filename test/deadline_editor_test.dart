import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/deadline/deadline_ui.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';

void main() {
  testWidgets('DDL editor fits a narrow screen and switches subjects', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    await tester.tap(find.text('Custom subject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mathematics').last);
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller?.text, 'Mathematics');
    expect(fields.first.readOnly, isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mathematics').first);
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
