import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/widgets/reminder_template_field.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/settings/theme_scheme_page.dart';
import 'package:orbit/features/settings/strong_reminder_page.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/course_color_providers.dart';
import 'package:orbit/services/course_color_utils.dart';
import 'package:orbit/services/grid_builder.dart';

class _FitSettings extends ScheduleDisplaySettingsNotifier {
  @override
  ScheduleDisplaySettings build() =>
      const ScheduleDisplaySettings(fitToPage: true);
}

class _EmptyOverrides extends CourseColorOverridesNotifier {
  @override
  Map<String, Color> build() => const {};
}

class _Palette extends MulticolorSettingsNotifier {
  @override
  MulticolorSettings build() => const MulticolorSettings(
    enabled: true,
    scheme: AppColorScheme.expressive,
  );
}

class _Reminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async => const ReminderSettings();
}

class _Seed extends ThemeColorNotifier {
  @override
  Color build() => kDefaultThemeColor;
}

class _Clock extends CurrentTimeNotifier {
  @override
  DateTime build() => DateTime(2026, 8, 24, 12);
}

List<CourseSession> courses() => [
  for (var i = 0; i < 12; i++)
    CourseSession(
      id: 'C$i',
      courseName: ['移动应用设计', '高等数学', '大学物理', '学术写作', '软件工程', '计算机网络'][i % 6],
      courseCode: 'C$i',
      room: 'A-${101 + i}',
      section: '01',
      classType: '课堂',
      date: DateTime(2026, 8, 24 + i % 7),
      weekday: i % 7 + 1,
      startAt: DateTime(2026, 8, 24 + i % 7, i < 7 ? 8 + i % 4 : 15 + i % 4),
      endAt: DateTime(2026, 8, 24 + i % 7, i < 7 ? 10 + i % 4 : 17 + i % 4),
      teachers: const ['陈老师'],
      faculty: '工程学院',
      semester: '2026',
    ),
];
Future<void> pumpPreview(
  WidgetTester tester,
  Widget child, {
  double width = 320,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
  ),
}) async {
  await tester.binding.setSurfaceSize(Size(width, 760));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final sessions = courses();
  final ids = allocateCourseColorIds({}, sessions.map(automaticCourseColorKey));
  final theme = brightness == Brightness.light
      ? AppTheme.light(
          style: AppThemeStyle.colorful,
          multicolor: const MulticolorSettings(enabled: true),
        )
      : AppTheme.dark(
          style: AppThemeStyle.colorful,
          multicolor: const MulticolorSettings(enabled: true),
        );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionsProvider.overrideWith((ref) async => sessions),
        scheduleDisplaySettingsProvider.overrideWith(_FitSettings.new),
        selectedScheduleDateProvider.overrideWith(
          (ref) => DateTime(2026, 8, 24),
        ),
        courseColorOverridesProvider.overrideWith(_EmptyOverrides.new),
        resolvedAutomaticCourseColorIdsProvider.overrideWithValue(ids),
        multicolorSettingsProvider.overrideWith(_Palette.new),
        reminderSettingsProvider.overrideWith(_Reminders.new),
        themeColorProvider.overrideWith(_Seed.new),
        currentTimeProvider.overrideWith(_Clock.new),
      ],
      child: MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'OrbitPreview'),
        ),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RepaintBoundary(key: const Key('preview'), child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (!Platform.isWindows) return;
    final loader = FontLoader('OrbitPreview');
    final bytes = await File('C:/Windows/Fonts/simhei.ttf').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final iconBytes = await File(
      '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    icons.addFont(Future.value(ByteData.sublistView(iconBytes)));
    await icons.load();
  });
  for (final config in [
    (320.0, Brightness.light),
    (1100.0, Brightness.light),
    (320.0, Brightness.dark),
  ]) {
    testWidgets(
      'adaptive colorful schedule ${config.$1} ${config.$2}',
      (tester) async {
        final sessions = courses();
        await pumpPreview(
          tester,
          Scaffold(
            body: WeekGridView(
              sessions: sessions,
              grid: GridBuilder().buildWeekGrid(
                weekStart: DateTime(2026, 8, 24),
                sessions: sessions,
              ),
            ),
          ),
          width: config.$1,
          brightness: config.$2,
        );
        await expectLater(
          find.byKey(const Key('preview')),
          matchesGoldenFile(
            'goldens/adaptive_${config.$1.toInt()}_${config.$2.name}.png',
          ),
        );
        expect(tester.takeException(), isNull);
      },
      skip: !Platform.isWindows,
    );
  }
  testWidgets('multicolor palette previews', (tester) async {
    await pumpPreview(tester, const ThemeSchemePage(), width: 400);
    await expectLater(
      find.byKey(const Key('preview')),
      matchesGoldenFile('goldens/theme_schemes.png'),
    );
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);
  testWidgets(
    'coordinated presets show distinct light and dark role colors',
    (tester) async {
      await pumpPreview(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              final l = AppLocalizations.of(context)!;
              final names = [
                l.paletteTonalSpot,
                ...l.themeSchemeNames.split('|'),
              ];
              return Column(
                children: [
                  for (final scheme in AppColorScheme.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(names[scheme.index]),
                            ),
                            for (final brightness in Brightness.values)
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final c = MulticolorSettings(
                                      enabled: true,
                                      scheme: scheme,
                                    ).colors(brightness);
                                    return Container(
                                      padding: const EdgeInsets.all(8),
                                      color: c.surface,
                                      child: Row(
                                        children: [
                                          for (final pair in [
                                            (c.primary, c.onPrimary),
                                            (c.secondary, c.onSecondary),
                                            (c.tertiary, c.onTertiary),
                                          ])
                                            Expanded(
                                              child: Container(
                                                margin: const EdgeInsets.all(3),
                                                color: pair.$1,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.check,
                                                    color: pair.$2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        width: 760,
      );
      await expectLater(
        find.byKey(const Key('preview')),
        matchesGoldenFile('goldens/coordinated_presets.png'),
      );
      expect(tester.takeException(), isNull);
    },
    skip: !Platform.isWindows,
  );
  testWidgets('narrow dark multicolor page', (tester) async {
    await pumpPreview(
      tester,
      const ThemeSchemePage(),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byKey(const Key('preview')),
      matchesGoldenFile('goldens/theme_schemes_320_dark.png'),
    );
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);
  testWidgets('narrow English strong scope page', (tester) async {
    await pumpPreview(
      tester,
      const StrongReminderPage(initial: StrongReminderSettings(enabled: true)),
      locale: const Locale('en'),
    );
    await expectLater(
      find.byKey(const Key('preview')),
      matchesGoldenFile('goldens/strong_scope_320.png'),
    );
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);
  testWidgets(
    'reminder template fields use compact top aligned spacing',
    (tester) async {
      final title = TextEditingController(text: '{course} 即将开始');
      final body = TextEditingController(
        text: '请前往 {room}。课程在 {time} 开始，提前 {minutes} 分钟提醒。',
      );
      addTearDown(title.dispose);
      addTearDown(body.dispose);
      await pumpPreview(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('通知消息自定义')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ReminderTemplateField(
                  controller: title,
                  label: '提醒标题',
                  variables: const ['course', 'room', 'time', 'minutes'],
                ),
                ReminderTemplateField(
                  controller: body,
                  label: '提醒正文',
                  multiline: true,
                  variables: const ['course', 'room', 'time', 'minutes'],
                ),
              ],
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const Key('preview')),
        matchesGoldenFile('goldens/reminder_templates.png'),
      );
      expect(tester.takeException(), isNull);
    },
    skip: !Platform.isWindows,
  );
}
