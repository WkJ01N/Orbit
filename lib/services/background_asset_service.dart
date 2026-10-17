import 'package:orbit/services/component_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:orbit/models/background_settings.dart';

class BackgroundAssetService {
  BackgroundAssetService({this._directory, ComponentService? components})
    : components = components ?? ComponentService.shared;
  final ComponentService components;
  final Directory? _directory;
  static const extensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'mp4',
    'm4v',
    'mov',
    'webm',
  ];
  static const videoExtensions = ['mp4', 'm4v', 'mov', 'webm'];
  Future<Directory> directory() async {
    final dir =
        _directory ??
        Directory(
          p.join((await getApplicationSupportDirectory()).path, 'backgrounds'),
        );
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> file(BackgroundAsset asset) async =>
      File(p.join((await directory()).path, '${asset.id}.${asset.extension}'));
  Future<File> poster(BackgroundAsset asset) async =>
      File(p.join((await directory()).path, '${asset.id}.poster.png'));

  Future<BackgroundAsset> importFile(File source, {String? name}) async {
    final extension = p
        .extension(name ?? source.path)
        .replaceFirst('.', '')
        .toLowerCase();
    if (!extensions.contains(extension)) {
      throw const FormatException('Unsupported background format');
    }
    final dir = await directory();
    final temporary = File(
      p.join(
        dir.path,
        '.import-${DateTime.now().microsecondsSinceEpoch}.$extension',
      ),
    );
    Player? player;
    try {
      await source.openRead().pipe(temporary.openWrite());
      final id = (await sha256.bind(temporary.openRead()).first).toString();
      int width, height;
      int? duration;
      var kind = BackgroundMediaKind.image;
      List<int>? preview;
      if (videoExtensions.contains(extension)) {
        MediaKit.ensureInitialized(libmpv: await components.ensureVideo());
        player = Player(
          configuration: const PlayerConfiguration(
            muted: true,
            protocolWhitelist: ['file'],
          ),
        );
        VideoController(player);
        await player.setVolume(0);
        await player.setAudioTrack(AudioTrack.no());
        await player.setSubtitleTrack(SubtitleTrack.no());
        await player
            .open(Media(temporary.path), play: false)
            .timeout(const Duration(seconds: 15));
        await player.setAudioTrack(AudioTrack.no());
        await player.play();
        width =
            player.state.width ??
            await player.stream.width
                .where((v) => v != null && v > 0)
                .first
                .timeout(const Duration(seconds: 15)) ??
            0;
        height =
            player.state.height ??
            await player.stream.height
                .where((v) => v != null && v > 0)
                .first
                .timeout(const Duration(seconds: 15)) ??
            0;
        duration = player.state.duration.inMilliseconds;
        if (width <= 0 || height <= 0) {
          throw const FormatException('Could not decode video');
        }
        kind = BackgroundMediaKind.video;
        try {
          preview = await player.screenshot(format: 'image/png');
        } catch (_) {
          /* Some devices cannot capture the first texture. */
        }
      } else {
        final codec = await ui.instantiateImageCodec(
          await temporary.readAsBytes(),
        );
        try {
          kind = codec.frameCount > 1
              ? BackgroundMediaKind.gif
              : BackgroundMediaKind.image;
          final frame = await codec.getNextFrame();
          try {
            width = frame.image.width;
            height = frame.image.height;
            preview = (await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            ))?.buffer.asUint8List();
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      }
      final asset = BackgroundAsset(
        id: id,
        name: name ?? p.basename(source.path),
        extension: extension,
        kind: kind,
        width: width,
        height: height,
        durationMs: duration,
      );
      final destination = await file(asset);
      if (!await destination.exists()) await temporary.rename(destination.path);
      if (preview != null) {
        await (await poster(asset)).writeAsBytes(preview, flush: true);
      }
      return asset;
    } finally {
      await player?.dispose();
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<BackgroundSettings> resolveAvailable(
    BackgroundSettings settings,
  ) async {
    var result = settings;
    final available = <String, bool>{};
    for (final asset in settings.assets.values) {
      final source = await file(asset);
      available[asset.id] =
          await source.exists() &&
          (await sha256.bind(source.openRead()).first).toString() == asset.id;
    }
    for (final owner in BackgroundPage.values) {
      final id = settings.resolved(owner).assetId;
      if (id != null && available[id] != true) {
        result = result.updatePage(
          owner,
          settings
              .resolved(owner)
              .copyWith(clearAsset: true, followGrid: false),
        );
      }
    }
    return result;
  }

  Future<void> removeUnreferenced(
    Iterable<BackgroundAsset> candidates,
    BackgroundSettings saved,
  ) async {
    final used = {
      for (final page in BackgroundPage.values) saved.resolved(page).assetId,
    };
    for (final asset in candidates) {
      if (used.contains(asset.id)) continue;
      for (final entry in [await file(asset), await poster(asset)]) {
        if (await entry.exists()) await entry.delete();
      }
    }
  }
}
