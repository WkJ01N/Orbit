import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/models/grid_density.dart';

void main() {
  group('weekStartFor', () {
    test('将一周内任意一天都对齐到所在周的周一零点', () {
      final expectedMonday = DateTime(2026, 6, 1);
      for (var day = 1; day <= 7; day++) {
        final date = DateTime(2026, 6, day, 15, 9);
        expect(weekStartFor(date), expectedMonday);
      }
    });

    test('周日起始时将周日作为一周第一天', () {
      // 2026-06-07 是周日
      expect(
        weekStartFor(DateTime(2026, 6, 7), startWeekday: DateTime.sunday),
        DateTime(2026, 6, 7),
      );
      // 2026-06-10 是周三，所在周从 6/7 开始
      expect(
        weekStartFor(DateTime(2026, 6, 10), startWeekday: DateTime.sunday),
        DateTime(2026, 6, 7),
      );
    });

    test('orderedWeekdays 从周日起排序', () {
      expect(
        orderedWeekdays(startWeekday: DateTime.sunday),
        [7, 1, 2, 3, 4, 5, 6],
      );
    });

    test('结果始终是零点（去除时分秒）', () {
      final result = weekStartFor(DateTime(2026, 6, 5, 23, 59, 59, 999));
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });

    test('翻页：以周一为基准加减 7 天后仍对齐到相邻周的周一', () {
      final base = weekStartFor(DateTime(2026, 6, 5));
      final next = weekStartFor(base.add(const Duration(days: 7)));
      final prev = weekStartFor(base.add(const Duration(days: -7)));
      expect(next, DateTime(2026, 6, 8));
      expect(prev, DateTime(2026, 5, 25));
      expect(next.weekday, DateTime.monday);
      expect(prev.weekday, DateTime.monday);
    });

    test('跨月/跨年回退仍正确对齐', () {
      expect(weekStartFor(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    });
  });

  group('GridDensityMetrics', () {
    test('standard 保持现有默认尺寸', () {
      final metrics = GridDensityMetrics.forDensity(GridDensity.standard);
      expect(metrics.rowHeight, 64);
      expect(metrics.timeColumnWidth, 52);
      expect(metrics.tableHeaderExtent, 52);
    });
  });
}
