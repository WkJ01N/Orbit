import 'package:orbit/models/course_session.dart';

enum CourseOperationScope { single, fromSelected, all }

final class CourseSeriesKey {
  const CourseSeriesKey(this.value);

  factory CourseSeriesKey.fromSession(CourseSession session) {
    final code = _normalize(session.courseCode);
    final section = _normalize(session.section);
    final identity = code.isNotEmpty && !code.startsWith('manual|')
        ? 'code:$code'
        : 'name:${_normalize(session.courseName)}';
    return CourseSeriesKey('$identity|section:$section');
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      other is CourseSeriesKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class CourseOperationPreview {
  const CourseOperationPreview({
    required this.targetCount,
    required this.conflictCount,
    required this.firstDate,
    required this.lastDate,
  });

  final int targetCount;
  final int conflictCount;
  final DateTime firstDate;
  final DateTime lastDate;
}

class CourseOperationResult {
  const CourseOperationResult({
    required this.affectedCount,
    this.conflictCount = 0,
  });

  final int affectedCount;
  final int conflictCount;
}

class RestoreDeletedResult {
  const RestoreDeletedResult({required this.restored, required this.skipped});

  final int restored;
  final int skipped;
}
