import 'dart:convert';

import 'package:orbit/models/course_session.dart';

enum SyncEntityType {
  courseSession,
  importTemplate,
  semesterPlan,
  periodTimePlan,
  deadline,
}

enum SyncOperation { upsert, delete }

enum SyncPhase { disabled, idle, syncing, offline, needsInitialMerge, error }

class SyncEntity {
  const SyncEntity({
    required this.type,
    required this.id,
    required this.payload,
    this.schemaVersion = 1,
    this.revision = 0,
    this.deleted = false,
  });

  final SyncEntityType type;
  final String id;
  final Map<String, dynamic> payload;
  final int schemaVersion;
  final int revision;
  final bool deleted;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'id': id,
    'schemaVersion': schemaVersion,
    'revision': revision,
    'deleted': deleted,
    'payload': payload,
  };

  factory SyncEntity.fromJson(Map<String, dynamic> json) => SyncEntity(
    type: SyncEntityType.values.byName(json['type'] as String),
    id: json['id'] as String,
    schemaVersion: json['schemaVersion'] as int? ?? 1,
    revision: json['revision'] as int? ?? 0,
    deleted: json['deleted'] as bool? ?? false,
    payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
  );
}

class SyncMutation {
  const SyncMutation({
    required this.mutationId,
    required this.entity,
    required this.operation,
    required this.baseRevision,
  });

  final String mutationId;
  final SyncEntity entity;
  final SyncOperation operation;
  final int baseRevision;

  Map<String, dynamic> toJson() => {
    'mutationId': mutationId,
    'operation': operation.name,
    'baseRevision': baseRevision,
    'entity': entity.toJson(),
  };

  factory SyncMutation.fromJson(Map<String, dynamic> json) => SyncMutation(
    mutationId: json['mutationId'] as String,
    operation: SyncOperation.values.byName(json['operation'] as String),
    baseRevision: json['baseRevision'] as int? ?? 0,
    entity: SyncEntity.fromJson(
      Map<String, dynamic>.from(json['entity'] as Map),
    ),
  );
}

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.local,
    required this.remote,
    required this.createdAt,
  });

  final String id;
  final SyncMutation local;
  final SyncEntity remote;
  final DateTime createdAt;
}

class SyncAccount {
  const SyncAccount({
    required this.uid,
    required this.email,
    this.username,
    this.avatarFileId,
  });

  final String uid;
  final String email;
  final String? username;
  final String? avatarFileId;
}

class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.disabled,
    this.account,
    this.pendingCount = 0,
    this.conflictCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  final SyncPhase phase;
  final SyncAccount? account;
  final int pendingCount;
  final int conflictCount;
  final DateTime? lastSyncedAt;
  final String? message;

  bool get signedIn => account != null;

  SyncStatus copyWith({
    SyncPhase? phase,
    SyncAccount? account,
    bool clearAccount = false,
    int? pendingCount,
    int? conflictCount,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? message,
    bool clearMessage = false,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    account: clearAccount ? null : (account ?? this.account),
    pendingCount: pendingCount ?? this.pendingCount,
    conflictCount: conflictCount ?? this.conflictCount,
    lastSyncedAt: clearLastSyncedAt
        ? null
        : (lastSyncedAt ?? this.lastSyncedAt),
    message: clearMessage ? null : (message ?? this.message),
  );
}

class SyncPushResult {
  const SyncPushResult({
    this.accepted = const {},
    this.conflicts = const [],
    required this.cursor,
  });

  final Map<String, int> accepted;
  final List<SyncConflict> conflicts;
  final int cursor;
}

class SyncExchangeResult {
  const SyncExchangeResult({required this.push, required this.pull});

  final SyncPushResult push;
  final SyncPullResult pull;
}

class SyncPullResult {
  const SyncPullResult({
    this.entities = const [],
    required this.cursor,
    this.hasMore = false,
  });

  final List<SyncEntity> entities;
  final int cursor;
  final bool hasMore;
}

class InitialSyncPreview {
  const InitialSyncPreview({
    this.localOnly = const [],
    this.remoteOnly = const [],
    this.identical = const [],
    this.conflicts = const [],
  });

  final List<SyncEntity> localOnly;
  final List<SyncEntity> remoteOnly;
  final List<SyncEntity> identical;
  final List<SyncConflict> conflicts;

  bool get isEmpty =>
      localOnly.isEmpty &&
      remoteOnly.isEmpty &&
      identical.isEmpty &&
      conflicts.isEmpty;
}

Map<String, dynamic> courseSessionSyncPayload(CourseSession session) => {
  'id': session.id,
  'classType': session.classType,
  'room': session.room,
  'date': session.date.toIso8601String(),
  'weekday': session.weekday,
  'courseName': session.courseName,
  'courseCode': session.courseCode,
  'section': session.section,
  'startAt': session.startAt.toIso8601String(),
  'endAt': session.endAt.toIso8601String(),
  'teachers': session.teachers,
  'faculty': session.faculty,
  'semester': session.semester,
  'note': session.note,
  'recurrenceSeriesId': session.recurrenceSeriesId,
  'recurrenceMeetingId': session.recurrenceMeetingId,
};

CourseSession courseSessionFromSyncPayload(Map<String, dynamic> json) =>
    CourseSession(
      id: json['id'] as String,
      classType: json['classType'] as String? ?? '',
      room: json['room'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      weekday: json['weekday'] as int,
      courseName: json['courseName'] as String,
      courseCode: json['courseCode'] as String? ?? '',
      section: json['section'] as String? ?? '',
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
      teachers: List<String>.from(json['teachers'] as List? ?? const []),
      faculty: json['faculty'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      note: json['note'] as String?,
      recurrenceSeriesId: json['recurrenceSeriesId'] as String?,
      recurrenceMeetingId: json['recurrenceMeetingId'] as String?,
    );

String canonicalSyncPayload(Map<String, dynamic> payload) {
  dynamic normalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return {for (final key in keys) key: normalize(value[key])};
    }
    if (value is List) return value.map(normalize).toList();
    return value;
  }

  return jsonEncode(normalize(payload));
}
