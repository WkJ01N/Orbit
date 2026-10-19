import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// One paint clock for the visible modules. It never rebuilds list rows on ticks.
class ModuleEntrance extends ChangeNotifier {
  ModuleEntrance(this.clock) {
    clock.addListener(notifyListeners);
  }
  final AnimationController clock;
  Animation<double>? _navigation;
  bool _reverseNavigation = false;
  double _navigationOrigin = 0, _navigationScale = 600;
  double _elementMs = 420, _staggerMs = 180, _navigationMs = 600;
  final _fromProgress = <_RenderPageModule, double>{};
  final _durations = <_RenderPageModule, double>{};
  final _frozenProgress = <_RenderPageModule, double>{};
  final _fromOffsets = <_RenderPageModule, double>{};
  final _frozenOffsets = <_RenderPageModule, double>{};
  double get _elapsed => _navigation == null
      ? clock.value * clock.duration!.inMilliseconds
      : ((_reverseNavigation ? 1 - _navigation!.value : _navigation!.value) -
                    _navigationOrigin)
                .clamp(0.0, 1.0) *
            _navigationScale;
  double get progress => _navigation == null
      ? clock.value
      : (_elapsed / _navigationMs).clamp(0, 1);
  void _detachNavigation() {
    _navigation?.removeListener(notifyListeners);
    _navigation = null;
  }

  /// Module progress is the transition, rather than a second animation started
  /// after it. A visible returning page keeps its currently painted progress.
  void follow(
    Animation<double> navigation, {
    required Duration duration,
    required int fromDirection,
    bool reverse = false,
    bool continuing = false,
    double visibility = 1,
  }) {
    final before = {for (final module in _modules) module: _progress(module)};
    final offsets = {
      for (final module in _modules) module: _translation(module).dx,
    };
    reset(fromDirection: fromDirection);
    gatePage = !continuing;
    if (continuing) {
      _fromProgress.addAll(
        before.map((module, value) => MapEntry(module, value * visibility)),
      );
      _fromOffsets.addAll(offsets);
    }
    _navigationScale = duration.inMilliseconds.toDouble();
    final position = reverse ? 1 - navigation.value : navigation.value;
    // A quick pop only has the remaining route distance to run. Starting its
    // module clock at 1 - route.value would jump most of the way to completion.
    _navigationOrigin = position > 0 && position < 1 ? position : 0;
    _navigationMs = ((1 - _navigationOrigin) * _navigationScale).clamp(
      1,
      _navigationScale,
    );
    _elementMs = _navigationMs * .84;
    _staggerMs = _navigationMs * .16;
    _navigation = navigation;
    _reverseNavigation = reverse;
    navigation.addListener(notifyListeners);
  }

  ModuleEntrance? _parent;
  int _parentGeneration = -1;
  bool _localWave = false;
  bool suspended = false, _parentPausedClock = false;
  int direction = -1;
  int get effectiveDirection =>
      !_localWave && _parent != null ? _parent!.effectiveDirection : direction;
  void setParent(ModuleEntrance? parent) {
    if (identical(parent, _parent)) return;
    _parent?.removeListener(_parentChanged);
    for (final module in _modules) {
      _parent?._unregisterModule(module);
    }
    _parent = parent;
    _parentGeneration = parent?.generation ?? -1;
    for (final module in _modules) {
      parent?._register(module);
    }
    parent?.addListener(_parentChanged);
  }

  void _parentChanged() {
    // An outgoing category owns its frozen presentation until its layer fades.
    // A new wave in the containing page must not erase that snapshot.
    if (suspended) return;
    if (_parentGeneration != _parent!.generation) {
      generation++;
      _detachNavigation();
      _parentGeneration = _parent!.generation;
      _localWave = false;
      clock.stop();
      pending = false;
      prepared = false;
      _late.clear();
      _lateQueued = false;
      _delays.clear();
    }
    if (_parent!.suspended) {
      _parentPausedClock |= clock.isAnimating;
      clock.stop();
    } else if (_parentPausedClock) {
      _parentPausedClock = false;
      if (_localWave && prepared && clock.value < 1) clock.forward();
    }
    notifyListeners();
  }

  final _modules = <_RenderPageModule>{};
  final _delays = <_RenderPageModule, double>{};
  bool pending = false;
  bool prepared = false;
  bool gatePage = true;
  int generation = 0;
  Rect? _region;
  bool _acceptLate = false, _lateQueued = false;
  final _late = <_RenderPageModule>{};
  Rect viewport = Rect.zero;

  void reset({Rect? region, int? fromDirection}) {
    _detachNavigation();
    _elementMs = 420;
    _staggerMs = 180;
    _fromProgress.clear();
    _fromOffsets.clear();
    _frozenOffsets.clear();
    _durations.clear();
    _frozenProgress.clear();
    generation++;
    _localWave = true;
    suspended = false;
    if (fromDirection != null) direction = fromDirection;
    _region = region;
    gatePage = region == null;
    _acceptLate = true;
    _late.clear();
    _lateQueued = false;
    pending = true;
    prepared = false;
    _delays.clear();
    clock.value = 0;
    notifyListeners();
  }

  void start(Rect bounds) => _start(bounds);
  void _start(Rect bounds, {Set<_RenderPageModule>? candidates}) {
    viewport = bounds;
    final continuing = prepared && !pending && candidates != null;
    final elapsed = continuing ? _elapsed : 0.0;
    if (!continuing) _delays.clear();
    var offstage = false;
    final geometry = <_RenderPageModule, Rect>{};
    final visible =
        (candidates ?? _modules).where((module) {
          if (!module.attached || !module.hasSize) return false;
          RenderObject? parent = module.parent;
          while (parent != null) {
            if (parent is RenderOffstage && parent.offstage) {
              offstage = true;
              return false;
            }
            if (parent is _RenderPageModule && identical(parent.motion, this)) {
              return false;
            }
            parent = parent.parent;
          }
          final area = module.localToGlobal(Offset.zero) & module.size;
          geometry[module] = area;
          return area.overlaps(bounds);
        }).toList()..sort((a, b) {
          final ap = geometry[a]!.topLeft, bp = geometry[b]!.topLeft;
          final row = ap.dy.compareTo(bp.dy);
          return row == 0 ? ap.dx.compareTo(bp.dx) : row;
        });
    if (visible.isEmpty &&
        offstage &&
        _navigation != null &&
        _elapsed < _navigationMs) {
      final session = generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (session == generation &&
            pending &&
            !suspended &&
            _navigation != null) {
          _start(bounds);
        }
      });
      return;
    }
    final content = visible.where((m) => !m.surface).toList();
    for (var i = 0; i < content.length; i++) {
      _delays[content[i]] =
          elapsed +
          (content.length < 2 ? 0 : i * _staggerMs / (content.length - 1));
    }
    for (final surface in visible.where((m) => m.surface)) {
      final area = geometry[surface]!;
      final first = content
          .where((m) => area.overlaps(geometry[m]!))
          .firstOrNull;
      _delays[surface] = first == null ? 0 : _delays[first]!;
    }
    for (final module in visible) {
      final delay = _delays[module] ?? 0;
      _delays[module] = _navigation == null
          ? delay
          : delay.clamp(0, _navigationMs - 1);
      _durations[module] = _navigation == null
          ? _elementMs
          : (_navigationMs - _delays[module]!).clamp(1, _elementMs);
    }
    pending = false;
    prepared = true;
    final duration = _delays.values
        .fold<double>(
          _navigation == null ? 600 : _navigationMs,
          (value, delay) =>
              value > delay + _elementMs ? value : delay + _elementMs,
        )
        .ceil();
    if (_navigation == null) {
      clock.duration = Duration(milliseconds: duration);
      clock.forward(from: elapsed / duration);
    }
    notifyListeners();
  }

  double _progress(_RenderPageModule module) {
    if (!_localWave && _parent != null) return _parent!._progress(module);
    if (suspended) return _frozenProgress[module] ?? 1;
    if (_late.contains(module)) return 0;
    if (pending) {
      if (_region == null || !module.hasSize) return _fromProgress[module] ?? 0;
      return (module.localToGlobal(Offset.zero) & module.size).overlaps(
            _region!,
          )
          ? 0
          : 1;
    }
    final delay = _delays[module];
    if (!prepared || delay == null) return 1;
    final progress = _waveProgress(module);
    final from = _fromProgress[module] ?? 0;
    return from + (1 - from) * progress;
  }

  double _waveProgress(_RenderPageModule module) {
    if (pending) return 0;
    final delay = _delays[module];
    if (!prepared || delay == null) return 1;
    return Curves.easeOutCubic.transform(
      ((_elapsed - delay) / (_durations[module] ?? _elementMs)).clamp(0.0, 1.0),
    );
  }

  Offset _translation(_RenderPageModule module) {
    if (!_localWave && _parent != null) return _parent!._translation(module);
    if (suspended) return Offset(_frozenOffsets[module] ?? 0, 0);
    final from = _fromOffsets[module];
    return Offset(
      from == null
          ? effectiveDirection * module.distance * (1 - _progress(module))
          : from * (1 - _waveProgress(module)),
      0,
    );
  }

  void finish() {
    _detachNavigation();
    generation++;
    _localWave = true;
    suspended = false;
    _acceptLate = false;
    _late.clear();
    _lateQueued = false;
    pending = false;
    prepared = false;
    _delays.clear();
    _fromOffsets.clear();
    clock.value = 1;
    notifyListeners();
  }

  void pause() {
    if (suspended) return;
    _frozenOffsets.clear();
    _frozenOffsets.addAll({
      for (final module in _modules) module: _translation(module).dx,
    });
    _frozenProgress.clear();
    _frozenProgress.addAll({
      for (final module in _modules) module: _progress(module),
    });
    _localWave = true;
    clock.stop();
    _acceptLate = false;
    suspended = true;
    notifyListeners();
  }

  void resume() {
    suspended = false;
    notifyListeners();
    if (_navigation == null && prepared && clock.value < 1) clock.forward();
  }

  void sealLate() {
    _parent?.sealLate();
    _acceptLate = false;
    if (_late.isNotEmpty) {
      _late.clear();
      notifyListeners();
    }
  }

  void _register(_RenderPageModule module) {
    _modules.add(module);
    _parent?._register(module);
    if (!prepared ||
        pending ||
        !_acceptLate ||
        (_navigation != null ? _elapsed >= _navigationMs : clock.isCompleted)) {
      return;
    }
    _late.add(module);
    if (_lateQueued) return;
    _lateQueued = true;
    final session = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (session != generation) return;
      _lateQueued = false;
      final candidates = _late.toSet();
      _late.clear();
      if (candidates.isNotEmpty && _acceptLate) {
        _start(viewport, candidates: candidates);
      }
    });
  }

  void _unregisterModule(_RenderPageModule module) {
    _modules.remove(module);
    _delays.remove(module);
    _durations.remove(module);
    _fromProgress.remove(module);
    _fromOffsets.remove(module);
    _frozenProgress.remove(module);
    _frozenOffsets.remove(module);
    _late.remove(module);
    _parent?._unregisterModule(module);
  }

  @override
  void dispose() {
    _detachNavigation();
    _acceptLate = false;
    _parent?.removeListener(_parentChanged);
    for (final module in _modules) {
      _parent?._unregisterModule(module);
    }
    clock.removeListener(notifyListeners);
    _modules.clear();
    _late.clear();
    super.dispose();
  }
}

class ModuleEntranceScope extends InheritedWidget {
  const ModuleEntranceScope({
    super.key,
    required this.motion,
    required super.child,
  });
  final ModuleEntrance motion;
  static ModuleEntrance? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ModuleEntranceScope>()?.motion;
  @override
  bool updateShouldNotify(ModuleEntranceScope oldWidget) =>
      motion != oldWidget.motion;
}

class PageModule extends SingleChildRenderObjectWidget {
  const PageModule({
    super.key,
    required super.child,
    this.enabled = true,
    this.surface = false,
    this.distance = 12,
  });
  final bool enabled, surface;
  final double distance;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPageModule(enabled ? ModuleEntranceScope.maybeOf(context) : null)
        ..surface = surface
        ..distance = distance;
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final module = renderObject as _RenderPageModule;
    module.surface = surface;
    module.distance = distance;
    module.motion = enabled ? ModuleEntranceScope.maybeOf(context) : null;
  }
}

class _RenderPageModule extends RenderProxyBox {
  _RenderPageModule(this._motion);
  ModuleEntrance? _motion;
  bool surface = false;
  double distance = 12;
  double _lastProgress = -1;
  Offset? _lastTranslation;
  @override
  bool get isRepaintBoundary => _motion != null;
  @override
  bool get alwaysNeedsCompositing => child != null && _motion != null;
  @override
  Rect get paintBounds =>
      super.paintBounds.expandToInclude(super.paintBounds.shift(_translation));
  @override
  OffsetLayer updateCompositedLayer({
    required covariant OpacityLayer? oldLayer,
  }) {
    final layer = oldLayer ?? OpacityLayer();
    layer.alpha = (255 * (_motion?._progress(this) ?? 1)).round();
    return layer;
  }

  ModuleEntrance? get motion => _motion;
  set motion(ModuleEntrance? value) {
    if (identical(_motion, value)) return;
    _unregister();
    _motion = value;
    if (attached) _register();
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  void _register() {
    _motion?._register(this);
    _motion?.addListener(_tick);
  }

  void _tick() {
    final progress = _motion?._progress(this) ?? 1;
    final translation = _translation;
    if (_lastProgress == progress && _lastTranslation == translation) return;
    _lastProgress = progress;
    _lastTranslation = translation;
    markNeedsCompositedLayerUpdate();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _unregister() {
    _motion?._unregisterModule(this);
    _motion?.removeListener(_tick);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }

  Offset get _translation {
    return _motion?._translation(this) ?? Offset.zero;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if ((_motion?._progress(this) ?? 1) <= .05) return false;
    return result.addWithPaintOffset(
      offset: _translation,
      position: position,
      hitTest: (result, position) => super.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    final offset = _translation;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  bool paintsChild(RenderBox child) => (_motion?._progress(this) ?? 1) > 0;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if ((_motion?._progress(this) ?? 1) > .05) {
      super.visitChildrenForSemantics(visitor);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final progress = _motion?._progress(this) ?? 1;
    if (progress <= 0) return;
    super.paint(context, offset + _translation);
  }
}
