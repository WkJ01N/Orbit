import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_models.dart';
import 'package:orbit/providers/database_providers.dart';
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

DateTime? earliestWeekStartFromSessions(List<CourseSession> sessions) {
  if (sessions.isEmpty) {
    return null;
  }
  final earliest = sessions
      .map((session) => session.date)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return weekStartFor(earliest);
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

  var weekStart = ref.watch(selectedWeekStartProvider);
  weekStart ??= earliestWeekStartFromSessions(sessions);
  if (weekStart == null) {
    return null;
  }

  return ref.read(gridBuilderProvider).buildWeekGrid(
        weekStart: weekStartFor(weekStart),
        sessions: sessions,
      );
});
