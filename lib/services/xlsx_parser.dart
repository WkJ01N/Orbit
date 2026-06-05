import 'package:excel/excel.dart';
import 'package:orbit/models/course_session.dart';

class XlsxParseException implements Exception {
  XlsxParseException(this.message);

  final String message;

  @override
  String toString() => 'XlsxParseException: $message';
}

class XlsxParser {
  List<CourseSession> parseBytes(
    List<int> bytes, {
    String? sourceFile,
  }) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw XlsxParseException('檔案中找不到工作表');
    }

    final sheet = excel.tables.values.first;
    if (sheet.maxRows <= 1) {
      throw XlsxParseException('課表內容為空');
    }

    final sessions = <CourseSession>[];
    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = _readRow(sheet, rowIndex);
      if (_isRowEmpty(row)) {
        continue;
      }
      sessions.add(_parseRow(row, sourceFile: sourceFile));
    }

    if (sessions.isEmpty) {
      throw XlsxParseException('未解析到任何課程資料');
    }

    return sessions;
  }

  List<CourseSession> parseMany(
    List<({List<int> bytes, String? sourceFile})> files,
  ) {
    final sessions = <CourseSession>[];
    for (final file in files) {
      sessions.addAll(
        parseBytes(file.bytes, sourceFile: file.sourceFile),
      );
    }
    return sessions;
  }

  CourseSession _parseRow(
    List<String> row, {
    String? sourceFile,
  }) {
    if (row.length < 13) {
      throw XlsxParseException('資料列欄位不足（第 ${row.length} 欄）');
    }

    final date = _parseDate(row[4]);
    final weekday = _parseWeekday(row[5], date);
    final startAt = _parseDateTime(date, row[9]);
    final endAt = _parseDateTime(date, row[10]);
    final courseCode = row[7].trim();
    final section = row[8].trim();

    return CourseSession(
      id: CourseSession.buildId(
        date: date,
        courseCode: courseCode,
        startAt: startAt,
        section: section,
      ),
      classType: row[0].trim(),
      room: row[1].trim(),
      date: date,
      weekday: weekday,
      courseName: row[6].trim(),
      courseCode: courseCode,
      section: section,
      startAt: startAt,
      endAt: endAt,
      teachers: _parseTeachers(row[11]),
      faculty: row[3].trim(),
      semester: row[12].trim(),
      sourceFile: sourceFile,
    );
  }

  List<String> _readRow(Sheet sheet, int rowIndex) {
    final values = <String>[];
    for (var columnIndex = 0; columnIndex < 13; columnIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      );
      values.add(_cellValue(cell));
    }
    return values;
  }

  String _cellValue(Data cell) {
    final value = cell.value;
    if (value == null) {
      return '';
    }
    if (value is TextCellValue) {
      return value.toString().trim();
    }
    if (value is IntCellValue) {
      return value.value.toString();
    }
    if (value is DoubleCellValue) {
      final d = value.value;
      if (d == d.roundToDouble()) {
        return d.toInt().toString();
      }
      return d.toString();
    }
    if (value is DateCellValue) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    }
    if (value is DateTimeCellValue) {
      if (value.hour == 0 && value.minute == 0) {
        return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      }
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    if (value is TimeCellValue) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return value.toString().trim();
  }

  bool _isRowEmpty(List<String> row) {
    return row.every((value) => value.trim().isEmpty);
  }

  DateTime _parseDate(String raw) {
    final value = raw.trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw XlsxParseException('無法解析日期：$value');
    }
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  int _parseWeekday(String raw, DateTime date) {
    final parsed = int.tryParse(raw.split('.').first);
    if (parsed != null && parsed >= 1 && parsed <= 6) {
      return parsed;
    }
    return date.weekday;
  }

  DateTime _parseDateTime(DateTime date, String raw) {
    final value = raw.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) {
      throw XlsxParseException('無法解析時間：$value');
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  List<String> _parseTeachers(String raw) {
    return raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part.toLowerCase() != 'null')
        .toList();
  }
}
