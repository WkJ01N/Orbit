import 'dart:convert';

class Deadline {
  const Deadline({
    required this.id,
    required this.subject,
    required this.title,
    required this.dueAt,
    required this.leadMinutes,
    this.courseKey,
    this.completedAt,
    this.deletedAt,
  });

  final String id;
  final String subject;
  final String title;
  final DateTime dueAt;
  final List<int> leadMinutes;
  final String? courseKey;
  final DateTime? completedAt;
  final DateTime? deletedAt;

  bool get completed => completedAt != null;
  bool get deleted => deletedAt != null;

  Deadline copyWith({
    DateTime? completedAt,
    bool clearCompleted = false,
    DateTime? deletedAt,
    bool clearDeleted = false,
  }) => Deadline(
    id: id,
    subject: subject,
    title: title,
    dueAt: dueAt,
    leadMinutes: leadMinutes,
    courseKey: courseKey,
    completedAt: clearCompleted ? null : completedAt ?? this.completedAt,
    deletedAt: clearDeleted ? null : deletedAt ?? this.deletedAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'subject': subject,
    'title': title,
    'due_at': dueAt.toUtc().toIso8601String(),
    'lead_minutes': jsonEncode(leadMinutes),
    'course_key': courseKey,
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  factory Deadline.fromMap(Map<String, Object?> value) => Deadline(
    id: value['id'] as String,
    subject: value['subject'] as String,
    title: value['title'] as String,
    dueAt: DateTime.parse(value['due_at'] as String).toLocal(),
    leadMinutes: List<int>.from(
      jsonDecode(value['lead_minutes'] as String) as List,
    ),
    courseKey: value['course_key'] as String?,
    completedAt: value['completed_at'] == null
        ? null
        : DateTime.parse(value['completed_at'] as String).toLocal(),
    deletedAt: value['deleted_at'] == null
        ? null
        : DateTime.parse(value['deleted_at'] as String).toLocal(),
  );

  Map<String, dynamic> toSyncPayload() => {
    'id': id,
    'subject': subject,
    'title': title,
    'dueAt': dueAt.toUtc().toIso8601String(),
    'leadMinutes': leadMinutes,
    'courseKey': courseKey,
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };

  factory Deadline.fromSyncPayload(Map<String, dynamic> value) => Deadline(
    id: value['id'] as String,
    subject: value['subject'] as String,
    title: value['title'] as String,
    dueAt: DateTime.parse(value['dueAt'] as String).toLocal(),
    leadMinutes: List<int>.from(value['leadMinutes'] as List),
    courseKey: value['courseKey'] as String?,
    completedAt: value['completedAt'] == null
        ? null
        : DateTime.parse(value['completedAt'] as String).toLocal(),
  );
}
