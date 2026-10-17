import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:orbit/features/settings/typography_settings_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/typography_settings.dart';
import 'package:orbit/providers/typography_providers.dart';
import 'package:orbit/services/font_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    for (final width in [320.0, 1100.0]) {
      testWidgets('font management fits $locale at $width and large text', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer(
          overrides: [
            typographySnapshotProvider.overrideWithValue(
              const TypographySettings(),
            ),
            fontServiceProvider.overrideWithValue(
              FontService(register: (_, _) async {}),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.8)),
                child: child!,
              ),
              home: const TypographySettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('app-font-choice')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('font-option-maiyuan')),
          250,
        );
        await tester.tap(find.byKey(const Key('font-option-maiyuan')));
        await tester.pumpAndSettle();
        expect(container.read(typographySettingsProvider).appFontId, 'system');
        await tester.scrollUntilVisible(
          find.byKey(const Key('apply-font')),
          -250,
        );
        await tester.tap(find.byKey(const Key('apply-font')));
        await tester.pumpAndSettle();
        expect(container.read(typographySettingsProvider).appFontId, 'maiyuan');
        expect(
          container.read(typographySettingsProvider).launchFontId,
          'nunito',
        );
        await tester.ensureVisible(find.byKey(const Key('launch-font-choice')));
        await tester.tap(find.byKey(const Key('launch-font-choice')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('font-option-nunito')),
          250,
        );
        expect(find.byKey(const Key('font-option-nunito')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test(
    'Android splash artwork has transparent circular edges and safe padding',
    () async {
      final image = img.decodePng(
        await File(
          'android/app/src/main/res/drawable-xxxhdpi/orbit_splash_icon.png',
        ).readAsBytes(),
      )!;
      expect(image.width, image.height);
      expect(image.getPixel(0, 0).a, 0);
      expect(image.getPixel(96, 96).a, 0);
      expect(image.getPixel(image.width ~/ 2, image.height ~/ 2).a, 255);
      for (final directory in ['values-v31', 'values-night-v31']) {
        final theme = await File(
          'android/app/src/main/res/$directory/styles.xml',
        ).readAsString();
        expect(theme, contains('@drawable/orbit_splash_icon'));
        expect(theme, isNot(contains('@mipmap/ic_launcher')));
      }
    },
  );
}
