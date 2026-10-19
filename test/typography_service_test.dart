import 'package:orbit/services/component_service.dart';
import 'support/font_components.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/typography_settings.dart';
import 'package:orbit/providers/typography_providers.dart';
import 'package:orbit/services/font_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/settings_sync_codec.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FontService fonts;
  late Uint8List ttf, otf;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('orbit-fonts-');
    fonts = FontService(directory: root, register: (_, _) async {});
    ttf = await File('assets/fonts/Nunito.ttf').readAsBytes();
    otf = await File('test/fixtures/typography/tiny.otf').readAsBytes();
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'native font loader accepts the three bundled families and variable/CFF imports',
    () async {
      final native = FontService(
        directory: root,
        components: await installedFontComponents(
          Directory('${root.path}/components'),
        ),
      );
      for (final id in ['rounded', 'huninn', 'maiyuan']) {
        await native.load(id, const {});
      }
      await native.importBytes('variable.ttf', ttf);
      await native.importBytes('cff.otf', otf);
    },
  );

  test(
    'restore failure rolls back new fonts and preserves preferences',
    () async {
      final first = (await fonts.importBytes('first.ttf', ttf)).font;
      final second = (await fonts.importBytes('second.otf', otf)).font;
      await fonts.save(
        TypographySettings(
          appFontId: first.id,
          launchFontId: second.id,
          imports: {first.id: first, second.id: second},
        ),
      );
      final encoder = ScheduleBackupService(fonts: fonts);
      final backup = encoder.decodeBackup(
        await encoder.encodeWithAudio(
          [],
          await SettingsService().exportPortableSettings(),
        ),
      );
      final before = (await SharedPreferences.getInstance()).getString(
        FontService.preferenceKey,
      );
      final targetDirectory = Directory('${root.path}/target');
      final target = FontService(
        directory: targetDirectory,
        register: (_, bytes) async {
          if (ByteData.sublistView(bytes.single).getUint32(0) == 0x4f54544f) {
            throw StateError('CFF registration failed');
          }
        },
      );
      await expectLater(
        ScheduleBackupService(fonts: target).restoreAudio(backup),
        throwsStateError,
      );
      expect(await targetDirectory.list().length, 0);
      expect(
        (await SharedPreferences.getInstance()).getString(
          FontService.preferenceKey,
        ),
        before,
      );
    },
  );

  test(
    'all bundled faces, a variable TTF and real CFF OTF are valid',
    () async {
      for (final asset in FontCatalog.builtins.values.expand((v) => v)) {
        FontService.validate(
          await File(
            asset.contains('Nunito')
                ? asset
                : asset.replaceFirst('assets/fonts/', 'resources/fonts/'),
          ).readAsBytes(),
        );
      }
      final imported = await fonts.importBytes('中文字体.TTF', ttf);
      final cff = await fonts.importBytes('test.otf', otf);
      expect(imported.font.extension, 'ttf');
      expect(cff.font.extension, 'otf');
    },
  );

  test(
    'rejects collections, broken tables, fake font and oversized data before writing',
    () async {
      final invalid = Uint8List.fromList(ttf);
      ByteData.sublistView(invalid).setUint32(20, invalid.length + 100);
      for (final bytes in [
        Uint8List(20),
        invalid,
        Uint8List(FontService.maxFileBytes + 1),
      ]) {
        await expectLater(
          fonts.importBytes('invalid.ttf', bytes),
          throwsFormatException,
        );
      }
      await expectLater(
        fonts.importBytes('collection.ttc', ttf),
        throwsFormatException,
      );
      expect(await root.list().length, 0);
    },
  );

  test(
    'hash deduplication retains one private file with safe storage name',
    () async {
      final first = await fonts.importBytes('../课程字体.ttf', ttf);
      final second = await fonts.importBytes('another.otf', ttf);
      expect(first.font.id, second.font.id);
      expect(first.created, isTrue);
      expect(second.created, isFalse);
      expect(await root.list().length, 1);
      expect((await fonts.file(first.font)).parent.path, root.path);
    },
  );

  test(
    'registration failure removes only newly created file and leaves settings unchanged',
    () async {
      final failed = FontService(
        directory: root,
        register: (_, _) async => throw StateError('rejected'),
      );
      await expectLater(failed.importBytes('bad.ttf', ttf), throwsStateError);
      expect(await root.list().length, 0);
      expect((await failed.read()).appFontId, 'system');
    },
  );

  test(
    'independent choices persist, cache loaded faces, rename and delete reset affected choices',
    () async {
      final imported = (await fonts.importBytes('custom.ttf', ttf)).font;
      final initial = TypographySettings(imports: {imported.id: imported});
      final container = ProviderContainer(
        overrides: [
          fontServiceProvider.overrideWithValue(fonts),
          typographySnapshotProvider.overrideWithValue(initial),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(typographySettingsProvider.notifier);
      await notifier.update((s) => s.copyWith(appFontId: imported.id));
      expect(container.read(typographySettingsProvider).launchFontId, 'nunito');
      await notifier.update((s) => s.copyWith(launchFontId: 'system'));
      expect((await fonts.read()).appFontId, imported.id);
      expect((await fonts.read()).launchFontId, 'system');
      await notifier.update(
        (s) => s.copyWith(
          imports: {
            imported.id: ImportedFont(
              id: imported.id,
              name: 'Renamed',
              extension: 'ttf',
            ),
          },
        ),
      );
      expect((await fonts.read()).imports[imported.id]!.name, 'Renamed');
      await notifier.remove(imported.id);
      expect((await fonts.read()).appFontId, 'system');
      expect((await fonts.read()).launchFontId, 'system');
      expect(await (await fonts.file(imported)).exists(), isFalse);
    },
  );

  test(
    'missing font recovers per scope and reports warning without changing saved choice',
    () async {
      final imported = (await fonts.importBytes('custom.ttf', ttf)).font;
      final settings = TypographySettings(
        appFontId: imported.id,
        launchFontId: imported.id,
        imports: {imported.id: imported},
      );
      await fonts.save(settings);
      await fonts.deleteFile(imported);
      final restarted = FontService(directory: root, register: (_, _) async {});
      final recovered = await restarted.initialize();
      expect(recovered.appFontId, imported.id);
      expect(recovered.launchFontId, imported.id);
      expect(recovered.effectiveAppFontId, 'system');
      expect(recovered.effectiveLaunchFontId, 'nunito');
      expect(recovered.loadWarning, isTrue);
      expect((await fonts.read()).appFontId, imported.id);
    },
  );

  test(
    'full backup deduplicates selected font, excludes unused files and restores to another directory',
    () async {
      final selected = (await fonts.importBytes('custom.ttf', ttf)).font;
      final unused = (await fonts.importBytes('unused.otf', otf)).font;
      final settings = TypographySettings(
        appFontId: selected.id,
        launchFontId: selected.id,
        imports: {selected.id: selected, unused.id: unused},
      );
      await fonts.save(settings);
      final portable = await SettingsService().exportPortableSettings();
      final encoder = ScheduleBackupService(fonts: fonts);
      final json = await encoder.encodeWithAudio([], portable);
      final backup = encoder.decodeBackup(json);
      expect(backup.version, ScheduleBackupService.backupVersion);
      expect(backup.fonts.keys.toList(), [selected.id]);
      expect(backup.settings!.typography!.imports.keys.toList(), [selected.id]);
      expect(json, isNot(contains(root.path.replaceAll(r'\', r'\\'))));
      final target = FontService(
        directory: Directory('${root.path}/restored'),
        register: (_, _) async {},
      );
      final restored = await ScheduleBackupService(
        fonts: target,
      ).restoreAudio(backup);
      expect(restored.importedFonts, hasLength(1));
      expect(await (await target.file(selected)).readAsBytes(), ttf);
      expect(restored.settings.typography!.launchFontId, selected.id);
      expect(
        SettingsSyncCodec.groups(portable)['appearance'],
        isNot(contains('typography')),
      );
    },
  );

  test(
    'corrupt or absent font payload is rejected before restoring data',
    () async {
      final font = (await fonts.importBytes('custom.ttf', ttf)).font;
      await fonts.save(
        TypographySettings(appFontId: font.id, imports: {font.id: font}),
      );
      final service = ScheduleBackupService(fonts: fonts);
      final raw = await service.encodeWithAudio(
        [],
        await SettingsService().exportPortableSettings(),
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      (json['fonts'][font.id] as Map)['data'] = base64Encode(otf);
      expect(
        () => service.decodeBackup(jsonEncode(json)),
        throwsA(isA<ScheduleBackupException>()),
      );
      json['fonts'] = {};
      expect(
        () => service.decodeBackup(jsonEncode(json)),
        throwsA(isA<ScheduleBackupException>()),
      );
    },
  );

  test(
    'v1-v10 backups without typography do not replace local font choices',
    () async {
      await fonts.save(const TypographySettings(launchFontId: 'system'));
      final old = (await SettingsService().exportPortableSettings()).toJson()
        ..remove('typography');
      final service = ScheduleBackupService(fonts: fonts);
      for (var version = 1; version <= 10; version++) {
        final backup = service.decodeBackup(
          jsonEncode({'version': version, 'sessions': [], 'settings': old}),
        );
        await SettingsService().importPortableSettings(backup.settings!);
        expect((await fonts.read()).launchFontId, 'system');
      }
    },
  );
  test(
    'v12 carries an installed font component and restores without downloading',
    () async {
      final components = await installedFontComponents(
        Directory('${root.path}/source-components'),
        ids: ['huninn'],
      );
      final source = FontService(
        directory: Directory('${root.path}/source-fonts'),
        components: components,
        register: (_, _) async {},
      );
      await source.save(const TypographySettings(appFontId: 'huninn'));
      final service = ScheduleBackupService(fonts: source);
      final encoded = await service.encodeWithAudio(
        [],
        await SettingsService().exportPortableSettings(),
      );
      final backup = service.decodeBackup(encoded);
      expect(backup.version, ScheduleBackupService.backupVersion);
      expect(backup.fontComponents['huninn']!['version'], 1);
      final targetComponents = ComponentService(
        directory: Directory('${root.path}/target-components'),
        catalog: await components.descriptors(),
      );
      final target = FontService(
        directory: Directory('${root.path}/target-fonts'),
        components: targetComponents,
        register: (_, _) async {},
      );
      final result = await ScheduleBackupService(
        fonts: target,
      ).restoreAudio(backup);
      expect(result.importedComponents, ['huninn']);
      final effective = await target.prepare(result.settings.typography!);
      expect(effective.effectiveAppFontId, 'huninn');
      final damaged = jsonDecode(encoded) as Map<String, dynamic>;
      final files = damaged['fontComponents']['huninn']['files'] as Map;
      final bytes = base64Decode(files['Huninn.ttf'] as String);
      bytes[bytes.length - 1] ^= 1;
      files['Huninn.ttf'] = base64Encode(bytes);
      final bad = service.decodeBackup(jsonEncode(damaged));
      await expectLater(
        ScheduleBackupService(fonts: target).restoreAudio(bad),
        throwsFormatException,
      );
      expect(
        targetComponents.ready('huninn'),
        isTrue,
        reason: 'A failed restore keeps an already installed component',
      );
      components.dispose();
      targetComponents.dispose();
    },
  );

  test(
    'downgrade protection preserves unused imported fonts and local launch settings',
    () async {
      final first = (await fonts.importBytes('first.ttf', ttf)).font;
      final unused = (await fonts.importBytes('unused.otf', otf)).font;
      await fonts.save(
        TypographySettings(
          appFontId: first.id,
          imports: {first.id: first, unused.id: unused},
        ),
      );
      await SettingsService().saveLocalJson('launch_presentation_v1', {
        'cardEntrance': 'nearby',
        'pageTransitionStyle': 'fluid',
        'pageTransitionSpeed': 'fast',
      });
      final service = ScheduleBackupService(fonts: fonts);
      final encoded = await service.encodeWithAudio(
        [],
        await SettingsService().exportPortableSettings(),
        protectLocalResources: true,
      );
      final backup = service.decodeBackup(encoded);
      expect(backup.fonts, hasLength(2));
      expect(backup.settings!.typography!.imports, hasLength(2));
      expect(backup.localPresentation!['cardEntrance'], 'nearby');
      expect(backup.localPresentation!['pageTransitionStyle'], 'fluid');
      expect(backup.localPresentation!['pageTransitionSpeed'], 'fast');
      final target = FontService(
        directory: Directory('${root.path}/protected-restore'),
        register: (_, _) async {},
      );
      final restored = await ScheduleBackupService(
        fonts: target,
      ).restoreAudio(backup);
      expect(restored.importedFonts, hasLength(2));
      expect(restored.launchPresentation!['cardEntrance'], 'nearby');
      expect(restored.settings.typography!.imports.keys, contains(unused.id));
    },
  );
}
