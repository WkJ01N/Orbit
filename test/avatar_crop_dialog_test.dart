import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:orbit/features/settings/avatar_crop_dialog.dart';

void main() {
  Uint8List sampleImage() {
    final value = image.Image(width: 80, height: 40, numChannels: 4)
      ..clear(image.ColorRgba8(30, 90, 150, 255));
    return Uint8List.fromList(image.encodePng(value));
  }

  Future<void> openDialog(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showAvatarCropDialog(context, sampleImage()),
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

      await tester.tap(find.text('Fill'));
      await tester.pump();
      switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches[1].value, isFalse);
      expect(switches[2].value, isTrue);
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
}
