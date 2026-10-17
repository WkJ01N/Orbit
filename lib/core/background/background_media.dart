import 'package:orbit/services/component_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:orbit/core/background/background_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/services/background_asset_service.dart';
import 'package:window_manager/window_manager.dart';

/// One decoder per continuity group. Cropping and blur share the same video texture.
class BackgroundMedia extends StatefulWidget {
  const BackgroundMedia({
    required this.asset,
    required this.framing,
    required this.service,
    this.animate = true,
    this.active = true,
    super.key,
  });
  final BackgroundAsset asset;
  final BackgroundFraming framing;
  final BackgroundAssetService service;
  final bool animate, active;
  @override
  State<BackgroundMedia> createState() => _BackgroundMediaState();
}

class _BackgroundMediaState extends State<BackgroundMedia>
    with WidgetsBindingObserver, WindowListener {
  late Future<File> _file;
  late Future<File> _posterFile;
  Player? _player;
  VideoController? _video;
  StreamSubscription<String>? _errors;
  bool _failed = false,
      _ready = false,
      _foreground = true,
      _windowVisible = true,
      _motion = true;
  int _generation = 0;
  String? _missingComponent;
  void _componentChanged() {
    if (_missingComponent != null &&
        widget.service.components.ready(_missingComponent!)) {
      _missingComponent = null;
      _failed = false;
      unawaited(_open());
    }
  }

  static final _positions = <String, Duration>{};
  static Future<void> _releases = Future<void>.value();
  String get _identity => widget.key.toString();
  bool get _playing =>
      widget.active &&
      widget.animate &&
      _foreground &&
      _windowVisible &&
      _motion;
  @override
  void initState() {
    super.initState();
    widget.service.components.addListener(_componentChanged);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) windowManager.addListener(this);
    _file = widget.service.file(widget.asset);
    _posterFile = widget.service.poster(widget.asset);
    if (widget.asset.kind == BackgroundMediaKind.video) unawaited(_open());
  }

  Future<void> _open() async {
    final generation = ++_generation;
    try {
      // Flutter disposes removed transition layers at the end of this frame.
      // Wait for their native decoders before allocating another one.
      await Future<void>.delayed(Duration.zero);
      await _releases;
      if (!mounted || generation != _generation) return;
      MediaKit.ensureInitialized(
        libmpv: await widget.service.components.ensureVideo(),
      );
      final player = Player(
        configuration: const PlayerConfiguration(
          muted: true,
          protocolWhitelist: ['file'],
        ),
      );
      _player = player;
      _video = VideoController(player);
      _errors = player.stream.error.listen((_) {
        if (mounted) setState(() => _failed = true);
      });
      await player.setVolume(0);
      await player.setAudioTrack(AudioTrack.no());
      await player.setSubtitleTrack(SubtitleTrack.no());
      await player.setPlaylistMode(PlaylistMode.single);
      final file = await _file;
      await player.open(Media(file.path), play: false);
      await player.setAudioTrack(AudioTrack.no());
      if (!mounted || generation != _generation) return;
      final position = _positions[_identity];
      if (position != null) await player.seek(position);
      if (!mounted) return;
      setState(() => _ready = true);
      await _syncPlayback();
    } on ComponentMissing catch (error) {
      _missingComponent = error.id;
      if (mounted) setState(() => _failed = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _syncPlayback() async {
    if (!_ready) return;
    try {
      if (_playing && !_failed) {
        await _player?.play();
      } else {
        await _player?.pause();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = !MediaQuery.disableAnimationsOf(context);
    unawaited(_syncPlayback());
  }

  @override
  void didUpdateWidget(BackgroundMedia old) {
    super.didUpdateWidget(old);
    unawaited(_syncPlayback());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
    unawaited(_syncPlayback());
  }

  @override
  void onWindowEvent(String eventName) {
    if (const [
      'hide',
      'minimize',
      'show',
      'restore',
      'focus',
    ].contains(eventName)) {
      if (mounted) {
        setState(
          () =>
              _windowVisible = !const ['hide', 'minimize'].contains(eventName),
        );
      }
      unawaited(_syncPlayback());
    }
  }

  @override
  void dispose() {
    widget.service.components.removeListener(_componentChanged);
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows) windowManager.removeListener(this);
    if (_player != null) _positions[_identity] = _player!.state.position;
    unawaited(_errors?.cancel());
    final player = _player;
    if (player != null) {
      _releases = _releases
          .then((_) => player.dispose())
          .catchError((Object _) {});
    }
    super.dispose();
  }

  Widget _poster() => FutureBuilder<File>(
    future: _posterFile,
    builder: (context, snapshot) => snapshot.hasData
        ? Image.file(
            snapshot.data!,
            fit: BoxFit.fill,
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          )
        : const SizedBox.expand(),
  );
  Widget _image(File file) {
    if (widget.asset.kind == BackgroundMediaKind.video) {
      if (_failed || !_ready || !_motion || !widget.animate) return _poster();
      return Video(
        controller: _video!,
        fit: BoxFit.fill,
        controls: NoVideoControls,
        wakelock: false,
        pauseUponEnteringBackgroundMode: false,
        resumeUponEnteringForegroundMode: false,
        fill: Colors.transparent,
      );
    }
    if (widget.asset.kind == BackgroundMediaKind.gif &&
        (!_motion || !widget.animate)) {
      return _poster();
    }
    return TickerMode(
      enabled: _playing,
      child: Image(
        image: widget.asset.kind == BackgroundMediaKind.gif
            ? LoopingBackgroundImage(file, identity: _identity)
            : FileImage(file),
        fit: BoxFit.fill,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _poster(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, box) => ClipRect(
          child: FutureBuilder<File>(
            future: _file,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.expand();
              final size = box.biggest;
              final rect = backgroundRect(
                size,
                Size(
                  widget.asset.width.toDouble(),
                  widget.asset.height.toDouble(),
                ),
                widget.framing,
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.framing.allowEdges &&
                      widget.framing.fill == BackgroundEdgeFill.blur)
                    ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: widget.asset.width.toDouble(),
                          height: widget.asset.height.toDouble(),
                          child: _image(snapshot.data!),
                        ),
                      ),
                    ),
                  Positioned.fromRect(
                    rect: rect,
                    child: ImageFiltered(
                      enabled: widget.framing.blur > 0,
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: widget.framing.blur * 20,
                        sigmaY: widget.framing.blur * 20,
                        tileMode: TileMode.clamp,
                      ),
                      child: _image(snapshot.data!),
                    ),
                  ),
                  ColoredBox(
                    color: Colors.black.withValues(alpha: widget.framing.dim),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
