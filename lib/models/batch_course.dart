import 'package:orbit/models/course_session.dart';

enum BatchConflictStrategy { skip, overwrite }

class BatchMeeting {
  const BatchMeeting({
    required this.id,
    required this.weekday,
    required this.room,
    required this.startMinute,
    required this.endMinute,
  });

  final String id;
  final int weekday;
  final String room;
  final int startMinute;
  final int endMinute;
}

class BatchCourseDraft {
  const BatchCourseDraft({
    required this.courseName,
    required this.courseCode,
    required this.section,
    required this.teachers,
    required this.faculty,
    required this.classType,
    required this.semester,
    required this.firstWeekMonday,
    required this.totalWeeks,
    required this.selectedWeeks,
    required this.meetings,
  });

  final String courseName;
  final String courseCode;
  final String section;
  final List<String> teachers;
  final String faculty;
  final String classType;
  final String semester;
  final DateTime firstWeekMonday;
  final int totalWeeks;
  final Set<int> selectedWeeks;
  final List<BatchMeeting> meetings;
}

class BatchCoursePreview {
  const BatchCoursePreview({
    required this.generatedCount,
    required this.conflictCount,
  });

  final int generatedCount;
  final int conflictCount;
}

class BatchCourseSaveResult {
  const BatchCourseSaveResult({
    required this.createdCount,
    required this.skippedCount,
    required this.overwrittenCount,
  });

  final int createdCount;
  final int skippedCount;
  final int overwrittenCount;
}

List<CourseSession> generateBatchCourseSessions(
  BatchCourseDraft draft, {
  required String seriesId,
}) {
  if (draft.totalWeeks < 1 || draft.totalWeeks > 30) {
    throw ArgumentError.value(draft.totalWeeks, 'totalWeeks');
  }
  if (draft.selectedWeeks.isEmpty || draft.meetings.isEmpty) {
    return const [];
  }
  final monday = DateTime(
    draft.firstWeekMonday.year,
    draft.firstWeekMonday.month,
    draft.firstWeekMonday.day,
  );
  final courseCode = draft.courseCode.trim().isEmpty
      ? 'MANUAL|$seriesId'
      : draft.courseCode.trim();
  final section = draft.section.trim().isEmpty ? '1' : draft.section.trim();
  final sessions = <CourseSession>[];
  final weeks = draft.selectedWeeks.toList()..sort();
  for (final week in weeks) {
    if (week < 1 || week > draft.totalWeeks) {
      throw ArgumentError.value(week, 'selectedWeeks');
    }
    for (final meeting in draft.meetings) {
      if (meeting.weekday < DateTime.monday ||
          meeting.weekday > DateTime.sunday ||
          meeting.startMinute < 0 ||
          meeting.endMinute > 24 * 60 ||
          meeting.endMinute <= meeting.startMinute) {
        throw ArgumentError.value(meeting, 'meetings');
      }
      final date = monday.add(
        Duration(days: (week - 1) * 7 + meeting.weekday - DateTime.monday),
      );
      final startAt = DateTime(
        date.year,
        date.month,
        date.day,
        meeting.startMinute ~/ 60,
        meeting.startMinute % 60,
      );
      final endAt = DateTime(
        date.year,
        date.month,
        date.day,
        meeting.endMinute ~/ 60,
        meeting.endMinute % 60,
      );
      final session = CourseSession(
        id: '',
        classType: draft.classType,
        room: meeting.room.trim(),
        date: date,
        weekday: meeting.weekday,
        courseName: draft.courseName.trim(),
        courseCode: courseCode,
        section: section,
        startAt: startAt,
        endAt: endAt,
        teachers: draft.teachers,
        faculty: draft.faculty.trim(),
        semester: draft.semester.trim(),
        recurrenceSeriesId: seriesId,
        recurrenceMeetingId: meeting.id,
      );
      sessions.add(session.copyWith(id: session.computeId()));
    }
  }
  sessions.sort((a, b) => a.startAt.compareTo(b.startAt));
  return sessions;
}

bool batchMeetingsOverlap(List<BatchMeeting> meetings) {
  for (var i = 0; i < meetings.length; i++) {
    for (var j = i + 1; j < meetings.length; j++) {
      final a = meetings[i];
      final b = meetings[j];
      if (a.weekday == b.weekday &&
          a.startMinute < b.endMinute &&
          b.startMinute < a.endMinute) {
        return true;
      }
    }
  }
  return false;
}
