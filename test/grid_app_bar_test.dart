import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/features/grid/grid_page.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';

CourseSession _session({required DateTime date, required int weekday}) {
  final startAt = DateTime(date.year, date.month, date.day, 9);
  final endAt = DateTime(date.year, date.month, date.day, 10);
  return CourseSession(
    id: '${date.toIso8601String()}|PHYS102|EX1|09:00',
    classType: '一般課堂',
    room: 'C508',
    date: date,
    weekday: weekday,
    courseName: '物理II',
    courseCode: 'PHYS102',
    section: 'EX1',
    startAt: startAt,
    endAt: endAt,
    teachers: const ['Teacher'],
    faculty: 'FIE',
    semester: '2602',
  );
}

Future<void> _pumpGridPage(WidgetTester tester, {required double width}) async {
  final weekStart = weekStartFor(DateTime(2026, 6, 1));
  final session = _session(date: DateTime(2026, 6, 2), weekday: 2);

  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionsProvider.overrideWith((ref) async => [session]),
        selectedWeekStartProvider.overrideWith((ref) => weekStart),
      ],
      child: MaterialApp(
        locale: defaultLocale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GridPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void _expectAppBarControlsDoNotOverlap(WidgetTester tester) {
  final add = find.byKey(const Key('grid-add-session'));
  expect(add, findsOneWidget);
  expect(find.byIcon(Icons.search), findsOneWidget);
  expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  expect(find.byType(FloatingActionButton), findsNothing);

  final addRect = tester.getRect(add);
  final nextWeekRect = tester.getRect(find.byIcon(Icons.chevron_right));
  final searchRect = tester.getRect(find.byIcon(Icons.search));

  expect(addRect.width, greaterThanOrEqualTo(48));
  expect(addRect.right, lessThan(nextWeekRect.left));
  expect(addRect.overlaps(searchRect), isFalse);
  final addIcon = tester.widget<Icon>(
    find.descendant(of: add, matching: find.byIcon(Icons.add)),
  );
  expect(addIcon.size, 21);
  expect(
    nextWeekRect.overlaps(searchRect),
    isFalse,
    reason: 'Date navigation should not overlap the search button',
  );
}

void main() {
  testWidgets('360dp 窄屏 AppBar 换周与搜索按钮不重叠', (WidgetTester tester) async {
    await _pumpGridPage(tester, width: 360);
    _expectAppBarControlsDoNotOverlap(tester);
  });

  testWidgets('320dp 极窄屏 AppBar 换周与搜索按钮不重叠', (WidgetTester tester) async {
    await _pumpGridPage(tester, width: 320);
    _expectAppBarControlsDoNotOverlap(tester);
  });

  testWidgets('课表左上角加号打开新增课程表单', (tester) async {
    await _pumpGridPage(tester, width: 360);

    await tester.tap(find.byKey(const Key('grid-add-session')));
    await tester.pumpAndSettle();

    expect(find.byType(SessionEditSheet), findsOneWidget);
  });

  testWidgets('课表加载完成前不显示添加课程入口', (tester) async {
    final pending = Completer<List<CourseSession>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionsProvider.overrideWith((ref) => pending.future)],
        child: MaterialApp(
          locale: defaultLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GridPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('grid-add-session')), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
