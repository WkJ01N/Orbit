import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/models/android_widget_settings.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/services/course_color_utils.dart';

enum AndroidWidgetKind { nextClass, todaySchedule }

@immutable
class AndroidWidgetStatus {
  const AndroidWidgetStatus({
    this.supported = false,
    this.canPin = false,
    this.nextClassCount = 0,
    this.todayScheduleCount = 0,
  });

  final bool supported;
  final bool canPin;
  final int nextClassCount;
  final int todayScheduleCount;
}

Map<String, int> _extractWidgetPalette(ColorScheme scheme) => {
  'surface': scheme.surface.toARGB32(),
  'surfaceContainer': scheme.surfaceContainerLow.toARGB32(),
  'onSurface': scheme.onSurface.toARGB32(),
  'onSurfaceVariant': scheme.onSurfaceVariant.toARGB32(),
  'primary': scheme.primary.toARGB32(),
  'primaryContainer': scheme.primaryContainer.toARGB32(),
  'onPrimaryContainer': scheme.onPrimaryContainer.toARGB32(),
  'outlineVariant': scheme.outlineVariant.toARGB32(),
  'error': scheme.error.toARGB32(),
  'errorContainer': scheme.errorContainer.toARGB32(),
  'onErrorContainer': scheme.onErrorContainer.toARGB32(),
};

/// Builds the full native widget configuration payload consumed by
/// `OrbitWidgetStore` on Android.
Map<String, dynamic> buildAndroidWidgetSyncPayload({
  required String? databasePath,
  required Locale locale,
  required ThemeMode themeMode,
  required AppThemeStyle themeStyle,
  required Color seedColor,
  required AppColorScheme colorScheme,
  required MulticolorSettings multicolor,
  required AndroidWidgetSettings widgetSettings,
  required List<CourseSession> sessions,
  required Map<String, Color> courseColorOverrides,
  required Map<String, int> automaticColorIds,
}) {
  final lightScheme = AppTheme.light(
    seed: seedColor,
    style: themeStyle,
    scheme: colorScheme,
    multicolor: multicolor,
  ).colorScheme;
  final darkScheme = AppTheme.dark(
    seed: seedColor,
    style: themeStyle,
    scheme: colorScheme,
    multicolor: multicolor,
  ).colorScheme;

  final courseColorsLight = <String, int>{};
  final courseColorsDark = <String, int>{};
  final palette = multicolor.enabled
      ? multicolor.palette
      : const <PaletteColor>[];

  for (final session in sessions) {
    final seriesKey = automaticCourseColorKey(session);
    final codeKey = session.courseCode.trim();
    final nameKey = session.courseName.trim();
    final override =
        courseColorOverrides[codeKey] ??
        courseColorOverrides[nameKey] ??
        courseColorOverrides[courseColorKey(session)];
    final autoId = automaticColorIds[seriesKey];
    final lightColor = resolvedCourseColor(
      session: session,
      colorScheme: lightScheme,
      themeStyle: themeStyle,
      override: override,
      automaticColorId: autoId,
      palette: palette,
    ).toARGB32();
    final darkColor = resolvedCourseColor(
      session: session,
      colorScheme: darkScheme,
      themeStyle: themeStyle,
      override: override,
      automaticColorId: autoId,
      palette: palette,
    ).toARGB32();

    courseColorsLight[seriesKey] = lightColor;
    courseColorsDark[seriesKey] = darkColor;
    if (codeKey.isNotEmpty) {
      courseColorsLight.putIfAbsent(codeKey, () => lightColor);
      courseColorsDark.putIfAbsent(codeKey, () => darkColor);
    }
    if (nameKey.isNotEmpty) {
      courseColorsLight.putIfAbsent(nameKey, () => lightColor);
      courseColorsDark.putIfAbsent(nameKey, () => darkColor);
    }
  }

  return {
    'databasePath': databasePath,
    'localeTag': localeStorageKey(locale),
    'themeMode': themeMode.name,
    'themeStyle': themeStyle.name,
    'backgroundOpacity': widgetSettings.backgroundOpacity,
    'showDeadlines': widgetSettings.showDeadlines,
    'deadlineLookaheadDays': widgetSettings.deadlineLookaheadDays,
    'paletteLight': _extractWidgetPalette(lightScheme),
    'paletteDark': _extractWidgetPalette(darkScheme),
    'courseColorsLight': courseColorsLight,
    'courseColorsDark': courseColorsDark,
  };
}

class AndroidWidgetService {
  AndroidWidgetService({MethodChannel? channel, this.isAndroidOverride})
    : _channel = channel ?? _defaultChannel;

  static final instance = AndroidWidgetService();
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.must.orbit.orbit/widgets',
  );

  final MethodChannel _channel;
  final bool? isAndroidOverride;

  bool get _isAndroid => isAndroidOverride ?? Platform.isAndroid;

  Future<void> syncConfig(Map<String, dynamic> payload) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('syncConfig', payload);
    } on MissingPluginException {
      // Ignored in tests or non-Android runtimes.
    } on PlatformException catch (error) {
      debugPrint('Android widget config sync failed: $error');
    }
  }

  Future<void> refreshWidgets() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('refreshWidgets');
    } on MissingPluginException {
      // Ignored in tests or non-Android runtimes.
    } on PlatformException catch (error) {
      debugPrint('Android widget refresh failed: $error');
    }
  }

  Future<AndroidWidgetStatus> getStatus() async {
    if (!_isAndroid) return const AndroidWidgetStatus();
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'widgetStatus',
      );
      if (raw == null) return const AndroidWidgetStatus(supported: true);
      return AndroidWidgetStatus(
        supported: true,
        canPin: raw['canPin'] == true,
        nextClassCount: (raw['nextClassCount'] as num?)?.toInt() ?? 0,
        todayScheduleCount: (raw['todayScheduleCount'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return const AndroidWidgetStatus();
    } on PlatformException catch (error) {
      debugPrint('Android widget status failed: $error');
      return const AndroidWidgetStatus();
    }
  }

  Future<bool> requestPin(AndroidWidgetKind kind) async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPinWidget', {
            'kind': kind.name,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('Android widget pin failed: $error');
      return false;
    }
  }
}
