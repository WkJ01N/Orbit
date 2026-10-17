import 'package:orbit/services/component_service.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:orbit/core/background/background_host.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/search/session_search_page.dart';
import 'package:orbit/features/settings/account_sync_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/account_sync_providers.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/background_providers.dart';
import 'package:orbit/services/background_asset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backgrounds extends BackgroundSettingsNotifier {
  _Backgrounds(this.settings);
  final BackgroundSettings settings;
  @override
  Future<BackgroundSettings> build() async => settings;
}

class _Reminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async =>
      const ReminderSettings(enabled: false);
}

class _Account extends AccountSyncNotifier {
  @override
  Future<SyncStatus> build() async => const SyncStatus(
    phase: SyncPhase.idle,
    account: SyncAccount(uid: 'benchmark', email: 'benchmark@example.com'),
  );
  @override
  Future<void> refreshProfile() async {}
}

double _paintedOpacity(Element element) {
  var opacity = 1.0;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    if (widget is Opacity) opacity *= widget.opacity;
    if (widget is Offstage && widget.offstage) opacity = 0;
    return true;
  });
  return opacity;
}

/// Uses in-memory preferences and a temporary media directory, without opening
/// the user's database or signing into an account. See docs/page-backgrounds.md.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('background transitions with native image GIF and video media', (
    tester,
  ) async {
    const fixtures = String.fromEnvironment('ORBIT_BACKGROUND_FIXTURES');
    expect(
      fixtures,
      isNotEmpty,
      reason: 'Provide a device-readable fixture directory',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Orbit background transition performance test'),
          ),
        ),
      ),
    );
    await tester.pump();
    debugPrint('ORBIT_BACKGROUND_PROFILE preparing fixtures');
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp(
      'orbit-background-profile-',
    );
    final components = ComponentService(
      directory: Directory('${directory.path}/components'),
    );
    await components.initialize();
    final service = BackgroundAssetService(
      directory: directory,
      components: components,
    );
    final assets = <BackgroundAsset>[
      for (final name in ['still.png', 'animated.gif'])
        await service.importFile(File('$fixtures/$name')),
    ];
    // The known 1280x720 fixture is installed directly: this test measures page
    // playback/transitions, without running the unrelated video import dialog.
    final video = BackgroundAsset(
      id: 'c' * 64,
      name: 'video.mp4',
      extension: 'mp4',
      kind: BackgroundMediaKind.video,
      width: 1280,
      height: 720,
    );
    await File('$fixtures/video.mp4').copy((await service.file(video)).path);
    await File('$fixtures/still.png').copy((await service.poster(video)).path);
    assets.add(video);

    for (final asset in assets) {
      if (asset.kind == BackgroundMediaKind.video) {
        const runtime = String.fromEnvironment('ORBIT_VIDEO_COMPONENT');
        expect(
          runtime,
          isNotEmpty,
          reason: 'Provide the verified component pack',
        );
        final descriptor = await components.descriptor(
          await components.videoId(),
        );
        await components.installArchive(descriptor, File(runtime));
      }
      debugPrint('ORBIT_BACKGROUND_PROFILE ${asset.kind.name} warmup');
      final settings = BackgroundSettings(
        enabled: true,
        assets: {asset.id: asset},
        pages: {
          BackgroundPage.grid: PageBackgroundSettings(assetId: asset.id),
          BackgroundPage.import: PageBackgroundSettings(assetId: asset.id),
          BackgroundPage.settings: const PageBackgroundSettings(
            followGrid: true,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          backgroundSettingsProvider.overrideWith(() => _Backgrounds(settings)),
          backgroundAssetServiceProvider.overrideWithValue(service),
          reminderSettingsProvider.overrideWith(_Reminders.new),
          accountSyncProvider.overrideWith(_Account.new),
          sessionsProvider.overrideWith((ref) async => []),
          upcomingSessionsProvider.overrideWith((ref) async => []),
          deadlinesProvider.overrideWith((ref) async => []),
          weekGridProvider.overrideWith((ref) => null),
        ],
      );
      final routes = BackgroundRouteObserver();
      routes.mainPage = () =>
          BackgroundPage.values[container.read(appNavIndexProvider)];
      routes.settingsSnapshot = () => settings;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            key: ValueKey(asset.id),
            theme: AppTheme.light(),
            navigatorKey: navigator,
            navigatorObservers: [routes],
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) =>
                BackgroundHost(routes: routes, child: child!),
            home: const AppShell(),
          ),
        ),
      );
      Future<void> waitForMotion() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }

      Future<void> tab(int index) async {
        container.read(appNavIndexProvider.notifier).state = index;
        await waitForMotion();
      }

      Future<void> account() async {
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const AccountSyncPage()),
        );
        await waitForMotion();
        final scroll = find.descendant(
          of: find.byType(AccountSyncPage),
          matching: find.byType(Scrollable),
        );
        await tester.drag(scroll, const Offset(0, -400));
        await waitForMotion();
        navigator.currentState!.pop();
        await waitForMotion();
      }

      await waitForMotion();
      await tester.pump(const Duration(seconds: 2));
      if (asset.kind == BackgroundMediaKind.video) {
        expect(
          find.byType(Video),
          findsOneWidget,
          reason: 'Must decode video, not just its poster',
        );
        final player = tester
            .widget<Video>(find.byType(Video))
            .controller
            .player;
        expect(player.state.width, 1280);
        expect(player.state.height, 720);
        expect(player.state.volume, 0);
        expect(player.state.track.audio.id, 'no');
      }
      // Cover the actual grid -> search route. Transparent wallpaper pages must
      // fade the previous content before Navigator hides its route at the end.
      final source = tester.element(find.byType(AppShell));
      SessionSearchPage.show(navigator.currentContext!);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final search = ModalRoute.of(
        tester.element(find.byType(SessionSearchPage)),
      )!;
      expect(search.animation!.isAnimating, isTrue);
      expect(_paintedOpacity(source), closeTo(0, .001));
      expect(tester.element(find.byType(AppShell)), same(source));
      await waitForMotion();
      navigator.currentState!.pop();
      await waitForMotion();
      expect(tester.element(find.byType(AppShell)), same(source));
      expect(_paintedOpacity(source), 1);
      debugPrint(
        'ORBIT_BACKGROUND_PROFILE ${asset.kind.name} search fade verified',
      );
      // Warm all destinations and the account page before recording timings.
      for (final index in [1, 2, 3, 0, 3]) {
        await tab(index);
      }
      await account();
      debugPrint('ORBIT_BACKGROUND_PROFILE ${asset.kind.name} tabs');
      await binding.watchPerformance(() async {
        for (var cycle = 0; cycle < 5; cycle++) {
          for (final index in [0, 1, 2, 3]) {
            await tab(index);
          }
        }
      }, reportKey: '${asset.kind.name}_tabs');
      debugPrint('ORBIT_BACKGROUND_PROFILE ${asset.kind.name} account');
      await binding.watchPerformance(() async {
        for (var cycle = 0; cycle < 5; cycle++) {
          await account();
        }
      }, reportKey: '${asset.kind.name}_account');
      for (final phase in ['tabs', 'account']) {
        final report = binding.reportData!['${asset.kind.name}_$phase'] as Map;
        expect(
          report['frame_count'],
          greaterThan(100),
          reason:
              'Measure intermediate animation frames, not only pumped endpoints',
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      routes.dispose();
      container.dispose();
      debugPrint('ORBIT_BACKGROUND_PROFILE ${asset.kind.name} complete');
    }
    // Decoder shutdown is asynchronous; Windows may still hold video handles.
    await tester.pump(const Duration(seconds: 2));
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Temporary fixtures may be reclaimed by the OS after native disposal.
    }
  });
}
