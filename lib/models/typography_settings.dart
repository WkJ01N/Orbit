import 'package:flutter/material.dart';

class ImportedFont {
  const ImportedFont({
    required this.id,
    required this.name,
    required this.extension,
  });
  final String id, name, extension;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'extension': extension,
  };
  factory ImportedFont.fromJson(Map<String, dynamic> json) {
    final id = json['id'], name = json['name'], extension = json['extension'];
    if (id is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 120 ||
        !['ttf', 'otf'].contains(extension)) {
      throw const FormatException('Invalid font descriptor');
    }
    return ImportedFont(id: id, name: name, extension: extension as String);
  }
}

class TypographySettings {
  const TypographySettings({
    this.appFontId = 'system',
    this.launchFontId = 'nunito',
    this.fallbackFontIds = const [],
    this.imports = const {},
    this.loadWarning = false,
    this.unavailableFontIds = const {},
  });
  final String appFontId, launchFontId;
  final List<String> fallbackFontIds;
  List<String> fallbackFamilies(String primary) => [
    for (final id in fallbackFontIds)
      if (id != primary && !unavailableFontIds.contains(id))
        FontCatalog.family(id),
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Segoe UI',
  ];
  final Map<String, ImportedFont> imports;
  final bool loadWarning;
  final Set<String> unavailableFontIds;
  String get effectiveAppFontId =>
      unavailableFontIds.contains(appFontId) ? 'system' : appFontId;
  String get effectiveLaunchFontId =>
      unavailableFontIds.contains(launchFontId) ? 'nunito' : launchFontId;
  Set<String> get selected => {appFontId, launchFontId, ...fallbackFontIds};
  TypographySettings copyWith({
    String? appFontId,
    String? launchFontId,
    List<String>? fallbackFontIds,
    Map<String, ImportedFont>? imports,
    bool? loadWarning,
    Set<String>? unavailableFontIds,
  }) => TypographySettings(
    appFontId: appFontId ?? this.appFontId,
    launchFontId: launchFontId ?? this.launchFontId,
    fallbackFontIds: fallbackFontIds ?? this.fallbackFontIds,
    imports: imports ?? this.imports,
    loadWarning: loadWarning ?? this.loadWarning,
    unavailableFontIds: unavailableFontIds ?? this.unavailableFontIds,
  );
  Map<String, dynamic> toJson({bool usedOnly = false}) => {
    'fallbackFontIds': fallbackFontIds,
    'appFontId': appFontId,
    'launchFontId': launchFontId,
    'imports': [
      for (final font in imports.values)
        if (!usedOnly || selected.contains(font.id)) font.toJson(),
    ],
  };
  factory TypographySettings.fromJson(Map<String, dynamic> json) {
    final fonts = <String, ImportedFont>{};
    final raw = json['imports'] ?? [];
    if (raw is! List || raw.length > 100) {
      throw const FormatException('Invalid font library');
    }
    for (final item in raw) {
      final font = ImportedFont.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
      if (fonts.containsKey(font.id)) {
        throw const FormatException('Duplicate font');
      }
      fonts[font.id] = font;
    }
    String selection(String key, String fallback) {
      final value = json[key] ?? fallback;
      if (value is! String ||
          (!FontCatalog.builtins.containsKey(value) &&
              value != 'system' &&
              !fonts.containsKey(value))) {
        throw const FormatException('Unknown font selection');
      }
      return value;
    }

    final fallback = List<String>.from(
      json['fallbackFontIds'] as List? ?? const [],
    );
    if (fallback.length > 3 ||
        fallback.toSet().length != fallback.length ||
        fallback.any(
          (id) =>
              id == 'system' ||
              (!FontCatalog.builtins.containsKey(id) && !fonts.containsKey(id)),
        )) {
      throw const FormatException('Invalid fallback fonts');
    }
    return TypographySettings(
      fallbackFontIds: fallback,
      appFontId: selection('appFontId', 'system'),
      launchFontId: selection('launchFontId', 'nunito'),
      imports: fonts,
    );
  }
}

class FontCatalog {
  static const builtins = {
    'rounded': [
      'assets/fonts/ResourceHanRoundedCN-Regular.ttf',
      'assets/fonts/ResourceHanRoundedCN-Bold.ttf',
    ],
    'huninn': ['assets/fonts/Huninn.ttf'],
    'maiyuan': ['assets/fonts/Maiyuan.ttf'],
    'nunito': ['assets/fonts/Nunito.ttf'],
  };
  static String family(String id) =>
      id == 'nunito' ? 'OrbitBrand' : 'OrbitFont_$id';
  static String systemFamily(TargetPlatform platform, Locale locale) =>
      platform == TargetPlatform.windows
      ? (locale.languageCode == 'zh' ? 'Microsoft YaHei UI' : 'Segoe UI')
      : platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
      ? '.SF UI Text'
      : 'Roboto';
  static List<String> fallback(String id) => [
    if (id != 'rounded' && id != 'system') family('rounded'),
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Segoe UI',
  ];
}
