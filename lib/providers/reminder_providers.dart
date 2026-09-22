import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/services/windows_reminder_maintenance.dart';
import 'package:orbit/services/android_native_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/reminder_schedule_report.dart';
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

final colorSchemeProvider =
    NotifierProvider<ColorSchemeNotifier, AppColorScheme>(
      ColorSchemeNotifier.new,
    );

final multicolorSettingsProvider =
    NotifierProvider<MulticolorSettingsNotifier, MulticolorSettings>(
      MulticolorSettingsNotifier.new,
    );

class MulticolorSettingsNotifier extends Notifier<MulticolorSettings> {
  int _generation = 0;
  Future<void> _saves = Future.value();
  @override
  MulticolorSettings build() {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    ref.read(settingsServiceProvider).loadMulticolorSettings().then((value) {
      if (generation == _generation) state = value;
    });
    return const MulticolorSettings();
  }

  Future<void> setValue(MulticolorSettings value) {
    _generation++;
    state = value;
    final service = ref.read(settingsServiceProvider);
    return _saves = _saves
        .catchError((Object _) {})
        .then((_) => service.saveMulticolorSettings(value));
  }
}

class ColorSchemeNotifier extends Notifier<AppColorScheme> {
  int _generation = 0;
  Future<void> _saves = Future.value();
  @override
  AppColorScheme build() {
    final generation = ++_generation;
    ref.read(settingsServiceProvider).loadColorScheme().then((saved) {
      if (generation == _generation) state = saved;
    });
    ref.onDispose(() => _generation++);
    return AppColorScheme.original;
  }

  Future<void> setScheme(AppColorScheme scheme) {
    _generation++;
    state = scheme;
    return _saves = _saves
        .catchError((Object _) {})
        .then((_) => ref.read(settingsServiceProvider).saveColorScheme(scheme));
  }
}

class ThemeColorNotifier extends Notifier<Color> {
  int _loadGeneration = 0;
  Future<void> _saves = Future.value();

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

  Future<void> setColor(Color color) {
    _loadGeneration++;
    state = color;
    final service = ref.read(settingsServiceProvider);
    return _saves = _saves
        .catchError((Object _) {})
        .then((_) => service.saveThemeColor(color));
  }
}

class ThemeModeNotifier extends Notifier<ThemeMode> {
  int _loadGeneration = 0;
  Future<void> _saves = Future.value();

  @override
  ThemeMode build() {
    ref.onDispose(() => _loadGeneration++);
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

  Future<void> setThemeMode(ThemeMode mode) {
    _loadGeneration++;
    state = mode;
    final service = ref.read(settingsServiceProvider);
    return _saves = _saves
        .catchError((Object _) {})
        .then((_) => service.saveThemeMode(mode));
  }
}

class ThemeStyleNotifier extends Notifier<AppThemeStyle> {
  int _loadGeneration = 0;
  Future<void> _saves = Future.value();

  @override
  AppThemeStyle build() {
    ref.onDispose(() => _loadGeneration++);
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

  Future<void> setStyle(AppThemeStyle style) {
    _loadGeneration++;
    state = style;
    final service = ref.read(settingsServiceProvider);
    return _saves = _saves
        .catchError((Object _) {})
        .then((_) => service.saveThemeStyle(style));
  }
}

class CourseColorOverridesNotifier extends Notifier<Map<String, Color>> {
  int _loadGeneration = 0;
  Future<void> _saves = Future.value();
  late Future<void> _loading;

  @override
  Map<String, Color> build() {
    ref.onDispose(() => _loadGeneration++);
    _loading = _load();
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

  Future<void> setColor(String key, Color color) {
    final service = ref.read(settingsServiceProvider);
    return _saves = _saves.catchError((Object _) {}).then((_) async {
      await _loading;
      final updated = Map<String, Color>.from(state)..[key] = color;
      await service.saveCourseColorOverrides(updated);
      state = updated;
    });
  }

  Future<void> clearColor(String key) {
    final service = ref.read(settingsServiceProvider);
    return _saves = _saves.catchError((Object _) {}).then((_) async {
      await _loading;
      final updated = Map<String, Color>.from(state)..remove(key);
      await service.saveCourseColorOverrides(updated);
      state = updated;
    });
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

final lastReminderScheduleReportProvider =
    StateProvider<ReminderScheduleReport>(
      (ref) => ReminderScheduleReport.empty,
    );

class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  Timer? _deferredResync;
  bool _disposed = false;
  ReminderSettings? _latestSelection;
  Future<void> _saveQueue = Future.value();

  @override
  Future<ReminderSettings> build() async {
    _disposed = false;
    if (Platform.isWindows) {
      WindowsReminderMaintenance.onStatus = (error) {
        if (!_disposed) {
          ref.read(lastRescheduleErrorProvider.notifier).state = error;
        }
      };
    }
    ref.onDispose(() {
      _disposed = true;
      _deferredResync?.cancel();
    });
    final settings = await ref.read(settingsServiceProvider).load();
    if (!_disposed && Platform.isAndroid) {
      await _rescheduleReminders(settings: settings);
    } else if (!_disposed && Platform.isWindows) {
      // Preferences can render immediately; OS scheduling is maintenance work.
      scheduleResync();
    }
    return _latestSelection ?? settings;
  }

  Future<int> _saveAndReschedule(ReminderSettings updated) async {
    _deferredResync?.cancel();
    _latestSelection = updated;
    state = AsyncData(updated);
    final service = ref.read(settingsServiceProvider);
    _saveQueue = _saveQueue
        .catchError((Object error) {
          debugPrint('Previous reminder save failed: $error');
        })
        .then((_) => service.save(updated));
    await _saveQueue;
    return _rescheduleReminders();
  }

  Future<int> setCustomRules(List<CustomReminderRule> rules) {
    final current = state.value ?? const ReminderSettings();
    final previous = {for (final rule in current.customRules) rule.id: rule};
    final now = DateTime.now();
    return _saveAndReschedule(
      current.copyWith(
        customRules: [
          for (final rule in rules)
            rule.enabled &&
                    (previous[rule.id] == null || !previous[rule.id]!.enabled)
                ? rule.copyWith(activeFrom: now)
                : rule,
        ],
      ),
    );
  }

  Future<int> setStrong(StrongReminderSettings strong) => _saveAndReschedule(
    (state.value ?? const ReminderSettings()).copyWith(strong: strong),
  );

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

  Future<int> setCheckInReminderEnabled(bool enabled) async {
    final current = state.value ?? const ReminderSettings();
    return _saveAndReschedule(
      current.copyWith(checkInReminderEnabled: enabled),
    );
  }

  Future<int> resyncReminders() {
    _deferredResync?.cancel();
    return _rescheduleReminders();
  }

  void scheduleResync() {
    _deferredResync?.cancel();
    _deferredResync = Timer(const Duration(milliseconds: 250), () {
      _deferredResync = null;
      unawaited(_rescheduleReminders());
    });
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
      if (sessionsAsync.hasValue && !sessionsAsync.isLoading) {
        all = sessionsAsync.value!;
        final now = DateTime.now();
        upcoming = all.where((session) => session.endAt.isAfter(now)).toList();
      } else {
        all = await repository.getAllSessions();
        upcoming = await repository.getUpcomingSessions();
      }
      final scheduler = ref.read(reminderSchedulerProvider);
      final database = ref.read(appDatabaseProvider);
      scheduler.database = database;
      await scheduler.rescheduleAll(
        upcomingSessions: upcoming,
        allSessions: all,
        deadlines: await database.getDeadlines(),
        settings: effectiveSettings,
        copy: copy,
      );
      if (_disposed) return 0;
      final failures = scheduler.lastScheduleFailureCount;
      ref.read(lastScheduledCountProvider.notifier).state =
          scheduler.lastPendingCount;
      ref.read(lastReminderScheduleReportProvider.notifier).state =
          scheduler.lastScheduleReport;
      if (scheduler.lastScheduleVerificationFailed) {
        ref.read(lastRescheduleErrorProvider.notifier).state = 'verify';
      } else if (failures > 0) {
        ref.read(lastRescheduleErrorProvider.notifier).state =
            'partial:$failures';
      } else {
        final prefs = await SharedPreferences.getInstance();
        if (Platform.isWindows &&
            prefs.getString('windows_reminder_failure') == 'maintenance') {
          try {
            await WindowsReminderMaintenance.register();
          } catch (error) {
            debugPrint('Maintenance retry failed: $error');
          }
        }
        if (Platform.isWindows &&
            prefs.getString('windows_reminder_failure') == 'schedule') {
          await prefs.remove('windows_reminder_failure');
        }
        ref.read(lastRescheduleErrorProvider.notifier).state = prefs.getString(
          'windows_reminder_failure',
        );
        if (Platform.isAndroid &&
            await AndroidNativeReminderService.instance.runtimeStatus() !=
                null) {
          ref.read(lastRescheduleErrorProvider.notifier).state = 'strong';
        }
      }
      if (!scheduler.lastScheduleReport.isBlocked &&
          !scheduler.lastScheduleReport.verificationFailed) {
        scheduler.markRescheduleSuccess();
      }
      return failures;
    } catch (error, stackTrace) {
      debugPrint('Reminder reschedule failed: $error');
      debugPrint('$stackTrace');
      if (!_disposed) {
        ref.read(lastRescheduleErrorProvider.notifier).state = '$error';
      }
      return 0;
    }
  }
}

Future<int> rescheduleAllReminders(WidgetRef ref) {
  return ref.read(reminderSettingsProvider.notifier).resyncReminders();
}
