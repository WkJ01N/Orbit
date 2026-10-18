import 'dart:typed_data';

/// Reads Unicode cmaps directly; names and filenames say nothing about coverage.
bool fontContainsChinese(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  const ranges = [
    (0x3400, 0x4dbf),
    (0x4e00, 0x9fff),
    (0xf900, 0xfaff),
    (0x20000, 0x323af),
  ];
  bool intersects(int start, int end) =>
      ranges.any((r) => start <= r.$2 && end >= r.$1);
  try {
    for (var table = 0; table < data.getUint16(4); table++) {
      final record = 12 + table * 16;
      if (data.getUint32(record) != 0x636d6170) continue;
      final base = data.getUint32(record + 8);
      final tableEnd = base + data.getUint32(record + 12);
      if (tableEnd > bytes.length || base + 4 > tableEnd) return false;
      final count = data.getUint16(base + 2);
      if (base + 4 + count * 8 > tableEnd) return false;
      for (var i = 0; i < count; i++) {
        final encoding = base + 4 + i * 8;
        final platform = data.getUint16(encoding),
            id = data.getUint16(encoding + 2);
        if (platform != 0 && !(platform == 3 && (id == 1 || id == 10))) {
          continue;
        }
        final at = base + data.getUint32(encoding + 4);
        if (at < base || at + 2 > tableEnd) continue;
        final format = data.getUint16(at);
        if ((format == 12 || format == 13) && at + 16 <= tableEnd) {
          final end = at + data.getUint32(at + 4);
          final groups = data.getUint32(at + 12);
          if (end > tableEnd || at + 16 + groups * 12 > end) continue;
          for (var g = 0; g < groups; g++) {
            final p = at + 16 + g * 12;
            final start = data.getUint32(p),
                stop = data.getUint32(p + 4),
                glyph = data.getUint32(p + 8);
            if (start > stop || !intersects(start, stop)) continue;
            for (final range in ranges) {
              final first = start > range.$1 ? start : range.$1;
              final last = stop < range.$2 ? stop : range.$2;
              if (first <= last &&
                  (glyph != 0 ||
                      format == 12 && (first > start || last > first))) {
                return true;
              }
            }
          }
        } else if (format == 4 && at + 16 <= tableEnd) {
          final end = at + data.getUint16(at + 2),
              segments = data.getUint16(at + 6) ~/ 2;
          if (segments == 0 || end > tableEnd || at + 16 + segments * 8 > end) {
            continue;
          }
          final starts = at + 16 + segments * 2,
              deltas = starts + segments * 2,
              offsets = deltas + segments * 2;
          for (var seg = 0; seg < segments; seg++) {
            final start = data.getUint16(starts + seg * 2),
                stop = data.getUint16(at + 14 + seg * 2);
            if (start > stop || !intersects(start, stop)) continue;
            final delta = data.getInt16(deltas + seg * 2),
                offset = data.getUint16(offsets + seg * 2);
            for (final range in ranges.take(3)) {
              final first = start > range.$1 ? start : range.$1,
                  last = stop < range.$2 ? stop : range.$2;
              for (var code = first; code <= last; code++) {
                if (offset == 0) {
                  if (((code + delta) & 0xffff) != 0) return true;
                } else {
                  final address =
                      offsets + seg * 2 + offset + (code - start) * 2;
                  if (address < at || address + 2 > end) break;
                  final glyph = data.getUint16(address);
                  if (glyph != 0 && ((glyph + delta) & 0xffff) != 0) {
                    return true;
                  }
                }
              }
            }
          }
        }
      }
    }
  } on RangeError {
    return false;
  }
  return false;
}
