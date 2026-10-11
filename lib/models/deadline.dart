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
    this.archivedAt,
    this.archiveHidden = false,
    this.autoArchivePaused = false,
    this.countsTowardStatistics = true,
    this.batchId,
    this.strongReminderEnabled = false,
    this.strongLeadMinutes,
    this.disabledReminderLeadMinutes = const [],
  });

  final String id;
  final String subject;
  final String title;
  final DateTime dueAt;
  final List<int> leadMinutes;
  final String? courseKey;
  final DateTime? completedAt;
  final DateTime? deletedAt;
  final DateTime? archivedAt;
  final bool archiveHidden;
  final bool autoArchivePaused;
  final bool countsTowardStatistics;
  final String? batchId;
  final bool strongReminderEnabled;

  /// Null initializes new reminder times using the 180-minute default.
  final List<int>? strongLeadMinutes;
  final List<int> disabledReminderLeadMinutes;
  List<int> get effectiveStrongLeadMinutes =>
      strongLeadMinutes ?? leadMinutes.where((m) => m > 0 && m <= 180).toList();
  bool usesStrongReminderAt(int minutes) =>
      strongReminderEnabled && effectiveStrongLeadMinutes.contains(minutes);
  bool get hasStrongReminder =>
      strongReminderEnabled && leadMinutes.any(usesStrongReminderAt);
  bool reminderEnabledAt(int minutes) =>
      !disabledReminderLeadMinutes.contains(minutes);
  bool get archived => archivedAt != null;
  bool get visible => !archived || !archiveHidden;

  bool get completed => completedAt != null;
  bool get deleted => deletedAt != null;

  Deadline copyWith({
    DateTime? completedAt,
    bool clearCompleted = false,
    DateTime? deletedAt,
    bool clearDeleted = false,
    DateTime? archivedAt,
    bool clearArchived = false,
    bool? archiveHidden,
    bool? autoArchivePaused,
    bool? countsTowardStatistics,
    bool? strongReminderEnabled,
    List<int>? strongLeadMinutes,
    List<int>? disabledReminderLeadMinutes,
  }) => Deadline(
    countsTowardStatistics:
        countsTowardStatistics ?? this.countsTowardStatistics,
    batchId: batchId,
    strongReminderEnabled: strongReminderEnabled ?? this.strongReminderEnabled,
    strongLeadMinutes: strongLeadMinutes ?? this.strongLeadMinutes,
    disabledReminderLeadMinutes:
        disabledReminderLeadMinutes ??
        (clearCompleted && completed
            ? const []
            : this.disabledReminderLeadMinutes),
    archivedAt: clearArchived ? null : archivedAt ?? this.archivedAt,
    archiveHidden: clearArchived ? false : archiveHidden ?? this.archiveHidden,
    autoArchivePaused:
        autoArchivePaused ??
        (completedAt != null && completedAt != this.completedAt
            ? false
            : this.autoArchivePaused),
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
    'archived_at': archivedAt?.toUtc().toIso8601String(),
    'archive_hidden': archiveHidden ? 1 : 0,
    'auto_archive_paused': autoArchivePaused ? 1 : 0,
    'counts_toward_statistics': countsTowardStatistics ? 1 : 0,
    'batch_id': batchId,
    'strong_reminder_enabled': strongReminderEnabled ? 1 : 0,
    'strong_lead_minutes': strongLeadMinutes == null
        ? null
        : jsonEncode(strongLeadMinutes),
    'disabled_reminder_lead_minutes': jsonEncode(disabledReminderLeadMinutes),
  };

  factory Deadline.fromMap(Map<String, Object?> value) => Deadline(
    countsTowardStatistics: value['counts_toward_statistics'] != 0,
    batchId: value['batch_id'] as String?,
    strongReminderEnabled: value['strong_reminder_enabled'] == 1,
    strongLeadMinutes: value['strong_lead_minutes'] == null
        ? null
        : List<int>.from(
            jsonDecode(value['strong_lead_minutes'] as String) as List,
          ),
    disabledReminderLeadMinutes: value['disabled_reminder_lead_minutes'] == null
        ? const []
        : List<int>.from(
            jsonDecode(value['disabled_reminder_lead_minutes'] as String)
                as List,
          ),
    archivedAt: value['archived_at'] == null
        ? null
        : DateTime.parse(value['archived_at'] as String).toLocal(),
    archiveHidden: value['archive_hidden'] == 1,
    autoArchivePaused: value['auto_archive_paused'] == 1,
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
    'countsTowardStatistics': countsTowardStatistics,
    'batchId': batchId,
    'strongReminderEnabled': strongReminderEnabled,
    'strongLeadMinutes': strongLeadMinutes,
    'disabledReminderLeadMinutes': disabledReminderLeadMinutes,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
    'archivedAt': archivedAt?.toUtc().toIso8601String(),
    'archiveHidden': archiveHidden,
    'autoArchivePaused': autoArchivePaused,
    'id': id,
    'subject': subject,
    'title': title,
    'dueAt': dueAt.toUtc().toIso8601String(),
    'leadMinutes': leadMinutes,
    'courseKey': courseKey,
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };

  factory Deadline.fromSyncPayload(Map<String, dynamic> value) => Deadline(
    countsTowardStatistics: value['countsTowardStatistics'] != false,
    batchId: value['batchId'] as String?,
    strongReminderEnabled: value['strongReminderEnabled'] == true,
    strongLeadMinutes: value['strongLeadMinutes'] == null
        ? null
        : List<int>.from(value['strongLeadMinutes'] as List),
    disabledReminderLeadMinutes: List<int>.from(
      value['disabledReminderLeadMinutes'] as List? ?? const [],
    ),
    deletedAt: value['deletedAt'] == null
        ? null
        : DateTime.parse(value['deletedAt'] as String).toLocal(),
    archivedAt: value['archivedAt'] == null
        ? null
        : DateTime.parse(value['archivedAt'] as String).toLocal(),
    archiveHidden: value['archiveHidden'] == true,
    autoArchivePaused: value['autoArchivePaused'] == true,
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
