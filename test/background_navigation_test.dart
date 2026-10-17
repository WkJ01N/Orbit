import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:orbit/core/background/background_host.dart';
import 'package:orbit/core/background/background_media.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/settings/account_sync_page.dart';
import 'package:orbit/features/search/session_search_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/providers/background_providers.dart';
import 'package:orbit/providers/account_sync_providers.dart';
import 'package:orbit/providers/navigation_providers.dart';
import 'package:orbit/services/background_asset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _asset = BackgroundAsset(
  id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  name: 'wallpaper.png',
  kind: BackgroundMediaKind.image,
  width: 4,
  height: 4,
);
final _settings = BackgroundSettings(
  enabled: true,
  assets: {_asset.id: _asset},
  pages: {
    BackgroundPage.grid: PageBackgroundSettings(
      assetId: _asset.id,
      framing: const BackgroundFraming(dim: 0),
      regions: const {BackgroundRegionId.header, BackgroundRegionId.content},
    ),
    BackgroundPage.settings: const PageBackgroundSettings(followGrid: true),
  },
);

class _FixedBackgrounds extends BackgroundSettingsNotifier {
  _FixedBackgrounds(this.value);
  final BackgroundSettings value;
  @override
  Future<BackgroundSettings> build() async => value;
}

class _FixtureService extends BackgroundAssetService {
  _FixtureService(this.image);
  final File image;
  @override
  Future<File> file(BackgroundAsset asset) => SynchronousFuture(image);
  @override
  Future<File> poster(BackgroundAsset asset) => SynchronousFuture(image);
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage();
  @override
  Widget build(BuildContext context) =>
      const BackgroundScaffold(body: SizedBox.expand());
}

class _SignedIn extends AccountSyncNotifier {
  @override
  Future<SyncStatus> build() async => const SyncStatus(
    phase: SyncPhase.idle,
    account: SyncAccount(uid: 'test-user', email: 'test@example.com'),
  );
  @override
  Future<void> refreshProfile() async {}
}

Widget _app({
  required BackgroundRouteObserver routes,
  required GlobalKey<NavigatorState> navigator,
  required File image,
  BackgroundSettings? settings,
  GlobalKey? capture,
  Widget home = const _EmptyPage(),
  List<Override> overrides = const [],
}) {
  final value = settings ?? _settings;
  routes.mainPage = () => BackgroundPage.grid;
  routes.settingsSnapshot = () => value;
  return ProviderScope(
    overrides: [
      backgroundSettingsProvider.overrideWith(() => _FixedBackgrounds(value)),
      backgroundAssetServiceProvider.overrideWithValue(_FixtureService(image)),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorKey: navigator,
      navigatorObservers: [routes],
      builder: (context, child) => RepaintBoundary(
        key: capture,
        child: BackgroundHost(routes: routes, child: child!),
      ),
      home: BackgroundPageTheme(
        settings: value,
        owner: BackgroundPage.grid,
        child: home,
      ),
    ),
  );
}

Future<void> _loadImage(WidgetTester tester, File file) async {
  await tester.runAsync(() async {
    await precacheImage(
      FileImage(file),
      tester.element(find.byType(Navigator)),
    );
  });
  await tester.pumpAndSettle();
}

Future<List<int>?> _pixelAt(
  WidgetTester tester,
  GlobalKey capture, [
  Offset? position,
]) => tester.runAsync(() async {
  final boundary =
      capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  final x = position?.dx.toInt() ?? image.width ~/ 2;
  final y = position?.dy.toInt() ?? image.height ~/ 2;
  final offset = (image.width * y + x) * 4;
  final result = bytes.sublist(offset, offset + 4);
  image.dispose();
  return result;
});

Future<void> _expectWallpaper(WidgetTester tester, GlobalKey capture) async {
  expect(await _pixelAt(tester, capture), [220, 30, 80, 255]);
}

void main() {
  late Directory directory;
  late File wallpaper;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'orbit-route-background-',
    );
    final image = img.Image(width: 4, height: 4)
      ..clear(img.ColorRgb8(220, 30, 80));
    wallpaper = await File(
      '${directory.path}/wallpaper.png',
    ).writeAsBytes(img.encodePng(image));
  });
  tearDownAll(() => directory.delete(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final nested in [false, true]) {
    testWidgets(
      'Windows search fades the previous page before offstage (nested=$nested)',
      (tester) async {
        final routes = BackgroundRouteObserver();
        addTearDown(routes.dispose);
        final navigator = GlobalKey<NavigatorState>();
        final capture = GlobalKey();
        const marker = Key('previous-page-marker');
        const sample = Offset(380, 260);
        const previousPage = BackgroundScaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 160,
              child: ColoredBox(key: marker, color: Color(0xff00cc66)),
            ),
          ),
        );
        await tester.pumpWidget(
          _app(
            routes: routes,
            navigator: navigator,
            image: wallpaper,
            capture: capture,
            home: previousPage,
          ),
        );
        await _loadImage(tester, wallpaper);
        if (nested) {
          navigator.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => previousPage),
          );
          await tester.pumpAndSettle();
        }
        final previous = tester.element(find.byKey(marker));
        expect(await _pixelAt(tester, capture, sample), [0, 204, 102, 255]);

        SessionSearchPage.show(navigator.currentContext!);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        final early = (await _pixelAt(tester, capture, sample))!;
        await tester.pump(const Duration(milliseconds: 15));
        final middle = (await _pixelAt(tester, capture, sample))!;
        expect(early[1], inExclusiveRange(30, 204));
        expect(middle[1], inExclusiveRange(30, early[1]));
        await tester.pump(const Duration(milliseconds: 55));
        final search = ModalRoute.of(
          tester.element(find.byType(SessionSearchPage)),
        )!;
        expect(search.animation!.isAnimating, isTrue);
        expect(await _pixelAt(tester, capture, sample), [220, 30, 80, 255]);
        expect(tester.element(find.byKey(marker)), same(previous));
        await tester.pumpAndSettle();
        expect(await _pixelAt(tester, capture, sample), [220, 30, 80, 255]);

        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));
        final returning = (await _pixelAt(tester, capture, sample))!;
        expect(returning[1], inExclusiveRange(30, 204));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(marker)), same(previous));
        expect(await _pixelAt(tester, capture, sample), [0, 204, 102, 255]);

        // Reversing an unfinished push must keep the same page and rendered frame.
        SessionSearchPage.show(navigator.currentContext!);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));
        final interrupted = await _pixelAt(tester, capture, sample);
        navigator.currentState!.pop();
        await tester.pump();
        expect(await _pixelAt(tester, capture, sample), interrupted);
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(marker)), same(previous));
        expect(await _pixelAt(tester, capture, sample), [0, 204, 102, 255]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      '$platform wallpaper remains visible throughout push and pop',
      (tester) async {
        final routes = BackgroundRouteObserver();
        addTearDown(routes.dispose);
        final navigator = GlobalKey<NavigatorState>();
        final capture = GlobalKey();
        await tester.pumpWidget(
          _app(
            routes: routes,
            navigator: navigator,
            image: wallpaper,
            capture: capture,
          ),
        );
        await _loadImage(tester, wallpaper);
        final media = tester.state(find.byType(BackgroundMedia));
        final route = MaterialPageRoute<void>(
          builder: (_) => const _EmptyPage(),
        );
        navigator.currentState!.push(route);
        for (final milliseconds in [0, 16, 80, 140, 240]) {
          await tester.pump(Duration(milliseconds: milliseconds));
          await _expectWallpaper(tester, capture);
          expect(tester.state(find.byType(BackgroundMedia)), same(media));
        }
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        expect(routes.snapshotFor(route), isNotNull);
        for (final milliseconds in [0, 16, 80, 100]) {
          await tester.pump(Duration(milliseconds: milliseconds));
          await _expectWallpaper(tester, capture);
          expect(tester.state(find.byType(BackgroundMedia)), same(media));
          expect(routes.snapshotFor(route), isNotNull);
        }
        await tester.pumpAndSettle();
        expect(routes.snapshotFor(route), isNull);
        await _expectWallpaper(tester, capture);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets('nested routes and popups keep their own background snapshot', (
    tester,
  ) async {
    final routes = BackgroundRouteObserver();
    addTearDown(routes.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(routes: routes, navigator: navigator, image: wallpaper),
    );
    await _loadImage(tester, wallpaper);
    final first = MaterialPageRoute<void>(builder: (_) => const _EmptyPage());
    navigator.currentState!.push(first);
    await tester.pumpAndSettle();
    final snapshot = routes.snapshotFor(first);
    routes.mainPage = () => BackgroundPage.import;
    routes.settingsSnapshot = () => const BackgroundSettings();
    final nested = MaterialPageRoute<void>(builder: (_) => const _EmptyPage());
    navigator.currentState!.push(nested);
    await tester.pumpAndSettle();
    expect(routes.snapshotFor(nested)!.settings, same(snapshot!.settings));
    expect(routes.snapshotFor(nested)!.owner, snapshot.owner);
    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => const AlertDialog(content: Text('Popup')),
    );
    await tester.pumpAndSettle();
    expect(routes.paintingSnapshot, same(routes.snapshotFor(nested)));
    final dialogContext = tester.element(find.byType(AlertDialog));
    expect(
      Theme.of(dialogContext).scaffoldBackgroundColor,
      isNot(Colors.transparent),
    );
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(routes.paintingSnapshot, same(routes.snapshotFor(nested)));
    await tester.pumpAndSettle();
    expect(routes.snapshotFor(nested), isNull);
    expect(routes.snapshotFor(first), same(snapshot));
  });

  testWidgets('empty backgrounds do not start media transitions between tabs', (
    tester,
  ) async {
    final routes = BackgroundRouteObserver();
    addTearDown(routes.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(
        routes: routes,
        navigator: navigator,
        image: wallpaper,
        settings: const BackgroundSettings(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackgroundHost)),
    );
    for (final page in [1, 3, 2, 0]) {
      container.read(appNavIndexProvider.notifier).state = page;
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.byType(BackgroundMedia), findsNothing);
    }
  });

  for (final background in [true, false]) {
    for (final systemBack in [false, true]) {
      testWidgets(
        'account scroll survives ${systemBack ? "system" : "app bar"} back with background=$background',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(420, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final routes = BackgroundRouteObserver();
          addTearDown(routes.dispose);
          final navigator = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            _app(
              routes: routes,
              navigator: navigator,
              image: wallpaper,
              settings: background ? _settings : const BackgroundSettings(),
              overrides: [accountSyncProvider.overrideWith(_SignedIn.new)],
            ),
          );
          await _loadImage(tester, wallpaper);
          final route = MaterialPageRoute<void>(
            builder: (_) => const AccountSyncPage(),
          );
          navigator.currentState!.push(route);
          await tester.pumpAndSettle();
          final scroll = find.descendant(
            of: find.byType(AccountSyncPage),
            matching: find.byType(Scrollable),
          );
          await tester.drag(scroll, const Offset(0, -500));
          await tester.pumpAndSettle();
          final state = tester.state<ScrollableState>(scroll);
          final position = state.position;
          final offset = position.pixels;
          expect(offset, greaterThan(100));
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.pageBack();
          }
          for (final milliseconds in [0, 16, 90, 90]) {
            await tester.pump(Duration(milliseconds: milliseconds));
            expect(tester.state(scroll), same(state));
            expect(state.position, same(position));
            expect(position.pixels, offset);
            expect(routes.snapshotFor(route), isNotNull);
          }
          await tester.pumpAndSettle();
          expect(find.byType(AccountSyncPage), findsNothing);
          expect(routes.snapshotFor(route), isNull);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets(
    'predictive back cancellation and commit preserve account scroll',
    (tester) async {
      final routes = BackgroundRouteObserver();
      addTearDown(routes.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _app(
          routes: routes,
          navigator: navigator,
          image: wallpaper,
          overrides: [accountSyncProvider.overrideWith(_SignedIn.new)],
        ),
      );
      await _loadImage(tester, wallpaper);
      final route = MaterialPageRoute<void>(
        builder: (_) => const AccountSyncPage(),
      );
      navigator.currentState!.push(route);
      await tester.pumpAndSettle();
      final snapshot = routes.snapshotFor(route);
      final media = tester.state(find.byType(BackgroundMedia));
      final scroll = find.descendant(
        of: find.byType(AccountSyncPage),
        matching: find.byType(Scrollable),
      );
      await tester.drag(scroll, const Offset(0, -500));
      await tester.pumpAndSettle();
      final scrollState = tester.state<ScrollableState>(scroll);
      final offset = scrollState.position.pixels;
      expect(offset, greaterThan(0));
      Future<void> gesture(
        String method, [
        Map<String, dynamic>? arguments,
      ]) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, arguments),
          ),
          (_) {},
        );
        await tester.pump();
      }

      await gesture('startBackGesture', {
        'touchOffset': [5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      expect(route.popGestureInProgress, isTrue);
      await gesture('updateBackGestureProgress', {
        'touchOffset': [100.0, 300.0],
        'progress': .35,
        'swipeEdge': 0,
      });
      expect(routes.snapshotFor(route), same(snapshot));
      expect(tester.state(scroll), same(scrollState));
      expect(scrollState.position.pixels, offset);
      await gesture('cancelBackGesture');
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      expect(route.popGestureInProgress, isFalse);
      expect(routes.snapshotFor(route), same(snapshot));
      expect(tester.state(find.byType(BackgroundMedia)), same(media));
      expect(tester.state(scroll), same(scrollState));
      expect(scrollState.position.pixels, offset);
      await gesture('startBackGesture', {
        'touchOffset': [5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await gesture('updateBackGestureProgress', {
        'touchOffset': [150.0, 300.0],
        'progress': .6,
        'swipeEdge': 0,
      });
      await gesture('commitBackGesture');
      expect(tester.state(scroll), same(scrollState));
      expect(scrollState.position.pixels, offset);
      expect(routes.snapshotFor(route), same(snapshot));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSyncPage), findsNothing);
      expect(routes.snapshotFor(route), isNull);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
