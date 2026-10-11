import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/deadline/deadline_strong_host.dart';
import 'package:orbit/features/deadline/deadline_ui.dart';
import 'package:orbit/features/grid/grid_week_view.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/grid_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Time extends CurrentTimeNotifier {
  @override
  DateTime build() => DateTime(2026, 11, 2, 9);
}

class _Display extends ScheduleDisplaySettingsNotifier {
  @override
  ScheduleDisplaySettings build() => const ScheduleDisplaySettings();
}

class _DB implements AppDatabase {
  @override
  Future<List<Deadline>> getDeadlines({bool includeDeleted = false}) async =>
      _deadlines;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _deadlines = [
  Deadline(
    id: 'strong',
    subject: '算法设计',
    title: '提交课程设计',
    dueAt: DateTime(2026, 11, 3, 23, 59),
    leadMinutes: const [1440, 180, 60],
    strongReminderEnabled: true,
    strongLeadMinutes: const [180, 60],
  ),
  Deadline(
    id: 'normal',
    subject: '数学',
    title: '本周作业',
    dueAt: DateTime(2026, 11, 4, 23, 59),
    leadMinutes: const [1440, 60],
  ),
];
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (!Platform.isWindows) return;
    final font = FontLoader('OrbitPreview');
    font.addFont(
      Future.value(
        ByteData.sublistView(
          await File('C:/Windows/Fonts/simhei.ttf').readAsBytes(),
        ),
      ),
    );
    await font.load();
    final icons = FontLoader('MaterialIcons');
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    icons.addFont(
      Future.value(
        ByteData.sublistView(
          await File(
            '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes(),
        ),
      ),
    );
    await icons.load();
  });
  for (final scene in ['editor', 'grid', 'manage', 'details']) {
    testWidgets('DDL strong visual $scene', (tester) async {
      if (!Platform.isWindows) return;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final theme = scene == 'grid' ? AppTheme.dark() : AppTheme.light();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(_DB()),
            sessionsProvider.overrideWith((_) async => []),
            deadlinesProvider.overrideWith((_) async => _deadlines),
            strongCourseIdsProvider.overrideWith((_) async => {}),
            currentTimeProvider.overrideWith(_Time.new),
            scheduleDisplaySettingsProvider.overrideWith(_Display.new),
            selectedScheduleDateProvider.overrideWith(
              (_) => DateTime(2026, 11, 2),
            ),
          ],
          child: MaterialApp(
            locale: const Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
            ),
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'OrbitPreview'),
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (c, child) => RepaintBoundary(
              key: const Key('ddl-preview'),
              child: MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(1.25)),
                child: child!,
              ),
            ),
            home: scene == 'grid'
                ? Scaffold(
                    body: WeekGridView(
                      grid: GridBuilder().buildWeekGrid(
                        weekStart: DateTime(2026, 11, 2),
                        sessions: [],
                      ),
                    ),
                  )
                : Builder(
                    builder: (c) => Scaffold(
                      body: Center(
                        child: FilledButton(
                          onPressed: () {
                            if (scene == 'editor') {
                              showDeadlineEditor(c, deadline: _deadlines.first);
                            } else if (scene == 'details') {
                              showDeadlineDetails(c, _deadlines.first);
                            } else {
                              showDeadlineReminderManagement(c, [
                                {
                                  'id': 'receipt',
                                  'deadlineId': 'strong',
                                  'leadMinutes': 1440,
                                },
                              ]);
                            }
                          },
                          child: const Text('打开'),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scene != 'grid') {
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
      }
      if (scene == 'editor') {
        await tester.ensureVisible(
          find.byKey(const Key('deadline-strong-enabled')),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('ddl-preview')),
        matchesGoldenFile('goldens/ddl_strong_$scene.png'),
      );
    });
  }
}
