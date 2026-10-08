import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class StrongSessionService {
  static const android = MethodChannel('com.must.orbit.orbit/reminders');
  static const windows = MethodChannel(
    'com.must.orbit.orbit/windows_reminders',
  );
  static MethodChannel get channel => Platform.isWindows ? windows : android;
  static Future<Map<String, dynamic>?> call(
    String action, [
    Map<String, dynamic>? args,
  ]) async {
    if (!Platform.isAndroid && !Platform.isWindows) return null;
    try {
      final raw = await channel.invokeMethod<String>(action, args);
      return raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on MissingPluginException {
      return null;
    }
  }

  static bool active(Map<String, dynamic>? state) =>
      state != null &&
      !['completed', 'unconfirmed', 'emergency'].contains(state['phase']) &&
      (state['expiresAt'] as num).toInt() >
          DateTime.now().millisecondsSinceEpoch;
}
