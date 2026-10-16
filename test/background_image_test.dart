import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/background/background_image.dart';

class _FiniteCodec implements ui.Codec {
  _FiniteCodec(this.frameCount);
  bool disposed = false;
  @override
  final int frameCount;
  @override
  int get repetitionCount => 0;
  @override
  Future<ui.FrameInfo> getNextFrame() => throw UnimplementedError();
  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  test('GIF decoder sharing follows composition ownership', () {
    final file = File('same.gif');
    expect(
      LoopingBackgroundImage(file, identity: 'shared'),
      LoopingBackgroundImage(file, identity: 'shared'),
    );
    expect(
      LoopingBackgroundImage(file, identity: 'shared'),
      isNot(LoopingBackgroundImage(file, identity: 'independent')),
    );
  });
  test(
    'finite GIFs loop as wallpapers and disposal releases the underlying codec',
    () {
      final finite = _FiniteCodec(2);
      final looping = LoopingBackgroundCodec(finite);
      expect(looping.frameCount, 2);
      expect(looping.repetitionCount, -1);
      looping.dispose();
      expect(finite.disposed, isTrue);
      expect(LoopingBackgroundCodec(_FiniteCodec(1)).repetitionCount, 0);
    },
  );
}
