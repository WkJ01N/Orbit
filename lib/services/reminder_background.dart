import 'package:flutter/widgets.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/reminder_scheduler.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/xlsx_parser.dart';

@pragma('vm:entry-point')
Future<void> reminderMaintenanceCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  try {
    database = await openAppDatabase();
    final settingsService = SettingsService();
    final settings = await settingsService.load();
    final locale = await settingsService.loadLocale();
    final copy = notificationCopyFor(locale);
    final repository = ScheduleRepository(database, XlsxParser());
    final upcoming = await repository.getUpcomingSessions();
    final all = await repository.getAllSessions();
    await ReminderScheduler.shared.rescheduleAll(
      upcomingSessions: upcoming,
      allSessions: all,
      settings: settings,
      copy: copy,
    );
  } finally {
    await database?.close();
  }
}
