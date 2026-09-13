import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/services/android_reminder_guard.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/startup_service.dart';
import 'package:orbit/services/tray_service.dart';
import 'package:orbit/services/windows_reminder_maintenance.dart';
import 'package:orbit/providers/notification_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final startHidden = Platform.isWindows && isStartupLaunch(args);
  final maintenance =
      Platform.isWindows && args.contains('--reminder-maintenance');
  final notificationAction =
      Platform.isWindows && args.contains('--notification-action');

  // Window setup and the database do not depend on each other.
  final databaseFuture = openAppDatabase();
  await Future.wait<void>([
    databaseFuture.then((_) {}),
    if (Platform.isWindows && !maintenance && !notificationAction)
      initializeDesktopWindow(startHidden: startHidden),
    if (Platform.isAndroid) _initializeAndroidGuard(),
  ]);
  final database = await databaseFuture;
  registerAppDatabase(database);
  String? launchPayload;
  if (Platform.isWindows) {
    WindowsReminderMaintenance.attach(database);
    if (maintenance || notificationAction) {
      try {
        if (maintenance) {
          await WindowsReminderMaintenance.run(database);
          launchPayload = await WindowsReminderMaintenance.pendingActivation(
            database,
          );
        } else {
          launchPayload = await WindowsReminderMaintenance.activation(database);
        }
      } catch (error) {
        debugPrint('Hidden reminder processing failed: $error');
      }
      if (launchPayload == null && !WindowsReminderMaintenance.showRequested) {
        await database.close();
        exit(0);
      }
      await initializeDesktopWindow(startHidden: false);
      await WindowsReminderMaintenance.channel.invokeMethod<void>(
        'finishHeadless',
      );
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        if (launchPayload != null)
          pendingNotificationPayloadProvider.overrideWith(
            (ref) => launchPayload,
          ),
      ],
      child: const OrbitApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runStartupMaintenance(database));
  });
}

Future<void> _initializeAndroidGuard() async {
  await AndroidReminderGuard.instance.initialize();
  await AndroidReminderGuard.instance.scheduleMaintenanceAlarm();
}

Future<void> _runStartupMaintenance(AppDatabase database) async {
  // Yield beyond the first frame; deleted rows are already excluded by queries.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  try {
    await database.purgeDeletedBefore(
      DateTime.now().subtract(const Duration(days: 7)),
    );
  } catch (error) {
    debugPrint('Startup database cleanup failed: $error');
  }
  if (Platform.isWindows) {
    try {
      await WindowsReminderMaintenance.register();
    } catch (error) {
      debugPrint('Reminder maintenance registration failed: $error');
    }
    try {
      await StartupService(SettingsService()).syncWithPreference();
    } catch (error) {
      debugPrint('Startup preference sync failed: $error');
    }
  }
}
