import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/widgets/section_header.dart';
import 'package:orbit/features/settings/debug_page.dart';
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
    expect(find.text('Test notification now'), findsNothing);
    expect(find.text('Test background reminder (1 min)'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-category-3')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings-category-content-3')),
      findsOneWidget,
    );
    expect(find.text('Export JSON backup'), findsOneWidget);
    expect(find.text('Debug'), findsOneWidget);

    await tester.ensureVisible(find.text('Debug'));
    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();
    expect(find.byType(DebugPage), findsOneWidget);
    expect(find.text('Test notification now'), findsOneWidget);
    expect(find.text('Test background reminder (1 min)'), findsNothing);
  });

  testWidgets('调试页仅在 Android 模式显示一分钟后台提醒', (tester) async {
    SharedPreferences.setMockInitialValues({});

    Future<void> pumpDebugPage(bool showAndroidTools) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localeProvider.overrideWith(_FixedLocaleNotifier.new)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: DebugPage(showAndroidTools: showAndroidTools),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpDebugPage(false);
    expect(find.text('Test notification now'), findsOneWidget);
    expect(find.text('Test background reminder (1 min)'), findsNothing);

    await pumpDebugPage(true);
    expect(find.text('Test notification now'), findsOneWidget);
    expect(find.text('Test background reminder (1 min)'), findsOneWidget);
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

  testWidgets('窄屏设置分类的整个分栏都可以点击', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [320.0, 360.0, 400.0]) {
      await tester.binding.setSurfaceSize(Size(width, 720));
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
            home: SettingsPage(key: ValueKey('tap-$width')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final secondTab = find.byKey(const Key('settings-category-1'));
      final secondRect = tester.getRect(secondTab);
      expect(secondRect.height, greaterThanOrEqualTo(48));
      expect(secondRect.width, closeTo(width / 4, 0.1));
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-category-tabs')),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('settings-category-indicator-0')),
        findsOneWidget,
      );
      await tester.tapAt(Offset(secondRect.left + 2, secondRect.center.dy));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-category-content-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-category-indicator-1')),
        findsOneWidget,
      );

      final fourthRect = tester.getRect(
        find.byKey(const Key('settings-category-3')),
      );
      await tester.tapAt(Offset(fourthRect.right - 2, fourthRect.center.dy));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-category-content-3')),
        findsOneWidget,
      );
    }
  });
}
