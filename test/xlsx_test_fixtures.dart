import 'package:excel/excel.dart';

/// 在测试中动态生成 xlsx 字节，避免仓库内附带真实课表样本。
List<int> buildScheduleXlsx(List<List<String>> dataRows) {
  final excel = Excel.createExcel();
  final sheet = excel[excel.sheets.keys.first];
  const header = [
    '课堂类型',
    '课室',
    '人数',
    '学院',
    '日期',
    '星期',
    '科目',
    '编号',
    '班别',
    '开始',
    '结束',
    '教师',
    '学期',
  ];

  for (var col = 0; col < header.length; col++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        .value = TextCellValue(header[col]);
  }

  for (var row = 0; row < dataRows.length; row++) {
    final values = dataRows[row];
    for (var col = 0; col < values.length; col++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
          )
          .value = TextCellValue(values[col]);
    }
  }

  final encoded = excel.encode();
  if (encoded == null) {
    throw StateError('Failed to encode test xlsx');
  }
  return encoded;
}

List<String> scheduleRow({
  required String date,
  required String weekday,
  required String courseName,
  required String courseCode,
  required String section,
  required String start,
  required String end,
  String classType = '一般课堂',
  String room = 'A101',
  String headcount = '30',
  String faculty = '示例学院',
  String teachers = '张老师',
  String semester = '2601',
}) {
  return [
    classType,
    room,
    headcount,
    faculty,
    date,
    weekday,
    courseName,
    courseCode,
    section,
    start,
    end,
    teachers,
    semester,
  ];
}

List<int> weekOneFixture() {
  return buildScheduleXlsx([
    scheduleRow(
      date: '2026-04-27',
      weekday: '1',
      courseName: '物理II',
      courseCode: 'PHYS102',
      section: 'EX1',
      start: '12:30',
      end: '15:20',
      room: 'C508',
      teachers: '张老师,null',
    ),
    scheduleRow(
      date: '2026-04-28',
      weekday: '2',
      courseName: '高等数学',
      courseCode: 'MATH201',
      section: 'EX2',
      start: '09:00',
      end: '10:30',
      teachers: 'Alice,Bob',
    ),
    scheduleRow(
      date: '2026-05-02',
      weekday: '6',
      courseName: '程序设计',
      courseCode: 'CS101',
      section: 'LAB1',
      start: '14:00',
      end: '16:00',
    ),
  ]);
}

List<int> weekTwoFixture() {
  return buildScheduleXlsx([
    scheduleRow(
      date: '2026-05-04',
      weekday: '1',
      courseName: '线性代数',
      courseCode: 'MATH202',
      section: 'EX1',
      start: '08:00',
      end: '09:30',
    ),
    scheduleRow(
      date: '2026-05-08',
      weekday: '5',
      courseName: '数据结构',
      courseCode: 'CS201',
      section: 'EX1',
      start: '10:00',
      end: '11:30',
    ),
  ]);
}

List<int> sparseWeekFixture() {
  return buildScheduleXlsx([
    scheduleRow(
      date: '2026-05-12',
      weekday: '2',
      courseName: '通识选修',
      courseCode: 'GLL-05',
      section: 'EX1',
      start: '13:00',
      end: '14:30',
    ),
  ]);
}
