import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/settings/android_widget_settings_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/android_widget_settings.dart';
import 'package:orbit/models/android_widget_text.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/providers/widget_providers.dart';
import 'package:orbit/services/android_widget_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAndroidWidgetService extends AndroidWidgetService {
  _RecordingAndroidWidgetService() : super(isAndroidOverride: true);

  final AndroidWidgetStatus status = const AndroidWidgetStatus(
    supported: true,
    canPin: true,
    nextClassCount: 1,
    todayScheduleCount: 0,
  );
  int refreshCalls = 0;
  final List<AndroidWidgetKind> pinCalls = [];

  @override
  Future<AndroidWidgetStatus> getStatus() async => status;

  @override
  Future<bool> requestPin(AndroidWidgetKind kind) async {
    pinCalls.add(kind);
    return true;
  }

  @override
  Future<void> refreshWidgets() async {
    refreshCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'AndroidWidgetSettings normalizes bounds, defaults, and JSON round-trip',
    () {
      const defaults = AndroidWidgetSettings();
      expect(defaults.showDeadlines, isTrue);
      expect(defaults.deadlineLookaheadDays, 3);
      expect(defaults.backgroundOpacity, 92);

      final normalized = AndroidWidgetSettings.fromJson({
        'showDeadlines': false,
        'deadlineLookaheadDays': 5,
        'backgroundOpacity': 10,
      });
      expect(normalized.showDeadlines, isFalse);
      expect(normalized.deadlineLookaheadDays, 3);
      expect(normalized.backgroundOpacity, AndroidWidgetSettings.minOpacity);

      final roundTrip = AndroidWidgetSettings.fromJson(
        defaults
            .copyWith(
              showDeadlines: false,
              deadlineLookaheadDays: 7,
              backgroundOpacity: 120,
            )
            .toJson(),
      );
      expect(roundTrip.showDeadlines, isFalse);
      expect(roundTrip.deadlineLookaheadDays, 7);
      expect(roundTrip.backgroundOpacity, AndroidWidgetSettings.maxOpacity);
    },
  );

  test(
    'buildAndroidWidgetSyncPayload maps palettes, course overrides, and locale',
    () {
      final session = CourseSession(
        id: '2026-11-27|CS101|A|09:00',
        classType: 'Lecture',
        room: 'A204',
        date: DateTime(2026, 11, 27),
        weekday: 5,
        courseName: 'Algorithms',
        courseCode: 'CS101',
        section: 'A',
        startAt: DateTime(2026, 11, 27, 9, 0),
        endAt: DateTime(2026, 11, 27, 10, 30),
        teachers: const ['Dr. Lin'],
        faculty: 'FIE',
        semester: '2026',
      );
      const customOverride = Color(0xFFE91E63);
      final payload = buildAndroidWidgetSyncPayload(
        databasePath: '/data/user/0/com.must.orbit.orbit/files/orbit.db',
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        themeMode: ThemeMode.dark,
        themeStyle: AppThemeStyle.colorful,
        seedColor: kDefaultThemeColor,
        colorScheme: AppColorScheme.original,
        multicolor: const MulticolorSettings(),
        widgetSettings: const AndroidWidgetSettings(
          showDeadlines: false,
          deadlineLookaheadDays: 7,
          backgroundOpacity: 80,
        ),
        sessions: [session],
        courseColorOverrides: {'CS101': customOverride},
        automaticColorIds: const {},
      );

      expect(payload['databasePath'], contains('orbit.db'));
      expect(payload['localeTag'], 'zh_Hans');
      expect(payload['themeMode'], 'dark');
      expect(payload['themeStyle'], 'colorful');
      expect(payload['backgroundOpacity'], 80);
      expect(payload['showDeadlines'], isFalse);
      expect(payload['deadlineLookaheadDays'], 7);
      expect(
        (payload['paletteLight'] as Map<String, int>)['surface'],
        isNotNull,
      );
      expect(
        (payload['paletteDark'] as Map<String, int>)['primaryContainer'],
        isNotNull,
      );
      expect(
        (payload['courseColorsLight'] as Map<String, int>)['CS101'],
        customOverride.toARGB32(),
      );
      expect(
        (payload['courseColorsDark']
            as Map<String, int>)['code:cs101|section:a'],
        customOverride.toARGB32(),
      );
    },
  );

  test('AndroidWidgetService forwards methods over MethodChannel', () async {
    const channel = MethodChannel('orbit_widget_test_channel');
    final recorded = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          recorded.add(call);
          if (call.method == 'widgetStatus') {
            return {
              'canPin': true,
              'nextClassCount': 2,
              'todayScheduleCount': 1,
            };
          }
          if (call.method == 'requestPinWidget') {
            return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final service = AndroidWidgetService(
      channel: channel,
      isAndroidOverride: true,
    );
    await service.syncConfig({'themeMode': 'light'});
    await service.refreshWidgets();
    final status = await service.getStatus();
    final pinned = await service.requestPin(AndroidWidgetKind.todaySchedule);

    expect(recorded.map((c) => c.method), [
      'syncConfig',
      'refreshWidgets',
      'widgetStatus',
      'requestPinWidget',
    ]);
    expect(status.canPin, isTrue);
    expect(status.nextClassCount, 2);
    expect(status.todayScheduleCount, 1);
    expect(pinned, isTrue);
    expect(recorded.last.arguments, {'kind': 'todaySchedule'});
  });

  testWidgets(
    'AndroidWidgetSettingsPage persists toggles, lookahead window, opacity, and refresh',
    (tester) async {
      final service = _RecordingAndroidWidgetService();
      final settingsService = SettingsService();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(settingsService),
          androidWidgetServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      const hans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
      const text = AndroidWidgetText(hans);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: hans,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: AndroidWidgetSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(text.addedCount(1)), findsOneWidget);
      expect(find.text(text.previewSampleDdl), findsOneWidget);

      final pinButton = find.descendant(
        of: find.byKey(const Key('pin-next-class-widget')),
        matching: find.text(text.addAction),
      );
      await tester.ensureVisible(pinButton);
      await tester.tap(pinButton);
      await tester.pumpAndSettle();
      expect(service.pinCalls, [AndroidWidgetKind.nextClass]);

      await tester.scrollUntilVisible(
        find.byKey(const Key('widget-show-deadlines-switch')),
        200,
      );
      await tester.tap(find.byKey(const Key('widget-show-deadlines-switch')));
      await tester.pumpAndSettle();
      expect(
        container.read(androidWidgetSettingsProvider).showDeadlines,
        isFalse,
      );
      expect(find.text(text.previewSampleDdl), findsNothing);

      await tester.tap(find.byKey(const Key('widget-show-deadlines-switch')));
      await tester.pumpAndSettle();
      expect(
        container.read(androidWidgetSettingsProvider).showDeadlines,
        isTrue,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('widget-lookahead-dropdown')),
        200,
      );
      await tester.tap(find.byKey(const Key('widget-lookahead-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text.lookaheadDaysLabel(7)).last);
      await tester.pumpAndSettle();
      expect(
        container.read(androidWidgetSettingsProvider).deadlineLookaheadDays,
        7,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('widget-refresh-now')),
        200,
      );
      await tester.tap(find.byKey(const Key('widget-refresh-now')));
      await tester.pumpAndSettle();
      expect(service.refreshCalls, 1);

      final persisted = await settingsService.loadAndroidWidgetSettings();
      expect(persisted.deadlineLookaheadDays, 7);
    },
  );
}
