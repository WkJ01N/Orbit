import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/settings_service.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler.shared,
);

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(),
);

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

final themeColorProvider = NotifierProvider<ThemeColorNotifier, Color>(
  ThemeColorNotifier.new,
);

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

final themeStyleProvider = NotifierProvider<ThemeStyleNotifier, AppThemeStyle>(
  ThemeStyleNotifier.new,
);

final courseColorOverridesProvider =
    NotifierProvider<CourseColorOverridesNotifier, Map<String, Color>>(
      CourseColorOverridesNotifier.new,
    );

class ThemeColorNotifier extends Notifier<Color> {
  int _loadGeneration = 0;

  @override
  Color build() {
    _loadSavedColor();
    return kDefaultThemeColor;
  }

  Future<void> _loadSavedColor() async {
    final generation = ++_loadGeneration;
    final saved = await ref.read(settingsServiceProvider).loadThemeColor();
    if (generation != _loadGeneration) {
      return;
    }
    state = saved;
  }

  Future<void> setColor(Color color) async {
    await ref.read(settingsServiceProvider).saveThemeColor(color);
    state = color;
  }
}

class ThemeModeNotifier extends Notifier<ThemeMode> {
  int _loadGeneration = 0;

  @override
  ThemeMode build() {
    _loadSavedMode();
    return ThemeMode.system;
  }

  Future<void> _loadSavedMode() async {
    final generation = ++_loadGeneration;
    final saved = await ref.read(settingsServiceProvider).loadThemeMode();
    if (generation != _loadGeneration) {
      return;
    }
    state = saved;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(settingsServiceProvider).saveThemeMode(mode);
    state = mode;
  }
}

class ThemeStyleNotifier extends Notifier<AppThemeStyle> {
  int _loadGeneration = 0;

  @override
  AppThemeStyle build() {
    _loadSavedStyle();
    return AppThemeStyle.standard;
  }

  Future<void> _loadSavedStyle() async {
    final generation = ++_loadGeneration;
    final saved = await ref.read(settingsServiceProvider).loadThemeStyle();
    if (generation == _loadGeneration) {
      state = saved;
    }
  }

  Future<void> setStyle(AppThemeStyle style) async {
    await ref.read(settingsServiceProvider).saveThemeStyle(style);
    state = style;
  }
}

class CourseColorOverridesNotifier extends Notifier<Map<String, Color>> {
  int _loadGeneration = 0;

  @override
  Map<String, Color> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final saved = await ref
        .read(settingsServiceProvider)
        .loadCourseColorOverrides();
    if (generation != _loadGeneration) {
      return;
    }
    state = saved;
  }

  Future<void> setColor(String key, Color color) async {
    final updated = Map<String, Color>.from(state)..[key] = color;
    await ref.read(settingsServiceProvider).saveCourseColorOverrides(updated);
    state = updated;
  }

  Future<void> clearColor(String key) async {
    final updated = Map<String, Color>.from(state)..remove(key);
    await ref.read(settingsServiceProvider).saveCourseColorOverrides(updated);
    state = updated;
  }
}

class LocaleNotifier extends Notifier<Locale> {
  int _loadGeneration = 0;

  @override
  Locale build() {
    _loadSavedLocale();
    return defaultLocale;
  }

  Future<void> _loadSavedLocale() async {
    final generation = ++_loadGeneration;
    final saved = await ref.read(settingsServiceProvider).loadLocale();
    if (generation != _loadGeneration) {
      return;
    }
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

  Future<int> setNextDayRemindWhenNoClass(bool enabled) async {
    final current = state.value ?? const ReminderSettings();
    return _saveAndReschedule(
      current.copyWith(nextDayRemindWhenNoClass: enabled),
    );
  }

  Future<int> updateNextDayTemplates({
    String? withClassTitle,
    String? withClassBody,
    String? noClassTitle,
    String? noClassBody,
  }) async {
    final current = state.value ?? const ReminderSettings();
    final wt = withClassTitle?.trim() ?? '';
    final wb = withClassBody?.trim() ?? '';
    final nt = noClassTitle?.trim() ?? '';
    final nb = noClassBody?.trim() ?? '';
    return _saveAndReschedule(
      current.copyWith(
        nextDayWithClassTitleTemplate: wt.isEmpty ? null : wt,
        nextDayWithClassBodyTemplate: wb.isEmpty ? null : wb,
        nextDayNoClassTitleTemplate: nt.isEmpty ? null : nt,
        nextDayNoClassBodyTemplate: nb.isEmpty ? null : nb,
        clearNextDayWithClassTitleTemplate: wt.isEmpty,
        clearNextDayWithClassBodyTemplate: wb.isEmpty,
        clearNextDayNoClassTitleTemplate: nt.isEmpty,
        clearNextDayNoClassBodyTemplate: nb.isEmpty,
      ),
    );
  }

  Future<int> updateClassLeadTemplates({String? title, String? body}) async {
    final current = state.value ?? const ReminderSettings();
    final t = title?.trim() ?? '';
    final b = body?.trim() ?? '';
    return _saveAndReschedule(
      current.copyWith(
        classLeadTitleTemplate: t.isEmpty ? null : t,
        classLeadBodyTemplate: b.isEmpty ? null : b,
        clearClassLeadTitleTemplate: t.isEmpty,
        clearClassLeadBodyTemplate: b.isEmpty,
      ),
    );
  }

  Future<int> updateCheckInTemplates({String? title, String? body}) async {
    final current = state.value ?? const ReminderSettings();
    final t = title?.trim() ?? '';
    final b = body?.trim() ?? '';
    return _saveAndReschedule(
      current.copyWith(
        checkInTitleTemplate: t.isEmpty ? null : t,
        checkInBodyTemplate: b.isEmpty ? null : b,
        clearCheckInTitleTemplate: t.isEmpty,
        clearCheckInBodyTemplate: b.isEmpty,
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
      final List<CourseSession> all;
      final List<CourseSession> upcoming;
      final sessionsAsync = ref.read(sessionsProvider);
      if (sessionsAsync.hasValue) {
        all = sessionsAsync.value!;
        upcoming = all
            .where((session) => session.startAt.isAfter(DateTime.now()))
            .toList();
      } else {
        all = await repository.getAllSessions();
        upcoming = await repository.getUpcomingSessions();
      }
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
