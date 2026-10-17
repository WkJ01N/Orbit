import 'dart:isolate';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';

List<CourseSession> _courses(List<Map<String, Object?>> rows) =>
    rows.map(CourseSession.fromMap).toList();
List<Deadline> _deadlines(List<Map<String, Object?>> rows) =>
    rows.map(Deadline.fromMap).toList();

/// SQLite I/O is asynchronous; materializing thousands of dates/JSON teachers
/// must also leave the UI isolate. The worker only receives detached row data,
/// never a database handle, provider, or platform channel.
Future<List<CourseSession>> decodeCourseRows(List<Map<String, Object?>> rows) {
  if (rows.length < 200) return Future.value(_courses(rows));
  final detached = rows
      .map((row) => Map<String, Object?>.from(row))
      .toList(growable: false);
  return Isolate.run(() => _courses(detached), debugName: 'orbit-course-rows');
}

Future<List<Deadline>> decodeDeadlineRows(List<Map<String, Object?>> rows) {
  if (rows.length < 200) return Future.value(_deadlines(rows));
  final detached = rows
      .map((row) => Map<String, Object?>.from(row))
      .toList(growable: false);
  return Isolate.run(
    () => _deadlines(detached),
    debugName: 'orbit-deadline-rows',
  );
}
