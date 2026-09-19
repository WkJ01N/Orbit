import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/services/schedule_import_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final encoding in ['utf-8', 'gbk', 'gb18030', 'auto']) {
    testWidgets(
      'native CSV $encoding decodes Chinese and keeps course fields',
      (tester) async {
        final prefix = utf8.encode('course,date,start,end\n');
        final suffix = utf8.encode(',2026-09-14,08:00,09:00');
        final name = encoding == 'utf-8'
            ? utf8.encode('数学')
            : encoding == 'gbk'
            ? [202, 253, 209, 167]
            : [202, 253, 209, 167, 149, 50, 130, 54];
        final bytes = [...prefix, ...name, ...suffix];
        final read = await ScheduleImportService().readFile(
          bytes,
          'encoding.csv',
          encoding: encoding,
        );
        final sheet = read.sheets.single;
        expect(
          sheet.cell(1, 0),
          encoding == 'gb18030' || encoding == 'auto' ? '数学𠀀' : '数学',
        );
        final result = await createSheetWorker(
          sheet,
          ScheduleImportService.candidates(sheet, []).single,
          const ImportContext(),
        ).run();
        expect(result.diagnostics, isEmpty);
        expect(result.sessions, hasLength(1));
      },
    );
  }
}
