import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:orbit/models/schedule_layout.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/services/schedule_layout_engine.dart';

const strongGridBellSize = 14.0;
const strongGridBellGap = 2.0;
Rect scheduleCardRect({
  required ScheduleEventLayout event,
  required int dayIndex,
  required double dayWidth,
  required int startMinute,
  required double pixelsPerMinute,
  required double topInset,
}) {
  const gap = 2.0;
  final laneWidth = dayWidth / event.laneCount;
  return Rect.fromLTWH(
    kScheduleTimeRailWidth + dayIndex * dayWidth + event.lane * laneWidth + gap,
    topInset + (event.startMinute - startMinute) * pixelsPerMinute + gap,
    math.max(1, laneWidth - gap * 2),
    math.max(1, event.durationMinutes * pixelsPerMinute - gap * 2),
  );
}

Color strongGridHighlight(Color accent) {
  final hsl = HSLColor.fromColor(accent);
  return hsl.withLightness(hsl.lightness + (1 - hsl.lightness) * .25).toColor();
}

Rect strongGridBellRect(Rect card) => Rect.fromLTWH(
  card.center.dx - strongGridBellSize / 2,
  card.top - strongGridBellGap - strongGridBellSize,
  strongGridBellSize,
  strongGridBellSize,
);

/// Evaluate all candidates together, so overlapping bells are both hidden.
/// Bounds may be the current scroll viewport: never render a clipped half bell.
Set<int> visibleStrongGridBells({
  required List<Rect> cards,
  required Set<int> strongIndices,
  required Rect bounds,
}) {
  final bells = {
    for (final index in strongIndices) index: strongGridBellRect(cards[index]),
  };
  final visible = <int>{};
  for (final entry in bells.entries) {
    final bell = entry.value;
    if (bell.left < bounds.left ||
        bell.top < bounds.top ||
        bell.right > bounds.right ||
        bell.bottom > bounds.bottom) {
      continue;
    }
    var blocked = false;
    for (var other = 0; other < cards.length; other++) {
      if (other == entry.key) continue;
      final card = cards[other];
      if (bell.overlaps(card)) {
        blocked = true;
        break;
      }
    }
    if (!blocked &&
        !bells.entries.any(
          (other) => other.key != entry.key && bell.overlaps(other.value),
        )) {
      visible.add(entry.key);
    }
  }
  return visible;
}

LinearGradient strongGridBackground({
  required Color accent,
  required Color surface,
  required StrongCardGradient extent,
}) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color.alphaBlend(
      strongGridHighlight(accent).withValues(alpha: .25),
      surface,
    ),
    surface,
    surface,
  ],
  stops: [
    0,
    switch (extent) {
      StrongCardGradient.upperHalf => .5,
      StrongCardGradient.fullCard => 1.0,
      StrongCardGradient.topQuarter => .25,
    },
    1,
  ],
);
