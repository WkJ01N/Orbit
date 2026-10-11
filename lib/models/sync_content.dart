import 'package:orbit/models/account_sync.dart';

enum SyncCategory {
  courses,
  deadlines,
  templates,
  semesters,
  periods,
  appearance,
  colors,
  display,
  reminders,
  strong,
  archive,
  statistics,
}

enum SyncScopeMode { perDevice, shared }

class SyncSelection {
  const SyncSelection(this.enabled);
  static const defaults = SyncSelection({
    SyncCategory.courses,
    SyncCategory.deadlines,
    SyncCategory.templates,
    SyncCategory.semesters,
    SyncCategory.periods,
    SyncCategory.statistics,
  });
  final Set<SyncCategory> enabled;
  Map<String, dynamic> toJson() => {
    for (final c in SyncCategory.values) c.name: enabled.contains(c),
  };
  factory SyncSelection.fromJson(Map<String, dynamic> json) => SyncSelection({
    for (final c in SyncCategory.values)
      if (json[c.name] == true ||
          (c == SyncCategory.statistics && !json.containsKey(c.name)))
        c,
  });
  SyncSelection toggle(SyncCategory c, bool value) => SyncSelection(
    {...enabled}
      ..remove(c)
      ..addAll(value ? [c] : []),
  );
  bool allows(SyncEntity entity) => enabled.contains(categoryFor(entity));
  static SyncCategory? categoryFor(SyncEntity entity) => switch (entity.type) {
    SyncEntityType.courseSession => SyncCategory.courses,
    SyncEntityType.deadline => SyncCategory.deadlines,
    SyncEntityType.statistic => SyncCategory.statistics,
    SyncEntityType.importTemplate => SyncCategory.templates,
    SyncEntityType.semesterPlan => SyncCategory.semesters,
    SyncEntityType.periodTimePlan => SyncCategory.periods,
    SyncEntityType.settingGroup =>
      SyncCategory.values.where((c) => c.name == entity.id).firstOrNull,
  };
}

class SyncScopePolicy {
  const SyncScopePolicy({
    this.mode = SyncScopeMode.perDevice,
    this.selection = SyncSelection.defaults,
    this.revision = 0,
  });
  final SyncScopeMode mode;
  final SyncSelection selection;
  final int revision;
  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'selection': selection.toJson(),
    'revision': revision,
  };
  factory SyncScopePolicy.fromJson(Map<String, dynamic> json) =>
      SyncScopePolicy(
        mode: json['mode'] == 'shared'
            ? SyncScopeMode.shared
            : SyncScopeMode.perDevice,
        selection: json['selection'] is Map
            ? SyncSelection.fromJson(
                Map<String, dynamic>.from(json['selection']),
              )
            : SyncSelection.defaults,
        revision: json['revision'] as int? ?? 0,
      );
}
