import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/import/import_page.dart';
import 'package:orbit/features/import/import_plan_editor.dart';
import 'package:orbit/features/import/import_template_editor.dart';
import 'package:orbit/features/import/import_templates_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MemoryPicker extends FilePicker {
  MemoryPicker(this.text);
  final String text;
  List<String>? extensions;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    extensions = allowedExtensions;
    final bytes = Uint8List.fromList(utf8.encode(text));
    return FilePickerResult([
      PlatformFile(name: 'courses.csv', size: bytes.length, bytes: bytes),
    ]);
  }
}

class QuietImportReminders extends ReminderSettingsNotifier {
  int resyncs = 0;
  @override
  Future<ReminderSettings> build() async =>
      const ReminderSettings(enabled: false);
  @override
  Future<int> resyncReminders() async {
    resyncs++;
    return 0;
  }
}

Widget app(
  Widget page, {
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: page,
  ),
);
Future<void> tapWorker(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() => tester.tap(finder));
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find
          .descendant(
            of: find.byType(ImportPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'import previews without database writes, errors require explicit skip, edits invalidate preview',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('orbit_import_workflow_'),
      ))!;
      final database = (await tester.runAsync(
        () => AppDatabase.open(directory.path),
      ))!;
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final picker = MemoryPicker(
        'course,date,start,end\nMath,2026-09-14,08:00,09:00\nPhysics,2026-02-30,10:00,11:00',
      );
      FilePicker.platform = picker;
      final reminders = QuietImportReminders();
      await tester.pumpWidget(
        app(
          const ImportPage(),
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            reminderSettingsProvider.overrideWith(() => reminders),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Select XLSX / CSV schedule files'));
      await tapWorker(tester, find.text('Select XLSX / CSV schedule files'));
      expect(picker.extensions, ['xlsx', 'csv']);
      expect(
        find.textContaining('courses.csv'),
        findsWidgets,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('\n'),
      );
      await reveal(tester, find.text('Parse & preview'));
      await tapWorker(tester, find.text('Parse & preview'));
      expect(await tester.runAsync(database.getAllSessions), isEmpty);
      final confirm = find.widgetWithText(FilledButton, 'Confirm import');
      await reveal(tester, confirm);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.ensureVisible(find.text('Explicitly skip failed courses'));
      await tester.tap(find.text('Explicitly skip failed courses'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      final selection = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile).first,
      );
      expect(selection.value, isTrue);
      selection.onChanged!(false);
      await tester.pumpAndSettle();
      expect(confirm, findsNothing);
      expect(await tester.runAsync(database.getAllSessions), isEmpty);
      selection.onChanged!(true);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Parse & preview'));
      await tapWorker(tester, find.text('Parse & preview'));
      await reveal(tester, find.text('Explicitly skip failed courses'));
      await tester.tap(find.text('Explicitly skip failed courses'));
      await tester.pumpAndSettle();
      await reveal(tester, confirm);
      await tapWorker(tester, confirm);
      final imported = await tester.runAsync(database.getAllSessions);
      expect(imported, hasLength(1));
      expect(imported!.single.courseName, 'Math');
      expect(reminders.resyncs, 1);
    },
  );
  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'import and editors fit 320dp ${locale.toLanguageTag()} with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final page in [
          const ImportPage(),
          const ImportTemplatesPage(),
          const ImportPlansPage(),
          const ImportTemplateEditor(),
        ]) {
          await tester.pumpWidget(
            app(
              MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 820),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: page,
              ),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  testWidgets(
    'template editing keeps input focus and persists numeric/named rules',
    (tester) async {
      const template = ScheduleImportTemplate(
        id: 'custom',
        name: 'School',
        layout: ImportLayout.list,
        fields: {
          ImportField.courseName: FieldMapping(
            column: 0,
            regex: RegexRule(pattern: '(Math)', group: '1'),
          ),
          ImportField.date: FieldMapping(column: 1),
          ImportField.startTime: FieldMapping(column: 2),
          ImportField.endTime: FieldMapping(column: 3),
        },
      );
      await tester.pumpWidget(
        app(const ImportTemplateEditor(template: template)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Course name'));
      await tester.pumpAndSettle();
      final pattern = find.widgetWithText(
        TextField,
        'Regular expression (blank = original)',
      );
      await tester.enterText(pattern, r'(?<name>Math)');
      await tester.pump();
      expect(
        tester.widget<TextField>(pattern).controller!.text,
        r'(?<name>Math)',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('context rejects unconfirmed or non-Monday dates', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Scaffold(body: ImportContextDialog())));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Semester name'),
      'Fall',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'First week Monday (YYYY-MM-DD)'),
      '2026-09-15',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Check semester name, Monday date and total weeks.'),
      findsOneWidget,
    );
  });
}
