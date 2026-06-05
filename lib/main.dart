import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/services/android_reminder_guard.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/startup_service.dart';
import 'package:orbit/services/tray_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final startHidden = Platform.isWindows && isStartupLaunch(args);

  if (Platform.isWindows) {
    await initializeDesktopWindow(startHidden: startHidden);
  }

  if (Platform.isAndroid) {
    await AndroidReminderGuard.instance.initialize();
    await AndroidReminderGuard.instance.scheduleMaintenanceAlarm();
  }

  final database = await openAppDatabase();
  registerAppDatabase(database);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const OrbitApp(),
    ),
  );

  if (Platform.isWindows) {
    final startupService = StartupService(SettingsService());
    await startupService.syncWithPreference();
  }
}
