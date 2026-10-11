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
import 'package:orbit/features/grid/strong_grid_decoration.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/models/wake_text.dart';
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
  _FitSettings([this.gradient = StrongCardGradient.upperHalf]);
  final StrongCardGradient gradient;
  @override
  ScheduleDisplaySettings build() =>
      ScheduleDisplaySettings(fitToPage: true, strongCardGradient: gradient);
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
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool strong = false,
  StrongCardGradient gradient = StrongCardGradient.upperHalf,
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
        strongCourseIdsProvider.overrideWith(
          (_) async => strong ? sessions.map((s) => s.id).toSet() : <String>{},
        ),
        scheduleDisplaySettingsProvider.overrideWith(
          () => _FitSettings(gradient),
        ),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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
  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    for (final brightness in Brightness.values) {
      for (final width in [240.0, 320.0, 1000.0]) {
        testWidgets('full width danger action $locale $brightness $width', (
          tester,
        ) async {
          await pumpPreview(
            tester,
            Scaffold(body: SessionDetailSheet(session: courses().first)),
            textScale: 1.7,
            width: width,
            brightness: brightness,
            locale: locale,
          );
          final button = find.ancestor(
            of: find.byIcon(Icons.delete_outline),
            matching: find.byType(OutlinedButton),
          );
          final rect = tester.getRect(button);
          expect(rect.width, closeTo(width - 40, 0.1));
          expect(rect.height, greaterThanOrEqualTo(48));
          for (final regular in [
            Icons.edit_outlined,
            Icons.palette_outlined,
            Icons.sticky_note_2_outlined,
            Icons.archive_outlined,
          ]) {
            final regularButton = find.ancestor(
              of: find.byIcon(regular),
              matching: find.byType(OutlinedButton),
            );
            expect(rect.top, greaterThan(tester.getRect(regularButton).bottom));
          }
          final theme = Theme.of(tester.element(button));
          final style = tester.widget<OutlinedButton>(button).style!;
          expect(style.foregroundColor!.resolve({}), theme.colorScheme.error);
          expect(
            style.backgroundColor!.resolve({}),
            theme.colorScheme.error.withValues(alpha: 0.06),
          );
          if (Platform.isWindows &&
              locale.languageCode == 'zh' &&
              locale.scriptCode == 'Hans' &&
              width == 320) {
            await expectLater(
              find.byKey(const Key('preview')),
              matchesGoldenFile(
                'goldens/course_detail_delete_${brightness.name}.png',
              ),
            );
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
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
  testWidgets('mixed challenge settings preview', (tester) async {
    await pumpPreview(
      tester,
      const StrongReminderPage(
        showTargets: false,
        initial: StrongReminderSettings(
          dismissTask: StrongDismissTask.mixed,
          sequenceNumberCount: 25,
          arithmeticDifficulty: ArithmeticDifficulty.hard,
          arithmeticAnswerMode: ArithmeticAnswerMode.choice6,
        ),
      ),
      width: 400,
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byKey(const Key('preview')),
      matchesGoldenFile('goldens/strong_mixed_settings.png'),
    );
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);
  for (final sequence in [true, false]) {
    testWidgets(
      'mixed challenge ${sequence ? 'numbers' : 'choices'} preview',
      (tester) async {
        final state = <String, dynamic>{
          'id': 'preview',
          'phase': 'task',
          'expiresAt': DateTime(2030).millisecondsSinceEpoch,
          'answerDeadline': DateTime(2030).millisecondsSinceEpoch,
          'records': [],
          'taskIndex': 1,
          'taskProgress': 0,
          'tasks': [
            {
              'type': 'arithmetic',
              'a': 32,
              'b': 9,
              'operator': 'multiply',
              'choices': [],
            },
            sequence
                ? {
                    'type': 'sequence',
                    'numberCount': 25,
                    'numbers': [
                      15,
                      9,
                      2,
                      20,
                      25,
                      1,
                      10,
                      11,
                      5,
                      24,
                      13,
                      12,
                      16,
                      19,
                      6,
                      21,
                      23,
                      3,
                      7,
                      18,
                      4,
                      8,
                      14,
                      22,
                      17,
                    ],
                  }
                : {
                    'type': 'arithmetic',
                    'a': 96,
                    'b': 87,
                    'operator': 'multiply',
                    'choices': [8351, 8325, 8352, 8412, 8132, 8353],
                  },
          ],
        };
        await pumpPreview(
          tester,
          ProviderScope(
            overrides: [strongSessionProvider.overrideWith((_) => state)],
            child: const StrongConfirmationPage(),
          ),
          width: 400,
          brightness: Brightness.dark,
        );
        await expectLater(
          find.byKey(const Key('preview')),
          matchesGoldenFile(
            'goldens/strong_mixed_${sequence ? 'numbers' : 'choices'}.png',
          ),
        );
        expect(tester.takeException(), isNull);
      },
      skip: !Platform.isWindows,
    );
  }
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
  for (final width in [320.0, 1100.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'strong colorful preview $width ${brightness.name}',
        (tester) async {
          final sessions = courses();
          await pumpPreview(
            tester,
            Scaffold(
              body: WeekGridView(
                grid: GridBuilder().buildWeekGrid(
                  weekStart: DateTime(2026, 8, 24),
                  sessions: sessions,
                ),
                sessions: sessions,
              ),
            ),
            width: width,
            brightness: brightness,
            strong: true,
          );
          await expectLater(
            find.byKey(const Key('preview')),
            matchesGoldenFile(
              'goldens/strong_colorful_${width.toInt()}_${brightness.name}.png',
            ),
          );
          // The indicator and background resolve the same automatic palette as
          // the course's own colored strip, rather than introducing a new color.
          final chip = find.byType(GridSessionChip).first;
          final strip = tester.widget<Container>(
            find
                .descendant(
                  of: chip,
                  matching: find.byWidgetPredicate(
                    (w) => w is Container && w.color != null,
                  ),
                )
                .first,
          );
          final accent = strip.color!.withAlpha(255);
          final ink = tester.widget<Ink>(
            find.descendant(of: chip, matching: find.byType(Ink)).first,
          );
          final gradient =
              (ink.decoration! as BoxDecoration).gradient! as LinearGradient;
          final material = tester.widget<Material>(
            find.descendant(of: chip, matching: find.byType(Material)).first,
          );
          expect(
            gradient.colors.first,
            Color.alphaBlend(
              strongGridHighlight(accent).withValues(alpha: .25),
              material.color!,
            ),
          );
          final session = tester.widget<GridSessionChip>(chip).session;
          final bell = find.byKey(ValueKey('grid-strong-bell-${session.id}'));
          final icon = tester.widget<Icon>(
            find.descendant(of: bell, matching: find.byType(Icon)),
          );
          expect(icon.color, strongGridHighlight(accent));
          expect(
            find.descendant(
              of: chip,
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.color == accent.withAlpha(100),
              ),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
        skip: !Platform.isWindows,
      );
    }
  }

  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'selected ongoing strong card retains its border and ${locale.toLanguageTag()} semantics',
      (tester) async {
        final session = courses().first.copyWith(
          startAt: DateTime(2026, 8, 24, 11),
          endAt: DateTime(2026, 8, 24, 13),
        );
        await pumpPreview(
          tester,
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 170,
                height: 100,
                child: Builder(
                  builder: (context) => GridSessionChip(
                    session: session,
                    colorScheme: Theme.of(context).colorScheme,
                    l10n: AppLocalizations.of(context)!,
                    isSelected: true,
                    onTap: () {},
                    onMenu: (_) {},
                  ),
                ),
              ),
            ),
          ),
          strong: true,
          locale: locale,
        );
        final chip = find.byType(GridSessionChip);
        final shape =
            tester
                    .widget<Material>(
                      find
                          .descendant(of: chip, matching: find.byType(Material))
                          .first,
                    )
                    .shape!
                as RoundedRectangleBorder;
        expect(shape.side.width, 2);
        expect(
          shape.side.color,
          Theme.of(tester.element(chip)).colorScheme.primary,
        );
        final semantics = tester.widget<Semantics>(
          find.descendant(of: chip, matching: find.byType(Semantics)).first,
        );
        expect(
          semantics.properties.label,
          contains(WakeText.of(tester.element(chip)).strong),
        );
        expect(find.text('11:00 - 13:00'), findsOneWidget);
        expect(
          find.descendant(of: chip, matching: find.byType(StrongCourseBadge)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final extent in [
    StrongCardGradient.fullCard,
    StrongCardGradient.topQuarter,
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'strong gradient extent ${extent.name} ${brightness.name}',
        (tester) async {
          final sessions = courses();
          await pumpPreview(
            tester,
            Scaffold(
              body: WeekGridView(
                grid: GridBuilder().buildWeekGrid(
                  weekStart: DateTime(2026, 8, 24),
                  sessions: sessions,
                ),
                sessions: sessions,
              ),
            ),
            width: 320,
            brightness: brightness,
            strong: true,
            gradient: extent,
          );
          await expectLater(
            find.byKey(const Key('preview')),
            matchesGoldenFile(
              'goldens/strong_gradient_${extent.name}_${brightness.name}.png',
            ),
          );
          expect(tester.takeException(), isNull);
        },
        skip: !Platform.isWindows,
      );
    }
  }
}
