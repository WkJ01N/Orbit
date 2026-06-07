import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/schedule_backup_service.dart';

void main() {
  test('encode and decode preserves session fields', () {
    final session = CourseSession(
      id: '2026-07-27|P0721|EX1|12:30',
      classType: '一般课堂',
      room: 'A001',
      date: DateTime(2026, 7, 27),
      weekday: 1,
      courseName: 'Physics',
      courseCode: 'P0721',
      section: 'EX1',
      startAt: DateTime(2026, 7, 27, 12, 30),
      endAt: DateTime(2026, 7, 27, 15, 20),
      teachers: const ['Miku'],
      faculty: 'Example',
      semester: '2606',
      note: 'note',
    );

    final service = ScheduleBackupService();
    final json = service.encodeToJson([session]);
    final restored = service.decodeFromJson(json);

    expect(restored, hasLength(1));
    expect(restored.first.id, session.id);
    expect(restored.first.courseName, session.courseName);
    expect(restored.first.room, session.room);
    expect(restored.first.teachers, session.teachers);
    expect(restored.first.note, session.note);
  });

  test('decode rejects invalid format', () {
    final service = ScheduleBackupService();
    expect(
      () => service.decodeFromJson('not json'),
      throwsA(isA<ScheduleBackupException>()),
    );
  });
}
