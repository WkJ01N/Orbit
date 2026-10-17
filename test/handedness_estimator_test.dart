import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/handedness_estimator.dart';

void main() {
  final epoch = DateTime(2026, 10, 17);
  HandGesture gesture(
    int millis,
    double x, {
    bool both = false,
    double? speed,
    double? z,
  }) => HandGesture(
    at: epoch.add(Duration(milliseconds: millis)),
    startX: x,
    endX: x + .02,
    meanX: x + .01,
    oppositeTouches: both,
    gravityZ: z,
    angularSpeed: speed,
  );

  for (final x in [.2, .8]) {
    test('two consistent swipes detect side $x without sensors', () {
      final estimator = HandednessEstimator();
      expect(estimator.add(gesture(0, x)).hand, OperatingHand.unknown);
      final result = estimator.add(gesture(400, x));
      expect(result.hand, x < .5 ? OperatingHand.left : OperatingHand.right);
      expect(result.confidence, greaterThanOrEqualTo(.7));
    });
  }
  test('rapid ambiguous gestures retain side; expiry returns unknown', () {
    final estimator = HandednessEstimator();
    estimator.add(gesture(0, .2));
    estimator.add(gesture(400, .2));
    estimator.add(gesture(600, .8));
    expect(estimator.estimate.hand, OperatingHand.left);
    estimator.add(gesture(1000, .5));
    expect(estimator.estimate.hand, OperatingHand.left);
    for (var t = 2000; t <= 7000; t += 1000) {
      estimator.add(gesture(t, .5));
    }
    expect(estimator.estimate.hand, OperatingHand.unknown);
  });
  test(
    'repeated opposite touches and alternating sides estimate both hands',
    () {
      final estimator = HandednessEstimator();
      for (var i = 0; i < 3; i++) {
        estimator.add(gesture(i * 500, .3, both: true));
      }
      expect(estimator.estimate.hand, OperatingHand.both);
      estimator.reset();
      for (var i = 0; i < 5; i++) {
        estimator.add(gesture(i * 500, i.isEven ? .2 : .8));
      }
      expect(estimator.estimate.hand, OperatingHand.both);
    },
  );
  test(
    'strong shaking cannot provide a hand vote; tilt alone cannot select a side',
    () {
      final estimator = HandednessEstimator();
      for (var i = 0; i < 8; i++) {
        estimator.add(gesture(i * 300, .2, speed: 3, z: 2));
      }
      expect(estimator.estimate.hand, OperatingHand.unknown);
      estimator.reset();
      for (var i = 0; i < 8; i++) {
        estimator.add(gesture(i * 300, .5, speed: .1, z: 2));
      }
      expect(estimator.estimate.hand, OperatingHand.unknown);
    },
  );
  test(
    'switch cooldown prevents rapid side changes; recent intent wins eventually',
    () {
      final estimator = HandednessEstimator();
      estimator.add(gesture(0, .2));
      estimator.add(gesture(100, .2));
      for (var i = 1; i <= 6; i++) {
        estimator.add(gesture(100 + i * 100, .8));
      }
      expect(estimator.estimate.hand, OperatingHand.left);
      estimator.add(gesture(1800, .8));
      expect(estimator.estimate.hand, OperatingHand.right);
      expect(
        estimator.expire(epoch.add(const Duration(seconds: 9))).hand,
        OperatingHand.unknown,
      );
    },
  );
}
