import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/background/background_host.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/features/settings/background_editor_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/background_providers.dart';
import 'package:orbit/services/background_asset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _QuietReminders extends ReminderSettingsNotifier {
  @override
  Future<ReminderSettings> build() async =>
      const ReminderSettings(enabled: false);
}

class _Probe extends StatefulWidget {
  const _Probe(this.id, {super.key});
  final String id;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'shared plane remains stationary and mounted; independent transitions keep at most two states',
    (tester) async {
      Widget app(String id, int page) => MaterialApp(
        home: BackgroundTransition(
          identity: id,
          page: page,
          child: _Probe(id, key: ValueKey(id)),
        ),
      );
      await tester.pumpWidget(app('shared', 0));
      final initial = tester.state(find.byType(_Probe));
      final rect = tester.getRect(find.byType(_Probe));
      await tester.pumpWidget(app('shared', 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.state(find.byType(_Probe)), same(initial));
      expect(tester.getRect(find.byType(_Probe)), rect);
      await tester.pumpWidget(app('independent', 2));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(_Probe), findsNWidgets(2));
      expect(
        tester.state(
          find.byWidgetPredicate((w) => w is _Probe && w.id == 'shared'),
        ),
        same(initial),
      );
      expect(
        tester
            .getRect(
              find.byWidgetPredicate((w) => w is _Probe && w.id == 'shared'),
            )
            .left,
        isNot(rect.left),
      );
      await tester.pumpWidget(app('third', 3));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(_Probe), findsNWidgets(2));
      await tester.pumpAndSettle();
      expect(find.byType(_Probe), findsOneWidget);
      expect(tester.widget<_Probe>(find.byType(_Probe)).id, 'third');
    },
  );

  testWidgets(
    'secondary routes capture source and preserve it across nested routes and underlying tab changes',
    (tester) async {
      final observer = BackgroundRouteObserver();
      var owner = BackgroundPage.settings;
      observer.mainPage = () => owner;
      var sourceSettings = const BackgroundSettings(enabled: true);
      observer.settingsSnapshot = () => sourceSettings;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: const SizedBox(),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      owner = BackgroundPage.import;
      sourceSettings = const BackgroundSettings();
      expect(observer.owner, BackgroundPage.settings);
      expect(observer.capturedSettings!.enabled, isTrue);
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      expect(observer.owner, BackgroundPage.settings);
      expect(observer.capturedSettings!.enabled, isTrue);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(observer.owner, BackgroundPage.import);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(arguments: BackgroundPage.upcoming),
          builder: (_) => const SizedBox(),
        ),
      );
      await tester.pumpAndSettle();
      expect(observer.owner, BackgroundPage.upcoming);
    },
  );

  testWidgets(
    'preview uses actual region bounds; taps edit draft without triggering page actions or persistence',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final asset = BackgroundAsset(
        id: 'a' * 64,
        name: 'test.png',
        kind: BackgroundMediaKind.image,
        width: 800,
        height: 600,
      );
      final settings = BackgroundSettings(
        enabled: true,
        assets: {asset.id: asset},
        pages: {BackgroundPage.grid: PageBackgroundSettings(assetId: asset.id)},
      );
      final directory =
          await tester.runAsync(
                () => Directory.systemTemp.createTemp('orbit-editor-widget-'),
              )
              as Directory;
      addTearDown(() => directory.delete(recursive: true));
      final container = ProviderContainer(
        overrides: [
          backgroundAssetServiceProvider.overrideWithValue(
            BackgroundAssetService(directory: directory),
          ),
          reminderSettingsProvider.overrideWith(_QuietReminders.new),
          sessionsProvider.overrideWith((ref) async => []),
          weekGridProvider.overrideWith((ref) => null),
          upcomingSessionsProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      final textScale = ValueNotifier<double>(1);
      addTearDown(textScale.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => ValueListenableBuilder<double>(
              valueListenable: textScale,
              builder: (context, scale, _) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BackgroundEditorPage(initial: settings),
                    ),
                  ),
                  child: const Text('Open backgrounds'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open backgrounds'));
      await tester.pumpAndSettle();
      BackgroundPageScope scope() => tester
          .widgetList<BackgroundPageScope>(find.byType(BackgroundPageScope))
          .firstWhere((s) => s.registry != null);
      final header = scope().registry!.registrations.values.firstWhere(
        (r) => r.region == BackgroundRegionId.header,
      );
      await tester.tapAt(header.bounds!.center);
      await tester.pump();
      expect(
        scope().settings.page(BackgroundPage.grid).regions,
        contains(BackgroundRegionId.header),
      );
      expect(
        (await container.read(backgroundSettingsProvider.future)).enabled,
        isFalse,
      );
      // The real grid '+' sits under the editor overlay and cannot open a course editor.
      final add = find.byIcon(Icons.add).first;
      await tester.tapAt(tester.getCenter(add));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundEditorPage), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      final beforeBrowse = {
        ...scope().settings.page(BackgroundPage.grid).regions,
      };
      final center = scope().registry!.registrations.values
          .firstWhere((r) => r.region == BackgroundRegionId.content)
          .bounds!
          .center;
      final first = await tester.startGesture(
        center - const Offset(25, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + const Offset(25, 0),
        pointer: 2,
      );
      await tester.pump();
      await first.moveBy(const Offset(-30, 0));
      await second.moveBy(const Offset(30, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pump();
      expect(
        scope().settings.resolved(BackgroundPage.grid).framing.zoom,
        greaterThan(1),
      );
      expect(scope().settings.page(BackgroundPage.grid).regions, beforeBrowse);
      await tester.tap(find.text('Browse preview'));
      await tester.pump();
      await tester.tapAt(header.bounds!.center);
      await tester.pump();
      expect(scope().settings.page(BackgroundPage.grid).regions, beforeBrowse);
      expect(tester.takeException(), isNull);
      Future<void> next() async {
        await tester.tap(find.text('Next'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }

      await next();
      expect(find.text('Apply to other pages?'), findsOneWidget);
      for (final name in ['Upcoming', 'Import', 'Settings']) {
        await tester.tap(find.widgetWithText(CheckboxListTile, name));
      }
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(scope().owner, BackgroundPage.upcoming);
      await next();
      expect(scope().owner, BackgroundPage.import);
      await next();
      expect(scope().owner, BackgroundPage.settings);
      await next();
      expect(find.text('Save all pages'), findsOneWidget);
      await tester.tap(find.text('Save all pages'));
      await tester.pumpAndSettle();
      expect(find.text('Open backgrounds'), findsOneWidget);
      final saved = await container.read(backgroundSettingsProvider.future);
      expect(saved.enabled, isTrue);
      for (final page in BackgroundPage.values.skip(1)) {
        expect(saved.page(page).followGrid, isTrue);
        expect(saved.resolved(page).assetId, asset.id);
      }
      await tester.tap(find.text('Open backgrounds'));
      await tester.pumpAndSettle();
      final reopenedHeader = scope().registry!.registrations.values.firstWhere(
        (r) => r.region == BackgroundRegionId.header,
      );
      await tester.tapAt(reopenedHeader.bounds!.center);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(
        (await container.read(backgroundSettingsProvider.future)).toJson(),
        saved.toJson(),
      );
      await tester.tap(find.text('Open backgrounds'));
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(320, 600));
      textScale.value = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
