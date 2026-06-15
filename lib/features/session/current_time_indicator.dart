import 'package:flutter/material.dart';
import 'package:orbit/models/grid_models.dart';

/// Overlays a horizontal line at the current time position on the week grid.
///
/// The caller is responsible for providing an up-to-date [now] value (e.g.
/// from [currentTimeProvider]) — this widget contains no internal timer.
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
  });

  final WeekGrid grid;
  final bool isCurrentWeek;
  final double rowHeight;
  final double headerHeight;
  final double timeColumnWidth;
  final DateTime now;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = currentTimeLineOffset(
      grid: grid,
      isCurrentWeek: isCurrentWeek,
      now: now,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
    );
    if (top == null) {
      return child;
    }

    final lineColor = Theme.of(context).colorScheme.error;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
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
        ),
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
}) {
  if (!isCurrentWeek || grid.timeLabels.isEmpty) {
    return null;
  }

  final today = DateTime(now.year, now.month, now.day);
  final weekEnd = grid.weekStart.add(const Duration(days: 6));
  if (today.isBefore(grid.weekStart) || today.isAfter(weekEnd)) {
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
