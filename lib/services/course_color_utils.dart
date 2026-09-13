import 'package:orbit/models/course_operation.dart';
import 'package:flutter/material.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/models/course_session.dart';

/// Stable key for per-course color overrides (code preferred, name fallback).
String courseColorKey(CourseSession session) {
  final code = session.courseCode.trim();
  if (code.isNotEmpty) {
    return code;
  }
  return session.courseName.trim();
}

String automaticCourseColorKey(CourseSession session) =>
    CourseSeriesKey.fromSession(session).value;
int legacyAutomaticColorId(CourseSession session) =>
    _stableCourseHash(courseColorKey(session)) % 8;

Color contrastForegroundFor(Color background) {
  return background.computeLuminance() > 0.179 ? Colors.black : Colors.white;
}

const _colorfulLightPalette = <Color>[
  Color(0xFF00796B),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFC62828),
  Color(0xFFEF6C00),
  Color(0xFF2E7D32),
  Color(0xFF00838F),
  Color(0xFFAD1457),
];

const _colorfulDarkPalette = <Color>[
  Color(0xFF4DB6AC),
  Color(0xFF64B5F6),
  Color(0xFFBA68C8),
  Color(0xFFEF9A9A),
  Color(0xFFFFB74D),
  Color(0xFF81C784),
  Color(0xFF4DD0E1),
  Color(0xFFF48FB1),
];

Color automaticCourseColor(
  CourseSession session, {
  required Brightness brightness,
  int? colorId,
  List<PaletteColor> palette = const [],
}) {
  final defaults = brightness == Brightness.dark
      ? _colorfulDarkPalette
      : _colorfulLightPalette;
  return automaticColorForId(
    colorId ?? _stableCourseHash(courseColorKey(session)) % defaults.length,
    brightness,
    palette: palette,
  );
}

Color resolvedCourseColor({
  required CourseSession session,
  required ColorScheme colorScheme,
  required AppThemeStyle themeStyle,
  Color? override,
  int? automaticColorId,
  List<PaletteColor> palette = const [],
}) {
  if (override != null) return override;
  if (themeStyle == AppThemeStyle.colorful) {
    return automaticCourseColor(
      session,
      brightness: colorScheme.brightness,
      colorId: automaticColorId,
      palette: palette,
    );
  }
  return colorScheme.secondary;
}

Color courseCardSurface({
  required Color accent,
  required ColorScheme colorScheme,
  required AppThemeStyle themeStyle,
  required bool highlighted,
  required bool isPast,
}) {
  if (themeStyle == AppThemeStyle.colorful) {
    final opacity = colorScheme.brightness == Brightness.dark ? 0.18 : 0.09;
    return Color.alphaBlend(
      accent.withValues(alpha: isPast ? opacity * 0.5 : opacity),
      colorScheme.surfaceContainerLow,
    );
  }
  return highlighted
      ? colorScheme.primaryContainer.withAlpha(isPast ? 70 : 130)
      : colorScheme.surfaceContainerLow.withAlpha(isPast ? 150 : 255);
}

int _stableCourseHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

Color automaticColorForId(
  int id,
  Brightness brightness, {
  List<PaletteColor> palette = const [],
}) {
  for (final entry in palette) {
    if (entry.id == id) {
      return ColorScheme.fromSeed(
        seedColor: entry.color,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).primary;
    }
  }
  if (id < 0) id = 0;
  final defaults = brightness == Brightness.dark
      ? _colorfulDarkPalette
      : _colorfulLightPalette;
  if (id < defaults.length) return defaults[id];
  // Vary saturation and tone as well as hue so large imports do not exhaust
  // the finite RGB values along a single hue circle.
  if (id >= 10000) {
    const levels = 173;
    final value = ((id - 10000) * 104729 + 895733) % (levels * levels * levels);
    final channels = [
      value % levels,
      value ~/ levels % levels,
      value ~/ (levels * levels),
    ];
    return Color.fromARGB(
      255,
      brightness == Brightness.dark ? 255 - channels[0] : channels[0],
      brightness == Brightness.dark ? 255 - channels[1] : channels[1],
      brightness == Brightness.dark ? 255 - channels[2] : channels[2],
    );
  }
  final band = (id - 8) ~/ 360;
  return HSLColor.fromAHSL(
    1,
    ((id - 8) * 137.507764 + 15) % 360,
    (brightness == Brightness.dark ? .65 : .62) + (band % 7) * .03,
    (brightness == Brightness.dark ? .72 : .38) + (band ~/ 7 % 5) * .012,
  ).toColor();
}

/// Preserve reserved identities, repair collisions, and append new colors only.
Map<String, int> allocateCourseColorIds(
  Map<String, int> saved,
  Iterable<String> keys, {
  Map<String, int> preferred = const {},
  List<PaletteColor> palette = const [],
  Set<int> retiredIds = const {},
}) {
  final result = <String, int>{};
  final usedIds = <int>{};
  final usedLight = <int>{}, usedDark = <int>{};
  var next = 0;
  bool available(int id) =>
      id >= 0 &&
      !retiredIds.contains(id) &&
      !usedIds.contains(id) &&
      !usedLight.contains(
        automaticColorForId(id, Brightness.light, palette: palette).toARGB32(),
      ) &&
      !usedDark.contains(
        automaticColorForId(id, Brightness.dark, palette: palette).toARGB32(),
      );
  void reserve(String key, int id) {
    result[key] = id;
    usedIds.add(id);
    usedLight.add(
      automaticColorForId(id, Brightness.light, palette: palette).toARGB32(),
    );
    usedDark.add(
      automaticColorForId(id, Brightness.dark, palette: palette).toARGB32(),
    );
  }

  // Valid existing assignments have priority over repaired and new assignments.
  for (final e in saved.entries) {
    if (available(e.value)) reserve(e.key, e.value);
  }
  for (final e in preferred.entries) {
    if (palette.isNotEmpty && !palette.any((color) => color.id == e.value)) {
      continue;
    }
    if (!result.containsKey(e.key) && available(e.value)) {
      reserve(e.key, e.value);
    }
  }
  for (final key in {...saved.keys, ...keys}) {
    if (result.containsKey(key)) continue;
    final preferredColor = palette
        .where((entry) => available(entry.id))
        .firstOrNull;
    if (preferredColor != null) {
      reserve(key, preferredColor.id);
      continue;
    }
    while (!available(next)) {
      next++;
    }
    reserve(key, next++);
  }
  return result;
}
