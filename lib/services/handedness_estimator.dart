import 'dart:math' as math;

enum OperatingHand { unknown, left, right, both }

class HandEstimate {
  const HandEstimate(this.hand, this.confidence);
  final OperatingHand hand;
  final double confidence;
}

/// Normalized coordinates in the current visible viewport. No raw trace is kept.
class HandGesture {
  const HandGesture({
    required this.at,
    required this.startX,
    required this.endX,
    required this.meanX,
    this.curvature = 0,
    this.oppositeTouches = false,
    this.gravityZ,
    this.angularSpeed,
  });
  final DateTime at;
  final double startX, endX, meanX, curvature;
  final bool oppositeTouches;
  final double? gravityZ, angularSpeed;

  OperatingHand get side {
    if (oppositeTouches) return OperatingHand.both;
    if (meanX < .43 && startX < .5 && endX < .55) {
      return OperatingHand.left;
    }
    if (meanX > .57 && startX > .5 && endX > .45) {
      return OperatingHand.right;
    }
    return OperatingHand.unknown;
  }
}

/// A conservative, bounded heuristic, not a biometric hand detector. Sensor
/// context adjusts confidence only: a tilt on its own never votes for a hand.
class HandednessEstimator {
  final _gestures = <HandGesture>[];
  HandEstimate _stable = const HandEstimate(OperatingHand.unknown, 0);
  OperatingHand _candidate = OperatingHand.unknown;
  int _consecutive = 0;
  DateTime? _lastSwitch;
  DateTime? _lastEvidence;

  HandEstimate get estimate => _stable;

  void reset() {
    _gestures.clear();
    _stable = const HandEstimate(OperatingHand.unknown, 0);
    _candidate = OperatingHand.unknown;
    _consecutive = 0;
    _lastSwitch = null;
    _lastEvidence = null;
  }

  HandEstimate expire(DateTime now) {
    _gestures.removeWhere(
      (g) => now.difference(g.at) > const Duration(seconds: 6),
    );
    if (_gestures.isEmpty ||
        (_lastEvidence != null &&
            now.difference(_lastEvidence!) >= const Duration(seconds: 6))) {
      reset();
    }
    return _stable;
  }

  HandEstimate add(HandGesture gesture) {
    expire(gesture.at);
    _gestures.add(gesture);
    if (_gestures.length > 8) _gestures.removeAt(0);
    final recent = _gestures.reversed.take(4).toList().reversed.toList();
    final sides = recent.map((g) => g.side).toList();
    final alternating =
        sides.length == 4 &&
        sides.every(
          (h) => h == OperatingHand.left || h == OperatingHand.right,
        ) &&
        List.generate(3, (i) => sides[i] != sides[i + 1]).every((v) => v);
    final bilateral = _gestures.where((g) => g.oppositeTouches).length >= 2;
    OperatingHand vote;
    double confidence;
    if (alternating || bilateral) {
      vote = OperatingHand.both;
      confidence = .85;
    } else {
      final left = recent.where((g) => g.side == OperatingHand.left).length;
      final right = recent.where((g) => g.side == OperatingHand.right).length;
      final dominance = math.max(left, right) / recent.length;
      vote = dominance >= .7
          ? (left > right ? OperatingHand.left : OperatingHand.right)
          : OperatingHand.unknown;
      // Curved thumb-like swipes add small support, never determine the side.
      confidence =
          .6 + .25 * dominance + (gesture.curvature.abs() >= .015 ? .03 : 0);
    }
    final speed = gesture.angularSpeed;
    if (speed != null && speed > 2) {
      // Shaking or repositioning the device is weak evidence for any hand.
      vote = OperatingHand.unknown;
      confidence = .2;
    } else if (gesture.gravityZ != null) {
      // A nearly flat device offers little evidence of one-handed holding.
      confidence += gesture.gravityZ!.abs() < 8.5 ? .03 : -.08;
    }
    confidence = confidence.clamp(0, 1);
    if (vote == OperatingHand.unknown || confidence < .7) {
      _candidate = OperatingHand.unknown;
      _consecutive = 0;
      return _stable;
    }
    _consecutive = vote == _candidate ? _consecutive + 1 : 1;
    _candidate = vote;
    if (_consecutive >= 2 &&
        (_lastSwitch == null ||
            gesture.at.difference(_lastSwitch!) >=
                const Duration(milliseconds: 1500))) {
      if (vote != _stable.hand) _lastSwitch = gesture.at;
      _stable = HandEstimate(vote, confidence);
      _lastEvidence = gesture.at;
    }
    return _stable;
  }
}
