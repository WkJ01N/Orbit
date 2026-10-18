enum SessionAction { edit, note, archive, delete }

enum QuickActionEdgeMode { merge, floatInward }

class CourseQuickActionSettings {
  const CourseQuickActionSettings({
    this.enabled = true,
    this.edgeMode = QuickActionEdgeMode.merge,
    this.positions = const [
      SessionAction.edit,
      SessionAction.note,
      SessionAction.delete,
      SessionAction.archive,
    ],
  });
  final bool enabled;
  final QuickActionEdgeMode edgeMode;

  /// Clockwise, starting at the top. Every action occurs exactly once.
  final List<SessionAction> positions;
  CourseQuickActionSettings copyWith({
    bool? enabled,
    QuickActionEdgeMode? edgeMode,
    List<SessionAction>? positions,
  }) => CourseQuickActionSettings(
    enabled: enabled ?? this.enabled,
    edgeMode: edgeMode ?? this.edgeMode,
    positions: positions ?? this.positions,
  );
  CourseQuickActionSettings swap(int direction, SessionAction action) {
    final next = positions.toList();
    final previous = next.indexOf(action);
    next[previous] = next[direction];
    next[direction] = action;
    return copyWith(positions: List.unmodifiable(next));
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'edgeMode': edgeMode.name,
    'positions': positions.map((v) => v.name).toList(),
  };
  factory CourseQuickActionSettings.fromJson(Map<String, dynamic> json) {
    final positions =
        (json['positions'] is List ? json['positions'] as List : const [])
            .map(
              (name) =>
                  SessionAction.values.where((a) => a.name == name).firstOrNull,
            )
            .toList();
    return CourseQuickActionSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      edgeMode: json['edgeMode'] == 'floatInward'
          ? QuickActionEdgeMode.floatInward
          : QuickActionEdgeMode.merge,
      positions:
          positions.length == 4 &&
              !positions.contains(null) &&
              positions.toSet().length == 4
          ? List.unmodifiable(positions.cast<SessionAction>())
          : const [
              SessionAction.edit,
              SessionAction.note,
              SessionAction.delete,
              SessionAction.archive,
            ],
    );
  }
}
