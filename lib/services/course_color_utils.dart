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

Color contrastForegroundFor(Color background) {
  return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
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
}) {
  final palette = brightness == Brightness.dark
      ? _colorfulDarkPalette
      : _colorfulLightPalette;
  return palette[_stableCourseHash(courseColorKey(session)) % palette.length];
}

Color resolvedCourseColor({
  required CourseSession session,
  required ColorScheme colorScheme,
  required AppThemeStyle themeStyle,
  Color? override,
}) {
  if (override != null) return override;
  if (themeStyle == AppThemeStyle.colorful) {
    return automaticCourseColor(session, brightness: colorScheme.brightness);
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
