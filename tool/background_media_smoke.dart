// Usage: dart run '-Ddart.vm.product=true' tool/background_media_smoke.dart <libmpv-2.dll> <video-with-audio>
// Match release behavior; media_kit hot-restart pointer tracking is debug-only.
import 'dart:async';
import 'dart:io';
import 'package:media_kit/media_kit.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) throw ArgumentError('Expected libmpv and video paths');
  MediaKit.ensureInitialized(libmpv: args[0]);
  final player = Player(
    configuration: const PlayerConfiguration(
      muted: true,
      protocolWhitelist: ['file'],
    ),
  );
  final errors = <String>[];
  final subscription = player.stream.error.listen(errors.add);
  void verify(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  try {
    await player.setVideoTrack(VideoTrack.auto());
    await player.setVolume(0);
    await player.setAudioTrack(AudioTrack.no());
    await player.setSubtitleTrack(SubtitleTrack.no());
    await player.setPlaylistMode(PlaylistMode.single);
    await player.open(Media(args[1]), play: false);
    await player.setAudioTrack(AudioTrack.no());
    await player.play();
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    verify(
      (player.state.width ?? 0) > 0 && (player.state.height ?? 0) > 0,
      'Video did not decode',
    );
    verify(
      player.state.volume == 0 && player.state.track.audio.id == 'no',
      'Audio was enabled',
    );
    await player.pause();
    final paused = player.state.position;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    verify(
      (player.state.position - paused).inMilliseconds.abs() < 150,
      'Playback advanced while paused',
    );
    await player.play();
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    verify(
      player.state.playing && !player.state.completed,
      'Video did not loop/resume',
    );
    verify(errors.isEmpty, 'Decoder errors: $errors');
    stdout.writeln(
      'PASS: Windows video decoded ${player.state.width}x${player.state.height}; no audio track; volume zero; pause/resume and loop verified.',
    );
  } finally {
    await subscription.cancel();
    await player.dispose();
  }
}
