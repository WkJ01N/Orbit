import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:orbit/services/avatar_image_service.dart';

void main() {
  Uint8List source(int width, int height) {
    final value = image.Image(width: width, height: height, numChannels: 4)
      ..clear(image.ColorRgba8(20, 80, 160, 255));
    return Uint8List.fromList(image.encodePng(value));
  }

  test('preserve keeps aspect ratio and limits the longest side', () {
    final output = processAvatarImage(source(800, 400));
    final decoded = image.decodePng(output)!;

    expect(decoded.width, avatarMaximumDimension);
    expect(decoded.height, avatarMaximumDimension ~/ 2);
    expect(output.length, lessThanOrEqualTo(avatarMaximumBytes));
  });

  test('stretch produces a square without upscaling the longest side', () {
    final output = processAvatarImage(
      source(400, 200),
      transform: AvatarImageTransform.stretch,
    );
    final decoded = image.decodePng(output)!;

    expect(decoded.width, 400);
    expect(decoded.height, 400);
  });

  test('fill centers content on a transparent square', () {
    final output = processAvatarImage(
      source(400, 200),
      transform: AvatarImageTransform.fill,
    );
    final decoded = image.decodePng(output)!;

    expect(decoded.width, 400);
    expect(decoded.height, 400);
    expect(decoded.getPixel(0, 0).a, 0);
    expect(decoded.getPixel(200, 200).a, 255);
  });
}
