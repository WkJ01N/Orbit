import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/schedule_summary_service.dart';

CourseSession _session({
  required String id,
  required DateTime date,
  required DateTime startAt,
  required DateTime endAt,
}) {
  return CourseSession(
    id: id,
    classType: '一般課堂',
    room: 'C508',
    date: date,
    weekday: date.weekday,
    courseName: '物理II',
    courseCode: 'PHYS102',
    section: 'EX1',
    startAt: startAt,
    endAt: endAt,
    teachers: const ['Teacher'],
    faculty: 'FIE',
    semester: '2602',
  );
}

void main() {
  test('summarizeDay 统计课程数量与第一节课', () {
    final day = DateTime(2026, 4, 27);
    final sessions = [
      _session(
        id: '1',
        date: day,
        startAt: DateTime(2026, 4, 27, 12, 30),
        endAt: DateTime(2026, 4, 27, 15, 20),
      ),
      _session(
        id: '2',
        date: day,
        startAt: DateTime(2026, 4, 27, 9, 0),
        endAt: DateTime(2026, 4, 27, 10, 30),
      ),
    ];

    final summary = summarizeDay(sessions, day);
    expect(summary.sessionCount, 2);
    expect(summary.firstSessionStart, DateTime(2026, 4, 27, 9, 0));
    expect(summary.firstCourseName, '物理II');
  });

  test('summarizeDay 无课程时返回空摘要', () {
    final day = DateTime(2026, 4, 28);
    final summary = summarizeDay(const [], day);
    expect(summary.hasClasses, false);
    expect(summary.sessionCount, 0);
  });

  test('summarizeUpcomingDays 生成指定天数摘要', () {
    final from = DateTime(2026, 4, 27);
    final sessions = [
      _session(
        id: '1',
        date: from,
        startAt: DateTime(2026, 4, 27, 9, 0),
        endAt: DateTime(2026, 4, 27, 10, 0),
      ),
    ];

    final summaries = summarizeUpcomingDays(sessions, days: 3, from: from);
    expect(summaries.length, 3);
    expect(summaries.first.sessionCount, 1);
    expect(summaries[1].sessionCount, 0);
  });
}
