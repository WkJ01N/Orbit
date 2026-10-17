import 'package:orbit/services/launch_icon_service.dart';
import 'package:orbit/providers/typography_providers.dart';
import 'package:orbit/services/font_service.dart';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:orbit/providers/reminder_providers.dart'
    show settingsServiceProvider;
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
  LicenseRegistry.addLicense(() async* {
    for (final entry in {
      'Resource Han Rounded': 'ResourceHanRounded-OFL.txt',
      'jf open huninn': 'Huninn-OFL.txt',
      'Kingnam Maiyuan': 'Maiyuan-OFL.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString('assets/fonts/${entry.value}'));
    }
    yield LicenseEntryWithLineBreaks([
      'Nunito',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    for (final name in [
      'ANGLE.txt',
      'GPL-2.0.txt',
      'GPL-3.0.txt',
      'LGPL-2.1.txt',
      'LGPL-3.0.txt',
      'media-kit.txt',
      'zlib.txt',
    ]) {
      yield LicenseEntryWithLineBreaks([
        'Orbit optional video runtime',
      ], await rootBundle.loadString('resources/video/licenses/$name'));
    }
    yield LicenseEntryWithLineBreaks([
      'Orbit optional video runtime sources',
    ], await rootBundle.loadString('resources/video/NOTICE.txt'));
  });

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
  final typographyFuture = FontService.shared.initialize();
  final databaseFuture = openAppDatabase();
  final settingsService = SettingsService();
  final presentationFuture = LaunchSnapshot.load(settingsService)
      .then<LaunchSnapshot?>(
        (value) => value,
        onError: (Object error) {
          debugPrint('Startup presentation preferences unavailable: $error');
          return null;
        },
      );
  await Future.wait<void>([
    databaseFuture.then((_) {}),
    typographyFuture.then((_) {}),
    presentationFuture.then(
      (value) => primeLaunchImages(value?.settings.iconPath),
    ),
    if (Platform.isWindows && !maintenance && !notificationAction)
      initializeDesktopWindow(startHidden: startHidden),
    if (Platform.isAndroid) _initializeAndroidGuard(),
  ]);
  final database = await databaseFuture;
  final presentation = await presentationFuture;
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
        settingsServiceProvider.overrideWithValue(settingsService),
        launchSnapshotProvider.overrideWithValue(presentation),
        typographySnapshotProvider.overrideWithValue(await typographyFuture),
        launchAnimationsEnabledProvider.overrideWithValue(
          !startHidden &&
              !maintenance &&
              !notificationAction &&
              launchPayload == null,
        ),
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
