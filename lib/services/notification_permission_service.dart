import 'dart:io';
import 'package:flutter/services.dart';
import 'package:orbit/services/android_reminder_guard.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:url_launcher/url_launcher.dart';

enum NotificationPermissionState { allowed, denied, failed }

class NotificationPermissionService {
  static const _windows = MethodChannel(
    'com.must.orbit.orbit/windows_reminders',
  );
  Future<NotificationPermissionState> query() async {
    try {
      if (Platform.isAndroid) {
        final enabled = await ReminderScheduler.shared
            .queryNotificationAuthorization();
        return enabled == null
            ? NotificationPermissionState.failed
            : enabled
            ? NotificationPermissionState.allowed
            : NotificationPermissionState.denied;
      }
      if (Platform.isWindows) {
        await ReminderScheduler.shared.ensurePluginInitialized();
        final enabled = await _windows
            .invokeMethod<bool>('notificationsEnabled')
            .timeout(const Duration(seconds: 5));
        if (enabled == null) return NotificationPermissionState.failed;
        return enabled
            ? NotificationPermissionState.allowed
            : NotificationPermissionState.denied;
      }
      return NotificationPermissionState.allowed;
    } catch (_) {
      return NotificationPermissionState.failed;
    }
  }

  Future<void> openSettings() async {
    if (Platform.isAndroid) {
      await AndroidReminderGuard.instance.openAppNotificationSettings();
    } else if (Platform.isWindows) {
      if (!await launchUrl(Uri.parse('ms-settings:notifications'))) {
        throw StateError('Notification settings could not be opened');
      }
    }
  }
}
