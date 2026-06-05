import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';
import 'package:orbit/features/grid/grid_page.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/grid_models.dart';
import 'package:orbit/providers/app_providers.dart';

WeekGrid _emptyWeekGrid() {
  final weekStart = weekStartFor(DateTime(2026, 7, 27));
  return WeekGrid(
    weekStart: weekStart,
    timeLabels: const [],
    cells: const {},
  );
}

void main() {
  testWidgets('清除全部課表後顯示全局空態', (WidgetTester tester) async {
    final staleWeekStart = weekStartFor(DateTime(2026, 7, 27));

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionsProvider.overrideWith((ref) async => []),
          selectedWeekStartProvider.overrideWith((ref) => staleWeekStart),
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

    expect(find.text('尚未匯入課表'), findsOneWidget);
    expect(find.text('本週無課程'), findsNothing);
    expect(find.byType(AdjacentPagePager), findsNothing);
  });

  testWidgets('空課程周仍保留 AdjacentPagePager 以支持翻頁', (WidgetTester tester) async {
    final emptyGrid = _emptyWeekGrid();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionsProvider.overrideWith((ref) async => []),
          weekGridProvider.overrideWith((ref) => emptyGrid),
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

    expect(find.byType(AdjacentPagePager), findsOneWidget);
    expect(find.text('本週無課程'), findsOneWidget);
  });
}
