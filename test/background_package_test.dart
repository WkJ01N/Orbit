import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/services/background_asset_service.dart';
import 'package:orbit/services/background_package_service.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('orbit-background-test-');
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'ZIP roundtrip deduplicates shared source, streams media, verifies and rolls back installed files',
    () async {
      final source = BackgroundAssetService(
        directory: Directory('${root.path}/source'),
      );
      final bytes = List<int>.generate(2 * 1024 * 1024, (i) => i % 251);
      final id = sha256.convert(bytes).toString();
      final asset = BackgroundAsset(
        id: id,
        name: 'video.mp4',
        kind: BackgroundMediaKind.video,
        extension: 'mp4',
        width: 1920,
        height: 1080,
      );
      await (await source.file(asset)).writeAsBytes(bytes);
      final settings = BackgroundSettings(
        enabled: true,
        assets: {id: asset},
        pages: {
          BackgroundPage.grid: PageBackgroundSettings(assetId: id),
          BackgroundPage.upcoming: const PageBackgroundSettings(
            followGrid: true,
          ),
        },
      );
      await SettingsService().saveBackgroundSettings(settings);
      final json = ScheduleBackupService().encodeToJson(
        [],
        settings: await SettingsService().exportPortableSettings(),
      );
      final exportDir = await Directory('${root.path}/export').create();
      final zip = await BackgroundPackageService(
        source,
      ).create(json, exportDir);
      final target = BackgroundAssetService(
        directory: Directory('${root.path}/target'),
      );
      final stage = await Directory('${root.path}/stage').create();
      final prepared = await BackgroundPackageService(
        target,
      ).prepare(zip, stage);
      expect(prepared.media, hasLength(1));
      expect(
        prepared.backup.settings!.backgrounds!
            .resolved(BackgroundPage.upcoming)
            .assetId,
        id,
      );
      await prepared.install(target);
      expect(
        (await sha256.bind((await target.file(asset)).openRead()).first)
            .toString(),
        id,
      );
      await prepared.rollback();
      expect(await (await target.file(asset)).exists(), isFalse);
      // Existing content must survive a failed/cancelled restore.
      await (await target.file(asset)).writeAsBytes(bytes);
      await prepared.install(target);
      await prepared.rollback();
      expect(await (await target.file(asset)).exists(), isTrue);
    },
  );

  test(
    'rejects path traversal, corrupt media hashes and duplicate entries',
    () async {
      final service = BackgroundPackageService(
        BackgroundAssetService(directory: Directory('${root.path}/assets')),
      );
      Future<void> reject(Archive archive, String name) async {
        final file = await File(
          '${root.path}/$name.orbit',
        ).writeAsBytes(ZipEncoder().encode(archive)!);
        final staging = await Directory('${root.path}/$name').create();
        await expectLater(
          service.prepare(file, staging),
          throwsFormatException,
        );
        expect(await File('${root.path}/escape').exists(), isFalse);
      }

      await reject(
        Archive()..addFile(ArchiveFile('../escape', 1, [1])),
        'traversal',
      );
      final id = 'f' * 64;
      final asset = BackgroundAsset(
        id: id,
        name: 'image.png',
        kind: BackgroundMediaKind.image,
        width: 2,
        height: 2,
      );
      await SettingsService().saveBackgroundSettings(
        BackgroundSettings(
          enabled: true,
          assets: {id: asset},
          pages: {BackgroundPage.grid: PageBackgroundSettings(assetId: id)},
        ),
      );
      final manifest = utf8.encode(
        ScheduleBackupService().encodeToJson(
          [],
          settings: await SettingsService().exportPortableSettings(),
        ),
      );
      await reject(
        Archive()
          ..addFile(ArchiveFile('backup.json', manifest.length, manifest))
          ..addFile(ArchiveFile(asset.relativePath, 3, [1, 2, 3])),
        'hash',
      );
    },
  );
}
