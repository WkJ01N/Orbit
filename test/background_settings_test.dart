import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/settings_sync_codec.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final asset = BackgroundAsset(
  id: 'a' * 64,
  name: 'wallpaper.png',
  kind: BackgroundMediaKind.image,
  width: 1200,
  height: 800,
);
BackgroundSettings sample() => BackgroundSettings(
  enabled: true,
  assets: {asset.id: asset},
  pages: {
    BackgroundPage.grid: PageBackgroundSettings(
      assetId: asset.id,
      framing: const BackgroundFraming(zoom: 2, x: .1),
    ),
    BackgroundPage.upcoming: const PageBackgroundSettings(followGrid: true),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'cover stays covered for varied viewports, aspects and extreme offsets',
    () {
      final random = Random(37);
      for (var i = 0; i < 1000; i++) {
        final viewport = Size(
          100 + random.nextDouble() * 1600,
          100 + random.nextDouble() * 1600,
        );
        final media = Size(
          1 + random.nextDouble() * 5000,
          1 + random.nextDouble() * 5000,
        );
        final frame = BackgroundFraming(
          zoom: random.nextDouble() * 12,
          x: random.nextDouble() * 200 - 100,
          y: random.nextDouble() * 200 - 100,
        );
        final rect = backgroundRect(viewport, media, frame);
        expect(rect.left, lessThanOrEqualTo(.00001));
        expect(rect.top, lessThanOrEqualTo(.00001));
        expect(rect.right + .00001, greaterThanOrEqualTo(viewport.width));
        expect(rect.bottom + .00001, greaterThanOrEqualTo(viewport.height));
        final exposed = backgroundRect(
          viewport,
          media,
          frame.copyWith(allowEdges: true, zoom: .1),
        );
        expect(exposed.overlaps(Offset.zero & viewport), isTrue);
      }
    },
  );

  test(
    'shared framing updates together, detachment captures crop and retains source',
    () {
      var settings = sample();
      expect(
        settings.continuityKey(BackgroundPage.upcoming),
        settings.continuityKey(BackgroundPage.grid),
      );
      final protected = settings.setFraming(
        BackgroundPage.upcoming,
        const BackgroundFraming(zoom: 8),
      );
      expect(protected.page(BackgroundPage.grid).framing.zoom, 2);
      settings = settings.setFraming(
        BackgroundPage.grid,
        const BackgroundFraming(zoom: 3, dim: .9, blur: .5),
      );
      expect(settings.page(BackgroundPage.grid).framing.zoom, 3);
      settings = settings.detach(BackgroundPage.upcoming);
      settings = settings.updatePage(
        BackgroundPage.grid,
        const PageBackgroundSettings(),
      );
      expect(settings.resolved(BackgroundPage.upcoming).assetId, asset.id);
      expect(settings.resolved(BackgroundPage.upcoming).framing.zoom, 3);
      expect(
        settings.continuityKey(BackgroundPage.upcoming),
        isNot(settings.continuityKey(BackgroundPage.grid)),
      );
      expect(
        BackgroundSettings.fromJson(
          jsonDecode(jsonEncode(settings.toJson())),
        ).toJson(),
        settings.toJson(),
      );
    },
  );

  test(
    'following resolves only header and navigation, then detaches without visual change',
    () {
      var settings = sample()
          .updatePage(
            BackgroundPage.grid,
            sample()
                .page(BackgroundPage.grid)
                .copyWith(
                  regions: {
                    BackgroundRegionId.header,
                    BackgroundRegionId.content,
                  },
                  framing: const BackgroundFraming(dim: .9, blur: .7),
                ),
          )
          .updatePage(
            BackgroundPage.settings,
            const PageBackgroundSettings(
              followGrid: true,
              regions: {
                BackgroundRegionId.navigation,
                BackgroundRegionId.categories,
              },
              surfaceOpacity: .4,
              autoTextProtection: false,
            ),
          );
      final effective = settings.resolved(BackgroundPage.settings);
      expect(effective.regions, {
        BackgroundRegionId.header,
        BackgroundRegionId.categories,
      });
      expect(effective.framing.blur, .7);
      expect(effective.framing.dim, .9);
      expect(effective.surfaceOpacity, .4);
      expect(effective.autoTextProtection, false);
      settings = settings.detach(BackgroundPage.settings);
      expect(
        settings.resolved(BackgroundPage.settings).toJson(),
        effective.copyWith(followGrid: false).toJson(),
      );
      settings = settings.setFraming(
        BackgroundPage.grid,
        const BackgroundFraming(),
      );
      expect(settings.resolved(BackgroundPage.settings).framing.blur, .7);
      final restored = BackgroundSettings.fromJson(settings.toJson());
      expect(restored.toJson(), settings.toJson());
      expect(BackgroundFraming.fromJson({}).blur, 0);
      expect(PageBackgroundSettings.fromJson({}).autoTextProtection, true);
    },
  );

  test('non-finite framing is normalized and managed paths cannot escape', () {
    final frame = BackgroundFraming.fromJson({
      'zoom': double.nan,
      'x': double.infinity,
      'dim': 10,
    });
    expect(frame.zoom, 1);
    expect(frame.x, 0);
    expect(frame.dim, .9);
    expect(
      () => BackgroundAsset.fromJson({...asset.toJson(), 'id': '../escape'}),
      throwsFormatException,
    );
    expect(
      () =>
          BackgroundAsset.fromJson({...asset.toJson(), 'extension': '../png'}),
      throwsFormatException,
    );
  });

  test(
    'v10 JSON preserves backgrounds; legacy imports leave local backgrounds intact; cloud excludes them',
    () async {
      final service = SettingsService();
      await service.saveBackgroundSettings(sample());
      final portable = await service.exportPortableSettings();
      final backupService = ScheduleBackupService();
      final json = backupService.encodeToJson([], settings: portable);
      expect(backupService.decodeBackup(json).version, 10);
      expect(
        backupService.decodeBackup(json).settings!.backgrounds!.toJson(),
        sample().toJson(),
      );
      final legacy = jsonDecode(json) as Map<String, dynamic>;
      (legacy['settings'] as Map).remove('backgrounds');
      for (var version = 1; version <= 9; version++) {
        legacy['version'] = version;
        final imported = backupService.decodeBackup(jsonEncode(legacy));
        await service.importPortableSettings(imported.settings!);
        expect(
          (await service.loadBackgroundSettings()).toJson(),
          sample().toJson(),
        );
      }
      expect(
        jsonEncode(SettingsSyncCodec.groups(portable)),
        isNot(contains('backgrounds')),
      );
      expect(
        jsonEncode(SettingsSyncCodec.groups(portable)),
        isNot(contains(asset.id)),
      );
      expect(json, isNot(contains('E:\\')));
    },
  );
}
