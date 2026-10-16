import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

/// Retains Flutter's image-cache/frame sharing, including the blurred fill.
class LoopingBackgroundImage extends FileImage {
  const LoopingBackgroundImage(super.file, {required this.identity});
  final String identity;
  @override
  bool operator ==(Object other) =>
      other is LoopingBackgroundImage &&
      other.identity == identity &&
      super == other;
  @override
  int get hashCode => Object.hash(super.hashCode, identity);
  @override
  ImageStreamCompleter loadImage(FileImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _decode(key, decode),
        scale: key.scale,
        debugLabel: key.file.path,
      );
  Future<ui.Codec> _decode(FileImage key, ImageDecoderCallback decode) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(key.file.path);
      return LoopingBackgroundCodec(await decode(buffer));
    } catch (_) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }
}

class LoopingBackgroundCodec implements ui.Codec {
  LoopingBackgroundCodec(this.codec);
  final ui.Codec codec;
  @override
  int get frameCount => codec.frameCount;
  @override
  int get repetitionCount => frameCount > 1 ? -1 : 0;
  @override
  Future<ui.FrameInfo> getNextFrame() => codec.getNextFrame();
  @override
  void dispose() => codec.dispose();
}
