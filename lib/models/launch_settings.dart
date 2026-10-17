enum CardEntranceMode { edge, nearby }

/// Device-local presentation preferences; image paths are not portable.
class LaunchSettings {
  const LaunchSettings({
    this.iconPath,
    this.cardEntrance = CardEntranceMode.edge,
  });

  final String? iconPath;
  final CardEntranceMode cardEntrance;

  factory LaunchSettings.fromJson(Map<String, dynamic> json) => LaunchSettings(
    iconPath: json['iconPath'] is String ? json['iconPath'] as String : null,
    cardEntrance: json['cardEntrance'] == 'nearby'
        ? CardEntranceMode.nearby
        : CardEntranceMode.edge,
  );

  Map<String, dynamic> toJson() => {
    if (iconPath != null) 'iconPath': iconPath,
    'cardEntrance': cardEntrance.name,
  };
}
