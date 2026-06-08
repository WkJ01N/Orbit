import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/zh_variant.dart';

void main() {
  group('foldToSimplified', () {
    test('folds traditional course-related characters', () {
      expect(foldToSimplified('計算機'), '计算机');
      expect(foldToSimplified('電腦科學'), '电脑科学');
    });

    test('leaves simplified and latin text unchanged', () {
      expect(foldToSimplified('计算机'), '计算机');
      expect(foldToSimplified('CS101'), 'CS101');
    });

    test('matches across scripts when both sides are folded', () {
      const traditional = '計算機概論';
      const simplifiedQuery = '计算机';
      expect(
        foldToSimplified(traditional).contains(foldToSimplified(simplifiedQuery)),
        isTrue,
      );
    });
  });
}
