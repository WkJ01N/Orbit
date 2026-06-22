import 'package:flutter/material.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _themeColorKey = 'theme_color';
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
  static const _systemAlarmEnabledKey = 'system_alarm_enabled';
  static const _systemAlarmLeadMinutesKey = 'system_alarm_lead_minutes';
  static const _checkInReminderEnabledKey = 'check_in_reminder_enabled';
  static const _launchAtStartupKey = 'launch_at_startup';
  static const _gridDefaultWeekModeKey = 'grid_default_week_mode';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _prefsInstance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<ReminderSettings> load() async {
    final prefs = await _prefsInstance();
    return ReminderSettings(
      leadMinutes: prefs.getInt(_leadMinutesKey) ?? 15,
      enabled: prefs.getBool(_enabledKey) ?? true,
      nextDaySummaryEnabled: prefs.getBool(_nextDaySummaryEnabledKey) ?? true,
      nextDaySummaryHour: prefs.getInt(_nextDaySummaryHourKey) ?? 23,
      nextDaySummaryMinute: prefs.getInt(_nextDaySummaryMinuteKey) ?? 0,
      nextDayRemindWhenNoClass:
          prefs.getBool(_nextDayRemindWhenNoClassKey) ?? true,
      nextDayWithClassTitleTemplate:
          prefs.getString(_nextDayWithClassTitleKey),
      nextDayWithClassBodyTemplate: prefs.getString(_nextDayWithClassBodyKey),
      nextDayNoClassTitleTemplate: prefs.getString(_nextDayNoClassTitleKey),
      nextDayNoClassBodyTemplate: prefs.getString(_nextDayNoClassBodyKey),
      systemAlarmEnabled: prefs.getBool(_systemAlarmEnabledKey) ?? false,
      systemAlarmLeadMinutes: prefs.getInt(_systemAlarmLeadMinutesKey) ?? 10,
      checkInReminderEnabled: prefs.getBool(_checkInReminderEnabledKey) ?? true,
    );
  }

  Future<void> save(ReminderSettings settings) async {
    final prefs = await _prefsInstance();
    await prefs.setInt(_leadMinutesKey, settings.leadMinutes);
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setBool(
      _nextDaySummaryEnabledKey,
      settings.nextDaySummaryEnabled,
    );
    await prefs.setInt(_nextDaySummaryHourKey, settings.nextDaySummaryHour);
    await prefs.setInt(
      _nextDaySummaryMinuteKey,
      settings.nextDaySummaryMinute,
    );
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
    await prefs.setBool(_systemAlarmEnabledKey, settings.systemAlarmEnabled);
    await prefs.setInt(
      _systemAlarmLeadMinutesKey,
      settings.systemAlarmLeadMinutes,
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
