import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';

void main() {
  group('weekStartFor', () {
    test('将一周内任意一天都对齐到所在周的周一零点', () {
      // 2026-06-01 是周一，2026-06-07 是周日
      final expectedMonday = DateTime(2026, 6, 1);
      for (var day = 1; day <= 7; day++) {
        final date = DateTime(2026, 6, day, 15, 9);
        expect(weekStartFor(date), expectedMonday);
      }
    });

    test('结果始终是零点（去除时分秒）', () {
      final result = weekStartFor(DateTime(2026, 6, 5, 23, 59, 59, 999));
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });

    test('翻页：以周一为基准加减 7 天后仍对齐到相邻周的周一', () {
      final base = weekStartFor(DateTime(2026, 6, 5)); // 周一 2026-06-01
      final next = weekStartFor(base.add(const Duration(days: 7)));
      final prev = weekStartFor(base.add(const Duration(days: -7)));
      expect(next, DateTime(2026, 6, 8));
      expect(prev, DateTime(2026, 5, 25));
      expect(next.weekday, DateTime.monday);
      expect(prev.weekday, DateTime.monday);
    });

    test('跨月/跨年回退仍正确对齐', () {
      // 2027-01-01 是周五，所在周周一应为 2026-12-28
      expect(weekStartFor(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    });
  });
}
