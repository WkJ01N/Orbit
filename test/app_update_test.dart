import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/app_update.dart';
import 'package:orbit/services/app_update_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  Map<String, dynamic> release({
    String tag = 'v1.5.3',
    bool prerelease = false,
    Map? manifest,
    String? digest,
  }) => {
    'tag_name': tag,
    'prerelease': prerelease,
    'draft': false,
    'body': 'Release notes',
    'orbitManifest': ?manifest,
    'assets': [
      {
        'name': 'orbit-windows-x64.zip',
        'browser_download_url':
            'https://github.com/WkJ01N/Orbit/releases/download/$tag/orbit-windows-x64.zip',
        'size': 100,
        'digest': ?digest,
      },
    ],
  };
  test(
    'ABI selection respects device priority and verifies each exact filename',
    () {
      const names = [
        'orbit-v1.5.6-android-x86_64.apk',
        'orbit-v1.5.6-android.apk',
        'orbit-v1.5.6-android-arm64-v8a.apk',
      ];
      Map<String, Object> metadata(String name, String hash) => {
        'name': name,
        'size': 100,
        'sha256': hash * 64,
      };
      final json = <String, dynamic>{
        'tag_name': 'v1.5.6',
        'assets': [
          for (final name in names)
            {
              'name': name,
              'size': 100,
              'browser_download_url':
                  'https://github.com/WkJ01N/Orbit/releases/download/v1.5.6/$name',
            },
        ],
        'orbitManifest': {
          'version': '1.5.6',
          'assets': {'android': metadata(names[1], 'a')},
          'androidAbis': {
            'x86_64': metadata(names[0], 'b'),
            'arm64-v8a': metadata(names[2], 'c'),
          },
        },
      };
      final parsed = AppRelease.fromGitHub(json);
      expect(parsed.assets.first.name, names[1]);
      expect(
        parsed
            .assetFor('android', supportedAbis: ['arm64-v8a', 'x86_64'])!
            .sha256,
        'c' * 64,
      );
      expect(
        parsed.assetFor('android', supportedAbis: ['x86_64'])!.sha256,
        'b' * 64,
      );
      expect(
        parsed.assetFor('android', supportedAbis: ['unknown'])!.sha256,
        'a' * 64,
      );
      expect(parsed.assetFor('android')!.abi, isNull);
      (json['orbitManifest'] as Map).remove('androidAbis');
      final legacy = AppRelease.fromGitHub(json);
      expect(legacy.assetFor('android')!.verifiable, isTrue);
      expect(
        legacy.assets.where((a) => a.abi != null).every((a) => !a.verifiable),
        isTrue,
      );
      final old = AppRelease.fromGitHub({
        ...json,
        'assets': [(json['assets'] as List)[1]],
      });
      expect(
        old.assetFor('android', supportedAbis: ['arm64-v8a'])!.abi,
        isNull,
      );
    },
  );

  test(
    'stable versions compare numerically and same-version builds compare separately',
    () {
      final value = AppRelease.fromGitHub(
        release(manifest: {'version': '1.5.3', 'buildNumber': 25}),
      );
      expect(value.newerThan('1.5.3', 24), isTrue);
      expect(value.newerThan('1.5.3', 25), isFalse);
      expect(value.newerThan('1.5.4', 1), isFalse);
      expect(AppRelease.compareVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(
        () => AppRelease.fromGitHub(release(prerelease: true)),
        throwsFormatException,
      );
      expect(
        () => AppRelease.fromGitHub(release(tag: 'v1.5.4-beta')),
        throwsFormatException,
      );
    },
  );
  test(
    'only a matching official manifest or API digest enables verification',
    () {
      final hash = 'a' * 64;
      final manifest = {
        'version': '1.5.3',
        'buildNumber': 25,
        'assets': {
          'windows': {
            'name': 'orbit-windows-x64.zip',
            'size': 100,
            'sha256': hash,
          },
        },
      };
      expect(
        AppRelease.fromGitHub(
          release(manifest: manifest),
        ).assets.single.verifiable,
        isTrue,
      );
      expect(
        AppRelease.fromGitHub(release()).assets.single.verifiable,
        isFalse,
      );
      expect(
        AppRelease.fromGitHub(
          release(manifest: {...manifest, 'version': '1.5.2'}),
        ).assets.single.verifiable,
        isFalse,
      );
      expect(
        AppRelease.fromGitHub(
          release(digest: 'sha256:$hash'),
        ).assets.single.sha256,
        hash,
      );
      final bad = release();
      (bad['assets'] as List).single['browser_download_url'] =
          'https://evil.example/package.zip';
      expect(() => AppRelease.fromGitHub(bad), throwsFormatException);
      expect(DownloadSource.validPrefix('http://mirror.test/'), isFalse);
      expect(
        DownloadSource.validPrefix('https://user:password@mirror.test/'),
        isFalse,
      );
      expect(DownloadSource.validPrefix('https://mirror.test/path/'), isTrue);
    },
  );
  test(
    'automatic checks are disabled or limited to 24 hours independently of login',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = AppUpdateService(SettingsService());
      await service.savePreferences({'automatic': false});
      expect(await service.check(automatic: true), isNull);
      await service.savePreferences({
        'lastCheck': DateTime.now().millisecondsSinceEpoch,
      });
      expect(await service.check(automatic: true), isNull);
    },
  );
  test(
    'downloads verify official bytes, reject corruption and remove partial files',
    () async {
      final dir = await Directory.systemTemp.createTemp('orbit_update_');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        await dir.delete(recursive: true);
      });
      final good = List<int>.generate(1000, (i) => i % 256);
      var corrupt = false;
      server.listen((r) {
        final data = corrupt ? ([...good]..[10] = 99) : good;
        r.response.contentLength = data.length;
        r.response.add(data);
        r.response.close();
      });
      final asset = UpdateAsset(
        platform: 'windows',
        name: 'package.zip',
        url: 'http://127.0.0.1:${server.port}/package.zip',
        size: good.length,
        sha256: sha256.convert(good).toString(),
      );
      final service = AppUpdateService(
        SettingsService(),
        directory: () async => dir,
      );
      final file = await service.download(
        asset,
        const DownloadSource('direct', ''),
        UpdateOperation(),
        onProgress: (_, _) {},
      );
      expect(await file.readAsBytes(), good);
      await file.delete();
      corrupt = true;
      await expectLater(
        service.download(
          asset,
          const DownloadSource('direct', ''),
          UpdateOperation(),
          onProgress: (_, _) {},
        ),
        throwsFormatException,
      );
      expect(await File('${dir.path}/package.zip.part').exists(), isFalse);
      expect(await File('${dir.path}/package.zip').exists(), isFalse);
      await expectLater(
        AppUpdateService.verify(
          file,
          const UpdateAsset(
            platform: 'windows',
            name: 'x.zip',
            url: 'https://github.com/x',
            size: 1000,
          ),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'latency probes use package ranges three times with at most two sources active',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var active = 0, maxActive = 0;
      final ranges = <String>[];
      server.listen((r) async {
        r.response.headers.contentType = ContentType.binary;
        active++;
        if (active > maxActive) maxActive = active;
        ranges.add(r.headers.value('Range') ?? '');
        await Future<void>.delayed(
          Duration(milliseconds: r.uri.path.startsWith('/slow') ? 40 : 3),
        );
        r.response.statusCode = 206;
        r.response.add([80, 75, 3, 4]);
        await r.response.close();
        active--;
      });
      final asset = UpdateAsset(
        platform: 'windows',
        name: 'x.zip',
        url: 'http://127.0.0.1:${server.port}/x.zip',
        size: 4,
      );
      final service = AppUpdateService(SettingsService());
      final sources = [
        DownloadSource('slow', 'http://127.0.0.1:${server.port}/slow/'),
        DownloadSource('fast', 'http://127.0.0.1:${server.port}/fast/'),
        DownloadSource('extra', 'http://127.0.0.1:${server.port}/extra/'),
      ];
      final values = await service.probe(asset, sources, UpdateOperation());
      expect(ranges, hasLength(9));
      expect(ranges.toSet(), {'bytes=0-65535'});
      expect(maxActive, lessThanOrEqualTo(2));
      expect(values.every((v) => v.milliseconds != null), isTrue);
      expect(
        values.firstWhere((v) => v.source.name == 'slow').milliseconds!,
        greaterThan(
          values.firstWhere((v) => v.source.name == 'fast').milliseconds!,
        ),
      );
      final cancelled = UpdateOperation()..cancel();
      await expectLater(
        service.probe(asset, sources, cancelled),
        throwsA(isA<UpdateCancelled>()),
      );
    },
  );
}
