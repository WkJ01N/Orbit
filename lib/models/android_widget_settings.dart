import 'package:flutter/foundation.dart';

@immutable
class AndroidWidgetSettings {
  const AndroidWidgetSettings({
    this.showDeadlines = true,
    this.deadlineLookaheadDays = 3,
    this.backgroundOpacity = 92,
  });

  static const int minOpacity = 35;
  static const int maxOpacity = 100;
  static const List<int> allowedLookaheadDays = [1, 3, 7];

  final bool showDeadlines;
  final int deadlineLookaheadDays;
  final int backgroundOpacity;

  static int normalizeLookaheadDays(int value) =>
      allowedLookaheadDays.contains(value) ? value : 3;

  static int normalizeOpacity(int value) => value.clamp(minOpacity, maxOpacity);

  AndroidWidgetSettings copyWith({
    bool? showDeadlines,
    int? deadlineLookaheadDays,
    int? backgroundOpacity,
  }) => AndroidWidgetSettings(
    showDeadlines: showDeadlines ?? this.showDeadlines,
    deadlineLookaheadDays: normalizeLookaheadDays(
      deadlineLookaheadDays ?? this.deadlineLookaheadDays,
    ),
    backgroundOpacity: normalizeOpacity(
      backgroundOpacity ?? this.backgroundOpacity,
    ),
  );

  Map<String, dynamic> toJson() => {
    'showDeadlines': showDeadlines,
    'deadlineLookaheadDays': normalizeLookaheadDays(deadlineLookaheadDays),
    'backgroundOpacity': normalizeOpacity(backgroundOpacity),
  };

  factory AndroidWidgetSettings.fromJson(Map<String, dynamic> json) =>
      AndroidWidgetSettings(
        showDeadlines: json['showDeadlines'] as bool? ?? true,
        deadlineLookaheadDays: normalizeLookaheadDays(
          (json['deadlineLookaheadDays'] as num?)?.toInt() ?? 3,
        ),
        backgroundOpacity: normalizeOpacity(
          (json['backgroundOpacity'] as num?)?.toInt() ?? 92,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is AndroidWidgetSettings &&
      other.showDeadlines == showDeadlines &&
      other.deadlineLookaheadDays == deadlineLookaheadDays &&
      other.backgroundOpacity == backgroundOpacity;

  @override
  int get hashCode =>
      Object.hash(showDeadlines, deadlineLookaheadDays, backgroundOpacity);
}
