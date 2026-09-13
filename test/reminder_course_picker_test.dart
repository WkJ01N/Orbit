import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/settings/reminder_course_picker.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';

CourseSession course(DateTime date, int index) => CourseSession(
  id: '${date.day}-$index',
  courseName: 'Course ${date.day}-$index',
  courseCode: 'C$index',
  classType: 'Class',
  room: 'A101',
  date: date,
  weekday: date.weekday,
  startAt: DateTime(date.year, date.month, date.day, 8 + index),
  endAt: DateTime(date.year, date.month, date.day, 9 + index),
  section: '1',
  teachers: const [],
  faculty: '',
  semester: '2026',
);
void main() {
  testWidgets(
    'single-course picker locates dates without filtering and keeps cross-day selection',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final sessions = [
        for (final date in [yesterday, today, tomorrow])
          for (var i = 0; i < 8; i++) course(date, i),
      ];
      List<String>? saved;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                child: const Text('open'),
                onPressed: () async {
                  saved = await showDialog<List<String>>(
                    context: ctx,
                    builder: (_) => ReminderCoursePicker(
                      sessions: sessions,
                      selected: const [],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final first = find.byKey(Key('reminder-course-${today.day}-0'));
      await tester.tap(first);
      await tester.pump();
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      final next = find.byKey(Key('reminder-course-${tomorrow.day}-0'));
      await tester.tap(next);
      await tester.pump();
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(first).value, isTrue);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, containsAll(['${today.day}-0', '${tomorrow.day}-0']));
      saved = null;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(first);
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
