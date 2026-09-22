import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';

void main() {
  final session = CourseSession(
    id: 'example',
    classType: 'Class',
    room: 'Room 1',
    date: DateTime(2026, 10, 1),
    weekday: 4,
    courseName: 'Mathematics',
    courseCode: 'MATH101',
    section: 'A',
    startAt: DateTime(2026, 10, 1, 9),
    endAt: DateTime(2026, 10, 1, 10),
    teachers: const [],
    faculty: '',
    semester: '2026',
  );

  Future<void> open(WidgetTester tester, double width, double scale) async {
    await tester.binding.setSurfaceSize(Size(width, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
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
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => SessionDetailSheet.show(context, session),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('English detail actions show complete short labels at 320px', (
    tester,
  ) async {
    await open(tester, 320, 1);
    for (final label in ['Edit', 'Color', 'Note', 'Delete']) {
      expect(find.text(label), findsOneWidget);
      final value = tester.widget<Text>(find.text(label));
      expect(value.overflow, isNot(TextOverflow.ellipsis));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('English actions wrap without overflow at large text scale', (
    tester,
  ) async {
    await open(tester, 320, 1.8);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
