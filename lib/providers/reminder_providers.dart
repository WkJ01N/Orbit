import 'dart:io';

import 'package:flutter/foundation.dart';
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

final lastRescheduleErrorProvider = StateProvider<String?>((ref) => null);

/// Number of reminders the OS reports as actually queued after the last
/// reschedule (-1 when verification is unavailable, e.g. on Windows).
final lastScheduledCountProvider = StateProvider<int>((ref) => -1);

/// Android AlarmManager one-shots registered after the last reschedule.
final lastRegisteredAlarmCountProvider = StateProvider<int>((ref) => 0);

class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() async {
    final settings = await ref.read(settingsServiceProvider).load();
    if (Platform.isAndroid || Platform.isWindows) {
      await _rescheduleReminders(settings: settings);
    }
    return settings;
  }

  Future<int> _saveAndReschedule(ReminderSettings updated) async {
    await ref.read(settingsServiceProvider).save(updated);
    state = AsyncData(updated);
    return _rescheduleReminders();
  }

  Future<int> updateLeadMinutes(int minutes) async {
    final current = state.value ?? const ReminderSettings();
    return _saveAndReschedule(current.copyWith(leadMinutes: minutes));
  }

  Future<int> setEnabled(bool enabled) async {
    final current = state.value ?? const ReminderSettings();
    return _saveAndReschedule(current.copyWith(enabled: enabled));
  }

  Future<int> setNextDaySummaryEnabled(bool enabled) async {
    final current = state.value ?? const ReminderSettings();
    return _saveAndReschedule(current.copyWith(nextDaySummaryEnabled: enabled));
  }

  Future<int> setNextDaySummaryTime(TimeOfDay time) async {
    final current = state.value ?? const ReminderSettings();
    return _saveAndReschedule(
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

  Future<int> setCheckInReminderEnabled(bool enabled) async {
    final current = state.value ?? const ReminderSettings();
    return _saveAndReschedule(
      current.copyWith(checkInReminderEnabled: enabled),
    );
  }

  Future<int> resyncReminders() {
    return _rescheduleReminders();
  }

  Future<int> _rescheduleReminders({ReminderSettings? settings}) async {
    try {
      final effectiveSettings =
          settings ?? state.value ?? const ReminderSettings();
      final locale = ref.read(localeProvider);
      final copy = notificationCopyFor(locale);
      final repository = ref.read(scheduleRepositoryProvider);
      final upcoming = await repository.getUpcomingSessions();
      final all = await repository.getAllSessions();
      final scheduler = ref.read(reminderSchedulerProvider);
      await scheduler.rescheduleAll(
        upcomingSessions: upcoming,
        allSessions: all,
        settings: effectiveSettings,
        copy: copy,
      );
      final failures = scheduler.lastScheduleFailureCount;
      ref.read(lastScheduledCountProvider.notifier).state =
          scheduler.lastPendingCount;
      ref.read(lastRegisteredAlarmCountProvider.notifier).state =
          scheduler.lastRegisteredAlarmCount;
      if (scheduler.lastScheduleVerificationFailed) {
        // The plugin reported success but the OS queued nothing: surface a
        // dedicated message so the user can fix exact-alarm / battery settings.
        ref.read(lastRescheduleErrorProvider.notifier).state = 'verify';
      } else if (failures > 0) {
        ref.read(lastRescheduleErrorProvider.notifier).state =
            'partial:$failures';
      } else {
        ref.read(lastRescheduleErrorProvider.notifier).state = null;
      }
      scheduler.markRescheduleSuccess();
      return failures;
    } catch (error, stackTrace) {
      debugPrint('Reminder reschedule failed: $error');
      debugPrint('$stackTrace');
      ref.read(lastRescheduleErrorProvider.notifier).state = '$error';
      return 0;
    }
  }
}

Future<int> rescheduleAllReminders(WidgetRef ref) {
  return ref.read(reminderSettingsProvider.notifier).resyncReminders();
}
