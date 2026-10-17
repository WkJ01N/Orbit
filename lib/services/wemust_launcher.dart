import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum WemustLaunchResult {
  linkLaunched,
  appLaunched,
  notInstalled,
  failed,
  unsupported,
}

final wemustLauncherProvider = Provider<WemustLauncher>(
  (ref) => WemustLauncher(),
);

class WemustLauncher {
  static const channel = MethodChannel('com.must.orbit.orbit/wemust');
  bool get supported => Platform.isAndroid;
  Future<WemustLaunchResult> open({bool timetable = true}) async {
    if (!supported) return WemustLaunchResult.unsupported;
    try {
      final result = await channel.invokeMethod<String>('open', {
        'timetable': timetable,
      });
      return WemustLaunchResult.values.firstWhere(
        (value) => value.name == result,
        orElse: () => WemustLaunchResult.failed,
      );
    } on PlatformException {
      return WemustLaunchResult.failed;
    } on MissingPluginException {
      return WemustLaunchResult.unsupported;
    }
  }
}
