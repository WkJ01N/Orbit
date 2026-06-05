import 'dart:convert';

class CourseSession {
  const CourseSession({
    required this.id,
    required this.classType,
    required this.room,
    required this.date,
    required this.weekday,
    required this.courseName,
    required this.courseCode,
    required this.section,
    required this.startAt,
    required this.endAt,
    required this.teachers,
    required this.faculty,
    required this.semester,
    this.sourceFile,
    this.note,
  });

  final String id;
  final String classType;
  final String room;
  final DateTime date;
  final int weekday;
  final String courseName;
  final String courseCode;
  final String section;
  final DateTime startAt;
  final DateTime endAt;
  final List<String> teachers;
  final String faculty;
  final String semester;
  final String? sourceFile;
  final String? note;

  static String buildId({
    required DateTime date,
    required String courseCode,
    required DateTime startAt,
    required String section,
  }) {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final timeKey =
        '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}';
    return '$dateKey|$courseCode|$section|$timeKey';
  }

  String computeId() {
    return buildId(
      date: date,
      courseCode: courseCode,
      startAt: startAt,
      section: section,
    );
  }

  factory CourseSession.fromMap(Map<String, Object?> map) {
    return CourseSession(
      id: map['id'] as String,
      classType: map['class_type'] as String,
      room: map['room'] as String,
      date: DateTime.parse(map['date'] as String),
      weekday: map['weekday'] as int,
      courseName: map['course_name'] as String,
      courseCode: map['course_code'] as String,
      section: map['section'] as String,
      startAt: DateTime.parse(map['start_at'] as String),
      endAt: DateTime.parse(map['end_at'] as String),
      teachers: List<String>.from(
        jsonDecode(map['teachers'] as String) as List<dynamic>,
      ),
      faculty: map['faculty'] as String,
      semester: map['semester'] as String,
      sourceFile: map['source_file'] as String?,
      note: map['note'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'class_type': classType,
      'room': room,
      'date': _dateKey(date),
      'weekday': weekday,
      'course_name': courseName,
      'course_code': courseCode,
      'section': section,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'teachers': jsonEncode(teachers),
      'faculty': faculty,
      'semester': semester,
      'source_file': sourceFile,
      'note': note,
    };
  }

  CourseSession copyWith({
    String? id,
    String? classType,
    String? room,
    DateTime? date,
    int? weekday,
    String? courseName,
    String? courseCode,
    String? section,
    DateTime? startAt,
    DateTime? endAt,
    List<String>? teachers,
    String? faculty,
    String? semester,
    String? sourceFile,
    String? note,
    bool clearNote = false,
  }) {
    return CourseSession(
      id: id ?? this.id,
      classType: classType ?? this.classType,
      room: room ?? this.room,
      date: date ?? this.date,
      weekday: weekday ?? this.weekday,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      section: section ?? this.section,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      teachers: teachers ?? this.teachers,
      faculty: faculty ?? this.faculty,
      semester: semester ?? this.semester,
      sourceFile: sourceFile ?? this.sourceFile,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  static String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
