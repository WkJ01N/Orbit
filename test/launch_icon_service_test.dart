import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:orbit/services/launch_icon_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'orbit-launch-icon-test-',
    );
  });
  tearDown(() async {
    final temp = p.normalize(p.absolute(Directory.systemTemp.path));
    final target = p.normalize(p.absolute(directory.path));
    expect(p.isWithin(temp, target), isTrue);
    await directory.delete(recursive: true);
  });

  Uint8List source() => Uint8List.fromList(
    image.encodePng(
      image.Image(width: 1024, height: 768, numChannels: 4)
        ..clear(image.ColorRgba8(25, 180, 160, 180)),
    ),
  );

  test(
    'managed images are normalized PNGs and replacements have independent files',
    () async {
      final first = await saveLaunchIcon(source(), supportDirectory: directory);
      final second = await saveLaunchIcon(
        source(),
        supportDirectory: directory,
      );
      expect(first, isNot(second));
      final decoded = image.decodePng(await File(first).readAsBytes())!;
      expect(decoded.width, 512);
      expect(decoded.height, 384);
      expect(decoded.getPixel(0, 0).a, 180);
      await deleteLaunchIcon(second, supportDirectory: directory);
      expect(await File(second).exists(), isFalse);
      expect(await File(first).exists(), isTrue);
    },
  );

  test('a bad replacement leaves the previous image intact', () async {
    final previous = await saveLaunchIcon(
      source(),
      supportDirectory: directory,
    );
    await expectLater(
      saveLaunchIcon(
        Uint8List.fromList([1, 2, 3]),
        supportDirectory: directory,
      ),
      throwsA(anything),
    );
    expect(await File(previous).exists(), isTrue);
    expect(await Directory(p.dirname(previous)).list().length, 1);
  });

  test('cleanup ignores paths outside managed icon storage', () async {
    final external = await File(
      p.join(directory.path, 'source.png'),
    ).writeAsBytes(source());
    await deleteLaunchIcon(external.path, supportDirectory: directory);
    expect(await external.exists(), isTrue);
    await deleteLaunchIcon(null, supportDirectory: directory);
    await deleteLaunchIcon(
      p.join(directory.path, 'launch_icons', 'missing.png'),
      supportDirectory: directory,
    );
  });
}
