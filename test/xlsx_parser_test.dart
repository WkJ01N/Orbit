import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'xlsx_test_fixtures.dart';

void main() {
  late XlsxParser parser;

  setUp(() {
    parser = XlsxParser();
  });

  group('XlsxParser — 基础解析', () {
    late List<int> bytes;

    setUp(() {
      bytes = weekOneFixture();
    });

    test('解析出正确的课程数量', () {
      final sessions = parser.parseBytes(bytes, sourceFile: 'week1.xlsx');
      expect(sessions.length, 3);
    });

    test('日期范围正确', () {
      final sessions = parser.parseBytes(bytes);
      final dates = sessions.map((s) => s.date).toList()..sort();
      expect(dates.first, DateTime(2026, 4, 27));
      expect(dates.last, DateTime(2026, 5, 2));
    });

    test('第一节课基本字段正确', () {
      final sessions = parser.parseBytes(bytes);
      final first = sessions.first;
      expect(first.courseCode, 'PHYS102');
      expect(first.courseName, '物理II');
      expect(first.room, 'C508');
      expect(first.startAt, DateTime(2026, 4, 27, 12, 30));
      expect(first.endAt, DateTime(2026, 4, 27, 15, 20));
      expect(first.weekday, 1);
      expect(first.section, 'EX1');
    });

    test('教师字段清洗正确（过滤 null）', () {
      final sessions = parser.parseBytes(bytes);
      final first = sessions.first;
      expect(first.teachers, isNot(contains('null')));
      expect(first.teachers, isNotEmpty);
      expect(first.teachers.first, '张老师');
    });

    test('多教师字段正确分割', () {
      final sessions = parser.parseBytes(bytes);
      final multiTeacher = sessions.firstWhere((s) => s.teachers.length > 1);
      expect(multiTeacher.teachers, ['Alice', 'Bob']);
    });

    test('sourceFile 字段被记录', () {
      final sessions = parser.parseBytes(bytes, sourceFile: 'week1.xlsx');
      expect(sessions.every((s) => s.sourceFile == 'week1.xlsx'), isTrue);
    });

    test('id 唯一性', () {
      final sessions = parser.parseBytes(bytes);
      final ids = sessions.map((s) => s.id).toSet();
      expect(ids.length, sessions.length);
    });
  });

  group('XlsxParser — 第二周', () {
    test('解析出正确的课程数量与日期范围', () {
      final sessions = parser.parseBytes(weekTwoFixture());
      expect(sessions.length, 2);
      final dates = sessions.map((s) => s.date).toList()..sort();
      expect(dates.first, DateTime(2026, 5, 4));
      expect(dates.last, DateTime(2026, 5, 8));
    });
  });

  group('XlsxParser — 稀疏周', () {
    test('稀疏周解析出一节课', () {
      final sessions = parser.parseBytes(sparseWeekFixture());
      expect(sessions.length, 1);
      expect(sessions.first.date, DateTime(2026, 5, 12));
      expect(sessions.first.courseCode, 'GLL-05');
    });
  });

  group('XlsxParser — 多档合并解析', () {
    test('多个档案合计课程数正确', () {
      final files = [
        (bytes: weekOneFixture(), sourceFile: 'week1.xlsx'),
        (bytes: weekTwoFixture(), sourceFile: 'week2.xlsx'),
        (bytes: sparseWeekFixture(), sourceFile: 'week3.xlsx'),
      ];
      final sessions = parser.parseMany(files);
      expect(sessions.length, 6);
    });

    test('跨周的 id 不重复', () {
      final files = [
        (bytes: weekOneFixture(), sourceFile: 'week1.xlsx'),
        (bytes: weekTwoFixture(), sourceFile: 'week2.xlsx'),
        (bytes: sparseWeekFixture(), sourceFile: 'week3.xlsx'),
      ];
      final sessions = parser.parseMany(files);
      final ids = sessions.map((s) => s.id).toSet();
      expect(ids.length, sessions.length);
    });
  });

  group('XlsxParser — 时间字段解析', () {
    test('开始/结束时间组合正确', () {
      final sessions = parser.parseBytes(weekOneFixture());
      for (final session in sessions) {
        expect(session.startAt.isBefore(session.endAt), isTrue);
        expect(session.startAt.year, session.date.year);
        expect(session.startAt.month, session.date.month);
        expect(session.startAt.day, session.date.day);
      }
    });
  });
}
