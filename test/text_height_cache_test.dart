import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/grid/text_height_cache.dart';

void main() {
  const style = TextStyle(fontSize: 12);

  test('repeated measurements reuse the first layout', () {
    final cache = TextHeightCache();
    final first = cache.measure(
      'Higher Mathematics',
      style,
      120,
      TextScaler.noScaling,
      TextDirection.ltr,
      maxLines: 2,
    );
    final second = cache.measure(
      'Higher Mathematics',
      style,
      120,
      TextScaler.noScaling,
      TextDirection.ltr,
      maxLines: 2,
    );

    expect(second, first);
    expect(cache.layoutCount, 1);
    expect(cache.length, 1);
  });

  test('any layout input change is a cache miss', () {
    final cache = TextHeightCache();
    double measure({
      String text = 'Higher Mathematics',
      double width = 120,
      TextScaler scaler = TextScaler.noScaling,
      int? maxLines = 2,
    }) => cache.measure(
      text,
      style,
      width,
      scaler,
      TextDirection.ltr,
      maxLines: maxLines,
    );

    measure();
    measure(text: 'Linear Algebra');
    measure(width: 90);
    measure(scaler: const TextScaler.linear(1.3));
    measure(maxLines: 1);

    expect(cache.layoutCount, 5);
    expect(cache.length, 5);
  });

  test('the cache drops everything once it reaches its capacity', () {
    final cache = TextHeightCache(capacity: 4);
    for (var i = 0; i < 4; i++) {
      cache.measure(
        'Course $i',
        style,
        100,
        TextScaler.noScaling,
        TextDirection.ltr,
      );
    }

    expect(cache.length, 4);

    cache.measure(
      'Course 4',
      style,
      100,
      TextScaler.noScaling,
      TextDirection.ltr,
    );

    expect(cache.length, 1);
    expect(cache.layoutCount, 5);
  });

  test('an empty label measures like a single space', () {
    final cache = TextHeightCache();

    final empty = cache.measure(
      '',
      style,
      100,
      TextScaler.noScaling,
      TextDirection.ltr,
    );
    final space = cache.measure(
      ' ',
      style,
      100,
      TextScaler.noScaling,
      TextDirection.ltr,
    );

    expect(empty, space);
  });

  test('clear forgets heights and the layout count', () {
    final cache = TextHeightCache();
    cache.measure('A', style, 50, TextScaler.noScaling, TextDirection.ltr);
    cache.clear();

    expect(cache.length, 0);
    expect(cache.layoutCount, 0);
  });
}
