import 'dart:io';
import 'package:flutter/services.dart';

class HandMotionSample {
  const HandMotionSample({this.gravityZ, this.angularSpeed});
  final double? gravityZ, angularSpeed;
  factory HandMotionSample.fromMap(Map<Object?, Object?> value) =>
      HandMotionSample(
        gravityZ: (value['gravityZ'] as num?)?.toDouble(),
        angularSpeed: (value['angularSpeed'] as num?)?.toDouble(),
      );
}

class HandMotionService {
  const HandMotionService();
  static const channel = EventChannel('com.must.orbit.orbit/hand_motion');
  Stream<HandMotionSample> samples() {
    if (!Platform.isAndroid) return const Stream.empty();
    return channel.receiveBroadcastStream().map(
      (event) =>
          HandMotionSample.fromMap(Map<Object?, Object?>.from(event as Map)),
    );
  }
}
