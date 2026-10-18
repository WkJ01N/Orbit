enum CardEntranceMode { edge, nearby }

/// Device-local presentation preferences; image paths are not portable.
class LaunchSettings {
  const LaunchSettings({
    this.iconPath,
    this.cardEntrance = CardEntranceMode.edge,
    this.brandEnabled = true,
    this.onStartup = true,
    this.onResume = false,
    this.onPageSwitch = false,
    this.pageEnabled = const [true, true, true, true],
  });

  final String? iconPath;
  final CardEntranceMode cardEntrance;
  final bool brandEnabled, onStartup, onResume, onPageSwitch;
  final List<bool> pageEnabled;
  LaunchSettings copyWith({
    String? iconPath,
    bool clearIcon = false,
    CardEntranceMode? cardEntrance,
    bool? brandEnabled,
    bool? onStartup,
    bool? onResume,
    bool? onPageSwitch,
    List<bool>? pageEnabled,
  }) => LaunchSettings(
    iconPath: clearIcon ? null : iconPath ?? this.iconPath,
    cardEntrance: cardEntrance ?? this.cardEntrance,
    brandEnabled: brandEnabled ?? this.brandEnabled,
    onStartup: onStartup ?? this.onStartup,
    onResume: onResume ?? this.onResume,
    onPageSwitch: onPageSwitch ?? this.onPageSwitch,
    pageEnabled: pageEnabled ?? this.pageEnabled,
  );

  factory LaunchSettings.fromJson(Map<String, dynamic> json) => LaunchSettings(
    brandEnabled: json['brandEnabled'] as bool? ?? true,
    onStartup: json['onStartup'] as bool? ?? true,
    onResume: json['onResume'] as bool? ?? false,
    onPageSwitch: json['onPageSwitch'] as bool? ?? false,
    pageEnabled:
        json['pageEnabled'] is List &&
            (json['pageEnabled'] as List).length == 4 &&
            (json['pageEnabled'] as List).every((v) => v is bool)
        ? List<bool>.from(json['pageEnabled'] as List)
        : const [true, true, true, true],
    iconPath: json['iconPath'] is String ? json['iconPath'] as String : null,
    cardEntrance: json['cardEntrance'] == 'nearby'
        ? CardEntranceMode.nearby
        : CardEntranceMode.edge,
  );

  Map<String, dynamic> toJson() => {
    if (iconPath != null) 'iconPath': iconPath,
    'cardEntrance': cardEntrance.name,
    'brandEnabled': brandEnabled,
    'onStartup': onStartup,
    'onResume': onResume,
    'onPageSwitch': onPageSwitch,
    'pageEnabled': pageEnabled,
  };
}
