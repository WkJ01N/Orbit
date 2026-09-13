import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/upcoming/upcoming_page.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

CourseSession _session(DateTime date, String code) {
  final start = DateTime(date.year, date.month, date.day, 10);
  return CourseSession(
    id: '$code-${date.toIso8601String()}',
    classType: '课堂',
    room: 'A101',
    date: date,
    weekday: date.weekday,
    courseName: '课程 $code',
    courseCode: code,
    section: '1',
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    teachers: const ['教师'],
    faculty: '学院',
    semester: '2026',
  );
}

void main() {
  testWidgets('长课程列表到底后按钮位于最后课程下方，点击平滑回顶', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sessions = List.generate(
      40,
      (index) => _session(
        DateTime.now().add(Duration(days: index + 1)),
        'scroll-$index',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingSessionsProvider.overrideWith((ref) async => sessions),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'Hans'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UpcomingPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    // Lazy variable-height cards refine their extent as the end is laid out.
    for (var attempt = 0; attempt < 5; attempt++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      if (position.extentAfter < 0.5) break;
    }
    final footer = find.byKey(const Key('upcoming-back-to-top-footer'));
    expect(footer.hitTestable(), findsOneWidget);
    expect(
      find.byKey(const Key('upcoming-back-to-top-floating')).hitTestable(),
      findsNothing,
    );
    final lastCard = find.ancestor(
      of: find.byKey(Key('upcoming-course-date-${sessions.last.id}')),
      matching: find.byType(Card),
    );
    expect(
      tester.getRect(lastCard).bottom,
      lessThan(tester.getRect(footer).top),
    );
    await tester.tap(footer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(position.pixels, greaterThan(0));
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(footer.hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('接下来列表为每周首节课显示周日期和课程日期', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final today = DateTime.now();
    final first = _session(today.add(const Duration(days: 2)), 'A');
    final second = _session(today.add(const Duration(days: 8)), 'B');
    final firstMonday = first.date.subtract(
      Duration(days: first.date.weekday - 1),
    );
    final secondMonday = second.date.subtract(
      Duration(days: second.date.weekday - 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingSessionsProvider.overrideWith((ref) async => [first, second]),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'Hans'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UpcomingPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        Key(
          'upcoming-week-marker-${firstMonday.year}-${firstMonday.month}-${firstMonday.day}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        Key(
          'upcoming-week-marker-${secondMonday.year}-${secondMonday.month}-${secondMonday.day}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(Key('upcoming-course-date-${first.id}')), findsOneWidget);
    expect(
      find.byKey(Key('upcoming-course-date-${second.id}')),
      findsOneWidget,
    );
    final add = find.byKey(const Key('upcoming-add-session'));
    expect(add, findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.getRect(add).width, greaterThanOrEqualTo(48));
    final addIcon = tester.widget<Icon>(
      find.descendant(of: add, matching: find.byIcon(Icons.add)),
    );
    expect(addIcon.size, 21);

    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SessionEditSheet), findsOneWidget);
  });

  testWidgets('接下来加载完成前不显示添加课程入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final pending = Completer<List<CourseSession>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingSessionsProvider.overrideWith((ref) => pending.future),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'Hans'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UpcomingPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('upcoming-add-session')), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
