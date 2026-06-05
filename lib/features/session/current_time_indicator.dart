import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbit/models/grid_models.dart';

/// Overlays a red horizontal line indicating the current time on the week grid.
class CurrentTimeIndicator extends StatefulWidget {
  const CurrentTimeIndicator({
    super.key,
    required this.grid,
    required this.isCurrentWeek,
    required this.rowHeight,
    required this.headerHeight,
    required this.timeColumnWidth,
    required this.child,
  });

  final WeekGrid grid;
  final bool isCurrentWeek;
  final double rowHeight;
  final double headerHeight;
  final double timeColumnWidth;
  final Widget child;

  @override
  State<CurrentTimeIndicator> createState() => _CurrentTimeIndicatorState();
}

class _CurrentTimeIndicatorState extends State<CurrentTimeIndicator> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double? _lineTopOffset() {
    if (!widget.isCurrentWeek || widget.grid.timeLabels.isEmpty) {
      return null;
    }

    final today = DateTime(_now.year, _now.month, _now.day);
    final weekEnd = widget.grid.weekStart.add(const Duration(days: 6));
    if (today.isBefore(widget.grid.weekStart) || today.isAfter(weekEnd)) {
      return null;
    }

    final labels = widget.grid.timeLabels;
    final slotMinutes = labels.map(_minutesFromLabel).toList();
    final nowMinutes = _now.hour * 60 + _now.minute;

    if (nowMinutes < slotMinutes.first) {
      final ratio = nowMinutes / slotMinutes.first;
      return widget.headerHeight + ratio * widget.rowHeight * 0.5;
    }

    if (nowMinutes >= slotMinutes.last) {
      final lastIndex = labels.length - 1;
      return widget.headerHeight + lastIndex * widget.rowHeight + widget.rowHeight * 0.85;
    }

    for (var i = 0; i < slotMinutes.length - 1; i++) {
      final start = slotMinutes[i];
      final end = slotMinutes[i + 1];
      if (nowMinutes >= start && nowMinutes < end) {
        final ratio = (nowMinutes - start) / (end - start);
        return widget.headerHeight + i * widget.rowHeight + ratio * widget.rowHeight;
      }
    }

    return null;
  }

  int _minutesFromLabel(String label) {
    final parts = label.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  @override
  Widget build(BuildContext context) {
    final top = _lineTopOffset();
    if (top == null) {
      return widget.child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          top: top,
          child: IgnorePointer(
            child: Row(
              children: [
                SizedBox(width: widget.timeColumnWidth),
                Expanded(
                  child: Container(
                    height: 2,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
