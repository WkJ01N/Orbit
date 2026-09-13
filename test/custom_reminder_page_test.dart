import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/settings/custom_reminders_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/providers/app_providers.dart';

class _FixedReminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
}

void main() {
  Widget app(Widget child) => ProviderScope(
    overrides: [
      reminderSettingsProvider.overrideWith(_FixedReminders.new),
      sessionsProvider.overrideWith((ref) async => []),
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
      home: child,
    ),
  );

  testWidgets(
    'fixed clock and relative duration keep independent drafts when switching basis',
    (tester) async {
      CustomReminderRule? saved;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('open'),
                onPressed: () async {
                  saved = await Navigator.push<CustomReminderRule>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomReminderEditor(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reminder-field-name')),
        'Clock',
      );
      await tester.enterText(
        find.byKey(const Key('reminder-field-hours')),
        '2',
      );
      final basis = find.byType(DropdownButtonFormField<ReminderTimeBasis>);
      tester
          .widget<DropdownButtonFormField<ReminderTimeBasis>>(basis)
          .onChanged!(ReminderTimeBasis.date);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reminder-field-days')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('reminder-field-clockHours')),
        '23',
      );
      await tester.enterText(
        find.byKey(const Key('reminder-field-clockMinutes')),
        '59',
      );
      await tester.enterText(
        find.byKey(const Key('reminder-field-clockSeconds')),
        '58',
      );
      tester
          .widget<DropdownButtonFormField<ReminderTimeBasis>>(basis)
          .onChanged!(ReminderTimeBasis.start);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('reminder-field-hours')),
            )
            .controller!
            .text,
        '2',
      );
      tester
          .widget<DropdownButtonFormField<ReminderTimeBasis>>(basis)
          .onChanged!(ReminderTimeBasis.date);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('reminder-field-clockHours')),
            )
            .controller!
            .text,
        '23',
      );
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(saved!.secondOfDay, 23 * 3600 + 59 * 60 + 58);
      expect(saved!.dayOffset, 0);
      expect(saved!.offsetSeconds, -(2 * 3600 + 15 * 60));
    },
  );

  testWidgets('fixed clock validates hours and weekdays use abbreviations', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CustomReminderEditor(
          rule: CustomReminderRule(
            id: 'clock',
            name: 'Clock',
            basis: ReminderTimeBasis.date,
            activeFrom: DateTime(2026),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reminder-field-clockHours')),
      '24',
    );
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(find.text('0–23'), findsOneWidget);
    await tester.ensureVisible(find.text('Mon'));
    expect(find.text('Mon'), findsOneWidget);
    expect(find.textContaining('(1)'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    '320 pixel editor preserves seconds and explicit save with readable controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      CustomReminderRule? saved;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('open'),
                onPressed: () async {
                  saved = await Navigator.push<CustomReminderRule>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomReminderEditor(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reminder-field-name')),
        'Seconds reminder',
      );
      await tester.enterText(
        find.byKey(const Key('reminder-field-seconds')),
        '7',
      );
      expect(tester.takeException(), isNull);
      final savedAfter = DateTime.now();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(saved!.activeFrom.isBefore(savedAfter), isFalse);
      expect(saved?.name, 'Seconds reminder');
      expect(saved?.offsetSeconds, -907);
      expect(saved?.sendCount, 1);
      expect(saved?.strength, ReminderStrength.inherit);
    },
  );
  testWidgets('dirty editor asks before abandoning unsaved changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('open'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomReminderEditor()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reminder-field-name')),
      'Unsaved',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    final discard = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Discard changes'),
    );
    expect(
      discard.style!.foregroundColor!.resolve({}),
      Theme.of(tester.element(find.byType(AlertDialog))).colorScheme.error,
    );
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
