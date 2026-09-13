import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WindowsReminderMaintenance {
  static const channel = MethodChannel(
    'com.must.orbit.orbit/windows_reminders',
  );
  static Future<void>? _running;
  static bool _rerunRequested = false;
  static bool showRequested = false;
  static void Function(String?)? onStatus;
  static void attach(AppDatabase database) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'maintenance') await run(database);
      if (call.method == 'showAfterMaintenance') showRequested = true;
    });
  }

  static Future<void> register() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await channel
          .invokeMethod<void>('registerMaintenance')
          .timeout(const Duration(seconds: 10));
      if (prefs.getString('windows_reminder_failure') == 'maintenance') {
        await prefs.remove('windows_reminder_failure');
        onStatus?.call(null);
      }
    } catch (error) {
      await prefs.setString('windows_reminder_failure', 'maintenance');
      onStatus?.call('maintenance');
      rethrow;
    }
  }

  static Future<void> run(AppDatabase database) {
    _rerunRequested = true;
    return _running ??= _drain(database);
  }

  static Future<void> _drain(AppDatabase database) async {
    try {
      do {
        _rerunRequested = false;
        await _run(database);
      } while (_rerunRequested);
    } catch (error) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('windows_reminder_failure', 'schedule');
      onStatus?.call('schedule');
      rethrow;
    } finally {
      _running = null;
    }
  }

  static Future<void> _run(AppDatabase database) async {
    final service = SettingsService();
    final settings = await service.load();
    final copy = notificationCopyFor(await service.loadLocale());
    final all = await database.getAllSessions();
    final now = DateTime.now();
    ReminderScheduler.shared.database = database;
    await ReminderScheduler.shared.rescheduleAll(
      upcomingSessions: all.where((s) => s.endAt.isAfter(now)).toList(),
      allSessions: all,
      settings: settings,
      copy: copy,
      requestPermissions: false,
    );
    final prefs = await SharedPreferences.getInstance();
    if (ReminderScheduler.shared.lastScheduleFailureCount > 0) {
      await prefs.setString('windows_reminder_failure', 'schedule');
      onStatus?.call('schedule');
    } else if (prefs.getString('windows_reminder_failure') == 'schedule') {
      await prefs.remove('windows_reminder_failure');
      onStatus?.call(null);
    }
  }

  static Future<String?> activation(AppDatabase database) async {
    final activation = Completer<String?>();
    ReminderScheduler.shared.registerNotificationTapHandler((payload) {
      if (!activation.isCompleted) activation.complete(payload);
    });
    final initial = await ReminderScheduler.shared
        .getLaunchNotificationPayload();
    if (initial != null && !activation.isCompleted) {
      activation.complete(initial);
    }
    final payload = await activation.future.timeout(
      const Duration(seconds: 25),
      onTimeout: () => null,
    );
    ReminderScheduler.shared.registerNotificationTapHandler(null);
    return handleActivationPayload(database, payload);
  }

  static Future<String?> pendingActivation(AppDatabase database) async =>
      handleActivationPayload(
        database,
        await ReminderScheduler.shared.getLaunchNotificationPayload(),
      );

  static Future<String?> handleActivationPayload(
    AppDatabase database,
    String? payload,
  ) async {
    if (payload == null) return null;
    if (payload.startsWith('{')) {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['action'] == 'ack') {
        await ReminderScheduler.shared.acknowledgeOccurrence(
          database,
          data['rule'] as String,
          data['session'] as String,
        );
        await run(database);
        return null;
      }
      if (data['identity'] is String && data['index'] is int) {
        await database.markReminderProcessed(
          data['rule'] as String,
          data['identity'] as String,
          data['index'] as int,
        );
      }
    }
    return payload;
  }
}
