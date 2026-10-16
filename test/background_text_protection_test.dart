import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/models/background_settings.dart';

void main() {
  testWidgets(
    'text protection is region scoped, fades with dimming and does not enter dialogs',
    (tester) async {
      final asset = BackgroundAsset(
        id: 'a' * 64,
        name: 'image.png',
        kind: BackgroundMediaKind.image,
        width: 100,
        height: 100,
      );
      Widget app(
        double dim, {
        bool protect = true,
        Brightness brightness = Brightness.light,
      }) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: BackgroundPageTheme(
          owner: BackgroundPage.grid,
          settings: BackgroundSettings(
            enabled: true,
            assets: {asset.id: asset},
            pages: {
              BackgroundPage.grid: PageBackgroundSettings(
                assetId: asset.id,
                regions: {BackgroundRegionId.header},
                framing: BackgroundFraming(dim: dim),
                autoTextProtection: protect,
              ),
            },
          ),
          child: Scaffold(
            body: Column(
              children: [
                BackgroundRegion(
                  region: BackgroundRegionId.header,
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: Text(
                            'dialog',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      child: Text(
                        'header',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
                BackgroundRegion(
                  region: BackgroundRegionId.content,
                  child: Builder(
                    builder: (context) => Text(
                      'content',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(0));
      expect(
        tester.widget<Text>(find.text('header')).style!.shadows,
        isNotEmpty,
      );
      expect(tester.widget<Text>(find.text('content')).style!.shadows, isNull);
      await tester.tap(find.text('header'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('dialog')).style!.shadows, isNull);
      Navigator.of(tester.element(find.text('dialog'))).pop();
      await tester.pumpAndSettle();
      final lightShadow = tester
          .widget<Text>(find.text('header'))
          .style!
          .shadows!
          .last;
      expect(lightShadow.color.r, 1);
      await tester.pumpWidget(app(.2));
      expect(
        tester.widget<Text>(find.text('header')).style!.shadows!.last.color.a,
        lessThan(lightShadow.color.a),
      );
      await tester.pumpWidget(app(0, brightness: Brightness.dark));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('header')).style!.shadows!.last.color.r,
        0,
      );
      await tester.pumpWidget(app(.9));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('header')).style!.shadows, isNull);
      await tester.pumpWidget(app(.3));
      expect(tester.widget<Text>(find.text('header')).style!.shadows, isNull);
      await tester.pumpWidget(app(0, protect: false));
      expect(tester.widget<Text>(find.text('header')).style!.shadows, isNull);
    },
  );
}
