import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// One paint clock for the visible modules. It never rebuilds list rows on ticks.
class ModuleEntrance extends ChangeNotifier {
  ModuleEntrance(this.clock) {
    clock.addListener(notifyListeners);
  }
  final AnimationController clock;
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
    if (_parentGeneration != _parent!.generation) {
      _parentGeneration = _parent!.generation;
      _localWave = false;
      clock.stop();
      pending = false;
      prepared = false;
      _late.clear();
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
    generation++;
    _localWave = true;
    suspended = false;
    if (fromDirection != null) direction = fromDirection;
    _region = region;
    gatePage = region == null;
    _acceptLate = true;
    _late.clear();
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
    final elapsed = continuing
        ? clock.value * clock.duration!.inMilliseconds
        : 0.0;
    if (!continuing) _delays.clear();
    final geometry = <_RenderPageModule, Rect>{};
    final visible =
        (candidates ?? _modules).where((module) {
          if (!module.attached || !module.hasSize) return false;
          RenderObject? parent = module.parent;
          while (parent != null) {
            if (parent is RenderOffstage && parent.offstage) return false;
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
    final content = visible.where((m) => !m.surface).toList();
    for (var i = 0; i < content.length; i++) {
      _delays[content[i]] =
          elapsed + (content.length < 2 ? 0 : i * 180 / (content.length - 1));
    }
    for (final surface in visible.where((m) => m.surface)) {
      final area = geometry[surface]!;
      final first = content
          .where((m) => area.overlaps(geometry[m]!))
          .firstOrNull;
      _delays[surface] = first == null ? 0 : _delays[first]!;
    }
    pending = false;
    prepared = true;
    final duration = _delays.values
        .fold<double>(
          600,
          (value, delay) => value > delay + 420 ? value : delay + 420,
        )
        .ceil();
    clock.duration = Duration(milliseconds: duration);
    clock.forward(from: elapsed / duration);
    notifyListeners();
  }

  double _progress(_RenderPageModule module) {
    if (!_localWave && _parent != null) return _parent!._progress(module);
    if (_late.contains(module)) return 0;
    if (pending) {
      if (_region == null || !module.hasSize) return 0;
      return (module.localToGlobal(Offset.zero) & module.size).overlaps(
            _region!,
          )
          ? 0
          : 1;
    }
    final delay = _delays[module];
    if (!prepared || delay == null) return 1;
    return Curves.easeOutCubic.transform(
      ((clock.value * clock.duration!.inMilliseconds - delay) / 420).clamp(
        0.0,
        1.0,
      ),
    );
  }

  void finish() {
    generation++;
    _localWave = true;
    suspended = false;
    _acceptLate = false;
    _late.clear();
    pending = false;
    prepared = false;
    _delays.clear();
    clock.value = 1;
    notifyListeners();
  }

  void pause() {
    clock.stop();
    _acceptLate = false;
    suspended = true;
    notifyListeners();
  }

  void resume() {
    suspended = false;
    notifyListeners();
    if (prepared && clock.value < 1) clock.forward();
  }

  void sealLate() {
    _acceptLate = false;
    if (_late.isNotEmpty) {
      _late.clear();
      notifyListeners();
    }
  }

  void _register(_RenderPageModule module) {
    _modules.add(module);
    _parent?._register(module);
    if (!prepared || pending || !_acceptLate) return;
    _late.add(module);
    if (_lateQueued) return;
    _lateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _late.remove(module);
    _parent?._unregisterModule(module);
  }

  @override
  void dispose() {
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
  });
  final bool enabled, surface;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPageModule(enabled ? ModuleEntranceScope.maybeOf(context) : null)
        ..surface = surface;
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final module = renderObject as _RenderPageModule;
    module.surface = surface;
    module.motion = enabled ? ModuleEntranceScope.maybeOf(context) : null;
  }
}

class _RenderPageModule extends RenderProxyBox {
  _RenderPageModule(this._motion);
  ModuleEntrance? _motion;
  bool surface = false;
  double _lastProgress = -1;
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
    if (_lastProgress == progress) return;
    _lastProgress = progress;
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
    final progress = _motion?._progress(this) ?? 1;
    return Offset((_motion?.effectiveDirection ?? -1) * 12 * (1 - progress), 0);
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
