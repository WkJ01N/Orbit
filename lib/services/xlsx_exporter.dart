import 'package:excel/excel.dart';
import 'package:orbit/models/course_session.dart';

class XlsxExporter {
  List<int> exportBytes(List<CourseSession> sessions) {
    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet()!;
    excel.rename(defaultName, 'Schedule');
    final sheet = excel.sheets['Schedule']!;

    const headers = [
      '课堂类型',
      '课室',
      '人数',
      '学院名称',
      '日期',
      '星期',
      '科目名称',
      '科目编号',
      '班别名称',
      '开始时间',
      '结束时间',
      '教师',
      '学期',
    ];

    for (var column = 0; column < headers.length; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .value = TextCellValue(headers[column]);
    }

    for (var row = 0; row < sessions.length; row++) {
      _writeSession(sheet, rowIndex: row + 1, session: sessions[row]);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('Failed to encode xlsx');
    }
    return encoded;
  }

  void _writeSession(
    Sheet sheet, {
    required int rowIndex,
    required CourseSession session,
  }) {
    final values = [
      session.classType,
      session.room,
      '',
      session.faculty,
      _dateKey(session.date),
      session.weekday.toString(),
      session.courseName,
      session.courseCode,
      session.section,
      _timeKey(session.startAt),
      _timeKey(session.endAt),
      session.teachers.join(','),
      session.semester,
    ];

    for (var column = 0; column < values.length; column++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: rowIndex,
            ),
          )
          .value = TextCellValue(values[column]);
    }
  }

  String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _timeKey(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
