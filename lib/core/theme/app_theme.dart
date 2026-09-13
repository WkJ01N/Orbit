import 'package:flutter/material.dart';
import 'package:material_color_utilities/hct/hct.dart';

/// Default brand color — #39C5BB
const kDefaultThemeColor = Color(0xFF39C5BB);

enum AppThemeStyle { standard, colorful }

enum AppColorScheme {
  original,
  vibrant,
  expressive,
  rainbow,
  fruitSalad,
  content,
  fidelity,
  neutral,
  monochrome,
}

DynamicSchemeVariant schemeVariant(AppColorScheme scheme) => switch (scheme) {
  AppColorScheme.original => DynamicSchemeVariant.tonalSpot,
  AppColorScheme.vibrant => DynamicSchemeVariant.vibrant,
  AppColorScheme.expressive => DynamicSchemeVariant.expressive,
  AppColorScheme.rainbow => DynamicSchemeVariant.rainbow,
  AppColorScheme.fruitSalad => DynamicSchemeVariant.fruitSalad,
  AppColorScheme.content => DynamicSchemeVariant.content,
  AppColorScheme.fidelity => DynamicSchemeVariant.fidelity,
  AppColorScheme.neutral => DynamicSchemeVariant.neutral,
  AppColorScheme.monochrome => DynamicSchemeVariant.monochrome,
};

/// Curated preset swatches for the theme color picker.
const kThemePresetColors = <Color>[
  Color(0xFF39C5BB), // default teal
  Color(0xFF3B6BF6), // blue
  Color(0xFF7C4DFF), // purple
  Color(0xFFE91E63), // pink
  Color(0xFFFF5722), // deep orange
  Color(0xFFFF9800), // orange
  Color(0xFF4CAF50), // green
  Color(0xFF009688), // teal
  Color(0xFF607D8B), // blue grey
];

class AppTheme {
  static ThemeData light({
    Color seed = kDefaultThemeColor,
    AppThemeStyle style = AppThemeStyle.standard,
    AppColorScheme scheme = AppColorScheme.original,
    bool useWindowsCjkFont = false,
    MulticolorSettings? multicolor,
  }) {
    final colorScheme = multicolor?.enabled == true
        ? multicolor!.colors(Brightness.light)
        : ColorScheme.fromSeed(
            seedColor: seed,
            dynamicSchemeVariant: schemeVariant(scheme),
            brightness: Brightness.light,
          );
    return _baseTheme(
      colorScheme,
      style,
      useWindowsCjkFont,
      multicolor: multicolor?.enabled == true,
    );
  }

  static ThemeData dark({
    Color seed = kDefaultThemeColor,
    AppThemeStyle style = AppThemeStyle.standard,
    AppColorScheme scheme = AppColorScheme.original,
    bool useWindowsCjkFont = false,
    MulticolorSettings? multicolor,
  }) {
    final colorScheme = multicolor?.enabled == true
        ? multicolor!.colors(Brightness.dark)
        : ColorScheme.fromSeed(
            seedColor: seed,
            dynamicSchemeVariant: schemeVariant(scheme),
            brightness: Brightness.dark,
          );
    return _baseTheme(
      colorScheme,
      style,
      useWindowsCjkFont,
      multicolor: multicolor?.enabled == true,
    );
  }

  static ThemeData _baseTheme(
    ColorScheme colorScheme,
    AppThemeStyle style,
    bool useWindowsCjkFont, {
    bool multicolor = false,
  }) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: useWindowsCjkFont ? 'Microsoft YaHei UI' : null,
      fontFamilyFallback: useWindowsCjkFont
          ? const ['Microsoft YaHei', 'Segoe UI']
          : null,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: colorScheme.primaryContainer,
        labelType: NavigationRailLabelType.selected,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: multicolor
            ? colorScheme.secondary
            : colorScheme.onSurfaceVariant,
        selectedColor: multicolor ? colorScheme.onSecondaryContainer : null,
        selectedTileColor: multicolor ? colorScheme.secondaryContainer : null,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: multicolor ? colorScheme.tertiaryContainer : null,
        labelStyle: multicolor
            ? TextStyle(color: colorScheme.onTertiaryContainer)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      checkboxTheme: multicolor
          ? CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colorScheme.secondary
                    : null,
              ),
              checkColor: WidgetStatePropertyAll(colorScheme.onSecondary),
            )
          : null,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.brightness == Brightness.light
            ? colorScheme.surfaceContainerHigh
            : colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.brightness == Brightness.light
              ? colorScheme.onSurface
              : colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.brightness == Brightness.light
            ? colorScheme.primary
            : colorScheme.inversePrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: colorScheme.brightness == Brightness.light
          ? FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
            )
          : null,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      extensions: [OrbitThemeStyle(style)],
    );
  }
}

@immutable
class OrbitThemeStyle extends ThemeExtension<OrbitThemeStyle> {
  const OrbitThemeStyle(this.style);

  final AppThemeStyle style;

  @override
  OrbitThemeStyle copyWith({AppThemeStyle? style}) {
    return OrbitThemeStyle(style ?? this.style);
  }

  @override
  OrbitThemeStyle lerp(OrbitThemeStyle? other, double t) {
    return t < 0.5 ? this : (other ?? this);
  }
}

AppThemeStyle appThemeStyleOf(BuildContext context) {
  return Theme.of(context).extension<OrbitThemeStyle>()?.style ??
      AppThemeStyle.standard;
}

/// Parses a 6-digit hex string (optional leading `#`) into a [Color].
/// Returns null if invalid.
Color? parseThemeHexColor(String input) {
  var hex = input.trim();
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }
  if (hex.length != 6) {
    return null;
  }
  final value = int.tryParse(hex, radix: 16);
  if (value == null) {
    return null;
  }
  return Color(0xFF000000 | value);
}

String formatThemeHexColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

bool colorsMatchTheme(Color a, Color b) {
  return (a.toARGB32() & 0xFFFFFF) == (b.toARGB32() & 0xFFFFFF);
}

@immutable
class PaletteColor {
  const PaletteColor(this.id, this.color);
  final int id;
  final Color color;
  Map<String, dynamic> toJson() => {'id': id, 'color': color.toARGB32()};
}

/// Independent from the original single seed. Palette identities survive reorder.
/// Orbit's coordinated role seeds; FlClash supplies the panel interaction model.
List<Color> presetRoleSeeds(Color seed, AppColorScheme scheme) {
  final source = Hct.fromInt(seed.toARGB32());
  final (rotation, second, third, chroma) = switch (scheme) {
    AppColorScheme.original => (0.0, 60.0, 180.0, 32.0),
    AppColorScheme.vibrant => (0.0, 60.0, 150.0, 64.0),
    AppColorScheme.expressive => (240.0, 120.0, 240.0, 48.0),
    AppColorScheme.rainbow => (0.0, 120.0, 240.0, 60.0),
    AppColorScheme.fruitSalad => (-50.0, 60.0, 120.0, 48.0),
    AppColorScheme.content => (
      0.0,
      30.0,
      90.0,
      source.chroma.clamp(24.0, 48.0),
    ),
    AppColorScheme.fidelity => (
      0.0,
      180.0,
      60.0,
      source.chroma.clamp(32.0, 64.0),
    ),
    AppColorScheme.neutral => (0.0, 0.0, 0.0, 8.0),
    AppColorScheme.monochrome => (0.0, 0.0, 0.0, 0.0),
  };
  return [
    for (final offset in [0.0, second, third])
      Color(
        Hct.from((source.hue + rotation + offset) % 360, chroma, 50).toInt(),
      ),
  ];
}

ColorScheme _roleScheme(
  ColorScheme base,
  ColorScheme second,
  ColorScheme third,
) => base.copyWith(
  secondary: second.primary,
  onSecondary: second.onPrimary,
  secondaryContainer: second.primaryContainer,
  onSecondaryContainer: second.onPrimaryContainer,
  secondaryFixed: second.primaryFixed,
  secondaryFixedDim: second.primaryFixedDim,
  onSecondaryFixed: second.onPrimaryFixed,
  onSecondaryFixedVariant: second.onPrimaryFixedVariant,
  tertiary: third.primary,
  onTertiary: third.onPrimary,
  tertiaryContainer: third.primaryContainer,
  onTertiaryContainer: third.onPrimaryContainer,
  tertiaryFixed: third.primaryFixed,
  tertiaryFixedDim: third.primaryFixedDim,
  onTertiaryFixed: third.onPrimaryFixed,
  onTertiaryFixedVariant: third.onPrimaryFixedVariant,
);

@immutable
class MulticolorSettings {
  const MulticolorSettings({
    this.enabled = false,
    this.primary = kDefaultThemeColor,
    this.secondary,
    this.tertiary,
    this.scheme = AppColorScheme.expressive,
    this.customRoles = false,
    this.presetSeed,
    this.palette = const [
      PaletteColor(0, Color(0xFF00796B)),
      PaletteColor(1, Color(0xFF1565C0)),
      PaletteColor(2, Color(0xFF6A1B9A)),
      PaletteColor(3, Color(0xFFC62828)),
      PaletteColor(4, Color(0xFFEF6C00)),
      PaletteColor(5, Color(0xFF2E7D32)),
      PaletteColor(6, Color(0xFF00838F)),
      PaletteColor(7, Color(0xFFAD1457)),
    ],
    this.nextId = 8,
    this.retiredIds = const {},
  });
  final bool enabled;
  final Color primary;
  final Color? secondary, tertiary;
  final AppColorScheme scheme;
  final bool customRoles;
  final Color? presetSeed;
  bool get isCustom => customRoles || secondary != null || tertiary != null;
  final List<PaletteColor> palette;
  final int nextId;
  final Set<int> retiredIds;

  /// Custom roles preserve the selected hues and the other generated roles.
  MulticolorSettings withRoleColor(int role, Color color) {
    assert(role >= 0 && role <= 2);
    final generated = colors(Brightness.light);
    return copyWith(
      customRoles: true,
      presetSeed: presetSeed ?? primary,
      primary: role == 0
          ? color
          : isCustom
          ? primary
          : generated.primary,
      secondary: role == 1 ? color : secondary ?? generated.secondary,
      tertiary: role == 2 ? color : tertiary ?? generated.tertiary,
    );
  }

  ColorScheme colors(Brightness brightness) {
    final seeds = isCustom
        ? [primary, secondary, tertiary]
        : presetRoleSeeds(primary, scheme);
    ColorScheme generate(Color seed) => ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    if (!isCustom) {
      return _roleScheme(
        generate(seeds[0]!),
        generate(seeds[1]!),
        generate(seeds[2]!),
      );
    }
    final base = generate(primary);
    final second = secondary == null ? base : generate(secondary!);
    final third = tertiary == null ? base : generate(tertiary!);
    return base.copyWith(
      secondary: secondary == null ? base.secondary : second.primary,
      onSecondary: secondary == null ? base.onSecondary : second.onPrimary,
      secondaryContainer: secondary == null
          ? base.secondaryContainer
          : second.primaryContainer,
      onSecondaryContainer: secondary == null
          ? base.onSecondaryContainer
          : second.onPrimaryContainer,
      secondaryFixed: secondary == null
          ? base.secondaryFixed
          : second.primaryFixed,
      secondaryFixedDim: secondary == null
          ? base.secondaryFixedDim
          : second.primaryFixedDim,
      onSecondaryFixed: secondary == null
          ? base.onSecondaryFixed
          : second.onPrimaryFixed,
      onSecondaryFixedVariant: secondary == null
          ? base.onSecondaryFixedVariant
          : second.onPrimaryFixedVariant,
      tertiary: tertiary == null ? base.tertiary : third.primary,
      onTertiary: tertiary == null ? base.onTertiary : third.onPrimary,
      tertiaryContainer: tertiary == null
          ? base.tertiaryContainer
          : third.primaryContainer,
      onTertiaryContainer: tertiary == null
          ? base.onTertiaryContainer
          : third.onPrimaryContainer,
      tertiaryFixed: tertiary == null ? base.tertiaryFixed : third.primaryFixed,
      tertiaryFixedDim: tertiary == null
          ? base.tertiaryFixedDim
          : third.primaryFixedDim,
      onTertiaryFixed: tertiary == null
          ? base.onTertiaryFixed
          : third.onPrimaryFixed,
      onTertiaryFixedVariant: tertiary == null
          ? base.onTertiaryFixedVariant
          : third.onPrimaryFixedVariant,
    );
  }

  MulticolorSettings copyWith({
    bool? enabled,
    Color? primary,
    Color? secondary,
    Color? tertiary,
    AppColorScheme? scheme,
    bool? customRoles,
    Color? presetSeed,
    List<PaletteColor>? palette,
    int? nextId,
    bool clearCustom = false,
    Set<int>? retiredIds,
  }) => MulticolorSettings(
    enabled: enabled ?? this.enabled,
    primary:
        primary ??
        (clearCustom ? this.presetSeed ?? this.primary : this.primary),
    presetSeed: presetSeed ?? this.presetSeed,
    secondary: clearCustom ? null : secondary ?? this.secondary,
    tertiary: clearCustom ? null : tertiary ?? this.tertiary,
    scheme: scheme ?? this.scheme,
    customRoles: clearCustom ? false : customRoles ?? this.customRoles,
    palette: palette ?? this.palette,
    nextId: nextId ?? this.nextId,
    retiredIds: retiredIds ?? this.retiredIds,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'primary': primary.toARGB32(),
    'secondary': secondary?.toARGB32(),
    'tertiary': tertiary?.toARGB32(),
    'scheme': scheme.name,
    'customRoles': customRoles,
    'presetSeed': presetSeed?.toARGB32(),
    'palette': palette.map((e) => e.toJson()).toList(),
    'nextId': nextId,
    'retiredIds': retiredIds.toList(),
  };
  factory MulticolorSettings.fromJson(Map<String, dynamic> json) {
    Color? color(dynamic value) =>
        value is int ? Color(value | 0xFF000000) : null;
    final ids = <int>{}, colors = <int>{};
    final entries = <PaletteColor>[];
    if (json['palette'] is List) {
      for (final entry in json['palette'] as List) {
        if (entry is! Map || entry['id'] is! int || entry['id'] < 0) continue;
        final c = color(entry['color']);
        if (c == null ||
            ids.contains(entry['id']) ||
            colors.contains(c.toARGB32())) {
          continue;
        }
        ids.add(entry['id'] as int);
        colors.add(c.toARGB32());
        entries.add(PaletteColor(entry['id'] as int, c));
      }
    }
    final minimumId = ids.fold<int>(8, (a, b) => a > b ? a : b + 1);
    final next = json['nextId'];
    return MulticolorSettings(
      enabled: json['enabled'] == true,
      primary: color(json['primary']) ?? kDefaultThemeColor,
      secondary: color(json['secondary']),
      tertiary: color(json['tertiary']),
      scheme: AppColorScheme.values.firstWhere(
        (e) => e.name == json['scheme'],
        orElse: () => AppColorScheme.expressive,
      ),
      customRoles: json['customRoles'] == true,
      presetSeed: color(json['presetSeed']),
      palette: json['palette'] is List
          ? entries
          : const MulticolorSettings().palette,
      nextId: next is int && next >= minimumId ? next : minimumId,
      retiredIds: json['retiredIds'] is List
          ? (json['retiredIds'] as List)
                .whereType<int>()
                .where((id) => id >= 0 && !ids.contains(id))
                .toSet()
          : const {},
    );
  }
}
