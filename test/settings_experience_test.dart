import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/widgets/section_header.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedLocaleNotifier extends LocaleNotifier {
  @override
  Locale build() => const Locale('en');
}

class _FixedReminderSettingsNotifier extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
}

void main() {
  testWidgets('设置按四个分类切换且不混杂内容', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWith(_FixedLocaleNotifier.new),
          reminderSettingsProvider.overrideWith(
            _FixedReminderSettingsNotifier.new,
          ),
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
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-category-tabs')), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      expect(find.byKey(Key('settings-category-$index')), findsOneWidget);
    }
    expect(
      find.byKey(const Key('settings-category-content-0')),
      findsOneWidget,
    );
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Default week'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-category-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings-category-content-1')),
      findsOneWidget,
    );
    expect(find.text('Default week'), findsOneWidget);
    expect(find.text('Language'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-category-2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings-category-content-2')),
      findsOneWidget,
    );
    expect(find.text('Enable class reminders'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-category-3')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings-category-content-3')),
      findsOneWidget,
    );
    expect(find.text('Export JSON backup'), findsOneWidget);
  });

  testWidgets('设置分组标题和主题色在不同宽度保持左对齐', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [320.0, 400.0, 600.0, 900.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(_FixedLocaleNotifier.new),
            reminderSettingsProvider.overrideWith(
              _FixedReminderSettingsNotifier.new,
            ),
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
            home: SettingsPage(key: ValueKey(width)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Appearance',
        'Theme color',
        if (Platform.isWindows) 'System',
      ]) {
        final finder = label == 'Theme color'
            ? find.text(label)
            : find.descendant(
                of: find.byType(SectionHeader),
                matching: find.text(label),
              );
        for (
          var attempt = 0;
          finder.evaluate().isEmpty && attempt < 4;
          attempt++
        ) {
          await tester.drag(
            find.byKey(const Key('settings-category-content-0')),
            const Offset(0, -220),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(finder).dx, closeTo(16, 0.1));
      }

      await tester.tap(
        find.byKey(const Key('settings-category-3')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      final dataHeader = find.descendant(
        of: find.byType(SectionHeader),
        matching: find.text('Data management'),
      );
      expect(tester.getTopLeft(dataHeader).dx, closeTo(16, 0.1));
    }
  });
}
