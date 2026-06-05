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

List<int> presentWeekdays(WeekGrid grid) {
  final presentWeekdays = <int>{};
  for (final key in grid.cells.keys) {
    presentWeekdays.add(int.parse(key.split('|').first));
  }
  return ([1, 2, 3, 4, 5, 6, 7]
        ..removeWhere((day) => !presentWeekdays.contains(day)))
      .toList();
}

bool isEmptyWeekGrid(WeekGrid grid) {
  final weekdays = presentWeekdays(grid);
  return weekdays.isEmpty || grid.timeLabels.isEmpty;
}

int defaultWeekdayForGrid(WeekGrid grid) {
  final weekdays = presentWeekdays(grid);
  if (weekdays.isEmpty) {
    return DateTime.monday;
  }
  final today = DateTime.now().weekday;
  if (weekdays.contains(today) &&
      weekStartFor(DateTime.now()) == weekStartFor(grid.weekStart)) {
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

GridPagerSlot? computePreviousDaySlot(GridPagerSlot current) {
  final weekdays = presentWeekdays(current.grid);
  final day = current.day;
  if (day == null) {
    return null;
  }

  if (weekdays.isEmpty) {
    final previousWeekStart =
        weekStartFor(current.weekStart.subtract(const Duration(days: 7)));
    return GridPagerSlot(
      grid: WeekGrid(
        weekStart: previousWeekStart,
        timeLabels: const [],
        cells: const {},
      ),
      day: DateTime.monday,
    );
  }

  final index = weekdays.indexOf(day);
  if (index < 0) {
    return GridPagerSlot(grid: current.grid, day: weekdays.first);
  }
  if (index > 0) {
    return GridPagerSlot(grid: current.grid, day: weekdays[index - 1]);
  }

  final previousWeekStart =
      weekStartFor(current.weekStart.subtract(const Duration(days: 7)));
  return GridPagerSlot(
    grid: WeekGrid(
      weekStart: previousWeekStart,
      timeLabels: const [],
      cells: const {},
    ),
    day: DateTime.sunday,
  );
}

GridPagerSlot? computeNextDaySlot(GridPagerSlot current) {
  final weekdays = presentWeekdays(current.grid);
  final day = current.day;
  if (day == null) {
    return null;
  }

  if (weekdays.isEmpty) {
    final nextWeekStart =
        weekStartFor(current.weekStart.add(const Duration(days: 7)));
    return GridPagerSlot(
      grid: WeekGrid(
        weekStart: nextWeekStart,
        timeLabels: const [],
        cells: const {},
      ),
      day: DateTime.monday,
    );
  }

  final index = weekdays.indexOf(day);
  if (index < 0) {
    return GridPagerSlot(grid: current.grid, day: weekdays.first);
  }
  if (index < weekdays.length - 1) {
    return GridPagerSlot(grid: current.grid, day: weekdays[index + 1]);
  }

  final nextWeekStart =
      weekStartFor(current.weekStart.add(const Duration(days: 7)));
  return GridPagerSlot(
    grid: WeekGrid(
      weekStart: nextWeekStart,
      timeLabels: const [],
      cells: const {},
    ),
    day: DateTime.monday,
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
}) {
  final weekdays = presentWeekdays(targetSlot.grid);
  if (weekdays.isEmpty) {
    return null;
  }
  return crossWeekDirection > 0 ? weekdays.first : weekdays.last;
}

bool slotsReferToSamePage(GridPagerSlot a, GridPagerSlot b, {required bool isCompact}) {
  if (weekStartFor(a.grid.weekStart) != weekStartFor(b.grid.weekStart)) {
    return false;
  }
  if (isCompact) {
    return a.day == b.day;
  }
  return true;
}
