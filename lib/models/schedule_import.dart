import 'dart:convert';

import 'package:orbit/models/course_session.dart';

enum ImportLayout { legacy, list, grid }

enum ImportField {
  courseName,
  courseCode,
  section,
  room,
  teachers,
  faculty,
  classType,
  semester,
  date,
  weekday,
  weeks,
  periods,
  startTime,
  endTime,
}

enum FieldSource { column, text, fixed, weekday, periods }

class RegexRule {
  const RegexRule({
    this.pattern = '',
    this.group = '0',
    this.caseSensitive = true,
    this.multiLine = false,
    this.dotAll = false,
    this.unicode = false,
  });
  final String pattern;
  final String group;
  final bool caseSensitive, multiLine, dotAll, unicode;
  RegExp compile() => RegExp(
    pattern,
    caseSensitive: caseSensitive,
    multiLine: multiLine,
    dotAll: dotAll,
    unicode: unicode,
  );
  void validate() {
    if (pattern.isEmpty) return;
    compile();
    var count = 0;
    var characterClass = false;
    final names = <String>{};
    for (var i = 0; i < pattern.length; i++) {
      final char = pattern[i];
      if (char == r'\') {
        i++;
        continue;
      }
      if (char == '[') {
        characterClass = true;
        continue;
      }
      if (char == ']') {
        characterClass = false;
        continue;
      }
      if (characterClass || char != '(') continue;
      if (i + 1 >= pattern.length || pattern[i + 1] != '?') {
        count++;
        continue;
      }
      if (pattern.startsWith('(?<', i) &&
          i + 3 < pattern.length &&
          pattern[i + 3] != '=' &&
          pattern[i + 3] != '!') {
        count++;
        final end = pattern.indexOf('>', i + 3);
        if (end >= 0) names.add(pattern.substring(i + 3, end));
      }
    }
    final index = int.tryParse(group);
    if (index == null ? !names.contains(group) : index < 0 || index > count) {
      throw const FormatException('captureGroup');
    }
  }

  Map<String, dynamic> toJson() => {
    'pattern': pattern,
    'group': group,
    'caseSensitive': caseSensitive,
    'multiLine': multiLine,
    'dotAll': dotAll,
    'unicode': unicode,
  };
  factory RegexRule.fromJson(Map<String, dynamic> j) => RegexRule(
    pattern: j['pattern'] as String? ?? '',
    group: j['group'] as String? ?? '0',
    caseSensitive: j['caseSensitive'] as bool? ?? true,
    multiLine: j['multiLine'] as bool? ?? false,
    dotAll: j['dotAll'] as bool? ?? false,
    unicode: j['unicode'] as bool? ?? false,
  );
  String capture(RegExpMatch match) {
    final index = int.tryParse(group);
    if (index != null) {
      if (index < 0 || index > match.groupCount) {
        throw const FormatException('captureGroup');
      }
      return match.group(index) ?? '';
    }
    if (!match.groupNames.contains(group)) {
      throw const FormatException('captureGroup');
    }
    return match.namedGroup(group) ?? '';
  }
}

class FieldMapping {
  const FieldMapping({
    this.source = FieldSource.column,
    this.column = 0,
    this.value = '',
    this.regex = const RegexRule(),
  });
  final FieldSource source;
  final int column;
  final String value;
  final RegexRule regex;
  Map<String, dynamic> toJson() => {
    'source': source.name,
    'column': column,
    'value': value,
    'regex': regex.toJson(),
  };
  factory FieldMapping.fromJson(Map<String, dynamic> j) => FieldMapping(
    source: FieldSource.values.byName(j['source'] as String),
    column: j['column'] as int? ?? 0,
    value: j['value'] as String? ?? '',
    regex: RegexRule.fromJson(
      Map<String, dynamic>.from(j['regex'] as Map? ?? {}),
    ),
  );
}

class ScheduleImportTemplate {
  const ScheduleImportTemplate({
    required this.id,
    required this.name,
    required this.layout,
    this.enabled = true,
    this.builtIn = false,
    this.headerRow = 0,
    this.firstRow = 1,
    this.lastRow,
    this.firstColumn = 1,
    this.lastColumn = 7,
    this.weekdayColumns = const {},
    this.periodRows = const {},
    this.fields = const {},
    this.blockRule = const RegexRule(),
    this.repeatBlocks = false,
  });
  static const version = 1;
  final String id, name;
  final ImportLayout layout;
  final bool enabled, builtIn, repeatBlocks;
  final int headerRow, firstRow, firstColumn, lastColumn;
  final int? lastRow;
  final Map<int, int> weekdayColumns;
  final Map<int, List<int>> periodRows;
  final Map<ImportField, FieldMapping> fields;
  final RegexRule blockRule;
  Map<String, dynamic> toJson() => {
    'version': version,
    'id': id,
    'name': name,
    'layout': layout.name,
    'enabled': enabled,
    'headerRow': headerRow,
    'firstRow': firstRow,
    'lastRow': lastRow,
    'firstColumn': firstColumn,
    'lastColumn': lastColumn,
    'weekdayColumns': weekdayColumns.map((k, v) => MapEntry('$k', v)),
    'periodRows': periodRows.map((k, v) => MapEntry('$k', v)),
    'fields': fields.map((k, v) => MapEntry(k.name, v.toJson())),
    'blockRule': blockRule.toJson(),
    'repeatBlocks': repeatBlocks,
  };
  factory ScheduleImportTemplate.fromJson(Map<String, dynamic> j) {
    if (j['version'] != version) throw const FormatException('templateVersion');
    final t = ScheduleImportTemplate(
      id: j['id'] as String,
      name: j['name'] as String,
      layout: ImportLayout.values.byName(j['layout'] as String),
      enabled: j['enabled'] as bool? ?? true,
      headerRow: j['headerRow'] as int? ?? 0,
      firstRow: j['firstRow'] as int? ?? 1,
      lastRow: j['lastRow'] as int?,
      firstColumn: j['firstColumn'] as int? ?? 1,
      lastColumn: j['lastColumn'] as int? ?? 7,
      weekdayColumns: (j['weekdayColumns'] as Map? ?? {}).map(
        (k, v) => MapEntry(int.parse(k as String), v as int),
      ),
      periodRows: (j['periodRows'] as Map? ?? {}).map(
        (k, v) => MapEntry(int.parse(k as String), List<int>.from(v as List)),
      ),
      fields: (j['fields'] as Map? ?? {}).map(
        (k, v) => MapEntry(
          ImportField.values.byName(k as String),
          FieldMapping.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      ),
      blockRule: RegexRule.fromJson(
        Map<String, dynamic>.from(j['blockRule'] as Map? ?? {}),
      ),
      repeatBlocks: j['repeatBlocks'] as bool? ?? false,
    );
    t.validate();
    if (t.layout != ImportLayout.legacy && t.fields.isEmpty) {
      throw const FormatException('missingName');
    }
    return t;
  }
  void validate() {
    if (id.trim().isEmpty ||
        name.trim().isEmpty ||
        headerRow < 0 ||
        firstRow < 0 ||
        (lastRow != null && lastRow! < firstRow) ||
        firstColumn < 0 ||
        lastColumn < firstColumn ||
        weekdayColumns.entries.any(
          (e) => e.key < 0 || e.value < 1 || e.value > 7,
        ) ||
        periodRows.entries.any(
          (e) => e.key < 0 || e.value.isEmpty || e.value.any((p) => p < 1),
        ) ||
        fields.values.any((f) => f.column < 0)) {
      throw const FormatException('templateInvalid');
    }
    for (final rule in [blockRule, ...fields.values.map((f) => f.regex)]) {
      rule.validate();
      if (rule.group.isEmpty || (int.tryParse(rule.group) ?? 0) < 0) {
        throw const FormatException('captureGroup');
      }
    }
    if (layout != ImportLayout.legacy &&
        fields.isNotEmpty &&
        !fields.containsKey(ImportField.courseName)) {
      throw const FormatException('missingName');
    }
  }

  ScheduleImportTemplate copy({String? id, String? name, bool? enabled}) =>
      ScheduleImportTemplate.fromJson({
        ...toJson(),
        'id': id ?? this.id,
        'name': name ?? this.name,
        'enabled': enabled ?? this.enabled,
      });
}

class SemesterPlan {
  const SemesterPlan({
    required this.id,
    required this.name,
    required this.firstWeekMonday,
    this.totalWeeks = 18,
  });
  final String id, name;
  final DateTime firstWeekMonday;
  final int totalWeeks;
  void validate() {
    if (id.isEmpty ||
        name.trim().isEmpty ||
        firstWeekMonday.weekday != 1 ||
        totalWeeks < 1 ||
        totalWeeks > 30) {
      throw const FormatException('semesterInvalid');
    }
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'name': name,
    'firstWeekMonday': firstWeekMonday.toIso8601String(),
    'totalWeeks': totalWeeks,
  };
  factory SemesterPlan.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) throw const FormatException('templateVersion');
    final p = SemesterPlan(
      id: j['id'] as String,
      name: j['name'] as String,
      firstWeekMonday: DateTime.parse(j['firstWeekMonday'] as String),
      totalWeeks: j['totalWeeks'] as int,
    );
    p.validate();
    return p;
  }
}

class PeriodTime {
  const PeriodTime({
    required this.number,
    required this.startMinute,
    required this.endMinute,
  });
  final int number, startMinute, endMinute;
  Map<String, dynamic> toJson() => {
    'number': number,
    'startMinute': startMinute,
    'endMinute': endMinute,
  };
  factory PeriodTime.fromJson(Map<String, dynamic> j) => PeriodTime(
    number: j['number'] as int,
    startMinute: j['startMinute'] as int,
    endMinute: j['endMinute'] as int,
  );
}

class PeriodTimePlan {
  const PeriodTimePlan({
    required this.id,
    required this.name,
    required this.periods,
  });
  final String id, name;
  final List<PeriodTime> periods;
  void validate() {
    final sorted = [...periods]..sort((a, b) => a.number.compareTo(b.number));
    if (id.isEmpty ||
        name.trim().isEmpty ||
        periods.isEmpty ||
        periods.map((p) => p.number).toSet().length != periods.length ||
        periods.any(
          (p) =>
              p.number < 1 ||
              p.startMinute < 0 ||
              p.endMinute >= 1440 ||
              p.endMinute <= p.startMinute,
        )) {
      throw const FormatException('periodInvalid');
    }
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].startMinute < sorted[i - 1].endMinute) {
        throw const FormatException('periodInvalid');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'name': name,
    'periods': periods.map((p) => p.toJson()).toList(),
  };
  factory PeriodTimePlan.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) throw const FormatException('templateVersion');
    final p = PeriodTimePlan(
      id: j['id'] as String,
      name: j['name'] as String,
      periods: (j['periods'] as List)
          .map((v) => PeriodTime.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList(),
    );
    p.validate();
    return p;
  }
}

class ImportContext {
  const ImportContext({
    this.semester,
    this.periodTimes,
    this.defaultWeeks = const {},
    this.confirmed = false,
  });
  final SemesterPlan? semester;
  final PeriodTimePlan? periodTimes;
  final Set<int> defaultWeeks;
  final bool confirmed;
}

class ImportConfiguration {
  const ImportConfiguration({
    this.templates = const [],
    this.semesters = const [],
    this.periodTimes = const [],
  });
  final List<ScheduleImportTemplate> templates;
  final List<SemesterPlan> semesters;
  final List<PeriodTimePlan> periodTimes;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'templates': templates.map((t) => t.toJson()).toList(),
    'semesters': semesters.map((p) => p.toJson()).toList(),
    'periodTimes': periodTimes.map((p) => p.toJson()).toList(),
  };
  factory ImportConfiguration.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) throw const FormatException('templateVersion');
    final c = ImportConfiguration(
      templates: (j['templates'] as List? ?? [])
          .map(
            (v) => ScheduleImportTemplate.fromJson(
              Map<String, dynamic>.from(v as Map),
            ),
          )
          .toList(),
      semesters: (j['semesters'] as List? ?? [])
          .map(
            (v) => SemesterPlan.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
      periodTimes: (j['periodTimes'] as List? ?? [])
          .map(
            (v) => PeriodTimePlan.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
    );
    for (final ids in [
      c.templates.map((t) => t.id),
      c.semesters.map((p) => p.id),
      c.periodTimes.map((p) => p.id),
    ]) {
      if (ids.toSet().length != ids.length) {
        throw const FormatException('templateInvalid');
      }
    }
    return c;
  }
  ImportConfiguration copy({
    List<ScheduleImportTemplate>? templates,
    List<SemesterPlan>? semesters,
    List<PeriodTimePlan>? periodTimes,
  }) => ImportConfiguration(
    templates: templates ?? this.templates,
    semesters: semesters ?? this.semesters,
    periodTimes: periodTimes ?? this.periodTimes,
  );
}

class ImportDiagnostic {
  const ImportDiagnostic({
    required this.code,
    this.detail = '',
    this.file = '',
    this.sheet = '',
    this.row,
    this.column,
    this.fatal = false,
  });
  final String code, detail, file, sheet;
  final int? row, column;
  final bool fatal;
  String get location => [
    file,
    sheet,
    if (row != null) '${column == null ? '' : columnLabel(column!)}${row! + 1}',
  ].where((s) => s.isNotEmpty).join(' · ');
}

class ScheduleParseResult {
  const ScheduleParseResult({
    this.sessions = const [],
    this.diagnostics = const [],
    this.duplicates = 0,
    this.templateId,
    this.traces = const [],
    this.locations = const {},
  });
  final List<CourseSession> sessions;
  final List<ImportDiagnostic> diagnostics;
  final int duplicates;
  final String? templateId;
  final List<ExtractionTrace> traces;
  final Map<String, ImportDiagnostic> locations;
  bool get hasFatal => diagnostics.any((d) => d.fatal);
}

class ExtractionTrace {
  const ExtractionTrace({
    required this.row,
    required this.column,
    required this.text,
    required this.values,
    this.captures = const {},
  });
  final int row, column;
  final String text;
  final Map<String, String> values;
  final Map<String, List<String?>> captures;
}

class MergedRegion {
  const MergedRegion(
    this.firstRow,
    this.lastRow,
    this.firstColumn,
    this.lastColumn,
  );
  final int firstRow, lastRow, firstColumn, lastColumn;
  bool contains(int row, int column) =>
      row >= firstRow &&
      row <= lastRow &&
      column >= firstColumn &&
      column <= lastColumn;
}

class ImportSheet {
  const ImportSheet({
    required this.file,
    required this.name,
    required this.rows,
    this.merges = const [],
  });
  final String file, name;
  final List<List<String>> rows;
  final List<MergedRegion> merges;
  int get columnCount => rows.fold(0, (n, r) => r.length > n ? r.length : n);
  String cell(int row, int column) =>
      row >= 0 && row < rows.length && column >= 0 && column < rows[row].length
      ? rows[row][column]
      : '';
}

String columnLabel(int column) {
  var n = column + 1;
  var label = '';
  while (n > 0) {
    n--;
    label = String.fromCharCode(65 + n % 26) + label;
    n ~/= 26;
  }
  return label;
}

String encodeTemplate(ScheduleImportTemplate template) =>
    const JsonEncoder.withIndent('  ').convert({
      'kind': 'orbit-import-template',
      'version': 1,
      'template': template.toJson(),
    });
ScheduleImportTemplate decodeTemplate(String text) {
  final j = jsonDecode(text);
  if (j is! Map<String, dynamic> ||
      j['kind'] != 'orbit-import-template' ||
      j['version'] != 1) {
    throw const FormatException('templateInvalid');
  }
  final t = ScheduleImportTemplate.fromJson(
    Map<String, dynamic>.from(j['template'] as Map),
  );
  if (t.layout == ImportLayout.legacy) {
    throw const FormatException('templateInvalid');
  }
  return t;
}
