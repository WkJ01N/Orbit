import 'package:flutter/material.dart';

/// Default brand color — #39C5BB
const kDefaultThemeColor = Color(0xFF39C5BB);

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
  static ThemeData light({Color seed = kDefaultThemeColor}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return _baseTheme(colorScheme);
  }

  static ThemeData dark({Color seed = kDefaultThemeColor}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return _baseTheme(colorScheme);
  }

  static ThemeData _baseTheme(ColorScheme colorScheme) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
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
        iconColor: colorScheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    );
  }
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
