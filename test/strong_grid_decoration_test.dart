import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/grid/strong_grid_decoration.dart';
import 'package:orbit/models/schedule_layout.dart';

import 'archive_and_first_class_test.dart' show sampleClass;

void main() {
  const bounds = Rect.fromLTWH(54, 0, 346, 700);
  Set<int> visible(List<Rect> cards, Set<int> strong, {Rect area = bounds}) =>
      visibleStrongGridBells(cards: cards, strongIndices: strong, bounds: area);

  test('card geometry retains gaps, conflict lanes and one-pixel minimum', () {
    final event = ScheduleEventLayout(
      session: sampleClass('a', DateTime(2026, 8, 24, 9)),
      startMinute: 540,
      endMinute: 541,
      lane: 1,
      laneCount: 2,
    );
    expect(
      scheduleCardRect(
        event: event,
        dayIndex: 2,
        dayWidth: 100,
        startMinute: 480,
        pixelsPerMinute: .5,
        topInset: 24,
      ),
      const Rect.fromLTWH(306, 56, 46, 1),
    );
  });

  test('bell is centered, 14dp and separated from its own card by 2dp', () {
    const card = Rect.fromLTWH(60, 30, 40, 90);
    expect(strongGridBellRect(card), const Rect.fromLTWH(73, 14, 14, 14));
    expect(visible([card], {0}), {0});
  });

  test('back-to-back and overlapping courses hide only obstructed bells', () {
    const cards = [
      Rect.fromLTWH(60, 30, 40, 90),
      Rect.fromLTWH(60, 124, 40, 90),
      Rect.fromLTWH(110, 124, 40, 90),
    ];
    expect(visible(cards, {0, 1, 2}), {0, 2});
    expect(visible(cards, {1}), isEmpty); // Ordinary cards also obstruct.
  });

  test('removed exterior border no longer obstructs a neighboring bell', () {
    const cards = [
      Rect.fromLTWH(60, 100, 20, 100),
      Rect.fromLTWH(85, 112, 8, 50),
    ];
    expect(visible(cards, {1}), {1});
    expect(visible(cards, {0, 1}), {0, 1});
  });

  test('overlapping narrow-lane bells are all hidden independent of order', () {
    const cards = [Rect.fromLTWH(60, 50, 6, 60), Rect.fromLTWH(70, 50, 6, 60)];
    expect(visible(cards, {0, 1}), isEmpty);
    expect(visible(cards.reversed.toList(), {0, 1}), isEmpty);
  });

  test('canvas, time rail and scroll viewport edges hide complete bells', () {
    expect(visible([const Rect.fromLTWH(60, 15, 40, 50)], {0}), isEmpty);
    expect(visible([const Rect.fromLTWH(55, 30, 2, 50)], {0}), isEmpty);
    expect(visible([const Rect.fromLTWH(394, 30, 2, 50)], {0}), isEmpty);
    expect(
      visible(
        [const Rect.fromLTWH(60, 30, 40, 50)],
        {0},
        area: const Rect.fromLTWH(54, 15, 346, 700),
      ),
      isEmpty,
    );
    expect(
      visible(
        [const Rect.fromLTWH(60, 30, 40, 50)],
        {0},
        area: const Rect.fromLTWH(54, 0, 346, 27),
      ),
      isEmpty,
    );
    expect(
      visible(
        [const Rect.fromLTWH(60, 30, 40, 50)],
        {0},
        area: const Rect.fromLTWH(54, 14, 346, 14),
      ),
      {0},
    );
  });

  test(
    'highlight keeps hue and saturation and fills 25 percent of lightness gap',
    () {
      for (final color in [
        Colors.teal,
        Colors.blue,
        Colors.pink,
        Colors.black,
        Colors.white,
        const Color(0x80996633),
      ]) {
        final source = HSLColor.fromColor(color);
        final highlight = HSLColor.fromColor(strongGridHighlight(color));
        expect(
          highlight.lightness,
          closeTo(source.lightness + (1 - source.lightness) * .25, .003),
        );
        if (source.saturation > 0 && source.lightness < 1) {
          expect(highlight.hue, closeTo(source.hue, 1));
          expect(highlight.saturation, closeTo(source.saturation, .01));
        }
        expect(highlight.alpha, source.alpha);
      }
    },
  );
}
