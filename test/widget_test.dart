import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';

List<Override> _testOverrides() => [
      localeProvider.overrideWith(() => _FixedLocaleNotifier()),
      reminderSettingsProvider.overrideWith(() => _FixedReminderSettingsNotifier()),
      sessionsProvider.overrideWith((ref) async => []),
      weekGridProvider.overrideWith((ref) => null),
      upcomingSessionsProvider.overrideWith((ref) async => []),
    ];

void main() {
  testWidgets('AppShell 顯示四個導航分頁', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _testOverrides(),
        child: MaterialApp(
          locale: defaultLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('課表'), findsWidgets);
    expect(find.text('接下來'), findsWidgets);
    expect(find.text('匯入'), findsWidgets);
    expect(find.text('設置'), findsWidgets);
  });

  testWidgets('課表空態「立即匯入」跳轉至匯入分頁', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: _testOverrides(),
        child: MaterialApp(
          locale: defaultLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('立即匯入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('選擇 xlsx 課表檔案'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppTab.import.index,
    );
  });
}

class _FixedLocaleNotifier extends LocaleNotifier {
  @override
  Locale build() => defaultLocale;
}

class _FixedReminderSettingsNotifier extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
}
