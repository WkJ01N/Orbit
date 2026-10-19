import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/features/deadline/deadline_strong_host.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/providers/notification_providers.dart';

/// Read in parallel with database startup, before the first branded frame.
class LaunchSnapshot {
  const LaunchSnapshot({
    required this.settings,
    required this.color,
    required this.mode,
    required this.style,
    required this.multicolor,
    required this.locale,
    required this.display,
    required this.weekStart,
    required this.defaultWeek,
    required this.density,
  });
  final LaunchSettings settings;
  final Color color;
  final ThemeMode mode;
  final AppThemeStyle style;
  final MulticolorSettings multicolor;
  final Locale locale;
  final ScheduleDisplaySettings display;
  final int weekStart;
  final GridDefaultWeekMode defaultWeek;
  final GridDensity density;

  static Future<LaunchSnapshot> load(SettingsService service) async {
    // SharedPreferences is cached by the plugin; independent reads can overlap.
    final values = await Future.wait<Object>([
      service
          .loadLocalJson('launch_presentation_v1')
          .then(LaunchSettings.fromJson),
      service.loadThemeColor(),
      service.loadThemeMode(),
      service.loadThemeStyle(),
      service.loadMulticolorSettings(),
      service.loadLocale(),
      service.loadScheduleDisplaySettings(),
      service.loadWeekStartDay(),
      service.loadGridDefaultWeekMode(),
      service.loadGridDensity(),
    ]);
    return LaunchSnapshot(
      settings: values[0] as LaunchSettings,
      color: values[1] as Color,
      mode: values[2] as ThemeMode,
      style: values[3] as AppThemeStyle,
      multicolor: values[4] as MulticolorSettings,
      locale: values[5] as Locale,
      display: values[6] as ScheduleDisplaySettings,
      weekStart: values[7] as int,
      defaultWeek: values[8] as GridDefaultWeekMode,
      density: values[9] as GridDensity,
    );
  }
}

final launchSnapshotProvider = Provider<LaunchSnapshot?>((ref) => null);
final launchAnimationsEnabledProvider = Provider<bool>((ref) => true);
final pageTransitionSuppressedProvider = Provider<bool>(
  (ref) =>
      !ref.watch(launchAnimationsEnabledProvider) ||
      ref.watch(strongConfirmationVisibleProvider) ||
      ref.watch(deadlineStrongEventsProvider).isNotEmpty ||
      ref.watch(pendingNotificationPayloadProvider) != null,
  dependencies: [
    launchAnimationsEnabledProvider,
    strongConfirmationVisibleProvider,
    deadlineStrongEventsProvider,
    pendingNotificationPayloadProvider,
  ],
);

final launchSettingsProvider =
    NotifierProvider<LaunchSettingsNotifier, LaunchSettings>(
      LaunchSettingsNotifier.new,
    );

class LaunchSettingsNotifier extends Notifier<LaunchSettings> {
  int _generation = 0;
  Future<void> _tail = Future.value();
  LaunchSettings? _confirmed;
  final _pending = <LaunchSettings Function(LaunchSettings)>[];
  bool _disposed = false;

  @override
  LaunchSettings build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    final snapshot = ref.read(launchSnapshotProvider);
    if (snapshot != null) return snapshot.settings;
    final generation = ++_generation;
    ref
        .read(settingsServiceProvider)
        .loadLocalJson('launch_presentation_v1')
        .then((json) {
          if (generation == _generation) state = LaunchSettings.fromJson(json);
        });
    return const LaunchSettings();
  }

  /// Changes are applied optimistically, and persisted against the last
  /// successful state. A failed change cannot roll back later, unrelated edits.
  Future<void> update(LaunchSettings Function(LaunchSettings) change) {
    _generation++;
    _confirmed ??= state;
    // Give each queued operation its own identity, even if callbacks are reused.
    LaunchSettings operation(LaunchSettings value) => change(value);
    _pending.add(operation);
    state = operation(state);
    final service = ref.read(settingsServiceProvider);
    final save = _tail.catchError((Object _) {}).then((_) async {
      try {
        final value = operation(_confirmed!);
        await service.saveLocalJson('launch_presentation_v1', value.toJson());
        _confirmed = value;
      } finally {
        _pending.remove(operation);
        if (!_disposed) {
          state = _pending.fold(_confirmed!, (value, apply) => apply(value));
        }
      }
    });
    _tail = save.catchError((Object _) {});
    return save;
  }

  Future<void> save(LaunchSettings value) => update((_) => value);
}
