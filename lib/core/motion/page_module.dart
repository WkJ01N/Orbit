import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// One paint clock for the visible modules. It never rebuilds list rows on ticks.
class ModuleEntrance extends ChangeNotifier {
  ModuleEntrance(this.clock) {
    clock.addListener(notifyListeners);
  }
  final AnimationController clock;
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

  void reset({Rect? region}) {
    generation++;
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
    _delays.clear();
    final visible =
        (candidates ?? _modules).where((module) {
          if (!module.attached || !module.hasSize) return false;
          RenderObject? parent = module.parent;
          while (parent != null) {
            if (parent is _RenderPageModule && identical(parent.motion, this)) {
              return false;
            }
            parent = parent.parent;
          }
          return (module.localToGlobal(Offset.zero) & module.size).overlaps(
            bounds,
          );
        }).toList()..sort((a, b) {
          final ap = a.localToGlobal(Offset.zero),
              bp = b.localToGlobal(Offset.zero);
          final row = ap.dy.compareTo(bp.dy);
          return row == 0 ? ap.dx.compareTo(bp.dx) : row;
        });
    for (var i = 0; i < visible.length; i++) {
      _delays[visible[i]] = visible.length < 2
          ? 0
          : i * 180 / (visible.length - 1);
    }
    pending = false;
    prepared = true;
    clock.forward(from: 0);
    notifyListeners();
  }

  double _progress(_RenderPageModule module) {
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
      ((clock.value * 600 - delay) / 420).clamp(0.0, 1.0),
    );
  }

  void finish() {
    generation++;
    _acceptLate = false;
    _late.clear();
    pending = false;
    prepared = false;
    _delays.clear();
    clock.value = 1;
    notifyListeners();
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

  @override
  void dispose() {
    _acceptLate = false;
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
  const PageModule({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPageModule(ModuleEntranceScope.maybeOf(context));
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) => (renderObject as _RenderPageModule).motion = ModuleEntranceScope.maybeOf(
    context,
  );
}

class _RenderPageModule extends RenderProxyBox {
  _RenderPageModule(this._motion);
  ModuleEntrance? _motion;
  ModuleEntrance? get motion => _motion;
  set motion(ModuleEntrance? value) {
    if (identical(_motion, value)) return;
    _unregister();
    _motion = value;
    if (attached) _register();
    markNeedsPaint();
  }

  void _register() {
    _motion?._register(this);
    _motion?.addListener(_tick);
  }

  void _tick() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _unregister() {
    _motion?._modules.remove(this);
    _motion?._delays.remove(this);
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
    return Offset(-12 * (1 - progress), 8 * (1 - progress));
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
  void paint(PaintingContext context, Offset offset) {
    final progress = _motion?._progress(this) ?? 1;
    if (progress <= 0) return;
    if (progress >= 1) {
      super.paint(context, offset);
      return;
    }
    context.pushOpacity(
      offset,
      (255 * progress).round(),
      (context, offset) => super.paint(
        context,
        offset + Offset(-12 * (1 - progress), 8 * (1 - progress)),
      ),
    );
  }
}
