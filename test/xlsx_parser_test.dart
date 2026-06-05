import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/xlsx_parser.dart';

void main() {
  late XlsxParser parser;

  setUp(() {
    parser = XlsxParser();
  });

  List<int> loadSample(String fileName) {
    final file = File('assets/samples/$fileName');
    return file.readAsBytesSync();
  }

  group('XlsxParser — 週次一 (2026-04-27 ~ 2026-05-02)', () {
    late List<int> bytes;

    setUp(() {
      bytes = loadSample('學生課表20260429105346.xlsx');
    });

    test('解析出正確的課程數量', () {
      final sessions = parser.parseBytes(bytes, sourceFile: 'week1.xlsx');
      expect(sessions.length, 11);
    });

    test('日期範圍正確', () {
      final sessions = parser.parseBytes(bytes);
      final dates = sessions.map((s) => s.date).toList()..sort();
      expect(dates.first, DateTime(2026, 4, 27));
      expect(dates.last, DateTime(2026, 5, 2));
    });

    test('第一節課基本欄位正確', () {
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

    test('教師欄位清洗正確（過濾 null）', () {
      final sessions = parser.parseBytes(bytes);
      final first = sessions.first;
      expect(first.teachers, isNot(contains('null')));
      expect(first.teachers, isNotEmpty);
      expect(first.teachers.first, '原田雄司');
    });

    test('多教師欄位正確分割', () {
      final sessions = parser.parseBytes(bytes);
      final multiTeacher = sessions.firstWhere(
        (s) => s.teachers.length > 1,
        orElse: () => sessions.first,
      );
      for (final teacher in multiTeacher.teachers) {
        expect(teacher.trim(), isNotEmpty);
        expect(teacher.toLowerCase(), isNot('null'));
      }
    });

    test('sourceFile 欄位被記錄', () {
      final sessions = parser.parseBytes(bytes, sourceFile: 'week1.xlsx');
      expect(sessions.every((s) => s.sourceFile == 'week1.xlsx'), isTrue);
    });

    test('id 唯一性', () {
      final sessions = parser.parseBytes(bytes);
      final ids = sessions.map((s) => s.id).toSet();
      expect(ids.length, sessions.length);
    });
  });

  group('XlsxParser — 週次二 (2026-05-04 ~ 2026-05-08)', () {
    late List<int> bytes;

    setUp(() {
      bytes = loadSample('學生課表20260429105348.xlsx');
    });

    test('解析出正確的課程數量', () {
      final sessions = parser.parseBytes(bytes);
      expect(sessions.length, 12);
    });

    test('日期範圍正確', () {
      final sessions = parser.parseBytes(bytes);
      final dates = sessions.map((s) => s.date).toList()..sort();
      expect(dates.first, DateTime(2026, 5, 4));
      expect(dates.last, DateTime(2026, 5, 8));
    });
  });

  group('XlsxParser — 週次三（稀疏週，僅一節課）', () {
    late List<int> bytes;

    setUp(() {
      bytes = loadSample('學生課表20260429105350.xlsx');
    });

    test('稀疏週解析出一節課', () {
      final sessions = parser.parseBytes(bytes);
      expect(sessions.length, 1);
    });

    test('單節課日期正確', () {
      final sessions = parser.parseBytes(bytes);
      expect(sessions.first.date, DateTime(2026, 5, 12));
    });

    test('單節課科目編號正確', () {
      final sessions = parser.parseBytes(bytes);
      expect(sessions.first.courseCode, 'GLL-05');
    });
  });

  group('XlsxParser — 多檔合併解析', () {
    test('三個檔案合計共 24 節課', () {
      final files = [
        '學生課表20260429105346.xlsx',
        '學生課表20260429105348.xlsx',
        '學生課表20260429105350.xlsx',
      ]
          .map(
            (name) => (
              bytes: loadSample(name),
              sourceFile: name as String?,
            ),
          )
          .toList();

      final sessions = parser.parseMany(files);
      expect(sessions.length, 24);
    });

    test('跨週的 id 不重複', () {
      final files = [
        '學生課表20260429105346.xlsx',
        '學生課表20260429105348.xlsx',
        '學生課表20260429105350.xlsx',
      ]
          .map(
            (name) => (
              bytes: loadSample(name),
              sourceFile: name as String?,
            ),
          )
          .toList();

      final sessions = parser.parseMany(files);
      final ids = sessions.map((s) => s.id).toSet();
      expect(ids.length, sessions.length);
    });
  });

  group('XlsxParser — 時間欄位解析', () {
    test('開始/結束時間組合正確', () {
      final bytes = loadSample('學生課表20260429105346.xlsx');
      final sessions = parser.parseBytes(bytes);
      for (final session in sessions) {
        expect(session.startAt.isBefore(session.endAt), isTrue);
        expect(session.startAt.year, session.date.year);
        expect(session.startAt.month, session.date.month);
        expect(session.startAt.day, session.date.day);
      }
    });
  });
}
