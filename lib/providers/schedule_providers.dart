import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/grid_models.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/grid_builder.dart';
import 'package:orbit/services/xlsx_parser.dart';

final xlsxParserProvider = Provider<XlsxParser>((ref) => XlsxParser());

final gridBuilderProvider = Provider<GridBuilder>((ref) => GridBuilder());

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(xlsxParserProvider),
  );
});

final sessionsProvider = FutureProvider<List<CourseSession>>((ref) async {
  ref.watch(scheduleRefreshProvider);
  return ref.read(scheduleRepositoryProvider).getAllSessions();
});

final upcomingSessionsProvider = FutureProvider<List<CourseSession>>((
  ref,
) async {
  ref.watch(scheduleRefreshProvider);
  return ref.read(scheduleRepositoryProvider).getUpcomingSessions();
});

final scheduleRefreshProvider = StateProvider<int>((ref) => 0);

void refreshSchedule(WidgetRef ref) {
  ref.read(scheduleRefreshProvider.notifier).state++;
}

void refreshScheduleContainer(ProviderContainer container) {
  container.read(scheduleRefreshProvider.notifier).state++;
}

final selectedWeekStartProvider = StateProvider<DateTime?>((ref) => null);

final selectedScheduleDateProvider = StateProvider<DateTime?>((ref) => null);

final scheduleDisplaySettingsProvider =
    NotifierProvider<ScheduleDisplaySettingsNotifier, ScheduleDisplaySettings>(
      ScheduleDisplaySettingsNotifier.new,
    );

class ScheduleDisplaySettingsNotifier
    extends Notifier<ScheduleDisplaySettings> {
  int _loadGeneration = 0;

  @override
  ScheduleDisplaySettings build() {
    _load();
    return const ScheduleDisplaySettings();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final settings = await ref
        .read(settingsServiceProvider)
        .loadScheduleDisplaySettings();
    if (generation == _loadGeneration) {
      state = settings;
    }
  }

  Future<void> setPreferredMultiDayCount(int count) async {
    final next = state.copyWith(preferredMultiDayCount: count.clamp(1, 6));
    state = next;
    await ref.read(settingsServiceProvider).saveScheduleDisplaySettings(next);
  }

  Future<void> setShowEmptyDays(bool value) async {
    final next = state.copyWith(showEmptyDays: value);
    state = next;
    await ref.read(settingsServiceProvider).saveScheduleDisplaySettings(next);
  }

  Future<void> setShowUpcomingCourseDate(bool value) async {
    final next = state.copyWith(showUpcomingCourseDate: value);
    state = next;
    await ref.read(settingsServiceProvider).saveScheduleDisplaySettings(next);
  }

  Future<void> setUpcomingDateDisplay(UpcomingDateDisplay value) async {
    final next = state.copyWith(upcomingDateDisplay: value);
    state = next;
    await ref.read(settingsServiceProvider).saveScheduleDisplaySettings(next);
  }
}

final gridDefaultWeekModeProvider =
    NotifierProvider<GridDefaultWeekModeNotifier, GridDefaultWeekMode>(
      GridDefaultWeekModeNotifier.new,
    );

class GridDefaultWeekModeNotifier extends Notifier<GridDefaultWeekMode> {
  int _loadGeneration = 0;

  @override
  GridDefaultWeekMode build() {
    _load();
    return GridDefaultWeekMode.smart;
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final mode = await ref
        .read(settingsServiceProvider)
        .loadGridDefaultWeekMode();
    if (generation != _loadGeneration) {
      return;
    }
    state = mode;
  }

  Future<void> setMode(GridDefaultWeekMode mode) async {
    await ref.read(settingsServiceProvider).saveGridDefaultWeekMode(mode);
    state = mode;
  }
}

final weekStartDayProvider = NotifierProvider<WeekStartDayNotifier, int>(
  WeekStartDayNotifier.new,
);

class WeekStartDayNotifier extends Notifier<int> {
  int _loadGeneration = 0;

  @override
  int build() {
    _load();
    return DateTime.monday;
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final day = await ref.read(settingsServiceProvider).loadWeekStartDay();
    if (generation != _loadGeneration) {
      return;
    }
    state = day;
  }

  Future<void> setWeekStartDay(int weekday) async {
    await ref.read(settingsServiceProvider).saveWeekStartDay(weekday);
    state = weekday;
    ref.read(selectedWeekStartProvider.notifier).state = null;
    ref.read(selectedScheduleDateProvider.notifier).state = null;
  }
}

final gridDensityProvider = NotifierProvider<GridDensityNotifier, GridDensity>(
  GridDensityNotifier.new,
);

class GridDensityNotifier extends Notifier<GridDensity> {
  int _loadGeneration = 0;

  @override
  GridDensity build() {
    _load();
    return GridDensity.standard;
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final density = await ref.read(settingsServiceProvider).loadGridDensity();
    if (generation != _loadGeneration) {
      return;
    }
    state = density;
  }

  Future<void> setDensity(GridDensity density) async {
    await ref.read(settingsServiceProvider).saveGridDensity(density);
    state = density;
  }
}

final gridDensityMetricsProvider = Provider<GridDensityMetrics>((ref) {
  return GridDensityMetrics.forDensity(ref.watch(gridDensityProvider));
});

final weekGridProvider = Provider<WeekGrid?>((ref) {
  final sessions = ref.watch(sessionsProvider).valueOrNull;
  if (sessions == null) {
    return null;
  }
  if (sessions.isEmpty) {
    return null;
  }

  final mode = ref.watch(gridDefaultWeekModeProvider);
  final startWeekday = ref.watch(weekStartDayProvider);
  var weekStart = ref.watch(selectedWeekStartProvider);
  weekStart ??= resolveDefaultWeekStart(
    sessions,
    mode,
    startWeekday: startWeekday,
  );
  if (weekStart == null) {
    return null;
  }

  return ref
      .read(gridBuilderProvider)
      .buildWeekGrid(
        weekStart: weekStartFor(weekStart, startWeekday: startWeekday),
        sessions: sessions,
      );
});
