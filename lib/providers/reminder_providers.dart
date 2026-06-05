import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/settings_service.dart';

final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => ReminderScheduler.shared);

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService());

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

final themeColorProvider =
    NotifierProvider<ThemeColorNotifier, Color>(ThemeColorNotifier.new);

class ThemeColorNotifier extends Notifier<Color> {
  @override
  Color build() {
    _loadSavedColor();
    return kDefaultThemeColor;
  }

  Future<void> _loadSavedColor() async {
    final saved = await ref.read(settingsServiceProvider).loadThemeColor();
    state = saved;
  }

  Future<void> setColor(Color color) async {
    await ref.read(settingsServiceProvider).saveThemeColor(color);
    state = color;
  }
}

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _loadSavedLocale();
    return defaultLocale;
  }

  Future<void> _loadSavedLocale() async {
    final saved = await ref.read(settingsServiceProvider).loadLocale();
    state = saved;
  }

  Future<void> setLocale(Locale locale) async {
    await ref.read(settingsServiceProvider).saveLocale(locale);
    state = locale;
  }
}

NotificationCopy notificationCopyFor(Locale locale) {
  return NotificationCopy.fromL10n(lookupL10n(locale));
}

final reminderSettingsProvider =
    AsyncNotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
  ReminderSettingsNotifier.new,
);

class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() async {
    final settings = await ref.read(settingsServiceProvider).load();
    if (Platform.isAndroid || Platform.isWindows) {
      await _rescheduleReminders();
    }
    return settings;
  }

  Future<void> _saveAndReschedule(ReminderSettings updated) async {
    await ref.read(settingsServiceProvider).save(updated);
    state = AsyncData(updated);
    await _rescheduleReminders();
  }

  Future<void> updateLeadMinutes(int minutes) async {
    final current = state.value ?? const ReminderSettings();
    await _saveAndReschedule(current.copyWith(leadMinutes: minutes));
  }

  Future<void> setEnabled(bool enabled) async {
    final current = state.value ?? const ReminderSettings();
    await _saveAndReschedule(current.copyWith(enabled: enabled));
  }

  Future<void> setNextDaySummaryEnabled(bool enabled) async {
    final current = state.value ?? const ReminderSettings();
    await _saveAndReschedule(current.copyWith(nextDaySummaryEnabled: enabled));
  }

  Future<void> setNextDaySummaryTime(TimeOfDay time) async {
    final current = state.value ?? const ReminderSettings();
    await _saveAndReschedule(
      current.copyWith(
        nextDaySummaryHour: time.hour,
        nextDaySummaryMinute: time.minute,
      ),
    );
  }

  Future<void> setSystemAlarmEnabled(bool enabled) async {
    final current = state.value ?? const ReminderSettings();
    final updated = current.copyWith(systemAlarmEnabled: enabled);
    await ref.read(settingsServiceProvider).save(updated);
    state = AsyncData(updated);
  }

  Future<void> setSystemAlarmLeadMinutes(int minutes) async {
    final current = state.value ?? const ReminderSettings();
    final updated = current.copyWith(systemAlarmLeadMinutes: minutes);
    await ref.read(settingsServiceProvider).save(updated);
    state = AsyncData(updated);
  }

  Future<void> setCheckInReminderEnabled(bool enabled) async {
    final current = state.value ?? const ReminderSettings();
    await _saveAndReschedule(
      current.copyWith(checkInReminderEnabled: enabled),
    );
  }

  Future<int> resyncReminders() async {
    return _rescheduleReminders();
  }

  Future<int> _rescheduleReminders() async {
    final settings = state.value ?? const ReminderSettings();
    final locale = ref.read(localeProvider);
    final copy = notificationCopyFor(locale);
    final repository = ref.read(scheduleRepositoryProvider);
    final upcoming = await repository.getUpcomingSessions();
    final all = await repository.getAllSessions();
    final scheduler = ref.read(reminderSchedulerProvider);
    await scheduler.rescheduleAll(
      upcomingSessions: upcoming,
      allSessions: all,
      settings: settings,
      copy: copy,
    );
    return scheduler.lastScheduleFailureCount;
  }
}

Future<int> rescheduleAllReminders(WidgetRef ref) {
  return ref.read(reminderSettingsProvider.notifier).resyncReminders();
}
