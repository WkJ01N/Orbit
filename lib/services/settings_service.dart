import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _themeColorKey = 'theme_color';
  static const _themeModeKey = 'theme_mode';
  static const _themeStyleKey = 'app_theme_style';
  static const _leadMinutesKey = 'reminder_lead_minutes';
  static const _enabledKey = 'reminder_enabled';
  static const _localeKey = 'app_locale';
  static const _nextDaySummaryEnabledKey = 'next_day_summary_enabled';
  static const _nextDaySummaryHourKey = 'next_day_summary_hour';
  static const _nextDaySummaryMinuteKey = 'next_day_summary_minute';
  static const _nextDayRemindWhenNoClassKey = 'next_day_remind_when_no_class';
  static const _nextDayWithClassTitleKey = 'next_day_with_class_title_tpl';
  static const _nextDayWithClassBodyKey = 'next_day_with_class_body_tpl';
  static const _nextDayNoClassTitleKey = 'next_day_no_class_title_tpl';
  static const _nextDayNoClassBodyKey = 'next_day_no_class_body_tpl';
  static const _classLeadTitleKey = 'class_lead_title_tpl';
  static const _classLeadBodyKey = 'class_lead_body_tpl';
  static const _checkInTitleKey = 'check_in_title_tpl';
  static const _checkInBodyKey = 'check_in_body_tpl';
  static const _checkInReminderEnabledKey = 'check_in_reminder_enabled';
  static const _launchAtStartupKey = 'launch_at_startup';
  static const _gridDefaultWeekModeKey = 'grid_default_week_mode';
  static const _weekStartDayKey = 'week_start_day';
  static const _gridDensityKey = 'grid_density';
  static const _courseColorOverridesKey = 'course_color_overrides';
  static const _scheduleMultiDayCountKey = 'schedule_multi_day_count';
  static const _scheduleNarrowLayoutKey = 'schedule_narrow_layout';
  static const _scheduleVerticalScaleKey = 'schedule_vertical_scale_percent';
  static const _scheduleShowEmptyDaysKey = 'schedule_show_empty_days';
  static const _upcomingShowCourseDateKey = 'upcoming_show_course_date';
  static const _upcomingDateDisplayKey = 'upcoming_date_display';
  static const _batchFirstWeekMondayKey = 'batch_first_week_monday';
  static const _batchTotalWeeksKey = 'batch_total_weeks';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _prefsInstance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<ReminderSettings> load() async {
    final prefs = await _prefsInstance();
    final rules = <CustomReminderRule>[];
    var strong = const StrongReminderSettings();
    try {
      final raw = jsonDecode(prefs.getString('custom_reminder_rules') ?? '[]');
      if (raw is List) {
        for (final item in raw) {
          try {
            rules.add(
              CustomReminderRule.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            );
          } catch (error) {
            debugPrint('Invalid reminder rule: $error');
          }
        }
      }
      strong = StrongReminderSettings.fromJson(
        jsonDecode(prefs.getString('strong_reminder_settings') ?? '{}')
            as Map<String, dynamic>,
      );
    } catch (error) {
      debugPrint('Invalid reminder settings: $error');
    }
    return ReminderSettings(
      customRules: rules,
      strong: strong,
      leadMinutes: prefs.getInt(_leadMinutesKey) ?? 15,
      enabled: prefs.getBool(_enabledKey) ?? true,
      nextDaySummaryEnabled: prefs.getBool(_nextDaySummaryEnabledKey) ?? true,
      nextDaySummaryHour: prefs.getInt(_nextDaySummaryHourKey) ?? 23,
      nextDaySummaryMinute: prefs.getInt(_nextDaySummaryMinuteKey) ?? 0,
      nextDayRemindWhenNoClass:
          prefs.getBool(_nextDayRemindWhenNoClassKey) ?? true,
      nextDayWithClassTitleTemplate: prefs.getString(_nextDayWithClassTitleKey),
      nextDayWithClassBodyTemplate: prefs.getString(_nextDayWithClassBodyKey),
      nextDayNoClassTitleTemplate: prefs.getString(_nextDayNoClassTitleKey),
      nextDayNoClassBodyTemplate: prefs.getString(_nextDayNoClassBodyKey),
      classLeadTitleTemplate: prefs.getString(_classLeadTitleKey),
      classLeadBodyTemplate: prefs.getString(_classLeadBodyKey),
      checkInTitleTemplate: prefs.getString(_checkInTitleKey),
      checkInBodyTemplate: prefs.getString(_checkInBodyKey),
      checkInReminderEnabled: prefs.getBool(_checkInReminderEnabledKey) ?? true,
    );
  }

  Future<void> save(ReminderSettings settings) async {
    final prefs = await _prefsInstance();
    await prefs.setString(
      'custom_reminder_rules',
      jsonEncode(settings.customRules.map((r) => r.toJson()).toList()),
    );
    await prefs.setString(
      'strong_reminder_settings',
      jsonEncode(settings.strong.toJson()),
    );
    await prefs.setInt(_leadMinutesKey, settings.leadMinutes);
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setBool(
      _nextDaySummaryEnabledKey,
      settings.nextDaySummaryEnabled,
    );
    await prefs.setInt(_nextDaySummaryHourKey, settings.nextDaySummaryHour);
    await prefs.setInt(_nextDaySummaryMinuteKey, settings.nextDaySummaryMinute);
    await prefs.setBool(
      _nextDayRemindWhenNoClassKey,
      settings.nextDayRemindWhenNoClass,
    );
    await _saveOptionalString(
      prefs,
      _nextDayWithClassTitleKey,
      settings.nextDayWithClassTitleTemplate,
    );
    await _saveOptionalString(
      prefs,
      _nextDayWithClassBodyKey,
      settings.nextDayWithClassBodyTemplate,
    );
    await _saveOptionalString(
      prefs,
      _nextDayNoClassTitleKey,
      settings.nextDayNoClassTitleTemplate,
    );
    await _saveOptionalString(
      prefs,
      _nextDayNoClassBodyKey,
      settings.nextDayNoClassBodyTemplate,
    );
    await _saveOptionalString(
      prefs,
      _classLeadTitleKey,
      settings.classLeadTitleTemplate,
    );
    await _saveOptionalString(
      prefs,
      _classLeadBodyKey,
      settings.classLeadBodyTemplate,
    );
    await _saveOptionalString(
      prefs,
      _checkInTitleKey,
      settings.checkInTitleTemplate,
    );
    await _saveOptionalString(
      prefs,
      _checkInBodyKey,
      settings.checkInBodyTemplate,
    );
    await prefs.setBool(
      _checkInReminderEnabledKey,
      settings.checkInReminderEnabled,
    );
  }

  Future<Locale> loadLocale() async {
    final prefs = await _prefsInstance();
    return localeFromStorage(prefs.getString(_localeKey));
  }

  Future<void> saveLocale(Locale locale) async {
    final prefs = await _prefsInstance();
    await prefs.setString(_localeKey, localeStorageKey(locale));
  }

  Future<Color> loadThemeColor() async {
    final prefs = await _prefsInstance();
    final saved = prefs.getInt(_themeColorKey);
    if (saved == null) {
      return kDefaultThemeColor;
    }
    return Color(saved);
  }

  Future<void> saveThemeColor(Color color) async {
    final prefs = await _prefsInstance();
    await prefs.setInt(_themeColorKey, color.toARGB32());
  }

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await _prefsInstance();
    final saved = prefs.getString(_themeModeKey);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _prefsInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, value);
  }

  Future<AppThemeStyle> loadThemeStyle() async {
    final prefs = await _prefsInstance();
    final saved = prefs.getString(_themeStyleKey);
    return AppThemeStyle.values.firstWhere(
      (style) => style.name == saved,
      orElse: () => AppThemeStyle.standard,
    );
  }

  Future<void> saveThemeStyle(AppThemeStyle style) async {
    final prefs = await _prefsInstance();
    await prefs.setString(_themeStyleKey, style.name);
  }

  Future<AppColorScheme> loadColorScheme() async {
    final prefs = await _prefsInstance();
    return AppColorScheme.values.firstWhere(
      (s) => s.name == prefs.getString('color_scheme'),
      orElse: () => AppColorScheme.original,
    );
  }

  Future<void> saveColorScheme(AppColorScheme scheme) async {
    final prefs = await _prefsInstance();
    await prefs.setString('color_scheme', scheme.name);
  }

  Future<MulticolorSettings> loadMulticolorSettings() async {
    final prefs = await _prefsInstance();
    final raw = prefs.getString('multicolor_settings');
    if (raw != null) {
      try {
        return MulticolorSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        return const MulticolorSettings();
      }
    }
    final scheme = await loadColorScheme();
    return MulticolorSettings(
      enabled: scheme != AppColorScheme.original,
      primary: await loadThemeColor(),
      scheme: scheme == AppColorScheme.original
          ? AppColorScheme.expressive
          : scheme,
    );
  }

  Future<void> saveMulticolorSettings(MulticolorSettings value) async {
    await (await _prefsInstance()).setString(
      'multicolor_settings',
      jsonEncode(value.toJson()),
    );
  }

  Future<bool> loadPermissionWarningIgnored() async =>
      (await _prefsInstance()).getBool('notification_warning_ignored') ?? false;
  Future<void> savePermissionWarningIgnored(bool value) async =>
      (await _prefsInstance()).setBool('notification_warning_ignored', value);

  Future<Map<String, int>> loadAutomaticCourseColorIds() async {
    final prefs = await _prefsInstance();
    try {
      final json =
          jsonDecode(prefs.getString('automatic_course_color_ids') ?? '{}')
              as Map;
      return {
        for (final e in json.entries)
          if (e.key is String && e.value is int && e.value >= 0)
            e.key as String: e.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAutomaticCourseColorIds(Map<String, int> ids) async {
    final prefs = await _prefsInstance();
    await prefs.setString('automatic_course_color_ids', jsonEncode(ids));
  }

  Future<bool> loadLaunchAtStartup() async {
    final prefs = await _prefsInstance();
    return prefs.getBool(_launchAtStartupKey) ?? false;
  }

  Future<void> saveLaunchAtStartup(bool enabled) async {
    final prefs = await _prefsInstance();
    await prefs.setBool(_launchAtStartupKey, enabled);
  }

  Future<GridDefaultWeekMode> loadGridDefaultWeekMode() async {
    final prefs = await _prefsInstance();
    final saved = prefs.getString(_gridDefaultWeekModeKey);
    return GridDefaultWeekMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => GridDefaultWeekMode.smart,
    );
  }

  Future<void> saveGridDefaultWeekMode(GridDefaultWeekMode mode) async {
    final prefs = await _prefsInstance();
    await prefs.setString(_gridDefaultWeekModeKey, mode.name);
  }

  Future<int> loadWeekStartDay() async {
    final prefs = await _prefsInstance();
    final saved = prefs.getInt(_weekStartDayKey);
    if (saved == DateTime.sunday || saved == DateTime.monday) {
      return saved!;
    }
    return DateTime.monday;
  }

  Future<void> saveWeekStartDay(int weekday) async {
    final prefs = await _prefsInstance();
    await prefs.setInt(_weekStartDayKey, weekday);
  }

  Future<GridDensity> loadGridDensity() async {
    final prefs = await _prefsInstance();
    final saved = prefs.getString(_gridDensityKey);
    return GridDensity.values.firstWhere(
      (density) => density.name == saved,
      orElse: () => GridDensity.standard,
    );
  }

  Future<void> saveGridDensity(GridDensity density) async {
    final prefs = await _prefsInstance();
    await prefs.setString(_gridDensityKey, density.name);
  }

  Future<ScheduleDisplaySettings> loadScheduleDisplaySettings() async {
    final prefs = await _prefsInstance();
    return ScheduleDisplaySettings(
      fitToPage: prefs.getBool('schedule_fit_to_page') ?? false,
      verticalScalePercent:
          ScheduleDisplaySettings.normalizeVerticalScalePercent(
            prefs.get(_scheduleVerticalScaleKey),
          ),
      narrowLayout: NarrowScheduleLayout.values.firstWhere(
        (layout) => layout.name == prefs.getString(_scheduleNarrowLayoutKey),
        orElse: () => NarrowScheduleLayout.compactWeek,
      ),
      preferredMultiDayCount: (prefs.getInt(_scheduleMultiDayCountKey) ?? 3)
          .clamp(1, 6),
      showEmptyDays: prefs.getBool(_scheduleShowEmptyDaysKey) ?? true,
      showUpcomingCourseDate: prefs.getBool(_upcomingShowCourseDateKey) ?? true,
      upcomingDateDisplay: UpcomingDateDisplay.values.firstWhere(
        (display) => display.name == prefs.getString(_upcomingDateDisplayKey),
        orElse: () => UpcomingDateDisplay.dateAndWeekday,
      ),
    );
  }

  Future<void> saveScheduleDisplaySettings(
    ScheduleDisplaySettings settings,
  ) async {
    final prefs = await _prefsInstance();
    await prefs.setBool('schedule_fit_to_page', settings.fitToPage);
    await prefs.setString(_scheduleNarrowLayoutKey, settings.narrowLayout.name);
    await prefs.setInt(
      _scheduleVerticalScaleKey,
      ScheduleDisplaySettings.normalizeVerticalScalePercent(
        settings.verticalScalePercent,
      ),
    );
    await prefs.setInt(
      _scheduleMultiDayCountKey,
      settings.preferredMultiDayCount.clamp(1, 6),
    );
    await prefs.setBool(_scheduleShowEmptyDaysKey, settings.showEmptyDays);
    await prefs.setBool(
      _upcomingShowCourseDateKey,
      settings.showUpcomingCourseDate,
    );
    await prefs.setString(
      _upcomingDateDisplayKey,
      settings.upcomingDateDisplay.name,
    );
  }

  Future<({DateTime? firstWeekMonday, int totalWeeks})>
  loadBatchCourseDefaults() async {
    final prefs = await _prefsInstance();
    final rawDate = prefs.getString(_batchFirstWeekMondayKey);
    return (
      firstWeekMonday: rawDate == null ? null : DateTime.tryParse(rawDate),
      totalWeeks: (prefs.getInt(_batchTotalWeeksKey) ?? 18).clamp(1, 30),
    );
  }

  Future<void> saveBatchCourseDefaults({
    required DateTime firstWeekMonday,
    required int totalWeeks,
  }) async {
    final prefs = await _prefsInstance();
    await prefs.setString(
      _batchFirstWeekMondayKey,
      DateTime(
        firstWeekMonday.year,
        firstWeekMonday.month,
        firstWeekMonday.day,
      ).toIso8601String(),
    );
    await prefs.setInt(_batchTotalWeeksKey, totalWeeks.clamp(1, 30));
  }

  Future<Map<String, Color>> loadCourseColorOverrides() async {
    final prefs = await _prefsInstance();
    final raw = prefs.getString(_courseColorOverridesKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, Color(value as int)));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveCourseColorOverrides(Map<String, Color> overrides) async {
    final prefs = await _prefsInstance();
    if (overrides.isEmpty) {
      await prefs.remove(_courseColorOverridesKey);
      return;
    }
    final encoded = jsonEncode(
      overrides.map((key, value) => MapEntry(key, value.toARGB32())),
    );
    await prefs.setString(_courseColorOverridesKey, encoded);
  }

  Future<PortableSettings> exportPortableSettings() async {
    final locale = await loadLocale();
    final themeColor = await loadThemeColor();
    final themeMode = await loadThemeMode();
    final themeStyle = await loadThemeStyle();
    final gridMode = await loadGridDefaultWeekMode();
    final weekStart = await loadWeekStartDay();
    final density = await loadGridDensity();
    final colors = await loadCourseColorOverrides();
    return PortableSettings(
      locale: localeStorageKey(locale),
      themeColor: themeColor.toARGB32(),
      themeMode: themeMode.name,
      themeStyle: themeStyle.name,
      colorScheme: (await loadColorScheme()).name,
      multicolor: await loadMulticolorSettings(),
      automaticCourseColorIds: await loadAutomaticCourseColorIds(),
      gridDefaultWeekMode: gridMode.name,
      weekStartDay: weekStart,
      gridDensity: density.name,
      reminders: await load(),
      scheduleDisplay: await loadScheduleDisplaySettings(),
      courseColorOverrides: colors.map(
        (key, value) => MapEntry(key, value.toARGB32()),
      ),
    );
  }

  Future<void> importPortableSettings(PortableSettings snapshot) async {
    await saveLocale(localeFromStorage(snapshot.locale));
    await saveThemeColor(Color(snapshot.themeColor));
    await saveThemeMode(
      ThemeMode.values.firstWhere(
        (value) => value.name == snapshot.themeMode,
        orElse: () => ThemeMode.system,
      ),
    );
    await saveThemeStyle(
      AppThemeStyle.values.firstWhere(
        (value) => value.name == snapshot.themeStyle,
        orElse: () => AppThemeStyle.standard,
      ),
    );
    await saveGridDefaultWeekMode(
      GridDefaultWeekMode.values.firstWhere(
        (value) => value.name == snapshot.gridDefaultWeekMode,
        orElse: () => GridDefaultWeekMode.smart,
      ),
    );
    await saveWeekStartDay(snapshot.weekStartDay);
    await saveGridDensity(
      GridDensity.values.firstWhere(
        (value) => value.name == snapshot.gridDensity,
        orElse: () => GridDensity.standard,
      ),
    );
    await saveColorScheme(
      AppColorScheme.values.firstWhere(
        (s) => s.name == snapshot.colorScheme,
        orElse: () => AppColorScheme.original,
      ),
    );
    await saveAutomaticCourseColorIds(snapshot.automaticCourseColorIds);
    await saveMulticolorSettings(
      snapshot.multicolor ??
          MulticolorSettings(
            enabled: snapshot.colorScheme != 'original',
            primary: Color(snapshot.themeColor),
            scheme: AppColorScheme.values.firstWhere(
              (s) => s.name == snapshot.colorScheme,
              orElse: () => AppColorScheme.expressive,
            ),
          ),
    );
    await save(snapshot.reminders);
    await saveScheduleDisplaySettings(snapshot.scheduleDisplay);
    await saveCourseColorOverrides(
      snapshot.courseColorOverrides.map(
        (key, value) => MapEntry(key, Color(value)),
      ),
    );
  }

  Future<void> _saveOptionalString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }
}
