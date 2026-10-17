import 'dart:io';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/services/background_asset_service.dart';
import 'package:orbit/services/schedule_backup_service.dart';

/// ZIP entries stay on disk, including deflated videos received from another device.
class BackgroundPackageService {
  BackgroundPackageService(this.assets);
  final BackgroundAssetService assets;

  Future<File> create(String json, Directory staging) async {
    final backup = ScheduleBackupService().decodeBackup(json);
    final manifest = await File(
      p.join(staging.path, 'backup.json'),
    ).writeAsString(json);
    final output = File(p.join(staging.path, 'orbit-backup.orbit'));
    final encoder = ZipFileEncoder()..create(output.path);
    try {
      await encoder.addFile(manifest, 'backup.json', 0);
      final settings = backup.settings?.backgrounds;
      if (settings != null) {
        final used = {
          for (final page in BackgroundPage.values)
            settings.resolved(page).assetId,
        };
        for (final asset in settings.assets.values.where(
          (a) => used.contains(a.id),
        )) {
          final file = await assets.file(asset);
          if (!await file.exists()) {
            throw FileSystemException('Missing background: ${asset.name}');
          }
          if ((await sha256.bind(file.openRead()).first).toString() !=
              asset.id) {
            throw const FormatException('Background hash mismatch');
          }
          await encoder.addFile(file, asset.relativePath, 0);
          final poster = await assets.poster(asset);
          if (await poster.exists()) {
            await encoder.addFile(
              poster,
              'backgrounds/${asset.id}.poster.png',
              0,
            );
          }
        }
      }
    } finally {
      await encoder.close();
    }
    return output;
  }

  Future<PreparedBackgroundPackage> prepare(
    File source,
    Directory staging,
  ) async {
    final input = InputFileStream(source.path);
    try {
      final zip = ZipDirectory.read(input);
      if (zip.fileHeaders.length > 100) {
        throw const FormatException('Too many backup entries');
      }
      final names = <String>{};
      final extracted = <String, File>{};
      for (final header in zip.fileHeaders) {
        final entry = header.file!;
        final name = entry.filename;
        final valid =
            name == 'backup.json' ||
            RegExp(
              r'^backgrounds/[a-f0-9]{64}\.(jpg|jpeg|png|webp|gif|mp4|m4v|mov|webm|poster\.png)$',
            ).hasMatch(name);
        if (!valid ||
            !names.add(name) ||
            (header.externalFileAttributes! >> 16 & 0xF000) == 0xA000 ||
            (entry.flags & 1) != 0) {
          throw const FormatException('Invalid backup entry');
        }
        final limit = name == 'backup.json'
            ? 256 * 1024 * 1024
            : 8 * 1024 * 1024 * 1024;
        if (entry.uncompressedSize! > limit) {
          throw const FormatException('Backup entry is too large');
        }
        final target = File(p.join(staging.path, name));
        await target.parent.create(recursive: true);
        final raw = entry.rawContent!;
        Stream<List<int>> chunks() async* {
          while (!raw.isEOS) {
            yield raw.readBytes(math.min(64 * 1024, raw.length)).toUint8List();
          }
        }

        Stream<List<int>> stream = chunks();
        if (entry.compressionMethod == 8) {
          stream = stream.transform(io.ZLibDecoder(raw: true));
        } else if (entry.compressionMethod != 0) {
          throw const FormatException('Unsupported ZIP compression');
        }
        var length = 0, crc = 0;
        await stream
            .map((bytes) {
              length += bytes.length;
              if (length > limit || length > entry.uncompressedSize!) {
                throw const FormatException('Invalid backup length');
              }
              crc = getCrc32(bytes, crc);
              return bytes;
            })
            .pipe(target.openWrite());
        if (length != entry.uncompressedSize || crc != entry.crc32) {
          throw const FormatException('Damaged backup entry');
        }
        extracted[name] = target;
      }
      final manifest = extracted['backup.json'];
      if (manifest == null) throw const FormatException('Missing backup.json');
      final json = await manifest.readAsString();
      final backup = ScheduleBackupService().decodeBackup(json);
      final settings = backup.settings?.backgrounds;
      final media = <BackgroundAsset, File>{};
      if (settings != null) {
        for (final asset in settings.assets.values) {
          final file = extracted.remove(asset.relativePath);
          if (file == null) {
            continue; // JSON descriptions may refer to local assets.
          }
          if ((await sha256.bind(file.openRead()).first).toString() !=
              asset.id) {
            throw const FormatException('Background hash mismatch');
          }
          media[asset] = file;
          extracted.remove('backgrounds/${asset.id}.poster.png');
        }
      }
      if (extracted.keys.any((name) => name != 'backup.json')) {
        throw const FormatException('Unreferenced media in backup');
      }
      return PreparedBackgroundPackage(backup, media, staging);
    } finally {
      await input.close();
    }
  }
}

class PreparedBackgroundPackage {
  PreparedBackgroundPackage(this.backup, this.media, this.staging);
  final OrbitBackup backup;
  final Map<BackgroundAsset, File> media;
  final Directory staging;
  final _installed = <File>[];

  Future<void> install(BackgroundAssetService service) async {
    for (final entry in media.entries) {
      final target = await service.file(entry.key);
      if (await target.exists()) {
        if ((await sha256.bind(target.openRead()).first).toString() !=
            entry.key.id) {
          throw const FormatException('Local background hash mismatch');
        }
      } else {
        final temporary = File('${target.path}.restore');
        try {
          await entry.value.openRead().pipe(temporary.openWrite());
          await temporary.rename(target.path);
          _installed.add(target);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      }
      final poster = File(
        p.join(staging.path, 'backgrounds/${entry.key.id}.poster.png'),
      );
      final destination = await service.poster(entry.key);
      if (await poster.exists() && !await destination.exists()) {
        await poster.copy(destination.path);
        _installed.add(destination);
      }
    }
  }

  Future<void> rollback() async {
    for (final file in _installed.reversed) {
      if (await file.exists()) await file.delete();
    }
    _installed.clear();
  }
}
