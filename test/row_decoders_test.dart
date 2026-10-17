import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/row_decoders.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';

void main() {
  test(
    'large row decoding preserves IDs, timezone dates, metadata and ordering',
    () async {
      final date = DateTime(2026, 10, 19);
      final values = List.generate(
        250,
        (i) => CourseSession(
          id: 's$i',
          classType: 'lecture',
          room: 'A101',
          date: date,
          weekday: 1,
          courseName: '课程',
          courseCode: 'M',
          section: '1',
          startAt: date.add(Duration(minutes: i)),
          endAt: date.add(Duration(minutes: i + 60)),
          teachers: const ['Teacher'],
          faculty: 'Science',
          semester: '1',
          note: '笔记',
        ),
      );
      final rows = values.map((e) => e.toMap()).toList();
      final decoded = await decodeCourseRows(rows);
      expect(decoded.map((e) => e.toMap()).toList(), rows);
      final deadlines = List.generate(
        250,
        (i) => Deadline(
          id: 'd$i',
          subject: 'S',
          title: 'DDL',
          dueAt: date.add(Duration(days: i)),
          leadMinutes: const [15],
        ),
      );
      final deadlineRows = deadlines.map((e) => e.toMap()).toList();
      final actual = await decodeDeadlineRows(deadlineRows);
      expect(actual.map((e) => e.toMap()).toList(), deadlineRows);
    },
  );
}
