import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
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

class _MediaPicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'picked.png', size: 1, path: 'picked.png'),
  ]);
}

class _MediaService extends BackgroundAssetService {
  _MediaService(Directory directory) : super(directory: directory);
  @override
  Future<BackgroundAsset> importFile(File source, {String? name}) async =>
      BackgroundAsset(
        id: 'b' * 64,
        name: 'picked.png',
        kind: BackgroundMediaKind.image,
        width: 800,
        height: 600,
      );
}

class _FailOnceBackgrounds extends BackgroundSettingsNotifier {
  bool failNext = true;
  @override
  Future<void> save(BackgroundSettings value) async {
    if (failNext) {
      failNext = false;
      throw StateError('disk unavailable');
    }
    await super.save(value);
  }
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
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Future<void> resize(Size size) async {
        tester.view.physicalSize = size;
        await tester.binding.setSurfaceSize(size);
      }

      await resize(const Size(400, 900));
      if (const bool.fromEnvironment('ORBIT_CAPTURE_EDITOR')) {
        await tester.runAsync(() async {
          for (final entry in {
            'Roboto': Platform.environment['ORBIT_SCREENSHOT_FONT'],
            'MaterialIcons': Platform.environment['ORBIT_SCREENSHOT_ICON_FONT'],
          }.entries) {
            if (entry.value == null) continue;
            final bytes = await File(entry.value!).readAsBytes();
            await (FontLoader(
              entry.key,
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          }
        });
      }
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
          backgroundSettingsProvider.overrideWith(_FailOnceBackgrounds.new),
          backgroundAssetServiceProvider.overrideWithValue(
            _MediaService(directory),
          ),
          reminderSettingsProvider.overrideWith(_QuietReminders.new),
          sessionsProvider.overrideWith((ref) async => []),
          weekGridProvider.overrideWith((ref) => null),
          upcomingSessionsProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      FilePicker.platform = _MediaPicker();
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
      expect(find.text('Choose a page'), findsOneWidget);
      await tester.tap(find.byKey(const Key('background-next-save')));
      await tester.pumpAndSettle();
      BackgroundPageScope scope() => tester
          .widgetList<BackgroundPageScope>(find.byType(BackgroundPageScope))
          .firstWhere((s) => s.registry != null);
      await tester.ensureVisible(find.text('Change media'));
      await tester.tap(find.text('Change media'));
      await tester.pumpAndSettle();
      expect(scope().settings.resolved(BackgroundPage.grid).assetId, 'b' * 64);
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
      await tester.ensureVisible(find.text('Browse preview'));
      await tester.tap(find.text('Browse preview'));
      await tester.pump();
      await tester.tapAt(header.bounds!.center);
      await tester.pump();
      expect(scope().settings.page(BackgroundPage.grid).regions, beforeBrowse);
      expect(tester.takeException(), isNull);
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('ORBIT_CAPTURE_EDITOR')) return;
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find
                .ancestor(
                  of: find.byType(BackgroundEditorPage),
                  matching: find.byType(RepaintBoundary),
                )
                .first,
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/background-editor-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> next() async {
        await tester.tap(find.text('Next'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }

      await next();
      expect(scope().owner, BackgroundPage.grid);
      expect(find.text('Apply to other pages?'), findsNothing);
      await capture('mobile');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('disk unavailable'), findsOneWidget);
      expect(find.byType(BackgroundEditorPage), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundEditorPage), findsNothing);
      expect(find.text('Open backgrounds'), findsOneWidget);
      final saved = await container.read(backgroundSettingsProvider.future);
      expect(saved.enabled, isTrue);
      expect(saved.resolved(BackgroundPage.grid).assetId, 'b' * 64);
      expect(saved.page(BackgroundPage.upcoming).assetId, isNull);
      expect(saved.resolved(BackgroundPage.grid).framing.zoom, greaterThan(1));
      await tester.tap(find.text('Open backgrounds'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a page'), findsOneWidget);
      await tester.tap(find.byKey(const Key('background-next-save')));
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
      expect(find.byType(BackgroundEditorPage), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        (await container.read(backgroundSettingsProvider.future)).toJson(),
        saved.toJson(),
      );
      await tester.tap(find.text('Open backgrounds'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a page'), findsOneWidget);
      await tester.tap(find.byKey(const Key('background-next-save')));
      await tester.pumpAndSettle();
      await resize(const Size(320, 600));
      textScale.value = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await resize(const Size(1200, 800));
      textScale.value = 1;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('background-page-upcoming')));
      await tester.tap(find.byKey(const Key('background-next-save')));
      await tester.pumpAndSettle();
      expect(scope().owner, BackgroundPage.upcoming);
      final follow = find.widgetWithText(
        SwitchListTile,
        'Follow schedule background',
      );
      await tester.ensureVisible(follow);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(scope().settings.page(BackgroundPage.upcoming).followGrid, isTrue);
      final followedHeader = scope().registry!.registrations.values.firstWhere(
        (r) => r.region == BackgroundRegionId.header,
      );
      await tester.tapAt(followedHeader.bounds!.center);
      await tester.pumpAndSettle();
      expect(
        scope().settings.resolved(BackgroundPage.upcoming).regions,
        isNot(contains(BackgroundRegionId.header)),
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await capture('desktop');
      expect(scope().settings.page(BackgroundPage.grid).framing.zoom, 1);
      expect(
        tester
            .widgetList<Slider>(find.byType(Slider))
            .where((slider) => slider.onChanged == null)
            .length,
        2,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundEditorPage), findsNothing);
      expect(
        (await container.read(
          backgroundSettingsProvider.future,
        )).page(BackgroundPage.upcoming).followGrid,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
