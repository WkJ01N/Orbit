import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as image;
import 'package:orbit/features/settings/avatar_crop_dialog.dart';

void main() {
  Uint8List sampleImage({int width = 80, int height = 40}) {
    final value = image.Image(width: width, height: height, numChannels: 4)
      ..clear(image.ColorRgba8(30, 90, 150, 255));
    return Uint8List.fromList(image.encodePng(value));
  }

  Future<void> openDialog(
    WidgetTester tester,
    Size size, {
    Uint8List? source,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () =>
                  showAvatarCropDialog(context, source ?? sampleImage()),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  Future<void> waitForCropControls(WidgetTester tester) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final tile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile).first,
      );
      if (tile.onChanged != null) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    fail('Crop controls did not become ready');
  }

  void expectHandlesVisible(WidgetTester tester, Size window) {
    final crop = tester.getRect(find.byType(Crop));
    final handles = find.descendant(
      of: find.byType(Crop),
      matching: find.byType(DotControl),
    );
    expect(handles, findsNWidgets(4));
    for (final handle in handles.evaluate()) {
      final rect = tester.getRect(
        find.byElementPredicate((element) => element == handle),
      );
      expect(rect.left, greaterThanOrEqualTo(crop.left - 16.01));
      expect(rect.top, greaterThanOrEqualTo(crop.top - 16.01));
      expect(rect.right, lessThanOrEqualTo(crop.right + 16.01));
      expect(rect.bottom, lessThanOrEqualTo(crop.bottom + 16.01));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(window.width));
      expect(rect.bottom, lessThanOrEqualTo(window.height));
    }
  }

  testWidgets(
    'mobile crop controls fit and square modes are mutually exclusive',
    (tester) async {
      await openDialog(tester, const Size(320, 640));

      expect(find.text('Square crop'), findsOneWidget);
      expect(find.text('Stretch'), findsNothing);
      expect(find.text('Fill'), findsNothing);
      expect(tester.takeException(), isNull);

      await waitForCropControls(tester);
      await tester.tap(find.text('Square crop'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Stretch'), findsOneWidget);
      expect(find.text('Fill'), findsOneWidget);

      await waitForCropControls(tester);
      await tester.tap(find.text('Stretch'));
      await tester.pump();
      var switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches[1].value, isTrue);
      expect(switches[2].value, isFalse);

      await tester.ensureVisible(find.text('Fill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fill'));
      await tester.pump();
      switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches[1].value, isFalse);
      expect(switches[2].value, isTrue);
      final handles = find.descendant(
        of: find.byType(Crop),
        matching: find.byType(DotControl),
      );
      await tester.drag(handles.last, const Offset(800, 800));
      await tester.pump();
      expectHandlesVisible(tester, const Size(320, 640));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop crop dialog remains bounded', (tester) async {
    await openDialog(tester, const Size(1200, 900));

    final panel = find.byKey(const Key('avatar-crop-desktop-panel'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, lessThanOrEqualTo(720));
    expect(tester.getSize(panel).height, lessThanOrEqualTo(712));
    expect(tester.takeException(), isNull);
  });

  testWidgets('crop viewport stays within a short mobile window', (
    tester,
  ) async {
    await openDialog(
      tester,
      const Size(320, 480),
      source: sampleImage(width: 40, height: 160),
    );
    final crop = tester.getRect(find.byType(Crop));
    expect(crop.left, greaterThanOrEqualTo(0));
    expect(crop.right, lessThanOrEqualTo(320));
    expect(crop.top, greaterThanOrEqualTo(0));
    expect(crop.bottom, lessThanOrEqualTo(480));
    expect(find.text('Use image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crop viewport remains bounded after resizing the window', (
    tester,
  ) async {
    await openDialog(
      tester,
      const Size(1200, 900),
      source: sampleImage(width: 160, height: 40),
    );
    await waitForCropControls(tester);
    final handles = find.descendant(
      of: find.byType(Crop),
      matching: find.byType(DotControl),
    );
    await tester.drag(handles.last, const Offset(1000, 1000));
    await tester.pump();
    expectHandlesVisible(tester, const Size(1200, 900));
    tester.view.physicalSize = const Size(640, 420);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await waitForCropControls(tester);
    final crop = tester.getRect(find.byType(Crop));
    expect(crop.right, lessThanOrEqualTo(640));
    expect(crop.bottom, lessThanOrEqualTo(420));
    expectHandlesVisible(tester, const Size(640, 420));
    expect(tester.takeException(), isNull);
  });

  for (final source in [(width: 160, height: 40), (width: 40, height: 160)]) {
    testWidgets('dragging crop handles cannot leave a 320px window: $source', (
      tester,
    ) async {
      const window = Size(320, 480);
      await openDialog(
        tester,
        window,
        source: sampleImage(width: source.width, height: source.height),
      );
      await waitForCropControls(tester);
      expectHandlesVisible(tester, window);

      final handles = find.descendant(
        of: find.byType(Crop),
        matching: find.byType(DotControl),
      );
      await tester.drag(handles.first, const Offset(-800, -800));
      await tester.pump();
      expectHandlesVisible(tester, window);
      await tester.drag(handles.last, const Offset(800, 800));
      await tester.pump();
      expectHandlesVisible(tester, window);

      final topLeft = tester.getCenter(handles.first);
      final bottomRight = tester.getCenter(handles.last);
      final selectionCenter = Offset(
        (topLeft.dx + bottomRight.dx) / 2,
        (topLeft.dy + bottomRight.dy) / 2,
      );
      await tester.dragFrom(selectionCenter, const Offset(800, -800));
      await tester.pump();
      expectHandlesVisible(tester, window);
      expect(tester.takeException(), isNull);
    });
  }
}
