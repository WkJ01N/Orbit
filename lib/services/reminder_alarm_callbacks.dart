import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/reminder_alarm_registry.dart';
import 'package:orbit/services/settings_service.dart';

const reminderAlarmChannelId = 'orbit_course_reminders';

@pragma('vm:entry-point')
Future<void> fireReminderAlarm(int alarmId) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    final spec = await ReminderAlarmRegistry.loadEntry(alarmId);
    if (spec == null) {
      debugPrint('No persisted reminder for alarm $alarmId');
      return;
    }
    await showReminderAlarmNotification(spec);
    await ReminderAlarmRegistry.removeByAlarmId(alarmId);
  } catch (error, stackTrace) {
    debugPrint('Background reminder $alarmId failed: $error');
    debugPrint('$stackTrace');
  }
}

Future<void> showReminderAlarmNotification(ReminderAlarmSpec spec) async {
  final settingsService = SettingsService();
  final locale = await settingsService.loadLocale();
  final copy = NotificationCopy.fromL10n(lookupL10n(locale));
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  try {
    final active = await plugin.getActiveNotifications();
    if (active.any((notification) => notification.id == spec.notificationId)) {
      return;
    }
  } catch (error) {
    debugPrint('Could not inspect active notifications: $error');
  }

  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(
    AndroidNotificationChannel(
      reminderAlarmChannelId,
      copy.channelName,
      description: copy.channelDescription,
      importance: Importance.max,
    ),
  );

  await plugin.show(
    spec.notificationId,
    spec.title,
    spec.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        reminderAlarmChannelId,
        copy.channelName,
        channelDescription: copy.channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        styleInformation: spec.bigText == null
            ? null
            : BigTextStyleInformation(spec.bigText!),
      ),
    ),
    payload: spec.payload,
  );
}
