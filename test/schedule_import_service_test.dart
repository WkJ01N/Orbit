import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/services/schedule_import_service.dart';
import 'xlsx_test_fixtures.dart';

ImportSheet csvSheet(String text) =>
    ScheduleImportService.readCsv(text, 'test.csv').single;
ScheduleParseResult parseList(String text) =>
    ScheduleImportService().parseSheet(
      csvSheet(text),
      const ScheduleImportTemplate(
        id: 'list',
        name: 'list',
        layout: ImportLayout.list,
      ),
    );
ImportContext weeklyContext({Set<int> defaults = const {}}) => ImportContext(
  confirmed: true,
  semester: SemesterPlan(
    id: 'fall',
    name: 'Fall',
    firstWeekMonday: DateTime(2026, 9, 14),
    totalWeeks: 18,
  ),
  periodTimes: const PeriodTimePlan(
    id: 'times',
    name: 'Times',
    periods: [
      PeriodTime(number: 1, startMinute: 480, endMinute: 525),
      PeriodTime(number: 2, startMinute: 535, endMinute: 580),
      PeriodTime(number: 3, startMinute: 600, endMinute: 645),
      PeriodTime(number: 4, startMinute: 655, endMinute: 700),
    ],
  ),
  defaultWeeks: defaults,
);

void main() {
  test('reordered list columns, extras and Sunday are recognized', () {
    final result = parseList(
      'Extra,Room,End Time,Course Name,Date,Start Time,Teachers\nX,A101,10:00,Physics,2026-09-20,08:00,"Alice,Bob"',
    );
    expect(result.diagnostics, isEmpty);
    expect(result.sessions, hasLength(1));
    expect(result.sessions.single.weekday, 7);
    expect(result.sessions.single.teachers, ['Alice', 'Bob']);
  });
  test('traditional headers and native dates work', () {
    final result = parseList('課程名稱,日期,開始時間,結束時間\n數學,2026年9月14日,08:00,09:00');
    expect(result.diagnostics, isEmpty);
    expect(result.sessions.single.courseName, '數學');
  });
  test('CSV BOM, quotes, embedded newline and leading zero stay intact', () {
    final sheet = csvSheet(
      '\uFEFFcourse,date,start,end,code,room\r\n"Math\nAdvanced",2026-09-14,08:00,09:00,001,"A ""101"""',
    );
    expect(sheet.cell(1, 0), 'Math\nAdvanced');
    expect(sheet.cell(1, 4), '001');
    expect(sheet.cell(1, 5), 'A "101"');
  });
  test(
    'CSV automatically detects semicolon and tab and preserves row numbers',
    () {
      for (final delimiter in [';', '\t']) {
        final sheet = csvSheet(
          'course${delimiter}date${delimiter}start${delimiter}end\n\nMath${delimiter}2026-09-14${delimiter}08:00${delimiter}09:00',
        );
        expect(sheet.cell(2, 0), 'Math');
      }
    },
  );
  test('explicit CSV delimiter overrides auto-detection', () {
    final sheet = ScheduleImportService.readCsv(
      'a;b;c\n1;2;3',
      't.csv',
      delimiter: ',',
    ).single;
    expect(sheet.columnCount, 1);
  });
  test('stable generated codes distinguish unnamed code courses', () {
    const text =
        'course,date,start,end\nMath,2026-09-14,08:00,09:00\nPhysics,2026-09-14,08:00,09:00';
    final a = parseList(text), b = parseList(text);
    expect(a.sessions.map((s) => s.id), b.sessions.map((s) => s.id));
    expect(a.sessions.map((s) => s.courseCode).toSet(), hasLength(2));
  });
  test(
    'duplicates removed and conflicting IDs excluded without arbitrary overwrite',
    () {
      final result = parseList(
        'course,date,start,end,code,room\nMath,2026-09-14,08:00,09:00,M,A\nMath,2026-09-14,08:00,09:00,M,A\nMath,2026-09-14,08:00,09:00,M,B\nPhysics,2026-09-14,10:00,11:00,P,C',
      );
      expect(result.duplicates, 1);
      expect(result.diagnostics.single.code, 'idConflict');
      expect(result.sessions.single.courseName, 'Physics');
    },
  );
  test('invalid calendar dates and overflowing/reversed times are located', () {
    final result = parseList(
      'course,date,start,end\nMath,2026-02-30,08:00,09:00\nMath,2026-09-14,24:00,25:00\nMath,2026-09-14,10:00,09:00\nMath,2026-09-14,08:00,09:00',
    );
    expect(result.sessions, hasLength(1));
    expect(result.diagnostics, hasLength(3));
    expect(result.diagnostics.first.row, 1);
    expect(result.diagnostics.first.file, 'test.csv');
  });
  test('week expressions handle intervals, discrete weeks and parity', () {
    expect(parseWeeks('第1-6周(单周),9,11', 18), [1, 3, 5, 9, 11]);
    expect(parseWeeks('2、4、6-8週（雙週）', 18), [2, 4, 6, 8]);
    expect(() => parseWeeks('单双周', 18), throwsFormatException);
    expect(() => parseWeeks('1-19', 18), throwsFormatException);
  });
  test('weekly list expands Sunday and keeps stable series identifiers', () {
    final sheet = csvSheet('course,weekday,weeks,periods\nMath,Sunday,1,1-2');
    const template = ScheduleImportTemplate(
      id: 'list',
      name: 'list',
      layout: ImportLayout.list,
    );
    final a = ScheduleImportService().parseSheet(
      sheet,
      template,
      context: weeklyContext(),
    );
    final b = ScheduleImportService().parseSheet(
      sheet,
      template,
      context: weeklyContext(),
    );
    expect(a.diagnostics, isEmpty);
    expect(a.sessions.single.date, DateTime(2026, 9, 20));
    expect(a.sessions.single.endAt.hour, 9);
    expect(a.sessions.single.endAt.minute, 40);
    expect(
      a.sessions.single.recurrenceSeriesId,
      b.sessions.single.recurrenceSeriesId,
    );
    expect(a.sessions.single.recurrenceMeetingId, isNotNull);
  });
  test('missing weeks and missing period mappings require user action', () {
    const template = ScheduleImportTemplate(
      id: 'list',
      name: 'list',
      layout: ImportLayout.list,
    );
    final service = ScheduleImportService();
    final sheet = csvSheet('course,weekday,periods\nMath,1,1-2');
    expect(
      service.parseSheet(sheet, template).diagnostics.single.code,
      'contextRequired',
    );
    expect(
      service
          .parseSheet(sheet, template, context: weeklyContext())
          .diagnostics
          .single
          .code,
      'weeksRequired',
    );
    expect(
      service
          .parseSheet(sheet, template, context: weeklyContext(defaults: {1, 3}))
          .sessions,
      hasLength(2),
    );
    final unknown = csvSheet('course,weekday,periods,weeks\nMath,1,1-5,1');
    expect(
      service
          .parseSheet(unknown, template, context: weeklyContext())
          .diagnostics
          .single
          .code,
      'unknownPeriod',
    );
  });
  test('merged grid cells read anchor once and span all covered periods', () {
    final sheet = ImportSheet(
      file: 'grid.xlsx',
      name: 'Grid',
      rows: [
        ['', '周一', '周二', '周三', '周四', '周五'],
        ['1', '数学\n教师：张老师\n教室：A101\n周次：1-2', '', '', '', ''],
        ['2', '', '', '', '', ''],
      ],
      merges: const [MergedRegion(1, 2, 1, 1)],
    );
    final t = ScheduleImportService.candidates(sheet, []).single;
    final result = ScheduleImportService().parseSheet(
      sheet,
      t,
      context: weeklyContext(),
    );
    expect(result.diagnostics, isEmpty);
    expect(result.sessions, hasLength(2));
    expect(result.sessions.first.endAt, DateTime(2026, 9, 14, 9, 40));
  });
  test('one grid cell can contain courses with different weeks', () {
    final sheet = ImportSheet(
      file: 'g.xlsx',
      name: 'Grid',
      rows: [
        ['', '周一'],
        ['1-2', '数学\n周次：1-4(单周)\n\n物理\n周次：1-4(双周)'],
      ],
    );
    final t = ScheduleImportService.basicGrid.copyWithCoordinates(
      firstRow: 1,
      firstColumn: 1,
      lastColumn: 1,
      weekdayColumns: {1: 1},
      periodRows: {
        1: [1, 2],
      },
    );
    final result = ScheduleImportService().parseSheet(
      sheet,
      t,
      context: weeklyContext(),
    );
    expect(result.diagnostics, isEmpty);
    expect(result.sessions, hasLength(4));
    expect(result.sessions.map((s) => s.courseName), ['数学', '物理', '数学', '物理']);
  });
  test('horizontal course merge produces positioned error', () {
    final sheet = ImportSheet(
      file: 'g.xlsx',
      name: 'Grid',
      rows: [
        ['', '周一', '周二'],
        ['1', 'Math', ''],
      ],
      merges: const [MergedRegion(1, 1, 1, 2)],
    );
    final t = ScheduleImportService.basicGrid.copyWithCoordinates(
      firstRow: 1,
      firstColumn: 1,
      lastColumn: 2,
      weekdayColumns: {1: 1, 2: 2},
      periodRows: {
        1: [1],
      },
    );
    final result = ScheduleImportService().parseSheet(
      sheet,
      t,
      context: weeklyContext(),
    );
    expect(result.diagnostics.single.code, 'horizontalMerge');
    expect(result.diagnostics.single.location, contains('B2'));
  });
  test('all worksheets and native Excel time/date cells preserved', () {
    final book = Excel.createExcel();
    book['Data'].appendRow([
      TextCellValue('course'),
      TextCellValue('date'),
      TextCellValue('start'),
      TextCellValue('end'),
    ]);
    book['Data'].appendRow([
      TextCellValue('Math'),
      DateCellValue(year: 2026, month: 9, day: 14),
      TimeCellValue(hour: 8, minute: 0),
      TimeCellValue(hour: 9, minute: 0),
    ]);
    final sheets = ScheduleImportService.readXlsx(book.encode()!, 'multi.xlsx');
    expect(sheets, hasLength(2));
    final data = sheets.singleWhere((s) => s.name == 'Data');
    expect(
      ScheduleImportService()
          .parseSheet(data, ScheduleImportService.candidates(data, []).single)
          .diagnostics,
      isEmpty,
    );
  });
  test('legacy adapter and compatibility output retain original IDs', () {
    final sheet = ScheduleImportService.readXlsx(
      weekOneFixture(),
      'old.xlsx',
    ).first;
    final candidates = ScheduleImportService.candidates(sheet, []);
    expect(candidates.single.layout, ImportLayout.legacy);
    final result = ScheduleImportService().parseSheet(sheet, candidates.single);
    expect(result.sessions, hasLength(3));
    expect(result.sessions.first.courseCode, 'PHYS102');
  });
  test('numeric and named captures and repeat rule tested in worker', () async {
    const rule = RegexRule(pattern: r'(?<name>\w+)=(\d+)', group: 'name');
    final result = await createRegexWorker(
      rule,
      'Math=1 Physics=2',
      repeat: true,
    ).run();
    expect(result.captures, ['Math', 'Physics']);
    expect(result.groups.first['2'], '1');
    expect(
      () => testRegex(const RegexRule(pattern: 'x', group: 'missing'), 'x'),
      throwsFormatException,
    );
    expect(
      () => testRegex(const RegexRule(pattern: r'.*'), 'x', repeat: true),
      throwsFormatException,
    );
  });
  test('background sheet and file workers return results', () async {
    final read = await ScheduleImportService().readFile(
      utf8.encode('course,date,start,end\nMath,2026-09-14,08:00,09:00'),
      't.csv',
    );
    final sheet = read.sheets.single;
    final candidates = await createCandidateWorker(sheet, []).run();
    final result = await createSheetWorker(
      sheet,
      candidates.single,
      const ImportContext(),
    ).run();
    expect(result.sessions, hasLength(1));
  });
  test(
    'catastrophic regex worker times out and subsequent work still succeeds',
    () async {
      final worker = ImportWorker(
        () => testRegex(
          const RegexRule(pattern: r'^(a+)+$'),
          '${List.filled(5000, 'a').join()}!',
        ),
        timeout: const Duration(milliseconds: 100),
      );
      await expectLater(
        worker.run(),
        throwsA(
          isA<FormatException>().having((e) => e.message, 'code', 'timeout'),
        ),
      );
      final result = await createRegexWorker(
        const RegexRule(pattern: 'Math'),
        'Math',
      ).run();
      expect(result.captures, ['Math']);
    },
  );
  test('active worker cancellation terminates without result', () async {
    final worker = ImportWorker(
      () => testRegex(
        const RegexRule(pattern: r'^(a+)+$'),
        '${List.filled(5000, 'a').join()}!',
      ),
    );
    final future = worker.run();
    worker.cancel();
    await expectLater(
      future,
      throwsA(
        isA<FormatException>().having((e) => e.message, 'code', 'cancelled'),
      ),
    );
  });
}
