import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/typography_settings.dart';
import 'package:orbit/services/app_update_service.dart';
import 'package:orbit/services/component_service.dart';
import 'package:orbit/services/font_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/font_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('orbit-components-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  ({ComponentDescriptor descriptor, List<int> bytes}) pack({
    String entry = 'font.ttf',
  }) {
    final data = utf8.encode('test font data');
    final zip = Archive()..addFile(ArchiveFile(entry, data.length, data));
    final bytes = ZipEncoder().encode(zip)!;
    final descriptor = ComponentDescriptor.fromJson({
      'id': 'rounded',
      'name': 'Rounded',
      'version': 1,
      'platform': 'any',
      'abi': null,
      'entrypoint': null,
      'url':
          'https://github.com/WkJ01N/Orbit/releases/download/v1.6.1/font.orbitpack',
      'size': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'files': {
        'font.ttf': {
          'size': data.length,
          'sha256': sha256.convert(data).toString(),
        },
      },
    });
    return (descriptor: descriptor, bytes: bytes);
  }

  test(
    'verified archives install atomically and reject traversal without replacing valid files',
    () async {
      final good = pack();
      final service = ComponentService(
        directory: root,
        catalog: [good.descriptor],
      );
      final file = await File(
        '${root.path}/input.orbitpack',
      ).writeAsBytes(good.bytes);
      await service.installArchive(good.descriptor, file);
      expect(service.ready('rounded'), isTrue);
      final folder = await service.installed('rounded');
      expect(
        await File('${folder.path}/font.ttf').readAsString(),
        'test font data',
      );
      final unsafe = pack(entry: '../font.ttf');
      final bad = await File(
        '${root.path}/unsafe.orbitpack',
      ).writeAsBytes(unsafe.bytes);
      await expectLater(
        service.installArchive(unsafe.descriptor, bad),
        throwsFormatException,
      );
      expect(
        await File('${folder.path}/font.ttf').readAsString(),
        'test font data',
      );
      expect(await File('${root.parent.path}/font.ttf').exists(), isFalse);
      service.dispose();
    },
  );
  test(
    'wrong digest and cancelled installs leave no ready component',
    () async {
      final value = pack();
      final service = ComponentService(
        directory: root,
        catalog: [value.descriptor],
      );
      final file = await File(
        '${root.path}/input.orbitpack',
      ).writeAsBytes([...value.bytes, 0]);
      await expectLater(
        service.installArchive(value.descriptor, file),
        throwsFormatException,
      );
      await file.writeAsBytes(value.bytes);
      final operation = UpdateOperation()..cancel();
      await expectLater(
        service.installArchive(value.descriptor, file, operation: operation),
        throwsA(isA<UpdateCancelled>()),
      );
      expect(service.ready('rounded'), isFalse);
      expect(
        await root
            .list()
            .where((entry) => entry.path.endsWith('.staging'))
            .length,
        0,
      );
      service.dispose();
    },
  );
  test(
    'missing optional fonts keep the desired selection and use an effective default',
    () async {
      final item = pack().descriptor;
      final components = ComponentService(directory: root, catalog: [item]);
      final fonts = FontService(
        directory: root,
        components: components,
        register: (_, _) async {},
      );
      const settings = TypographySettings(
        appFontId: 'rounded',
        launchFontId: 'rounded',
      );
      await fonts.save(settings);
      final actual = await fonts.initialize();
      expect(actual.appFontId, 'rounded');
      expect(actual.launchFontId, 'rounded');
      expect(actual.effectiveAppFontId, 'system');
      expect(actual.effectiveLaunchFontId, 'nunito');
      expect(actual.loadWarning, isTrue);
      expect((await fonts.read()).appFontId, 'rounded');
      components.dispose();
    },
  );
  test(
    'downloaded font backups restore offline and reject altered bytes',
    () async {
      final source = await installedFontComponents(
        Directory('${root.path}/source'),
        ids: ['huninn'],
      );
      final payload = await source.exportFontComponents({'huninn'});
      final catalog = await source.descriptors();
      final target = ComponentService(
        directory: Directory('${root.path}/target'),
        catalog: catalog,
      );
      expect(
        await target.restoreFontComponent(
          'huninn',
          Map<String, dynamic>.from(payload['huninn'] as Map),
        ),
        isTrue,
      );
      expect(target.ready('huninn'), isTrue);
      final other = ComponentService(
        directory: Directory('${root.path}/bad'),
        catalog: catalog,
      );
      final damaged = Map<String, dynamic>.from(payload['huninn'] as Map);
      damaged['files'] = {
        ...(damaged['files'] as Map),
        'Huninn.ttf': base64Encode([1, 2, 3]),
      };
      await expectLater(
        other.restoreFontComponent('huninn', damaged),
        throwsFormatException,
      );
      expect(other.ready('huninn'), isFalse);
      source.dispose();
      target.dispose();
      other.dispose();
    },
  );
  test(
    'catalog rejects arbitrary download hosts and executable traversal paths',
    () {
      final base = {
        'id': 'rounded',
        'name': 'Font',
        'version': 1,
        'platform': 'any',
        'abi': null,
        'entrypoint': null,
        'url': 'https://evil.example/font.orbitpack',
        'size': 1,
        'sha256': 'a' * 64,
        'files': {
          'font.ttf': {'size': 1, 'sha256': 'b' * 64},
        },
      };
      expect(() => ComponentDescriptor.fromJson(base), throwsFormatException);
      expect(
        () => ComponentDescriptor.fromJson({
          ...base,
          'url':
              'https://github.com/WkJ01N/Orbit/releases/download/v1.6.1/a.orbitpack',
          'files': {
            '../a.dll': {'size': 1, 'sha256': 'b' * 64},
          },
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'every bundled platform descriptor is valid, including x86_64',
    () async {
      final raw =
          jsonDecode(
                await File('assets/components/catalog.json').readAsString(),
              )
              as Map;
      final values = [
        for (final item in raw['components'] as List)
          ComponentDescriptor.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
      expect(values.any((e) => e.id == 'video-android-x86_64'), isTrue);
      expect(values.where((e) => e.platform == 'any'), hasLength(3));
    },
  );

  ComponentDescriptor repacked(ComponentDescriptor previous) =>
      ComponentDescriptor.fromJson({
        'id': previous.id,
        'name': previous.name,
        'version': previous.version,
        'platform': previous.platform,
        'abi': previous.abi,
        'entrypoint': previous.entrypoint,
        'url': previous.asset.url,
        'size': previous.asset.size + 1,
        'sha256': 'a' * 64,
        'files': previous.files,
      });

  test(
    'upgrade recognizes legacy extracted fonts offline after archive digest changes',
    () async {
      final original = pack();
      final old = await Directory(
        '${root.path}/rounded-1-${original.descriptor.asset.sha256!.substring(0, 12)}',
      ).create();
      await File('${old.path}/font.ttf').writeAsString('test font data');
      final next = repacked(original.descriptor);
      final upgraded = ComponentService(directory: root, catalog: [next]);
      await upgraded.initialize();
      expect(upgraded.ready('rounded'), isTrue);
      expect(
        p.normalize((await upgraded.installed('rounded')).path),
        p.normalize(old.path),
      );
      final index = File('${root.path}/.font-installations.json');
      expect(await index.exists(), isTrue);
      upgraded.dispose();
      final restarted = ComponentService(directory: root, catalog: [next]);
      await restarted.initialize();
      expect(restarted.ready('rounded'), isTrue);
      await restarted.clearOldCaches();
      expect(await old.exists(), isTrue);
      await restarted.remove('rounded');
      restarted.dispose();
      final removed = ComponentService(directory: root, catalog: [next]);
      await removed.initialize();
      expect(removed.ready('rounded'), isFalse);
      expect(await old.exists(), isFalse);
      removed.dispose();
    },
  );

  test(
    'font identity survives repacking without moving or redownloading installed files',
    () async {
      final original = pack();
      final installed = ComponentService(
        directory: root,
        catalog: [original.descriptor],
      );
      final archive = await File(
        '${root.path}/input.orbitpack',
      ).writeAsBytes(original.bytes);
      await installed.installArchive(original.descriptor, archive);
      final old = await installed.installed('rounded');
      installed.dispose();
      final upgraded = ComponentService(
        directory: root,
        catalog: [repacked(original.descriptor)],
      );
      await upgraded.initialize();
      expect((await upgraded.installed('rounded')).path, old.path);
      upgraded.dispose();
    },
  );

  test(
    'invalid legacy fonts and preferences are not erased by cache cleanup',
    () async {
      final original = pack();
      final old = await Directory(
        '${root.path}/rounded-1-aaaaaaaaaaaa',
      ).create();
      await File('${old.path}/font.ttf').writeAsString('damaged');
      final service = ComponentService(
        directory: root,
        catalog: [original.descriptor],
      );
      await service.initialize();
      expect(service.ready('rounded'), isFalse);
      await service.clearOldCaches();
      expect(await old.exists(), isTrue);
      service.dispose();
    },
  );

  test(
    'failed installation-record writes preserve a verified legacy font',
    () async {
      final original = pack();
      final old = await Directory(
        '${root.path}/rounded-1-aaaaaaaaaaaa',
      ).create();
      await File('${old.path}/font.ttf').writeAsString('test font data');
      await Directory('${root.path}/.font-installations.pending').create();
      final service = ComponentService(
        directory: root,
        catalog: [original.descriptor],
      );
      await service.initialize();
      expect(service.ready('rounded'), isTrue);
      expect(
        p.normalize((await service.installed('rounded')).path),
        p.normalize(old.path),
      );
      service.dispose();
    },
  );

  test(
    'offline upgrade preserves real downloaded fonts, imported fonts and every selected scope',
    () async {
      final raw =
          jsonDecode(
                await File('assets/components/catalog.json').readAsString(),
              )
              as Map;
      final values = [
        for (final item in raw['components'] as List)
          if (const {
            'rounded',
            'huninn',
            'maiyuan',
          }.contains((item as Map)['id']))
            ComponentDescriptor.fromJson(Map<String, dynamic>.from(item)),
      ];
      for (final value in values) {
        final legacy = await Directory(
          p.join(root.path, '${value.id}-1-bbbbbbbbbbbb'),
        ).create();
        for (final name in value.files.keys) {
          final source = File(p.join('resources/fonts', name));
          if (name.endsWith('.txt')) {
            // Component packaging normalizes license text line endings.
            await File(p.join(legacy.path, name)).writeAsString(
              (await source.readAsString())
                  .replaceAll('\r\n', '\n')
                  .replaceAll('\r', '\n'),
            );
          } else {
            await source.copy(p.join(legacy.path, name));
          }
        }
      }
      final components = ComponentService(directory: root, catalog: values);
      final importRoot = Directory(p.join(root.path, 'imported'));
      final first = FontService(
        directory: importRoot,
        components: components,
        register: (_, _) async {},
      );
      final imported = (await first.importBytes(
        'custom.otf',
        await File('test/fixtures/typography/tiny.otf').readAsBytes(),
      )).font;
      await first.save(
        TypographySettings(
          appFontId: 'rounded',
          launchFontId: 'huninn',
          fallbackFontIds: ['maiyuan', imported.id],
          imports: {imported.id: imported},
        ),
      );
      final registered = <String>[];
      final upgraded = FontService(
        directory: importRoot,
        components: components,
        register: (family, _) async {
          registered.add(family);
        },
      );
      final prepared = await upgraded.initialize();
      expect(prepared.appFontId, 'rounded');
      expect(prepared.launchFontId, 'huninn');
      expect(prepared.fallbackFontIds, ['maiyuan', imported.id]);
      expect(prepared.loadWarning, isFalse);
      expect(prepared.unavailableFontIds, isEmpty);
      expect(
        registered,
        containsAll([
          'OrbitFont_rounded',
          'OrbitFont_huninn',
          'OrbitFont_maiyuan',
          FontCatalog.family(imported.id),
        ]),
      );
      await components.clearOldCaches();
      expect(await (await upgraded.file(imported)).exists(), isTrue);
      expect(values.every((value) => components.ready(value.id)), isTrue);
      components.dispose();
    },
  );

  test('cache cleanup only removes old owned component folders', () async {
    final good = pack();
    final service = ComponentService(
      directory: root,
      catalog: [good.descriptor],
    );
    final file = await File(
      '${root.path}/input.orbitpack',
    ).writeAsBytes(good.bytes);
    await service.installArchive(good.descriptor, file);
    final stale = await Directory(
      '${root.path}/rounded-0-aaaaaaaaaaaa',
    ).create();
    await File('${stale.path}/old.ttf').writeAsString('old');
    final unrelated = await Directory('${root.path}/personal-fonts').create();
    await service.clearOldCaches();
    expect(await stale.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
    expect(await (await service.installed('rounded')).exists(), isTrue);
    service.dispose();
  });
}
