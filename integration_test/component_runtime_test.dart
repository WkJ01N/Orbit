import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:orbit/core/background/background_media.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/services/background_asset_service.dart';
import 'package:orbit/services/component_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'video is optional at startup and a verified Release runtime becomes usable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const fixtures = String.fromEnvironment('ORBIT_BACKGROUND_FIXTURES');
      const pack = String.fromEnvironment('ORBIT_VIDEO_COMPONENT');
      expect(fixtures, isNotEmpty);
      expect(pack, isNotEmpty);
      final directory = await Directory.systemTemp.createTemp(
        'orbit-component-runtime-',
      );
      final components = ComponentService(
        directory: Directory('${directory.path}/components'),
      );
      await components.initialize();
      final id = await components.videoId();
      expect(components.ready(id), isFalse);
      final service = BackgroundAssetService(
        directory: Directory('${directory.path}/media'),
        components: components,
      );
      final source = File('$fixtures/video.mp4');
      final asset = BackgroundAsset(
        id: (await sha256.bind(source.openRead()).first).toString(),
        name: 'Fixture video',
        extension: 'mp4',
        kind: BackgroundMediaKind.video,
        width: 1280,
        height: 720,
      );
      await source.copy((await service.file(asset)).path);
      await File(
        '$fixtures/still.png',
      ).copy((await service.poster(asset)).path);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundMedia(
              key: const ValueKey('runtime'),
              asset: asset,
              framing: const BackgroundFraming(),
              service: service,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(Video), findsNothing);
      await components.installArchive(
        await components.descriptor(id),
        File(pack),
      );
      for (var i = 0; i < 60 && find.byType(Video).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Video), findsOneWidget);
      final player = tester.widget<Video>(find.byType(Video)).controller.player;
      for (
        var i = 0;
        i < 60 && (player.state.width == null || player.state.width! <= 0);
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(player.state.width, greaterThan(0));
      expect(player.state.volume, 0);
      expect(player.state.track.audio.id, 'no');
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'component': id,
        'verifiedReleaseRuntime': true,
        'width': player.state.width,
        'muted': true,
        'directory': directory.path,
      };
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      components.dispose();
      // Windows keeps the runtime DLL mapped until process exit. The driver-side
      // validation task can remove this reported temporary directory afterward.
    },
  );
}
