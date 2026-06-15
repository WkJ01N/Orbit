import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/grid_builder.dart';

CourseSession _session({
  required DateTime date,
  required int weekday,
  required int startHour,
  int endHour = 0,
  String courseCode = 'PHYS102',
}) {
  final end = endHour == 0 ? startHour + 1 : endHour;
  final startAt = DateTime(date.year, date.month, date.day, startHour);
  final endAt = DateTime(date.year, date.month, date.day, end);
  return CourseSession(
    id: '${date.toIso8601String()}|$courseCode|EX1|$startHour:00',
    classType: '一般課堂',
    room: 'C508',
    date: date,
    weekday: weekday,
    courseName: '物理II',
    courseCode: courseCode,
    section: 'EX1',
    startAt: startAt,
    endAt: endAt,
    teachers: const ['Teacher'],
    faculty: 'FIE',
    semester: '2602',
  );
}

List<CourseSession> _denseWeekSessions() {
  final weekStart = DateTime(2026, 6, 1);
  final sessions = <CourseSession>[];
  for (var hour = 8; hour <= 19; hour++) {
    sessions.add(
      _session(
        date: DateTime(2026, 6, 2),
        weekday: 2,
        startHour: hour,
      ),
    );
  }
  for (final weekday in [3, 4, 5, 6]) {
    sessions.add(
      _session(
        date: weekStart.add(Duration(days: weekday - 1)),
        weekday: weekday,
        startHour: 9,
        courseCode: 'MATH101',
      ),
    );
  }
  return sessions;
}

void _expectHeaderBodyColumnsAligned(WidgetTester tester) {
  final tables = find.byType(Table);
  expect(tables, findsNWidgets(2));

  final headerRect = tester.getRect(tables.first);
  final bodyRect = tester.getRect(tables.last);

  expect(
    (headerRect.left - bodyRect.left).abs(),
    lessThan(1.0),
    reason: 'Table left edges differ: header=${headerRect.left} body=${bodyRect.left}',
  );
  expect(
    (headerRect.width - bodyRect.width).abs(),
    lessThan(1.0),
    reason: 'Table widths differ: header=${headerRect.width} body=${bodyRect.width}',
  );
  expect(
    (headerRect.right - bodyRect.right).abs(),
    lessThan(1.0),
    reason: 'Table right edges differ: header=${headerRect.right} body=${bodyRect.right}',
  );
}

Future<void> _pumpWideWeekGrid(WidgetTester tester) async {
  final weekStart = DateTime(2026, 6, 1);
  final grid = GridBuilder().buildWeekGrid(
    weekStart: weekStart,
    sessions: _denseWeekSessions(),
  );

  await tester.binding.setSurfaceSize(const Size(900, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: defaultLocale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: WeekGridView(grid: grid)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('宽屏多时段课表表头与课程列水平对齐', (WidgetTester tester) async {
    await _pumpWideWeekGrid(tester);
    _expectHeaderBodyColumnsAligned(tester);
  });

  testWidgets('宽屏纵向滚动后表头与课程列仍对齐', (WidgetTester tester) async {
    await _pumpWideWeekGrid(tester);
    _expectHeaderBodyColumnsAligned(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    _expectHeaderBodyColumnsAligned(tester);
  });
}
