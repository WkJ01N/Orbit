import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/grid_models.dart';

class GridPagerSlot {
  const GridPagerSlot({
    required this.grid,
    this.day,
  });

  final WeekGrid grid;
  final int? day;

  DateTime get weekStart => weekStartFor(grid.weekStart);
}

List<int> presentWeekdays(
  WeekGrid grid, {
  int startWeekday = DateTime.monday,
}) {
  final presentWeekdays = <int>{};
  for (final key in grid.cells.keys) {
    presentWeekdays.add(int.parse(key.split('|').first));
  }
  return orderedWeekdays(startWeekday: startWeekday)
      .where((day) => presentWeekdays.contains(day))
      .toList();
}

bool isEmptyWeekGrid(WeekGrid grid, {int startWeekday = DateTime.monday}) {
  final weekdays = presentWeekdays(grid, startWeekday: startWeekday);
  return weekdays.isEmpty || grid.timeLabels.isEmpty;
}

int defaultWeekdayForGrid(
  WeekGrid grid, {
  int startWeekday = DateTime.monday,
}) {
  final weekdays = presentWeekdays(grid, startWeekday: startWeekday);
  if (weekdays.isEmpty) {
    return startWeekday;
  }
  final today = DateTime.now().weekday;
  if (weekdays.contains(today) &&
      weekStartFor(DateTime.now(), startWeekday: startWeekday) ==
          weekStartFor(grid.weekStart, startWeekday: startWeekday)) {
    return today;
  }
  return weekdays.first;
}

GridPagerSlot slotForDay(WeekGrid grid, int day) {
  return GridPagerSlot(grid: grid, day: day);
}

GridPagerSlot slotForWeek(WeekGrid grid) {
  return GridPagerSlot(grid: grid);
}

GridPagerSlot? computePreviousDaySlot(
  GridPagerSlot current, {
  int startWeekday = DateTime.monday,
}) {
  final weekdays = presentWeekdays(current.grid, startWeekday: startWeekday);
  final day = current.day;
  if (day == null) {
    return null;
  }

  final order = orderedWeekdays(startWeekday: startWeekday);
  final firstDay = order.first;
  final lastDay = order.last;

  if (weekdays.isEmpty) {
    final previousWeekStart = weekStartFor(
      current.weekStart.subtract(const Duration(days: 7)),
      startWeekday: startWeekday,
    );
    return GridPagerSlot(
      grid: WeekGrid(
        weekStart: previousWeekStart,
        timeLabels: const [],
        cells: const {},
      ),
      day: firstDay,
    );
  }

  final index = weekdays.indexOf(day);
  if (index < 0) {
    return GridPagerSlot(grid: current.grid, day: weekdays.first);
  }
  if (index > 0) {
    return GridPagerSlot(grid: current.grid, day: weekdays[index - 1]);
  }

  final previousWeekStart = weekStartFor(
    current.weekStart.subtract(const Duration(days: 7)),
    startWeekday: startWeekday,
  );
  return GridPagerSlot(
    grid: WeekGrid(
      weekStart: previousWeekStart,
      timeLabels: const [],
      cells: const {},
    ),
    day: lastDay,
  );
}

GridPagerSlot? computeNextDaySlot(
  GridPagerSlot current, {
  int startWeekday = DateTime.monday,
}) {
  final weekdays = presentWeekdays(current.grid, startWeekday: startWeekday);
  final day = current.day;
  if (day == null) {
    return null;
  }

  final order = orderedWeekdays(startWeekday: startWeekday);
  final firstDay = order.first;

  if (weekdays.isEmpty) {
    final nextWeekStart = weekStartFor(
      current.weekStart.add(const Duration(days: 7)),
      startWeekday: startWeekday,
    );
    return GridPagerSlot(
      grid: WeekGrid(
        weekStart: nextWeekStart,
        timeLabels: const [],
        cells: const {},
      ),
      day: firstDay,
    );
  }

  final index = weekdays.indexOf(day);
  if (index < 0) {
    return GridPagerSlot(grid: current.grid, day: weekdays.first);
  }
  if (index < weekdays.length - 1) {
    return GridPagerSlot(grid: current.grid, day: weekdays[index + 1]);
  }

  final nextWeekStart = weekStartFor(
    current.weekStart.add(const Duration(days: 7)),
    startWeekday: startWeekday,
  );
  return GridPagerSlot(
    grid: WeekGrid(
      weekStart: nextWeekStart,
      timeLabels: const [],
      cells: const {},
    ),
    day: firstDay,
  );
}

GridPagerSlot? computePreviousWeekSlot(GridPagerSlot current) {
  final previousWeekStart =
      weekStartFor(current.weekStart.subtract(const Duration(days: 7)));
  return GridPagerSlot(
    grid: WeekGrid(
      weekStart: previousWeekStart,
      timeLabels: const [],
      cells: const {},
    ),
  );
}

GridPagerSlot? computeNextWeekSlot(GridPagerSlot current) {
  final nextWeekStart =
      weekStartFor(current.weekStart.add(const Duration(days: 7)));
  return GridPagerSlot(
    grid: WeekGrid(
      weekStart: nextWeekStart,
      timeLabels: const [],
      cells: const {},
    ),
  );
}

int? resolveDayAfterWeekChange({
  required GridPagerSlot targetSlot,
  required int crossWeekDirection,
  int startWeekday = DateTime.monday,
}) {
  final weekdays =
      presentWeekdays(targetSlot.grid, startWeekday: startWeekday);
  if (weekdays.isEmpty) {
    return null;
  }
  return crossWeekDirection > 0 ? weekdays.first : weekdays.last;
}

bool slotsReferToSamePage(
  GridPagerSlot a,
  GridPagerSlot b, {
  required bool isCompact,
}) {
  if (weekStartFor(a.grid.weekStart) != weekStartFor(b.grid.weekStart)) {
    return false;
  }
  if (isCompact) {
    return a.day == b.day;
  }
  return true;
}
