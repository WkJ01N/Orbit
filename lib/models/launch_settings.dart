enum CardEntranceMode { edge, nearby }

enum PageTransitionStyle { compact, fluid }

enum PageTransitionSpeed {
  fast(280),
  standard(360),
  relaxed(440);

  const PageTransitionSpeed(this.milliseconds);
  final int milliseconds;
}

/// Device-local presentation preferences; image paths are not portable.
class LaunchSettings {
  const LaunchSettings({
    this.iconPath,
    this.cardEntrance = CardEntranceMode.edge,
    this.brandEnabled = true,
    this.onStartup = true,
    this.onResume = false,
    bool onPageSwitch = false,
    PageTransitionStyle? pageTransitionStyle,
    this.pageTransitionSpeed = PageTransitionSpeed.standard,
    this.pageEnabled = const [true, true, true, true],
  }) : pageTransitionStyle =
           pageTransitionStyle ??
           (onPageSwitch
               ? PageTransitionStyle.fluid
               : PageTransitionStyle.compact);

  final String? iconPath;
  final CardEntranceMode cardEntrance;
  final bool brandEnabled, onStartup, onResume;
  final PageTransitionStyle pageTransitionStyle;
  final PageTransitionSpeed pageTransitionSpeed;
  bool get onPageSwitch => pageTransitionStyle == PageTransitionStyle.fluid;
  Duration get transitionDuration =>
      Duration(milliseconds: pageTransitionSpeed.milliseconds);
  final List<bool> pageEnabled;
  LaunchSettings copyWith({
    String? iconPath,
    bool clearIcon = false,
    CardEntranceMode? cardEntrance,
    bool? brandEnabled,
    bool? onStartup,
    bool? onResume,
    bool? onPageSwitch,
    PageTransitionStyle? pageTransitionStyle,
    PageTransitionSpeed? pageTransitionSpeed,
    List<bool>? pageEnabled,
  }) => LaunchSettings(
    iconPath: clearIcon ? null : iconPath ?? this.iconPath,
    cardEntrance: cardEntrance ?? this.cardEntrance,
    brandEnabled: brandEnabled ?? this.brandEnabled,
    onStartup: onStartup ?? this.onStartup,
    onResume: onResume ?? this.onResume,
    onPageSwitch: onPageSwitch ?? this.onPageSwitch,
    pageTransitionStyle:
        pageTransitionStyle ??
        (onPageSwitch == null ? this.pageTransitionStyle : null),
    pageTransitionSpeed: pageTransitionSpeed ?? this.pageTransitionSpeed,
    pageEnabled: pageEnabled ?? this.pageEnabled,
  );

  factory LaunchSettings.fromJson(Map<String, dynamic> json) => LaunchSettings(
    brandEnabled: json['brandEnabled'] as bool? ?? true,
    onStartup: json['onStartup'] as bool? ?? true,
    onResume: json['onResume'] as bool? ?? false,
    onPageSwitch: json['onPageSwitch'] as bool? ?? false,
    pageTransitionStyle: PageTransitionStyle.values
        .where((v) => v.name == json['pageTransitionStyle'])
        .firstOrNull,
    pageTransitionSpeed:
        PageTransitionSpeed.values
            .where((v) => v.name == json['pageTransitionSpeed'])
            .firstOrNull ??
        PageTransitionSpeed.standard,
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
    'pageTransitionStyle': pageTransitionStyle.name,
    'pageTransitionSpeed': pageTransitionSpeed.name,
    'pageEnabled': pageEnabled,
  };
}
