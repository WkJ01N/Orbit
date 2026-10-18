import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/app_info.dart';
import 'package:orbit/features/settings/update_page.dart';
import 'package:orbit/features/settings/wemust_debug_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/app_update.dart';
import 'package:orbit/services/app_update_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/wemust_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Update extends AppUpdateService {
  _Update() : super(SettingsService());
  int checks = 0;
  AppRelease get current => AppRelease(
    version: kAppVersion,
    buildNumber: kAppBuildNumber,
    notes: 'Current release notes',
    releaseUrl: '',
    assets: [
      UpdateAsset(
        // The picker filters by host platform, including on Linux CI.
        platform: Platform.operatingSystem,
        name: 'orbit-current-windows-x64.zip',
        url:
            'https://github.com/WkJ01N/Orbit/releases/download/v1.6.1/orbit-current-windows-x64.zip',
        size: 100,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    ],
  );
  @override
  Future<AppRelease> check({bool automatic = false}) async {
    checks++;
    return current;
  }

  @override
  Future<AppRelease> release(String version) async => current;
  @override
  Future<List<String>> supportedAbis() async => [];
  @override
  Future<Map<String, dynamic>> preferences() async => {};
  @override
  Future<List<DownloadSource>> sources() async => DownloadSource.builtIn;
}

class _Wemust extends WemustLauncher {
  final Completer<WemustLaunchResult> completer = Completer();
  int calls = 0;
  @override
  bool get supported => true;
  @override
  Future<String?> installedVersion() async => '1.13.1';
  @override
  Future<WemustLaunchResult> open({bool timetable = true}) {
    calls++;
    return completer.future;
  }
}

Widget page(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  ),
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'current version still offers reinstall and a verified package download',
    (tester) async {
      final service = _Update();
      await tester.pumpWidget(
        page(const UpdatePage(), [
          appUpdateServiceProvider.overrideWithValue(service),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reinstall this version'));
      await tester.pumpAndSettle();
      expect(find.text('Current release notes'), findsOneWidget);
      expect(find.text('Package type'), findsOneWidget);
      expect(find.text('Version history'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'WeMust diagnostics retain inferred URI and do not equate a launch with arrival',
    (tester) async {
      final service = _Wemust();
      await tester.pumpWidget(
        page(const WemustDebugPage(), [
          wemustLauncherProvider.overrideWithValue(service),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open WeMust timetable'));
      await tester.pump();
      await tester.tap(find.text('Open WeMust timetable'));
      expect(service.calls, 1);
      service.completer.complete(WemustLaunchResult.linkLaunched);
      await tester.pumpAndSettle();
      expect(find.textContaining('page arrival is unverified'), findsOneWidget);
      expect(find.textContaining(WemustLauncher.timetableUri), findsOneWidget);
      expect(find.text('Copy diagnostics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
