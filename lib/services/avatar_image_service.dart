import 'dart:typed_data';

import 'package:image/image.dart' as image;

enum AvatarImageTransform { preserve, stretch, fill }

const int avatarMaximumDimension = 512;
const int avatarMaximumBytes = 2 * 1024 * 1024;

Uint8List processAvatarImage(
  Uint8List source, {
  AvatarImageTransform transform = AvatarImageTransform.preserve,
}) {
  final decoded = image.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('avatar_decode_failed');
  }

  var result = image.bakeOrientation(decoded);
  switch (transform) {
    case AvatarImageTransform.preserve:
      result = _limitLongestSide(result);
    case AvatarImageTransform.stretch:
      final side = _limitedSide(result.width, result.height);
      result = image.copyResize(
        result,
        width: side,
        height: side,
        interpolation: image.Interpolation.linear,
      );
    case AvatarImageTransform.fill:
      final side = result.width > result.height ? result.width : result.height;
      final canvas = image.Image(width: side, height: side, numChannels: 4)
        ..clear(image.ColorRgba8(0, 0, 0, 0));
      image.compositeImage(canvas, result, center: true);
      result = _limitLongestSide(canvas);
  }

  final encoded = Uint8List.fromList(image.encodePng(result));
  if (encoded.length > avatarMaximumBytes) {
    throw const FormatException('avatar_too_large');
  }
  return encoded;
}

image.Image _limitLongestSide(image.Image source) {
  final longest = source.width > source.height ? source.width : source.height;
  if (longest <= avatarMaximumDimension) return source;
  if (source.width >= source.height) {
    return image.copyResize(
      source,
      width: avatarMaximumDimension,
      interpolation: image.Interpolation.linear,
    );
  }
  return image.copyResize(
    source,
    height: avatarMaximumDimension,
    interpolation: image.Interpolation.linear,
  );
}

int _limitedSide(int width, int height) {
  final side = width > height ? width : height;
  return side > avatarMaximumDimension ? avatarMaximumDimension : side;
}
