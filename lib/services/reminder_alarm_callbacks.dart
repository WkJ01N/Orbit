import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/timezone_utils.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/services/reminder_alarm_registry.dart';
import 'package:orbit/services/settings_service.dart';

const reminderAlarmChannelId = 'orbit_course_reminders';
const backgroundTestAlarmId = 999990;

/// Fires when an Android AlarmManager one-shot triggers in a background isolate.
@pragma('vm:entry-point')
Future<void> fireReminderAlarm(int alarmId) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await configureReminderTimezone();
    final spec = await ReminderAlarmRegistry.loadEntry(alarmId);
    if (spec == null) {
      debugPrint('No registry entry for alarm $alarmId');
      return;
    }
    await showReminderAlarmNotification(spec);
    await ReminderAlarmRegistry.removeByAlarmId(alarmId);
  } catch (error, stackTrace) {
    debugPrint('fireReminderAlarm failed for $alarmId: $error');
    debugPrint('$stackTrace');
  }
}

Future<void> showReminderAlarmNotification(ReminderAlarmSpec spec) async {
  final settingsService = SettingsService();
  final locale = await settingsService.loadLocale();
  final copy = NotificationCopy.fromL10n(lookupL10n(locale));

  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(
    const InitializationSettings(android: androidSettings),
  );

  final androidPlugin = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(
      reminderAlarmChannelId,
      copy.channelName,
      description: copy.channelDescription,
      importance: Importance.max,
    ),
  );

  final styleInformation = spec.bigText != null
      ? BigTextStyleInformation(spec.bigText!)
      : null;

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      reminderAlarmChannelId,
      copy.channelName,
      channelDescription: copy.channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      styleInformation: styleInformation,
    ),
  );

  await plugin.show(
    spec.notificationId,
    spec.title,
    spec.body,
    details,
    payload: spec.payload,
  );
}
