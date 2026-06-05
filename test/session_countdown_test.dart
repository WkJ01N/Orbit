import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/session/session_countdown.dart';
import 'package:orbit/models/course_session.dart';

CourseSession _sampleSession({
  required DateTime startAt,
  required DateTime endAt,
}) {
  return CourseSession(
    id: 'test',
    classType: '一般課堂',
    room: 'C508',
    date: DateTime(startAt.year, startAt.month, startAt.day),
    weekday: startAt.weekday,
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
  group('computeCountdownParts', () {
    test('formats remaining time into day/hour/minute parts', () {
      final from = DateTime(2026, 6, 5, 10, 0);
      final target = DateTime(2026, 6, 8, 12, 15);
      final parts = computeCountdownParts(from, target);
      expect(parts.days, 3);
      expect(parts.hours, 2);
      expect(parts.minutes, 15);
    });

    test('never returns negative parts', () {
      final from = DateTime(2026, 6, 5, 12, 0);
      final target = DateTime(2026, 6, 5, 10, 0);
      final parts = computeCountdownParts(from, target);
      expect(parts.days, 0);
      expect(parts.hours, 0);
      expect(parts.minutes, 0);
    });
  });

  group('session state helpers', () {
    test('detects ongoing and soon sessions', () {
      final start = DateTime(2026, 6, 5, 12, 0);
      final end = DateTime(2026, 6, 5, 13, 0);
      final now = DateTime(2026, 6, 5, 12, 30);
      expect(isSessionOngoing(now, start, end), isTrue);
      expect(isSessionStartingSoon(now, start), isFalse);
    });

    test('detects starting soon within threshold', () {
      final now = DateTime(2026, 6, 5, 11, 45);
      final start = DateTime(2026, 6, 5, 12, 0);
      expect(isSessionStartingSoon(now, start), isTrue);
    });
  });

  group('CourseSession.copyWith', () {
    test('updates note and rebuilds id when start time changes', () {
      final start = DateTime(2026, 6, 5, 12, 30);
      final end = DateTime(2026, 6, 5, 13, 30);
      final session = _sampleSession(startAt: start, endAt: end);
      final noted = session.copyWith(note: '带电脑');
      expect(noted.note, '带电脑');

      final newStart = DateTime(2026, 6, 5, 14, 0);
      final updated = session.copyWith(startAt: newStart);
      expect(updated.computeId(), isNot(session.id));
    });
  });
}
