import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/course_session.dart';
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

final weekGridProvider = FutureProvider((ref) async {
  ref.watch(scheduleRefreshProvider);
  final repository = ref.watch(scheduleRepositoryProvider);
  final gridBuilder = ref.watch(gridBuilderProvider);

  var weekStart = ref.watch(selectedWeekStartProvider);
  weekStart ??= await repository.getEarliestWeekStart();
  if (weekStart == null) {
    return null;
  }
  weekStart = weekStartFor(weekStart);

  final weekSessions = await repository.getSessionsForWeek(weekStart);
  return gridBuilder.buildWeekGrid(
    weekStart: weekStart,
    sessions: weekSessions,
  );
});
