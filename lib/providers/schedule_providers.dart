import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_models.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/services/grid_builder.dart';
import 'package:orbit/services/settings_service.dart';
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

final upcomingSessionsProvider =
    FutureProvider<List<CourseSession>>((ref) async {
  ref.watch(scheduleRefreshProvider);
  return ref.read(scheduleRepositoryProvider).getUpcomingSessions();
});

final scheduleRefreshProvider = StateProvider<int>((ref) => 0);

void refreshSchedule(WidgetRef ref) {
  ref.read(scheduleRefreshProvider.notifier).state++;
}

final selectedWeekStartProvider = StateProvider<DateTime?>((ref) => null);

final gridDefaultWeekModeProvider =
    NotifierProvider<GridDefaultWeekModeNotifier, GridDefaultWeekMode>(
  GridDefaultWeekModeNotifier.new,
);

class GridDefaultWeekModeNotifier extends Notifier<GridDefaultWeekMode> {
  @override
  GridDefaultWeekMode build() {
    _load();
    return GridDefaultWeekMode.smart;
  }

  Future<void> _load() async {
    state = await SettingsService().loadGridDefaultWeekMode();
  }

  Future<void> setMode(GridDefaultWeekMode mode) async {
    await SettingsService().saveGridDefaultWeekMode(mode);
    state = mode;
  }
}

final weekGridProvider = Provider<WeekGrid?>((ref) {
  ref.watch(scheduleRefreshProvider);
  final sessions = ref.watch(sessionsProvider).valueOrNull;
  if (sessions == null) {
    return null;
  }
  if (sessions.isEmpty) {
    return null;
  }

  final mode = ref.watch(gridDefaultWeekModeProvider);
  var weekStart = ref.watch(selectedWeekStartProvider);
  weekStart ??= resolveDefaultWeekStart(sessions, mode);
  if (weekStart == null) {
    return null;
  }

  return ref.read(gridBuilderProvider).buildWeekGrid(
        weekStart: weekStartFor(weekStart),
        sessions: sessions,
      );
});
