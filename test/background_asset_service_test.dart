import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/services/background_asset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late BackgroundAssetService service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-asset-test-');
    service = BackgroundAssetService(
      directory: Directory('${root.path}/managed'),
    );
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'image import decodes, hashes, deduplicates and copies independently of original file',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xFF4477AA), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(24, 16);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      final source = await File('${root.path}/source.png').writeAsBytes(bytes);
      final first = await service.importFile(source);
      final second = await service.importFile(source, name: 'copy.png');
      expect(first.id, second.id);
      expect(first.width, 24);
      expect(first.height, 16);
      await source.delete();
      expect(await (await service.file(first)).readAsBytes(), bytes);
      expect(await (await service.poster(first)).exists(), isTrue);
      final saved = BackgroundSettings(
        enabled: true,
        assets: {first.id: first},
        pages: {BackgroundPage.grid: PageBackgroundSettings(assetId: first.id)},
      );
      await service.removeUnreferenced([second], saved);
      expect(await (await service.file(first)).exists(), isTrue);
      await service.removeUnreferenced([second], const BackgroundSettings());
      expect(await (await service.file(first)).exists(), isFalse);
      expect(await (await service.poster(first)).exists(), isFalse);
    },
  );

  test(
    'decode failure removes staging files; missing or corrupt local hashes disable dependent pages',
    () async {
      final source = await File(
        '${root.path}/broken.png',
      ).writeAsString('not an image');
      await expectLater(service.importFile(source), throwsA(anything));
      expect(await (await service.directory()).list().toList(), isEmpty);
      final asset = BackgroundAsset(
        id: 'e' * 64,
        name: 'lost.gif',
        kind: BackgroundMediaKind.gif,
        width: 2,
        height: 2,
        extension: 'gif',
      );
      final settings = BackgroundSettings(
        enabled: true,
        assets: {asset.id: asset},
        pages: {
          BackgroundPage.grid: PageBackgroundSettings(assetId: asset.id),
          BackgroundPage.upcoming: const PageBackgroundSettings(
            followGrid: true,
          ),
        },
      );
      for (final corrupt in [false, true]) {
        if (corrupt) {
          await (await service.file(
            asset,
          )).writeAsBytes(utf8.encode('corrupt'));
        }
        final available = await service.resolveAvailable(settings);
        expect(available.resolved(BackgroundPage.grid).assetId, isNull);
        expect(available.resolved(BackgroundPage.upcoming).assetId, isNull);
      }
    },
  );
}
