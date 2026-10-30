import 'package:flutter/widgets.dart';

/// Memoises text heights for the schedule grid.
///
/// Measuring text is the grid's hottest layout path: every course chip asks for
/// the height of its name, time, room and teacher, and the grid rebuilds once a
/// minute for the "now" indicator. A measurement only depends on the string,
/// the style, the available width and the text scaler, so caching it turns
/// thousands of [TextPainter] layouts per minute into hash lookups.
class TextHeightCache {
  TextHeightCache({this.capacity = 512});

  /// Maximum number of measurements kept. When the cache is full it is dropped
  /// wholesale instead of tracking recency: entries are cheap to recompute and
  /// the grid only ever asks for a few dozen distinct measurements per frame.
  final int capacity;

  final Map<_TextHeightKey, double> _heights = {};

  /// Number of cached measurements.
  int get length => _heights.length;

  /// Number of real [TextPainter] layouts performed so far, i.e. cache misses.
  int get layoutCount => _layoutCount;
  int _layoutCount = 0;

  double measure(
    String value,
    TextStyle? style,
    double width,
    TextScaler scaler,
    TextDirection direction, {
    int? maxLines,
  }) {
    final key = _TextHeightKey(
      value,
      style,
      width,
      scaler,
      direction,
      maxLines,
    );
    final cached = _heights[key];
    if (cached != null) {
      return cached;
    }
    final painter = TextPainter(
      text: TextSpan(text: value.isEmpty ? ' ' : value, style: style),
      textScaler: scaler,
      textDirection: direction,
      maxLines: maxLines,
    )..layout(maxWidth: width);
    _layoutCount++;
    if (_heights.length >= capacity) {
      _heights.clear();
    }
    return _heights[key] = painter.height;
  }

  void clear() {
    _heights.clear();
    _layoutCount = 0;
  }
}

/// Height cache shared by every grid instance.
final scheduleTextHeightCache = TextHeightCache();

class _TextHeightKey {
  const _TextHeightKey(
    this.value,
    this.style,
    this.width,
    this.scaler,
    this.direction,
    this.maxLines,
  );

  final String value;
  final TextStyle? style;
  final double width;
  final TextScaler scaler;
  final TextDirection direction;
  final int? maxLines;

  @override
  bool operator ==(Object other) =>
      other is _TextHeightKey &&
      other.value == value &&
      other.style == style &&
      other.width == width &&
      other.scaler == scaler &&
      other.direction == direction &&
      other.maxLines == maxLines;

  @override
  int get hashCode =>
      Object.hash(value, style, width, scaler, direction, maxLines);
}
