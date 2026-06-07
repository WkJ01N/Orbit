import 'dart:convert';

import 'package:orbit/models/course_session.dart';

class ScheduleBackupException implements Exception {
  ScheduleBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScheduleBackupService {
  static const backupVersion = 1;

  String encodeToJson(List<CourseSession> sessions) {
    final payload = {
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'sessions': sessions.map(_sessionToJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  List<CourseSession> decodeFromJson(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw ScheduleBackupException('invalid_format');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ScheduleBackupException('invalid_format');
    }

    final version = decoded['version'];
    if (version is! int || version > backupVersion) {
      throw ScheduleBackupException('unsupported_version');
    }

    final sessionsRaw = decoded['sessions'];
    if (sessionsRaw is! List<dynamic>) {
      throw ScheduleBackupException('invalid_format');
    }

    return sessionsRaw
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw ScheduleBackupException('invalid_format');
          }
          return _sessionFromJson(item);
        })
        .toList();
  }

  Map<String, dynamic> _sessionToJson(CourseSession session) {
    return {
      'id': session.id,
      'classType': session.classType,
      'room': session.room,
      'date': _dateKey(session.date),
      'weekday': session.weekday,
      'courseName': session.courseName,
      'courseCode': session.courseCode,
      'section': session.section,
      'startAt': session.startAt.toIso8601String(),
      'endAt': session.endAt.toIso8601String(),
      'teachers': session.teachers,
      'faculty': session.faculty,
      'semester': session.semester,
      'sourceFile': session.sourceFile,
      'note': session.note,
    };
  }

  CourseSession _sessionFromJson(Map<String, dynamic> json) {
    final teachersRaw = json['teachers'];
    final teachers = teachersRaw is List
        ? teachersRaw.map((value) => value.toString()).toList()
        : <String>[];

    return CourseSession(
      id: json['id'] as String,
      classType: json['classType'] as String? ?? '',
      room: json['room'] as String,
      date: DateTime.parse(json['date'] as String),
      weekday: json['weekday'] as int,
      courseName: json['courseName'] as String,
      courseCode: json['courseCode'] as String? ?? '',
      section: json['section'] as String? ?? '',
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
      teachers: teachers,
      faculty: json['faculty'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      sourceFile: json['sourceFile'] as String?,
      note: json['note'] as String?,
    );
  }

  static String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
