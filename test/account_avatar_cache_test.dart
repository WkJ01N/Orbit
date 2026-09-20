import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:orbit/services/account_avatar_cache.dart';

void main() {
  late Directory directory;

  Uint8List avatar(int red) {
    final value = image.Image(width: 8, height: 8, numChannels: 4)
      ..clear(image.ColorRgba8(red, 20, 30, 255));
    return Uint8List.fromList(image.encodePng(value));
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbit_avatar_cache_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('same avatar id survives cache recreation without a download', () async {
    var downloads = 0;
    final first = AccountAvatarCache(
      directoryProvider: () async => directory,
      downloader: (_) async {
        downloads++;
        return avatar(100);
      },
    );

    final initial = await first.load(
      uid: 'user-1',
      fileId: 'avatar-1',
      resolveUrl: (_) async => 'https://example.test/avatar.png',
    );
    expect(initial, isNotNull);
    expect(downloads, 1);

    var resolvedUrls = 0;
    final restored = AccountAvatarCache(
      directoryProvider: () async => directory,
      downloader: (_) async => throw StateError('must not download'),
    );
    final cached = await restored.load(
      uid: 'user-1',
      fileId: 'avatar-1',
      resolveUrl: (_) async {
        resolvedUrls++;
        return 'https://example.test/avatar.png';
      },
    );

    expect(cached, initial);
    expect(resolvedUrls, 0);
  });

  test('changed id downloads once and replaces the stored version', () async {
    var downloads = 0;
    final cache = AccountAvatarCache(
      directoryProvider: () async => directory,
      downloader: (uri) async {
        downloads++;
        return avatar(uri.path.endsWith('2') ? 200 : 100);
      },
    );

    await cache.load(
      uid: 'user-1',
      fileId: 'avatar-1',
      resolveUrl: (_) async => 'https://example.test/1',
    );
    final changed = await cache.load(
      uid: 'user-1',
      fileId: 'avatar-2',
      resolveUrl: (_) async => 'https://example.test/2',
    );
    final repeated = await cache.load(
      uid: 'user-1',
      fileId: 'avatar-2',
      resolveUrl: (_) async => 'https://example.test/2',
    );

    expect(downloads, 2);
    expect(repeated, changed);
  });

  test('failed replacement keeps the previous local avatar', () async {
    final cache = AccountAvatarCache(
      directoryProvider: () async => directory,
      downloader: (uri) async {
        if (uri.path.endsWith('2')) throw const SocketException('offline');
        return avatar(100);
      },
    );
    final initial = await cache.load(
      uid: 'user-1',
      fileId: 'avatar-1',
      resolveUrl: (_) async => 'https://example.test/1',
    );
    final fallback = await cache.load(
      uid: 'user-1',
      fileId: 'avatar-2',
      resolveUrl: (_) async => 'https://example.test/2',
    );

    expect(fallback, initial);
  });

  test(
    'accounts are isolated and clearing one leaves the other intact',
    () async {
      final cache = AccountAvatarCache(
        directoryProvider: () async => directory,
      );
      await cache.store(uid: 'user-1', fileId: 'avatar', bytes: avatar(100));
      await cache.store(uid: 'user-2', fileId: 'avatar', bytes: avatar(200));
      await cache.clearUser('user-1');

      final second = await cache.load(
        uid: 'user-2',
        fileId: 'avatar',
        resolveUrl: (_) async => throw StateError('must stay cached'),
      );
      expect(image.decodePng(second!)!.getPixel(0, 0).r, 200);
    },
  );

  test(
    'removing the remote avatar clears local data without resolving a url',
    () async {
      final cache = AccountAvatarCache(
        directoryProvider: () async => directory,
      );
      await cache.store(uid: 'user-1', fileId: 'avatar', bytes: avatar(100));
      var resolved = false;

      final removed = await cache.load(
        uid: 'user-1',
        fileId: null,
        resolveUrl: (_) async {
          resolved = true;
          return null;
        },
      );

      expect(removed, isNull);
      expect(resolved, isFalse);
      expect(await directory.list(recursive: true).toList(), isEmpty);
    },
  );
}
