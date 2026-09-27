import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'package:orbit/services/course_import_identity.dart';

void _workerEntry((SendPort, Object? Function()) message) {
  try {
    message.$1.send(['ok', message.$2()]);
  } catch (e) {
    message.$1.send(['error', e is FormatException ? e.message : '$e']);
  }
}

/// A cancellable worker. Killing the isolate also stops synchronous RegExp work.
class ImportWorker<T> {
  ImportWorker(this.operation, {this.timeout = const Duration(seconds: 30)});
  final T Function() operation;
  final Duration timeout;
  final _result = Completer<T>();
  Isolate? _isolate;
  ReceivePort? _port;
  Timer? _timer;
  bool _started = false;
  Future<T> run() {
    if (!_started && !_result.isCompleted) {
      _started = true;
      _start();
    }
    return _result.future;
  }

  Future<void> _start() async {
    final port = _port = ReceivePort();
    port.listen((message) {
      if (_result.isCompleted) return;
      if (message is List && message.length == 2 && message.first == 'ok') {
        _result.complete(message[1] as T);
      } else if (message is List &&
          message.length == 2 &&
          message.first == 'error') {
        _result.completeError(FormatException(message[1] as String));
      } else if (message == null) {
        _result.completeError(const FormatException('workerFailed'));
      } else {
        _result.completeError(const FormatException('workerFailed'));
      }
      _dispose();
    });
    _timer = Timer(timeout, () => _fail('timeout'));
    final sender = port.sendPort;
    final task = operation;
    try {
      final worker = await Isolate.spawn(
        _workerEntry,
        (sender, task),
        onError: sender,
        onExit: sender,
      );
      if (_result.isCompleted) {
        worker.kill(priority: Isolate.immediate);
      } else {
        _isolate = worker;
      }
    } catch (e) {
      if (!_result.isCompleted) _result.completeError(e);
      _dispose();
    }
  }

  void cancel() => _fail('cancelled');
  void _fail(String code) {
    if (!_result.isCompleted) _result.completeError(FormatException(code));
    _dispose();
  }

  void _dispose() {
    _timer?.cancel();
    _port?.close();
    _isolate?.kill(priority: Isolate.immediate);
  }
}

class RegexTestResult {
  const RegexTestResult(this.matches, this.captures, this.groups);
  final List<String> matches;
  final List<String> captures;
  final List<Map<String, String?>> groups;
}

class _RecognitionDraft {
  const _RecognitionDraft(this.template, this.structuralScore, this.evidence);
  final ScheduleImportTemplate template;
  final double structuralScore;
  final List<RecognitionEvidence> evidence;
}

ImportWorker<RegexTestResult> createRegexWorker(
  RegexRule rule,
  String text, {
  bool repeat = false,
}) => ImportWorker(
  () => testRegex(rule, text, repeat: repeat),
  timeout: const Duration(seconds: 2),
);
ImportWorker<ScheduleParseResult> createSheetWorker(
  ImportSheet sheet,
  ScheduleImportTemplate template,
  ImportContext context,
) => ImportWorker(
  () => ScheduleImportService().parseSheet(sheet, template, context: context),
);
ImportWorker<RecognitionAnalysis> createCandidateWorker(
  ImportSheet sheet,
  List<ScheduleImportTemplate> templates,
) => ImportWorker(() => ScheduleImportService.analyze(sheet, templates));
ImportWorker<List<ImportSheet>> createFileWorker(
  List<int> bytes,
  String file,
  String? decoded,
  String delimiter,
) => ImportWorker(
  () => decoded == null
      ? ScheduleImportService.readXlsx(bytes, file)
      : ScheduleImportService.readCsv(decoded, file, delimiter: delimiter),
);

RegexTestResult testRegex(RegexRule rule, String text, {bool repeat = false}) {
  rule.validate();
  final matches = rule
      .compile()
      .allMatches(text)
      .take(repeat ? 100 : 1)
      .toList();
  if (matches.any((m) => m.start == m.end)) {
    throw const FormatException('zeroLength');
  }
  return RegexTestResult(
    matches.map((m) => m.group(0)!).toList(),
    matches.map(rule.capture).toList(),
    matches
        .map(
          (m) => <String, String?>{
            for (var i = 0; i <= m.groupCount; i++) '$i': m.group(i),
            for (final name in m.groupNames) name: m.namedGroup(name),
          },
        )
        .toList(),
  );
}

class ScheduleImportService {
  Future<({List<ImportSheet> sheets, String encoding})> readFile(
    List<int> bytes,
    String file, {
    String encoding = 'auto',
    String delimiter = '',
    void Function(ImportWorker<List<ImportSheet>> worker)? onWorker,
  }) async {
    final lower = file.toLowerCase();
    if (!lower.endsWith('.xlsx') && !lower.endsWith('.csv')) {
      throw const FormatException('unsupportedFile');
    }
    String? decoded;
    var used = encoding;
    if (lower.endsWith('.csv')) {
      if (encoding == 'auto' || encoding == 'utf-8') {
        try {
          decoded = utf8.decode(bytes);
          used = 'utf-8';
        } on FormatException {
          if (encoding != 'auto') throw const FormatException('encodingFailed');
        }
      }
      if (decoded == null) {
        used = encoding == 'auto' ? 'gb18030' : encoding;
        try {
          final platformEncoding = Platform.isWindows && used == 'gbk'
              ? 'gb2312'
              : used;
          decoded = await CharsetConverter.decode(
            platformEncoding,
            Uint8List.fromList(bytes),
          );
        } catch (_) {
          throw const FormatException('encodingFailed');
        }
        if (decoded.contains('\uFFFD')) {
          throw const FormatException('encodingFailed');
        }
      }
    }
    final worker = createFileWorker(bytes, file, decoded, delimiter);
    onWorker?.call(worker);
    return (
      sheets: await worker.run(),
      encoding: lower.endsWith('.csv') ? used : '',
    );
  }

  static List<ImportSheet> readXlsx(List<int> bytes, String file) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) throw const FormatException('noSheet');
    return workbook.tables.entries.map((entry) {
      final sheet = entry.value;
      final merges = sheet.spannedItems.map((span) {
        final cells = span.split(':');
        final first = CellIndex.indexByString(cells.first);
        final last = CellIndex.indexByString(cells.last);
        return MergedRegion(
          first.rowIndex,
          last.rowIndex,
          first.columnIndex,
          last.columnIndex,
        );
      }).toList();
      return ImportSheet(
        file: file,
        name: entry.key,
        merges: merges,
        rows: sheet.rows
            .map(
              (row) =>
                  row.map((cell) => XlsxParser.cellText(cell?.value)).toList(),
            )
            .toList(),
      );
    }).toList();
  }

  static List<ImportSheet> readCsv(
    String text,
    String file, {
    String delimiter = '',
  }) {
    final input = text.startsWith('\uFEFF') ? text.substring(1) : text;
    final rows = Csv(
      fieldDelimiter: delimiter.isEmpty ? ',' : delimiter,
      autoDetect: delimiter.isEmpty,
      skipEmptyLines: false,
      dynamicTyping: false,
    ).decode(input);
    return [
      ImportSheet(
        file: file,
        name: 'CSV',
        rows: rows.map((r) => r.map((v) => '$v').toList()).toList(),
      ),
    ];
  }

  static const aliases = <ImportField, List<String>>{
    ImportField.courseName: [
      '课程名称',
      '課程名稱',
      '科目名称',
      '科目名稱',
      '课程',
      '課程',
      '科目',
      '课程名',
      '課程名',
      '教学课程',
      '教學課程',
      'course',
      'coursename',
      'subject',
    ],
    ImportField.courseCode: [
      '课程编号',
      '課程編號',
      '科目编号',
      '科目編號',
      '课程代码',
      '課程代碼',
      '课程号',
      '課程號',
      '课程序号',
      '課程序號',
      '编号',
      '編號',
      'coursecode',
      'code',
    ],
    ImportField.section: [
      '班别名称',
      '班別名稱',
      '班别',
      '班別',
      '教学班',
      '教學班',
      '教学班名称',
      '教學班名稱',
      '班级',
      '班級',
      'section',
      'class',
    ],
    ImportField.room: [
      '课室',
      '課室',
      '教室',
      '上课地点',
      '上課地點',
      '上课教室',
      '上課教室',
      '地点',
      '地點',
      'room',
      'location',
    ],
    ImportField.teachers: [
      '教师',
      '教師',
      '老师',
      '老師',
      '任课教师',
      '任課教師',
      '授课教师',
      '授課教師',
      'teacher',
      'teachers',
      'instructor',
    ],
    ImportField.faculty: ['学院名称', '學院名稱', '学院', '學院', 'faculty', 'department'],
    ImportField.classType: ['课堂类型', '課堂類型', '课程类型', '課程類型', 'classtype'],
    ImportField.semester: ['学期', '學期', 'semester'],
    ImportField.date: ['日期', '上课日期', '上課日期', 'date'],
    ImportField.weekday: ['星期', '星期几', '星期幾', 'weekday', 'day'],
    ImportField.weeks: [
      '周次',
      '週次',
      '上课周次',
      '上課週次',
      '教学周',
      '教學週',
      '起止周',
      '起止週',
      'weeks',
      'week',
    ],
    ImportField.periods: [
      '节次',
      '節次',
      '节数',
      '節數',
      '上课节次',
      '上課節次',
      '上课节数',
      '上課節數',
      'periods',
      'period',
    ],
    ImportField.startTime: [
      '开始时间',
      '開始時間',
      '上课时间',
      '上課時間',
      '开始',
      '開始',
      'starttime',
      'start',
    ],
    ImportField.endTime: [
      '结束时间',
      '結束時間',
      '下课时间',
      '下課時間',
      '结束',
      '結束',
      'endtime',
      'end',
    ],
  };
  static String normalize(String value) {
    final buffer = StringBuffer();
    for (final rune in value.trim().toLowerCase().runes) {
      if (rune == 0x3000) {
        buffer.write(' ');
      } else if (rune >= 0xff01 && rune <= 0xff5e) {
        buffer.writeCharCode(rune - 0xfee0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().replaceAll(
      RegExp(r'[\s_\-:：/\\()（）\[\]【】<>《》]'),
      '',
    );
  }

  static ({ImportField? field, double score}) _matchHeader(String value) {
    final header = normalize(value);
    if (header.isEmpty) return (field: null, score: 0);
    ImportField? best;
    var bestScore = 0.0;
    for (final entry in aliases.entries) {
      for (final rawAlias in entry.value) {
        final alias = normalize(rawAlias);
        final score = header == alias
            ? 1.0
            : header.length >= 2 &&
                  alias.length >= 2 &&
                  (header.startsWith(alias) || alias.startsWith(header))
            ? 0.9
            : header.length >= 3 &&
                  alias.length >= 3 &&
                  (header.contains(alias) || alias.contains(header))
            ? 0.82
            : 0.0;
        if (score > bestScore) {
          best = entry.key;
          bestScore = score;
        }
      }
    }
    return (field: best, score: bestScore);
  }

  static ({Map<ImportField, FieldMapping> fields, double score, bool ambiguous})
  _analyzeHeader(ImportSheet sheet, int row) {
    final fields = <ImportField, FieldMapping>{};
    final scores = <ImportField, double>{};
    var ambiguous = false;
    for (var c = 0; c < sheet.columnCount.clamp(0, 100); c++) {
      final match = _matchHeader(sheet.cell(row, c));
      final field = match.field;
      if (field == null || match.score < 0.8) continue;
      if (fields.containsKey(field)) {
        ambiguous = true;
        if (match.score <= scores[field]!) continue;
      }
      fields[field] = FieldMapping(column: c);
      scores[field] = match.score;
    }
    final average = scores.isEmpty
        ? 0.0
        : scores.values.reduce((a, b) => a + b) / scores.length;
    return (fields: fields, score: average, ambiguous: ambiguous);
  }

  static Map<ImportField, FieldMapping> headerFields(
    ImportSheet sheet,
    int row,
  ) {
    final analysis = _analyzeHeader(sheet, row);
    if (analysis.ambiguous) throw const FormatException('ambiguous');
    return analysis.fields;
  }

  static bool _validListFields(Map<ImportField, FieldMapping> fields) =>
      fields.containsKey(ImportField.courseName) &&
      (fields.containsKey(ImportField.date) ||
          fields.containsKey(ImportField.weekday)) &&
      (fields.containsKey(ImportField.periods) ||
          (fields.containsKey(ImportField.startTime) &&
              fields.containsKey(ImportField.endTime)));

  static bool _valueMatches(ImportField field, String value) {
    if (value.trim().isEmpty) return false;
    try {
      switch (field) {
        case ImportField.date:
          parseDate(value);
          return true;
        case ImportField.weekday:
          parseWeekday(value);
          return true;
        case ImportField.weeks:
          parseWeeks(value, 30);
          return true;
        case ImportField.periods:
          parseNumbers(value, 'periodInvalid');
          return true;
        case ImportField.startTime:
        case ImportField.endTime:
          parseMinute(value);
          return true;
        case ImportField.courseName:
          return !RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(value.trim());
        default:
          return true;
      }
    } on FormatException {
      return false;
    }
  }

  static double _listValueScore(
    ImportSheet sheet,
    int headerRow,
    Map<ImportField, FieldMapping> fields,
  ) {
    final important = fields.entries.where(
      (entry) => const {
        ImportField.courseName,
        ImportField.date,
        ImportField.weekday,
        ImportField.weeks,
        ImportField.periods,
        ImportField.startTime,
        ImportField.endTime,
      }.contains(entry.key),
    );
    var valid = 0, total = 0, sampled = 0;
    for (
      var row = headerRow + 1;
      row < sheet.rows.length && sampled < 20;
      row++
    ) {
      if (sheet.rows[row].every((cell) => cell.trim().isEmpty)) continue;
      sampled++;
      for (final entry in important) {
        final value = sheet.cell(row, entry.value.column);
        if (value.trim().isEmpty) continue;
        total++;
        if (_valueMatches(entry.key, value)) valid++;
      }
    }
    return total == 0 ? 0 : valid / total;
  }

  static ImportContext get _recognitionContext => ImportContext(
    confirmed: true,
    semester: SemesterPlan(
      id: 'recognition',
      name: 'recognition',
      firstWeekMonday: DateTime(2000, 1, 3),
      totalWeeks: 30,
    ),
    periodTimes: PeriodTimePlan(
      id: 'recognition',
      name: 'recognition',
      periods: [
        for (var number = 1; number <= 100; number++)
          PeriodTime(
            number: number,
            startMinute: (number - 1) * 10,
            endMinute: (number - 1) * 10 + 9,
          ),
      ],
    ),
    defaultWeeks: const {1},
  );

  static RecognitionAnalysis analyze(
    ImportSheet sheet,
    List<ScheduleImportTemplate> custom,
  ) {
    final drafts = <_RecognitionDraft>[];
    final rowLimit = sheet.rows.length.clamp(0, 50);
    for (var r = 0; r < rowLimit; r++) {
      final header = _analyzeHeader(sheet, r);
      final fields = header.fields;
      if (!header.ambiguous && _validListFields(fields)) {
        final legacy =
            fields[ImportField.courseName]?.column == 6 &&
            fields[ImportField.date]?.column == 4 &&
            fields[ImportField.courseCode]?.column == 7 &&
            fields[ImportField.startTime]?.column == 9 &&
            fields[ImportField.endTime]?.column == 10 &&
            sheet.columnCount >= 13 &&
            r == 0;
        final valueScore = _listValueScore(sheet, r, fields);
        drafts.add(
          _RecognitionDraft(
            ScheduleImportTemplate(
              id: legacy ? 'builtin-legacy' : 'builtin-list-$r',
              name: legacy ? 'legacy' : 'list',
              layout: legacy ? ImportLayout.legacy : ImportLayout.list,
              builtIn: true,
              headerRow: r,
              firstRow: r + 1,
              fields: fields,
            ),
            (0.55 +
                    header.score * 0.2 +
                    valueScore * 0.2 +
                    (fields.length - 4).clamp(0, 5) * 0.01)
                .clamp(0, 0.96),
            [
              const RecognitionEvidence('headers'),
              RecognitionEvidence(
                'values',
                detail: '${(valueScore * 100).round()}',
              ),
            ],
          ),
        );
      }
      final weekdays = <int, int>{};
      for (var c = 0; c < sheet.columnCount; c++) {
        try {
          final d = parseWeekday(sheet.cell(r, c));
          if (sheet.cell(r, c).trim().isNotEmpty) weekdays[c] = d;
        } on FormatException {
          /* Not a weekday header. */
        }
      }
      if (weekdays.length >= 3 &&
          weekdays.length <= 7 &&
          weekdays.values.toSet().length == weekdays.length) {
        final columns = weekdays.keys.toList()..sort();
        Map<int, List<int>> periods = {};
        for (
          var labelColumn = columns.first - 1;
          labelColumn >= 0 && labelColumn >= columns.first - 3;
          labelColumn--
        ) {
          final found = <int, List<int>>{};
          for (var rr = r + 1; rr < sheet.rows.length; rr++) {
            try {
              found[rr] = parseNumbers(
                sheet.cell(rr, labelColumn),
                'periodInvalid',
              );
            } on FormatException {
              /* Ignore decorative rows. */
            }
          }
          if (found.length > periods.length) periods = found;
        }
        if (periods.isNotEmpty) {
          final rows = periods.keys.toList()..sort();
          final nonEmptyCourseCells = rows.fold<int>(0, (count, row) {
            return count +
                columns
                    .where(
                      (column) => sheet.cell(row, column).trim().isNotEmpty,
                    )
                    .length;
          });
          final density = nonEmptyCourseCells == 0
              ? 0.0
              : (nonEmptyCourseCells / (rows.length * columns.length)).clamp(
                  0.0,
                  1.0,
                );
          drafts.add(
            _RecognitionDraft(
              basicGrid.copyWithCoordinates(
                headerRow: r,
                firstRow: rows.first,
                lastRow: rows.last,
                firstColumn: columns.first,
                lastColumn: columns.last,
                weekdayColumns: weekdays,
                periodRows: periods,
              ),
              (0.7 +
                      weekdays.length / 7 * 0.1 +
                      (periods.length / 8).clamp(0, 1) * 0.08 +
                      (density > 0 ? 0.08 : 0))
                  .clamp(0, 0.95),
              [
                RecognitionEvidence(
                  'grid',
                  detail: '${weekdays.length}/${periods.length}',
                ),
              ],
            ),
          );
        }
      }
    }
    for (final t in custom.where((t) => t.enabled)) {
      if (t.layout == ImportLayout.list) {
        if (t.fields.isEmpty) continue;
        final selectedColumns = t.fields.values
            .where((f) => f.source == FieldSource.column)
            .map((f) => f.column);
        if (selectedColumns.any((c) => c >= sheet.columnCount)) continue;
        final mapped = t.fields.entries
            .where((entry) => entry.value.source == FieldSource.column)
            .toList();
        final scores = mapped.map((entry) {
          final match = _matchHeader(
            sheet.cell(t.headerRow, entry.value.column),
          );
          return match.field == entry.key ? match.score : 0.0;
        }).toList();
        if (scores.isNotEmpty && scores.every((score) => score >= 0.8)) {
          final headerScore = scores.reduce((a, b) => a + b) / scores.length;
          final valueScore = _listValueScore(sheet, t.headerRow, t.fields);
          drafts.add(
            _RecognitionDraft(
              t,
              (0.6 + headerScore * 0.2 + valueScore * 0.15).clamp(0, 0.95),
              const [RecognitionEvidence('custom')],
            ),
          );
        }
      } else if (t.layout == ImportLayout.grid &&
          t.weekdayColumns.isNotEmpty &&
          t.weekdayColumns.entries.every((e) {
            try {
              return parseWeekday(sheet.cell(t.headerRow, e.key)) == e.value;
            } on FormatException {
              return false;
            }
          })) {
        drafts.add(
          _RecognitionDraft(t, 0.88, const [RecognitionEvidence('custom')]),
        );
      }
    }
    final unique = <String, _RecognitionDraft>{};
    for (final draft in drafts) {
      final old = unique[draft.template.id];
      if (old == null || draft.structuralScore > old.structuralScore) {
        unique[draft.template.id] = draft;
      }
    }
    final service = ScheduleImportService();
    final candidates = unique.values.map((draft) {
      final preview = service.parseSheet(
        sheet,
        draft.template,
        context: _recognitionContext,
      );
      final parseQuality = preview.sessions.isEmpty
          ? 0.0
          : preview.diagnostics.isEmpty
          ? 1.0
          : (preview.sessions.length /
                    (preview.sessions.length + preview.diagnostics.length))
                .clamp(0.0, 1.0);
      return RecognitionCandidate(
        template: draft.template,
        confidence: (draft.structuralScore * 0.85 + parseQuality * 0.15).clamp(
          0.0,
          1.0,
        ),
        preview: preview,
        evidence: [
          ...draft.evidence,
          RecognitionEvidence(
            'parse',
            detail: '${preview.sessions.length}/${preview.diagnostics.length}',
          ),
        ],
      );
    }).toList()..sort((a, b) => b.confidence.compareTo(a.confidence));
    RecognitionCandidate? recommended;
    if (candidates.isNotEmpty) {
      final top = candidates.first;
      final runnerUp = candidates.length > 1 ? candidates[1].confidence : 0.0;
      if (top.confidence >= 0.85 &&
          top.confidence - runnerUp >= 0.15 &&
          top.preview.sessions.isNotEmpty &&
          !top.preview.hasFatal) {
        recommended = top;
      }
    }
    return RecognitionAnalysis(
      candidates: candidates,
      recommended: recommended,
    );
  }

  static List<ScheduleImportTemplate> candidates(
    ImportSheet sheet,
    List<ScheduleImportTemplate> custom,
  ) => analyze(sheet, custom).templates;

  static const basicGrid = ScheduleImportTemplate(
    id: 'builtin-grid',
    name: 'grid',
    layout: ImportLayout.grid,
    builtIn: true,
    fields: {
      ImportField.courseName: FieldMapping(
        source: FieldSource.text,
        regex: RegexRule(
          pattern: r'^\s*(?:课程[：:]|課程[：:])?([^\r\n{]+)',
          group: '1',
        ),
      ),
      ImportField.teachers: FieldMapping(
        source: FieldSource.text,
        regex: RegexRule(
          pattern: r'(?:教师|教師|老师|老師)[：:]\s*([^\r\n]+)',
          group: '1',
        ),
      ),
      ImportField.room: FieldMapping(
        source: FieldSource.text,
        regex: RegexRule(pattern: r'(?:教室|课室|課室)[：:]\s*([^\r\n]+)', group: '1'),
      ),
      ImportField.weeks: FieldMapping(
        source: FieldSource.text,
        regex: RegexRule(
          pattern:
              r'(?:(?<=周次：)|(?<=周次:)|(?<=週次：)|(?<=週次:)|(?=第?[ \t]*\d+(?:[ \t]*[-~～—–至、,，][ \t]*\d+)*(?:[ \t]*(?:周|週))))[ \t]*(?<weeks>第?[ \t]*\d+(?:[ \t]*[-~～—–至、,，][ \t]*\d+)*(?:[ \t]*(?:周|週))?(?:[ \t]*[（(]?[单双單雙](?:周|週)?[）)]?)?)',
          group: 'weeks',
        ),
      ),
      ImportField.weekday: FieldMapping(source: FieldSource.weekday),
      ImportField.periods: FieldMapping(source: FieldSource.periods),
    },
    blockRule: RegexRule(pattern: r'\r?\n\s*\r?\n'),
    editorHints: TemplateEditorHints(
      blockMode: 'blankLines',
      fields: {
        ImportField.courseName: VisualExtractionHint(
          kind: VisualExtractionKind.firstNonEmptyLine,
        ),
        ImportField.teachers: VisualExtractionHint(
          kind: VisualExtractionKind.afterLabel,
          label: '教师|教師|老师|老師',
        ),
        ImportField.room: VisualExtractionHint(
          kind: VisualExtractionKind.afterLabel,
          label: '教室|课室|課室',
        ),
        ImportField.weeks: VisualExtractionHint(
          kind: VisualExtractionKind.afterLabel,
          label: '周次|週次',
        ),
      },
    ),
  );

  ScheduleParseResult parseSheet(
    ImportSheet sheet,
    ScheduleImportTemplate template, {
    ImportContext context = const ImportContext(),
  }) {
    template.validate();
    if (sheet.rows.isEmpty) {
      return ScheduleParseResult(
        diagnostics: [
          ImportDiagnostic(
            code: 'noSessions',
            file: sheet.file,
            sheet: sheet.name,
          ),
        ],
      );
    }
    final sessions = <CourseSession>[];
    final diagnostics = <ImportDiagnostic>[];
    final traces = <ExtractionTrace>[];
    final locations = <String, ImportDiagnostic>{};
    void error(String code, int row, int? column, [String detail = '']) =>
        diagnostics.add(
          ImportDiagnostic(
            code: code,
            detail: detail,
            file: sheet.file,
            sheet: sheet.name,
            row: row,
            column: column,
          ),
        );
    if (template.layout == ImportLayout.legacy) {
      for (var r = 1; r < sheet.rows.length; r++) {
        if (sheet.rows[r].every((v) => v.trim().isEmpty)) continue;
        try {
          final row = List.generate(13, (c) => sheet.cell(r, c));
          final parsed = XlsxParser().parseRows([
            const [],
            row,
          ], sourceFile: sheet.file).single;
          if (parsed.courseName.isEmpty) {
            throw const FormatException('missingName');
          }
          if (!parsed.endAt.isAfter(parsed.startAt)) {
            throw const FormatException('invalidTime');
          }
          sessions.add(parsed);
          locations[parsed.id] = ImportDiagnostic(
            code: 'idConflict',
            detail: parsed.courseName,
            file: sheet.file,
            sheet: sheet.name,
            row: r,
          );
        } on XlsxParseException catch (e) {
          error(e.code.name, r, null, e.detail ?? '');
        } on FormatException catch (e) {
          error(e.message, r, null);
        }
      }
    } else {
      final fields = template.fields.isEmpty
          ? headerFields(sheet, template.headerRow)
          : template.fields;
      final end = template.lastRow == null
          ? sheet.rows.length - 1
          : template.lastRow!.clamp(0, sheet.rows.length - 1);
      for (var r = template.firstRow; r <= end; r++) {
        if (template.layout == ImportLayout.list) {
          if (sheet.rows[r].every((v) => v.trim().isEmpty)) continue;
          _extract(
            sheet,
            template,
            fields,
            context,
            r,
            0,
            sheet.rows[r].join('\t'),
            '',
            '',
            sessions,
            diagnostics,
            traces,
            locations,
          );
        } else {
          for (var c = template.firstColumn; c <= template.lastColumn; c++) {
            final merge = sheet.merges
                .where((m) => m.contains(r, c))
                .firstOrNull;
            if (merge != null &&
                (merge.firstRow < template.firstRow ||
                    merge.lastRow > end ||
                    merge.firstColumn < template.firstColumn ||
                    merge.lastColumn > template.lastColumn)) {
              if (r == merge.firstRow.clamp(template.firstRow, end) &&
                  c ==
                      merge.firstColumn.clamp(
                        template.firstColumn,
                        template.lastColumn,
                      )) {
                error('templateInvalid', r, c);
              }
              continue;
            }
            if (merge != null &&
                (merge.firstRow != r || merge.firstColumn != c)) {
              continue;
            }
            final text = sheet.cell(r, c).trim();
            if (text.isEmpty) continue;
            if (merge != null && merge.lastColumn > merge.firstColumn) {
              error('horizontalMerge', r, c);
              continue;
            }
            try {
              final day = template.weekdayColumns[c];
              if (day == null &&
                  fields.values.any((f) => f.source == FieldSource.weekday)) {
                throw const FormatException('invalidWeekday');
              }
              final periods = <int>[];
              for (var pr = r; pr <= (merge?.lastRow ?? r); pr++) {
                final p = template.periodRows[pr];
                if (p == null &&
                    fields.values.any((f) => f.source == FieldSource.periods)) {
                  throw const FormatException('unknownPeriod');
                }
                periods.addAll(p ?? []);
              }
              final blocks = _blocks(template, text);
              for (final block in blocks) {
                _extract(
                  sheet,
                  template,
                  fields,
                  context,
                  r,
                  c,
                  block,
                  day == null ? '' : '$day',
                  periods.join(','),
                  sessions,
                  diagnostics,
                  traces,
                  locations,
                );
              }
            } on FormatException catch (e) {
              error(e.message, r, c);
            }
          }
        }
      }
    }
    if (sessions.isEmpty && diagnostics.isEmpty) {
      error('noSessions', template.firstRow, null);
    }
    final result = deduplicate(sessions, locations: locations);
    return ScheduleParseResult(
      sessions: result.sessions,
      diagnostics: [...diagnostics, ...result.diagnostics],
      duplicates: result.duplicates,
      templateId: template.id,
      traces: traces,
      locations: locations,
    );
  }

  static List<String> _blocks(ScheduleImportTemplate t, String text) {
    if (t.blockRule.pattern.isEmpty) return [text];
    final regex = t.blockRule.compile();
    final matches = regex.allMatches(text).toList();
    if (matches.any((m) => m.start == m.end)) {
      throw const FormatException('zeroLength');
    }
    if (t.repeatBlocks) {
      if (matches.isEmpty) throw const FormatException('noMatch');
      // Unmatched non-whitespace must not silently discard a course.
      var cursor = 0;
      for (final m in matches) {
        if (text.substring(cursor, m.start).trim().isNotEmpty) {
          throw const FormatException('unmatchedText');
        }
        cursor = m.end;
      }
      if (text.substring(cursor).trim().isNotEmpty) {
        throw const FormatException('unmatchedText');
      }
      return matches.map(t.blockRule.capture).toList();
    }
    final blocks = <String>[];
    var cursor = 0;
    for (final m in matches) {
      blocks.add(text.substring(cursor, m.start));
      cursor = m.end;
    }
    blocks.add(text.substring(cursor));
    return blocks.where((b) => b.trim().isNotEmpty).toList();
  }

  void _extract(
    ImportSheet sheet,
    ScheduleImportTemplate t,
    Map<ImportField, FieldMapping> mappings,
    ImportContext context,
    int r,
    int c,
    String text,
    String weekday,
    String periods,
    List<CourseSession> sessions,
    List<ImportDiagnostic> errors,
    List<ExtractionTrace> traces,
    Map<String, ImportDiagnostic> locations,
  ) {
    final values = <ImportField, String>{};
    final captures = <String, List<String?>>{};
    try {
      for (final e in mappings.entries) {
        final m = e.value;
        var value = switch (m.source) {
          FieldSource.column => sheet.cell(r, m.column),
          FieldSource.text => text,
          FieldSource.fixed => m.value,
          FieldSource.weekday => weekday,
          FieldSource.periods => periods,
        };
        if (m.regex.pattern.isNotEmpty) {
          final match = m.regex.compile().firstMatch(value);
          if (match == null) {
            value = '';
          } else {
            captures[e.key.name] = [
              for (var i = 0; i <= match.groupCount; i++) match.group(i),
              for (final name in match.groupNames)
                '$name=${match.namedGroup(name)}',
            ];
            value = m.regex.capture(match);
          }
        }
        values[e.key] = value.trim();
      }
      final generated = _sessions(values, context, sheet.file);
      sessions.addAll(generated);
      for (final session in generated) {
        locations[session.id] = ImportDiagnostic(
          code: 'idConflict',
          detail: session.courseName,
          file: sheet.file,
          sheet: sheet.name,
          row: r,
          column: t.layout == ImportLayout.grid ? c : null,
        );
      }
    } on FormatException catch (e) {
      errors.add(
        ImportDiagnostic(
          code: e.message,
          file: sheet.file,
          sheet: sheet.name,
          row: r,
          column: t.layout == ImportLayout.grid ? c : null,
        ),
      );
    } finally {
      if (traces.length < 100) {
        traces.add(
          ExtractionTrace(
            row: r,
            column: c,
            text: text,
            values: values.map((k, v) => MapEntry(k.name, v)),
            captures: captures,
          ),
        );
      }
    }
  }

  static List<CourseSession> _sessions(
    Map<ImportField, String> v,
    ImportContext context,
    String file,
  ) {
    String get(ImportField f) => v[f] ?? '';
    final name = get(ImportField.courseName);
    if (name.isEmpty) throw const FormatException('missingName');
    int start, end;
    if (get(ImportField.startTime).isEmpty &&
        get(ImportField.endTime).isEmpty &&
        get(ImportField.periods).isNotEmpty) {
      if (!context.confirmed || context.periodTimes == null) {
        throw const FormatException('contextRequired');
      }
      context.periodTimes!.validate();
      final numbers = parseNumbers(get(ImportField.periods), 'periodInvalid')
        ..sort();
      final times = numbers
          .map(
            (n) => context.periodTimes!.periods
                .where((p) => p.number == n)
                .firstOrNull,
          )
          .toList();
      if (times.any((t) => t == null)) {
        throw const FormatException('unknownPeriod');
      }
      start = times.first!.startMinute;
      end = times.last!.endMinute;
    } else {
      start = parseMinute(get(ImportField.startTime));
      end = parseMinute(get(ImportField.endTime));
    }
    if (end <= start) throw const FormatException('invalidTime');
    final dates = <DateTime>[];
    final recurring = get(ImportField.date).isEmpty;
    if (!recurring) {
      final date = parseDate(get(ImportField.date));
      if (get(ImportField.weekday).isNotEmpty &&
          parseWeekday(get(ImportField.weekday)) != date.weekday) {
        throw const FormatException('weekdayMismatch');
      }
      dates.add(date);
    } else {
      if (!context.confirmed || context.semester == null) {
        throw const FormatException('contextRequired');
      }
      final plan = context.semester!;
      plan.validate();
      final day = parseWeekday(get(ImportField.weekday));
      final weeks = get(ImportField.weeks).isEmpty
          ? context.defaultWeeks.toList()
          : parseWeeks(get(ImportField.weeks), plan.totalWeeks);
      if (weeks.isEmpty) throw const FormatException('weeksRequired');
      if (weeks.any((w) => w < 1 || w > plan.totalWeeks)) {
        throw const FormatException('invalidWeeks');
      }
      weeks.sort();
      for (final w in weeks) {
        dates.add(
          DateTime(
            plan.firstWeekMonday.year,
            plan.firstWeekMonday.month,
            plan.firstWeekMonday.day + (w - 1) * 7 + day - 1,
          ),
        );
      }
    }
    final teachers = get(ImportField.teachers)
        .split(RegExp(r'[,，、;；]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.toLowerCase() != 'null')
        .toList();
    final identity = courseImportIdentity(
      name,
      get(ImportField.section),
      teachers,
      get(ImportField.faculty),
    );
    final code = get(ImportField.courseCode).isEmpty
        ? generatedImportCourseCode(identity)
        : get(ImportField.courseCode);
    final series = recurring
        ? 'IMPORT|${_hash(jsonEncode([code, identity, context.semester!.firstWeekMonday.toIso8601String()]))}'
        : null;
    final meeting = recurring
        ? 'IMPORT|${_hash(jsonEncode([series, dates.first.weekday, start, end, normalizeImportIdentity(get(ImportField.room))]))}'
        : null;
    return dates.map((date) {
      final startAt = DateTime(
        date.year,
        date.month,
        date.day,
        start ~/ 60,
        start % 60,
      );
      final endAt = DateTime(
        date.year,
        date.month,
        date.day,
        end ~/ 60,
        end % 60,
      );
      return CourseSession(
        id: CourseSession.buildId(
          date: date,
          courseCode: code,
          startAt: startAt,
          section: get(ImportField.section),
        ),
        classType: get(ImportField.classType),
        room: get(ImportField.room),
        date: date,
        weekday: date.weekday,
        courseName: name,
        courseCode: code,
        section: get(ImportField.section),
        startAt: startAt,
        endAt: endAt,
        teachers: teachers,
        faculty: get(ImportField.faculty),
        semester: get(ImportField.semester),
        sourceFile: file,
        recurrenceSeriesId: series,
        recurrenceMeetingId: meeting,
      );
    }).toList();
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  static ScheduleParseResult deduplicate(
    List<CourseSession> sessions, {
    Map<String, ImportDiagnostic> locations = const {},
  }) {
    final unique = <String, CourseSession>{};
    final signatures = <String, String>{};
    final conflicts = <String>{};
    final errors = <ImportDiagnostic>[];
    var duplicates = 0;
    for (final s in sessions) {
      final map = s.toMap()
        ..remove('source_file')
        ..remove('recurrence_series_id')
        ..remove('recurrence_meeting_id');
      final signature = jsonEncode(map);
      if (signatures.containsKey(s.id)) {
        if (signatures[s.id] == signature) {
          duplicates++;
        } else if (conflicts.add(s.id)) {
          errors.add(
            locations[s.id] ??
                ImportDiagnostic(
                  code: 'idConflict',
                  detail: s.courseName,
                  file: s.sourceFile ?? '',
                ),
          );
          unique.remove(s.id);
        }
      } else {
        signatures[s.id] = signature;
        unique[s.id] = s;
      }
    }
    final result = unique.values.toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return ScheduleParseResult(
      sessions: result,
      diagnostics: errors,
      duplicates: duplicates,
    );
  }
}

extension GridCoordinates on ScheduleImportTemplate {
  ScheduleImportTemplate copyWithCoordinates({
    int? headerRow,
    required int firstRow,
    int? lastRow,
    required int firstColumn,
    required int lastColumn,
    required Map<int, int> weekdayColumns,
    required Map<int, List<int>> periodRows,
  }) => ScheduleImportTemplate(
    id: id,
    name: name,
    layout: layout,
    enabled: enabled,
    builtIn: builtIn,
    headerRow: headerRow ?? firstRow - 1,
    firstRow: firstRow,
    lastRow: lastRow,
    firstColumn: firstColumn,
    lastColumn: lastColumn,
    fields: fields,
    blockRule: blockRule,
    repeatBlocks: repeatBlocks,
    editorHints: editorHints,
    weekdayColumns: weekdayColumns,
    periodRows: periodRows,
  );
}

int parseMinute(String value) {
  final m = RegExp(r'^(\d{1,2})[:：](\d{2})(?::00)?$').firstMatch(value.trim());
  if (m == null) throw const FormatException('invalidTime');
  final h = int.parse(m[1]!), minute = int.parse(m[2]!);
  if (h > 23 || minute > 59) throw const FormatException('invalidTime');
  return h * 60 + minute;
}

DateTime parseDate(String value) {
  final m = RegExp(
    r'^(\d{4})[-/年.](\d{1,2})[-/月.](\d{1,2})日?$',
  ).firstMatch(value.trim());
  if (m == null) throw const FormatException('invalidDate');
  final y = int.parse(m[1]!), month = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime(y, month, d);
  if (date.year != y || date.month != month || date.day != d) {
    throw const FormatException('invalidDate');
  }
  return date;
}

int parseWeekday(String value) {
  var s = value.trim().toLowerCase().replaceAll(RegExp(r'^(星期|礼拜|禮拜|周|週)'), '');
  const days = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '日': 7,
    '天': 7,
    'mon': 1,
    'monday': 1,
    'tue': 2,
    'tuesday': 2,
    'wed': 3,
    'wednesday': 3,
    'thu': 4,
    'thursday': 4,
    'fri': 5,
    'friday': 5,
    'sat': 6,
    'saturday': 6,
    'sun': 7,
    'sunday': 7,
  };
  final n = days[s] ?? int.tryParse(s);
  if (n == null || n < 1 || n > 7) {
    throw const FormatException('invalidWeekday');
  }
  return n;
}

List<int> parseNumbers(String value, String error) {
  final s = value
      .replaceAll(RegExp(r'[第节節周週\s]'), '')
      .replaceAll(RegExp(r'[、，;；]'), ',')
      .replaceAll(RegExp(r'[~～—–至]'), '-');
  if (s.isEmpty) throw FormatException(error);
  final numbers = <int>{};
  for (final part in s.split(',')) {
    final m = RegExp(r'^(\d+)(?:-(\d+))?$').firstMatch(part);
    if (m == null) throw FormatException(error);
    final start = int.parse(m[1]!),
        end = m[2] == null ? start : int.parse(m[2]!);
    if (start < 1 || end < start || end > 100) throw FormatException(error);
    for (var n = start; n <= end; n++) {
      numbers.add(n);
    }
  }
  return numbers.toList()..sort();
}

List<int> parseWeeks(String value, int total) {
  var s = value.trim();
  final odd = RegExp(r'[单單]').hasMatch(s),
      even = s.contains('双') || s.contains('雙');
  if (odd && even) throw const FormatException('invalidWeeks');
  s = s.replaceAll(RegExp(r'[()（）单双單雙]'), '').replaceAll(RegExp(r'[周週\s]'), '');
  final weeks = s.isEmpty
      ? (odd || even ? List.generate(total, (i) => i + 1) : <int>[])
      : parseNumbers(s, 'invalidWeeks');
  if (weeks.isEmpty || weeks.any((w) => w > total)) {
    throw const FormatException('invalidWeeks');
  }
  return weeks
      .where(
        (w) => odd
            ? w.isOdd
            : even
            ? w.isEven
            : true,
      )
      .toList();
}

String minuteLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
