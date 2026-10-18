import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:orbit/models/course_quick_actions.dart';

class QuickActionEdgeSegment {
  const QuickActionEdgeSegment(this.side, this.start, this.end);
  final int side;
  final double start, end;
}

class QuickActionCell {
  const QuickActionCell({
    required this.action,
    required this.direction,
    required this.slot,
    required this.zone,
    required this.edges,
  });
  final SessionAction action;
  final int direction;
  final Rect slot;
  final List<Offset> zone;
  final List<QuickActionEdgeSegment> edges;
  bool contains(Offset point) {
    if (zone.isEmpty) return false;
    final path = Path()..addPolygon(zone, true);
    return path.contains(point);
  }
}

List<Offset> _clip(List<Offset> points, double a, double b, double c) {
  final result = <Offset>[];
  if (points.isEmpty) return result;
  for (var i = 0; i < points.length; i++) {
    final p = points[i], q = points[(i + 1) % points.length];
    final dp = a * p.dx + b * p.dy - c, dq = a * q.dx + b * q.dy - c;
    if (dp <= .001) result.add(p);
    if ((dp < 0) != (dq < 0)) result.add(p + (q - p) * (dp / (dp - dq)));
  }
  return result;
}

/// Geometry is shared by pointer selection, targets and the edge light painter.
class QuickActionLayout {
  QuickActionLayout._(
    this.viewport,
    this.source,
    this.card,
    this.cells,
    this.floating,
  );
  final Rect viewport, source, card;
  final List<QuickActionCell> cells;
  final bool floating;

  factory QuickActionLayout({
    required Rect viewport,
    required Rect source,
    required CourseQuickActionSettings settings,
  }) {
    final safe = viewport.deflate(8);
    var card = source.intersect(viewport);
    final floating = settings.edgeMode == QuickActionEdgeMode.floatInward;
    if (floating) {
      card = source;
      final reserveX = math.min(72.0, safe.width / 4);
      final reserveY = math.min(72.0, safe.height / 4);
      final width = math.min(
        card.width * 1.04,
        math.max(1.0, safe.width - reserveX * 2),
      );
      final height = math.min(
        card.height * 1.04,
        math.max(1.0, safe.height - reserveY * 2),
      );
      final center = Offset(
        card.center.dx.clamp(
          safe.left + reserveX + width / 2,
          safe.right - reserveX - width / 2,
        ),
        card.center.dy.clamp(
          safe.top + reserveY + height / 2,
          safe.bottom - reserveY - height / 2,
        ),
      );
      card = Rect.fromCenter(center: center, width: width, height: height);
    }
    final blocked = [
      card.top - safe.top < 58,
      safe.right - card.right < 68,
      safe.bottom - card.bottom < 58,
      card.left - safe.left < 68,
    ];
    // Extremely tall/narrow cards still need two useful sides.
    if (blocked[0] && blocked[2]) {
      blocked[card.center.dy < safe.center.dy ? 2 : 0] = false;
    }
    if (blocked[1] && blocked[3]) {
      blocked[card.center.dx < safe.center.dx ? 1 : 3] = false;
    }
    final sides = <int, List<int>>{};
    for (var direction = 0; direction < 4; direction++) {
      final physical = blocked[direction] ? (direction + 2) % 4 : direction;
      sides.putIfAbsent(physical, () => []).add(direction);
    }
    final corner = blocked.where((v) => v).length == 2;
    final bounds = [
      viewport.topLeft,
      viewport.topRight,
      viewport.bottomRight,
      viewport.bottomLeft,
    ];
    List<Offset> sector(int side) {
      var p = bounds.toList();
      final verticalEdge = !corner && (blocked[0] || blocked[2]);
      if (verticalEdge) {
        final boundary = blocked[2] ? card.top : card.bottom;
        if (side == (blocked[2] ? 0 : 2)) {
          return _clip(
            p,
            0,
            blocked[2] ? 1 : -1,
            blocked[2] ? boundary : -boundary,
          );
        }
        p = _clip(p, 0, blocked[2] ? -1 : 1, blocked[2] ? -boundary : boundary);
        return side == 3
            ? _clip(p, 1, 0, card.left)
            : _clip(p, -1, 0, -card.right);
      }
      switch (side) {
        case 0:
          p = _clip(p, 0, 1, card.top);
          p = _clip(p, -1, 1, card.top - card.left);
          return _clip(p, 1, 1, card.right + card.top);
        case 1:
          p = _clip(p, -1, 0, -card.right);
          p = _clip(p, -1, -1, -card.right - card.top);
          return _clip(p, -1, 1, card.bottom - card.right);
        case 2:
          p = _clip(p, 0, -1, -card.bottom);
          p = _clip(p, -1, -1, -card.left - card.bottom);
          return _clip(p, 1, -1, card.right - card.bottom);
        default:
          p = _clip(p, 1, 0, card.left);
          p = _clip(p, 1, -1, card.left - card.top);
          return _clip(p, 1, 1, card.left + card.bottom);
      }
    }

    final cells = <QuickActionCell>[];
    for (final entry in sides.entries) {
      final side = entry.key;
      final directions = entry.value
        ..sort(
          (a, b) => (a == side
              ? -1
              : b == side
              ? 1
              : a.compareTo(b)),
        );
      final polygon = sector(side);
      final split = side.isEven ? card.center.dx : card.center.dy;
      final pairedCorner = corner && directions.length == 2;
      // Include the maximum 1.06 highlight scale when reserving the gap.
      final separation = side.isEven ? 60.0 : 72.0;
      final centers = <Offset>[];
      for (var i = 0; i < directions.length; i++) {
        final distance = pairedCorner ? 36.0 + i * separation : 36.0;
        var center = switch (side) {
          0 => Offset(card.center.dx, card.top - distance),
          1 => Offset(card.right + distance, card.center.dy),
          2 => Offset(card.center.dx, card.bottom + distance),
          _ => Offset(card.left - distance, card.center.dy),
        };
        if (directions.length == 2 && !corner) {
          center = side.isEven
              ? Offset(split + (i == 0 ? -32 : 32), center.dy)
              : Offset(center.dx, split + (i == 0 ? -30 : 30));
        }
        centers.add(center);
      }
      final minX = centers.map((p) => p.dx).reduce(math.min) - 28 * 1.06;
      final maxX = centers.map((p) => p.dx).reduce(math.max) + 28 * 1.06;
      final minY = centers.map((p) => p.dy).reduce(math.min) - 22 * 1.06;
      final maxY = centers.map((p) => p.dy).reduce(math.max) + 22 * 1.06;
      final shiftX = minX < safe.left
          ? safe.left - minX
          : maxX > safe.right
          ? safe.right - maxX
          : 0.0;
      final shiftY = minY < safe.top
          ? safe.top - minY
          : maxY > safe.bottom
          ? safe.bottom - maxY
          : 0.0;
      for (var i = 0; i < centers.length; i++) {
        centers[i] += Offset(shiftX, shiftY);
      }
      for (var index = 0; index < directions.length; index++) {
        var zone = polygon;
        if (directions.length == 2) {
          if (corner) {
            final boundary = side.isEven
                ? (centers[0].dy + centers[1].dy) / 2
                : (centers[0].dx + centers[1].dx) / 2;
            final nearSign = side == 0 || side == 3 ? -1.0 : 1.0;
            final sign = index == 0 ? nearSign : -nearSign;
            zone = _clip(
              zone,
              side.isEven ? 0 : sign,
              side.isEven ? sign : 0,
              boundary * sign,
            );
          } else {
            final sign = index == 0 ? 1.0 : -1.0;
            zone = _clip(
              zone,
              side.isEven ? sign : 0,
              side.isEven ? 0 : sign,
              sign * split,
            );
          }
        }
        final center = centers[index];
        final horizontal = side.isEven;
        var start = horizontal ? viewport.left : viewport.top;
        var end = horizontal ? viewport.right : viewport.bottom;
        if (directions.length == 2) {
          final cut = corner ? (start + end) / 2 : split;
          // At corners the original item illuminates the portion near its card.
          final reverse =
              corner &&
              (horizontal
                  ? card.center.dx > viewport.center.dx
                  : card.center.dy > viewport.center.dy);
          if ((index == 0) != reverse) {
            end = cut;
          } else {
            start = cut;
          }
        }
        cells.add(
          QuickActionCell(
            action: settings.positions[directions[index]],
            direction: directions[index],
            slot: Rect.fromCenter(center: center, width: 56, height: 44),
            zone: List.unmodifiable(zone),
            edges: [QuickActionEdgeSegment(side, start, end)],
          ),
        );
      }
    }
    cells.sort((a, b) => a.direction.compareTo(b.direction));
    return QuickActionLayout._(
      viewport,
      source,
      card,
      List.unmodifiable(cells),
      floating,
    );
  }

  QuickActionCell? hitTest(Offset point, {SessionAction? previous}) {
    if (!viewport.contains(point) || card.contains(point)) {
      return null;
    }
    final old = cells.where((c) => c.action == previous).firstOrNull;
    if (old != null &&
        [
          point + const Offset(4, 0),
          point - const Offset(4, 0),
          point + const Offset(0, 4),
          point - const Offset(0, 4),
        ].any(old.contains)) {
      return old;
    }
    return cells.where((cell) => cell.contains(point)).firstOrNull;
  }
}
