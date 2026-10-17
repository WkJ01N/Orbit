import 'dart:io';
import 'dart:convert';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/models/schedule_import.dart';

import 'package:flutter/material.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/models/auto_sync_settings.dart';
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
  static const _autoSyncSettingsKey = 'auto_sync_settings_v1';

  static const _backupPreferenceKeys = {
    'launch_at_startup',
    'notification_warning_ignored',
    'batch_first_week_monday',
    'batch_total_weeks',
    'update_preferences',
    'sync_scope_local_device',
  };
  SharedPreferences? _prefs;
  Future<void> _importSaveTail = Future.value();

  Future<BackgroundSettings> loadBackgroundSettings() async {
    final raw = (await _prefsInstance()).getString('page_backgrounds_v1');
    if (raw == null) return const BackgroundSettings();
    try {
      return BackgroundSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const BackgroundSettings();
    }
  }

  Future<void> saveBackgroundSettings(BackgroundSettings settings) async {
    final json = jsonEncode(settings.toJson());
    BackgroundSettings.fromJson(
      Map<String, dynamic>.from(jsonDecode(json) as Map),
    );
    if (!await (await _prefsInstance()).setString(
      'page_backgrounds_v1',
      json,
    )) {
      throw StateError('Could not save page backgrounds');
    }
  }

  Future<ImportConfiguration> loadImportConfiguration() async {
    final prefs = await _prefsInstance();
    final text = prefs.getString('schedule_import_configuration');
    if (text == null) return const ImportConfiguration();
    return ImportConfiguration.fromJson(
      jsonDecode(text) as Map<String, dynamic>,
    );
  }

  Future<void> saveImportConfiguration(ImportConfiguration configuration) {
    final encoded = jsonEncode(configuration.toJson());
    // Validate the complete snapshot before modifying persisted settings.
    ImportConfiguration.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    final write = _importSaveTail.then((_) async {
      final prefs = await _prefsInstance();
      if (!await prefs.setString('schedule_import_configuration', encoded)) {
        throw StateError('Could not save import configuration');
      }
    });
    _importSaveTail = write.catchError((Object _) {});
    return write;
  }

  Future<AutoSyncSettings> loadAutoSyncSettings() async {
    final raw = (await _prefsInstance()).getString(_autoSyncSettingsKey);
    if (raw == null) return const AutoSyncSettings();
    try {
      return AutoSyncSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const AutoSyncSettings();
    }
  }

  Future<void> saveAutoSyncSettings(AutoSyncSettings settings) async {
    final saved = await (await _prefsInstance()).setString(
      _autoSyncSettingsKey,
      jsonEncode(settings.toJson()),
    );
    if (!saved) throw StateError('Could not save automatic sync settings');
  }

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
    if (!await prefs.setString(
      'custom_reminder_rules',
      jsonEncode(settings.customRules.map((r) => r.toJson()).toList()),
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setString(
      'strong_reminder_settings',
      jsonEncode(settings.strong.toJson()),
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setInt(_leadMinutesKey, settings.leadMinutes)) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setBool(_enabledKey, settings.enabled)) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setBool(
      _nextDaySummaryEnabledKey,
      settings.nextDaySummaryEnabled,
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setInt(
      _nextDaySummaryHourKey,
      settings.nextDaySummaryHour,
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setInt(
      _nextDaySummaryMinuteKey,
      settings.nextDaySummaryMinute,
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setBool(
      _nextDayRemindWhenNoClassKey,
      settings.nextDayRemindWhenNoClass,
    )) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setBool(
      _checkInReminderEnabledKey,
      settings.checkInReminderEnabled,
    )) {
      throw StateError("Could not save settings");
    }
  }

  Future<Locale> loadLocale() async {
    final prefs = await _prefsInstance();
    return localeFromStorage(prefs.getString(_localeKey));
  }

  Future<void> saveLocale(Locale locale) async {
    final prefs = await _prefsInstance();
    if (!await prefs.setString(_localeKey, localeStorageKey(locale))) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setInt(_themeColorKey, color.toARGB32())) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setString(_themeModeKey, value)) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setString(_themeStyleKey, style.name)) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setString('color_scheme', scheme.name)) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setString('automatic_course_color_ids', jsonEncode(ids))) {
      throw StateError("Could not save settings");
    }
  }

  Future<bool> loadLaunchAtStartup() async {
    final prefs = await _prefsInstance();
    return prefs.getBool(_launchAtStartupKey) ?? false;
  }

  Future<void> saveLaunchAtStartup(bool enabled) async {
    final prefs = await _prefsInstance();
    if (!await prefs.setBool(_launchAtStartupKey, enabled)) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setString(_gridDefaultWeekModeKey, mode.name)) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setInt(_weekStartDayKey, weekday)) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setString(_gridDensityKey, density.name)) {
      throw StateError("Could not save settings");
    }
  }

  Future<ScheduleDisplaySettings> loadScheduleDisplaySettings() async {
    final prefs = await _prefsInstance();
    return ScheduleDisplaySettings(
      fitToPage: prefs.getBool('schedule_fit_to_page') ?? false,
      hideUpcomingPage: prefs.getBool('schedule_hide_upcoming') ?? false,
      hideImportPage: prefs.getBool('schedule_hide_import') ?? false,
      strongCardGradient: StrongCardGradient.values.firstWhere(
        (v) => v.name == prefs.getString('schedule_strong_card_gradient'),
        orElse: () => StrongCardGradient.upperHalf,
      ),
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
      backToTopPosition: BackToTopPosition.values.firstWhere(
        (value) =>
            value.name == prefs.getString('upcoming_back_to_top_position'),
        orElse: () => BackToTopPosition.smart,
      ),
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
    if (!await prefs.setBool(
          'schedule_hide_upcoming',
          settings.hideUpcomingPage,
        ) ||
        !await prefs.setBool('schedule_hide_import', settings.hideImportPage)) {
      throw StateError('Could not save navigation settings');
    }
    if (!await prefs.setBool('schedule_fit_to_page', settings.fitToPage)) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setString(
      'schedule_strong_card_gradient',
      settings.strongCardGradient.name,
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setString(
      _scheduleNarrowLayoutKey,
      settings.narrowLayout.name,
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setInt(
      _scheduleVerticalScaleKey,
      ScheduleDisplaySettings.normalizeVerticalScalePercent(
        settings.verticalScalePercent,
      ),
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setInt(
      _scheduleMultiDayCountKey,
      settings.preferredMultiDayCount.clamp(1, 6),
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setBool(
      _scheduleShowEmptyDaysKey,
      settings.showEmptyDays,
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setBool(
      _upcomingShowCourseDateKey,
      settings.showUpcomingCourseDate,
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setString(
      'upcoming_back_to_top_position',
      settings.backToTopPosition.name,
    )) {
      throw StateError('Could not save button position');
    }
    if (!await prefs.setString(
      _upcomingDateDisplayKey,
      settings.upcomingDateDisplay.name,
    )) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setString(
      _batchFirstWeekMondayKey,
      DateTime(
        firstWeekMonday.year,
        firstWeekMonday.month,
        firstWeekMonday.day,
      ).toIso8601String(),
    )) {
      throw StateError("Could not save settings");
    }
    if (!await prefs.setInt(_batchTotalWeeksKey, totalWeeks.clamp(1, 30))) {
      throw StateError("Could not save settings");
    }
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
    if (!await prefs.setString(_courseColorOverridesKey, encoded)) {
      throw StateError("Could not save settings");
    }
  }

  Future<ArchiveSettings> loadArchiveSettings() async {
    final prefs = await _prefsInstance();
    try {
      return ArchiveSettings.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(prefs.getString('archive_settings') ?? '{}') as Map,
        ),
      );
    } catch (_) {
      return const ArchiveSettings();
    }
  }

  Future<void> saveArchiveSettings(ArchiveSettings settings) async {
    final prefs = await _prefsInstance();
    if (!await prefs.setString(
      'archive_settings',
      jsonEncode(settings.toJson()),
    )) {
      throw StateError("Could not save settings");
    }
  }

  Future<PortableSettings> exportPortableSettings({String? accountUid}) async {
    final locale = await loadLocale();
    final themeColor = await loadThemeColor();
    final themeMode = await loadThemeMode();
    final themeStyle = await loadThemeStyle();
    final gridMode = await loadGridDefaultWeekMode();
    final weekStart = await loadWeekStartDay();
    final density = await loadGridDensity();
    final colors = await loadCourseColorOverrides();
    final prefs = await _prefsInstance();
    return PortableSettings(
      sourcePlatform: Platform.operatingSystem,
      localPreferences: {
        'syncSelection': await loadLocalJson(
          'sync_scope_${accountUid ?? "local"}_device',
        ),
        for (final key in _backupPreferenceKeys)
          if (prefs.containsKey(key)) key: prefs.get(key),
      },
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
      importConfiguration: await loadImportConfiguration(),
      autoSyncSettings: await loadAutoSyncSettings(),
      archive: await loadArchiveSettings(),
      backgrounds: await loadBackgroundSettings(),
    );
  }

  Future<void> importPortableSettings(
    PortableSettings snapshot, {
    String? accountUid,
  }) async {
    final prefs = await _prefsInstance();
    for (final e in snapshot.localPreferences.entries) {
      if (e.key == 'syncSelection') {
        await saveLocalJson(
          'sync_scope_${accountUid ?? "local"}_device',
          Map<String, dynamic>.from(e.value as Map),
        );
        continue;
      }
      if (!_backupPreferenceKeys.contains(e.key)) continue;
      if (e.key == 'launch_at_startup' &&
          (!Platform.isWindows || snapshot.sourcePlatform != 'windows')) {
        continue;
      }
      final value = e.value;
      if (value is bool) {
        if (!await prefs.setBool(e.key, value)) {
          throw StateError('Could not save ${e.key}');
        }
      } else if (value is int) {
        if (!await prefs.setInt(e.key, value)) {
          throw StateError('Could not save ${e.key}');
        }
      } else if (value is String) {
        if (!await prefs.setString(e.key, value)) {
          throw StateError('Could not save ${e.key}');
        }
      } else {
        throw FormatException('Invalid preference ${e.key}');
      }
    }
    if (snapshot.backgrounds != null) {
      await saveBackgroundSettings(snapshot.backgrounds!);
    }
    await saveArchiveSettings(snapshot.archive);
    if (snapshot.importConfiguration != null) {
      await saveImportConfiguration(snapshot.importConfiguration!);
    }
    if (snapshot.autoSyncSettings != null) {
      await saveAutoSyncSettings(snapshot.autoSyncSettings!);
    }
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

  Future<Map<String, Object>> snapshotPreferences() async {
    final prefs = await _prefsInstance();
    return {
      for (final key in prefs.getKeys())
        if (prefs.get(key) != null) key: prefs.get(key)!,
    };
  }

  Future<void> restorePreferences(Map<String, Object> snapshot) async {
    final prefs = await _prefsInstance();
    for (final key in prefs.getKeys().difference(snapshot.keys.toSet())) {
      await prefs.remove(key);
    }
    for (final e in snapshot.entries) {
      final v = e.value;
      if (v is bool) {
        if (!await prefs.setBool(e.key, v)) {
          throw StateError("Could not save settings");
        }
      } else if (v is int) {
        if (!await prefs.setInt(e.key, v)) {
          throw StateError("Could not save settings");
        }
      } else if (v is double) {
        if (!await prefs.setDouble(e.key, v)) {
          throw StateError("Could not save settings");
        }
      } else if (v is String) {
        if (!await prefs.setString(e.key, v)) {
          throw StateError("Could not save settings");
        }
      } else if (v is List<String>) {
        if (!await prefs.setStringList(e.key, v)) {
          throw StateError("Could not save settings");
        }
      }
    }
  }

  Future<Map<String, dynamic>> loadLocalJson(String key) async {
    final prefs = await _prefsInstance();
    try {
      return Map<String, dynamic>.from(
        jsonDecode(prefs.getString(key) ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveLocalJson(String key, Map<String, dynamic> value) async {
    if (!await (await _prefsInstance()).setString(key, jsonEncode(value))) {
      throw StateError('Could not save $key');
    }
  }

  Future<void> _saveOptionalString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(key);
    } else {
      if (!await prefs.setString(key, value)) {
        throw StateError("Could not save settings");
      }
    }
  }
}
