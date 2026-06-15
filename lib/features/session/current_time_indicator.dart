import 'package:flutter/material.dart';
import 'package:orbit/models/grid_models.dart';

/// Overlays a horizontal line at the current time position on the week grid.
///
/// The caller is responsible for providing an up-to-date [now] value (e.g.
/// from [currentTimeProvider]) — this widget contains no internal timer.
///
/// When [visibleWeekdays] is non-null, the line is only drawn when
/// [now.weekday] is in that set (typically the day column(s) on screen).
/// When [dayColumnIndex] and [dayColumnWidth] are set, the line spans only
/// that column instead of the full grid width.
class CurrentTimeIndicator extends StatelessWidget {
  const CurrentTimeIndicator({
    super.key,
    required this.grid,
    required this.isCurrentWeek,
    required this.rowHeight,
    required this.headerHeight,
    required this.timeColumnWidth,
    required this.now,
    required this.child,
    this.visibleWeekdays,
    this.dayColumnIndex,
    this.dayColumnWidth,
  });

  final WeekGrid grid;
  final bool isCurrentWeek;
  final double rowHeight;
  final double headerHeight;
  final double timeColumnWidth;
  final DateTime now;
  final Widget child;

  /// ISO weekday (1=Mon … 7=Sun) columns currently visible. When set, the line
  /// is hidden unless [now.weekday] is included.
  final List<int>? visibleWeekdays;

  /// Zero-based index of today's column among the visible day columns.
  final int? dayColumnIndex;

  /// Width of each day column; required when [dayColumnIndex] is set.
  final double? dayColumnWidth;

  @override
  Widget build(BuildContext context) {
    final top = currentTimeLineOffset(
      grid: grid,
      isCurrentWeek: isCurrentWeek,
      now: now,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      visibleWeekdays: visibleWeekdays,
    );
    if (top == null) {
      return child;
    }

    final lineColor = Theme.of(context).colorScheme.error;
    final columnIndex = dayColumnIndex;
    final columnWidth = dayColumnWidth;

    Widget line;
    if (columnIndex != null && columnWidth != null) {
      line = Positioned(
        left: timeColumnWidth + columnIndex * columnWidth,
        width: columnWidth,
        top: top,
        child: IgnorePointer(
          child: Container(height: 2, color: lineColor),
        ),
      );
    } else {
      line = Positioned(
        left: 0,
        right: 0,
        top: top,
        child: IgnorePointer(
          child: Row(
            children: [
              SizedBox(width: timeColumnWidth),
              Expanded(
                child: Container(height: 2, color: lineColor),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        line,
      ],
    );
  }
}

/// Computes the vertical offset (in pixels) for the current-time line, or null
/// when the line should be hidden.
///
/// The line is hidden when:
///  - the grid is not for the current week, or has no time slots;
///  - today is outside the displayed week;
///  - [now.weekday] is not in [visibleWeekdays] when that list is provided;
///  - the current time is before the first slot or at/after the latest class
///    end (i.e. outside the schedule's visible time range).
///
/// Rows are uniform height ([rowHeight]). Each row i spans
/// `[slot[i], slot[i+1])`, and the last row spans `[slot[last], lastSlotEnd)`,
/// where `lastSlotEnd` is the latest class end time-of-day in the grid.
double? currentTimeLineOffset({
  required WeekGrid grid,
  required bool isCurrentWeek,
  required DateTime now,
  required double rowHeight,
  required double headerHeight,
  List<int>? visibleWeekdays,
}) {
  if (!isCurrentWeek || grid.timeLabels.isEmpty) {
    return null;
  }

  final today = DateTime(now.year, now.month, now.day);
  final weekEnd = grid.weekStart.add(const Duration(days: 6));
  if (today.isBefore(grid.weekStart) || today.isAfter(weekEnd)) {
    return null;
  }

  if (visibleWeekdays != null &&
      visibleWeekdays.isNotEmpty &&
      !visibleWeekdays.contains(now.weekday)) {
    return null;
  }

  final slotMinutes = grid.timeLabels.map(_minutesFromLabel).toList();
  final nowMinutes = now.hour * 60 + now.minute;

  final lastSlotEnd = _lastSlotEndMinutes(grid, slotMinutes.last);
  if (nowMinutes < slotMinutes.first || nowMinutes >= lastSlotEnd) {
    return null;
  }

  for (var i = 0; i < slotMinutes.length; i++) {
    final start = slotMinutes[i];
    final end = i < slotMinutes.length - 1 ? slotMinutes[i + 1] : lastSlotEnd;
    if (nowMinutes >= start && nowMinutes < end) {
      final ratio = (nowMinutes - start) / (end - start);
      return headerHeight + i * rowHeight + ratio * rowHeight;
    }
  }

  return null;
}

int _lastSlotEndMinutes(WeekGrid grid, int lastSlotStart) {
  var maxEnd = lastSlotStart;
  for (final sessions in grid.cells.values) {
    for (final session in sessions) {
      final minutes = session.endAt.hour * 60 + session.endAt.minute;
      if (minutes > maxEnd) {
        maxEnd = minutes;
      }
    }
  }
  return maxEnd > lastSlotStart ? maxEnd : lastSlotStart + 60;
}

int _minutesFromLabel(String label) {
  final parts = label.split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}
