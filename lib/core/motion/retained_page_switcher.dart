import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class PageTransitionData {
  const PageTransitionData({
    required this.animation,
    required this.epoch,
    required this.direction,
    required this.active,
    required this.visible,
    required this.continuing,
  });
  final Animation<double> animation;
  final int epoch, direction;
  final bool active, visible, continuing;
}

/// Transition updates reach their host without rebuilding a cached page theme.
class PageTransitionScope extends InheritedWidget {
  const PageTransitionScope({
    super.key,
    required this.data,
    required super.child,
  });
  final PageTransitionData data;
  static PageTransitionData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageTransitionScope>()!.data;
  @override
  bool updateShouldNotify(PageTransitionScope oldWidget) =>
      data.epoch != oldWidget.data.epoch ||
      data.active != oldWidget.data.active;
}

class _PageLayer {
  _PageLayer(this.fromOpacity, this.toOpacity, this.fromX, this.toX);
  final double fromOpacity, toOpacity, fromX, toX;
  double opacity(double t) =>
      fromOpacity +
      (toOpacity - fromOpacity) * Curves.easeInOutCubic.transform(t);
  double x(double t) =>
      fromX + (toX - fromX) * Curves.easeOutCubic.transform(t);
}

/// Retargets every visible layer from its actual painted state. Page elements
/// retain a stable path even when three destinations overlap during a reversal.
class RetainedPageSwitcher extends StatefulWidget {
  const RetainedPageSwitcher({
    super.key,
    required this.index,
    required this.itemCount,
    required this.builder,
    this.duration = const Duration(milliseconds: 260),
    this.keyPrefix = 'retained-page',
  });
  final int index, itemCount;
  final Widget Function(BuildContext, int, PageTransitionData) builder;
  final Duration duration;
  final String keyPrefix;
  @override
  State<RetainedPageSwitcher> createState() => _RetainedPageSwitcherState();
}

class _RetainedPageSwitcherState extends State<RetainedPageSwitcher>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final _layers = <int, _PageLayer>{widget.index: _PageLayer(1, 1, 0, 0)};
  late final _order = <int>[widget.index];
  late int _active = widget.index;
  int _epoch = 0, _direction = 1;
  bool _continuing = false;
  bool _reduced = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) _clock.value = 1;
  }

  @override
  void didUpdateWidget(RetainedPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_active == widget.index) return;
    final time = _clock.value;
    final before = {
      for (final entry in _layers.entries)
        entry.key: (opacity: entry.value.opacity(time), x: entry.value.x(time)),
    };
    _direction = widget.index > _active ? 1 : -1;
    _continuing = (before[widget.index]?.opacity ?? 0) > .001;
    _active = widget.index;
    _epoch++;
    if (!_order.contains(_active)) _order.insert(0, _active);
    for (final index in _order) {
      final state = before[index];
      if (index == _active) {
        _layers[index] = _PageLayer(
          _continuing ? state!.opacity : 1,
          1,
          _continuing ? state!.x : _direction * 14.0,
          0,
        );
      } else {
        final alpha = state?.opacity ?? 0;
        final x = state?.x ?? 0;
        _layers[index] = _PageLayer(alpha, 0, x, x - _direction * 6);
      }
    }
    _clock.duration = widget.duration;
    if (_reduced) {
      _clock.value = 1;
    } else {
      _clock.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transitions = <int, PageTransitionData>{
      for (final index in _order)
        index: PageTransitionData(
          animation: _clock,
          epoch: _epoch,
          direction: _direction,
          active: index == _active,
          visible:
              index == _active ||
              (!_reduced && _layers[index]!.opacity(_clock.value) > .001),
          continuing: index == _active && _continuing,
        ),
    };
    final pages = <int, Widget>{
      for (final index in _order)
        index: PageTransitionScope(
          data: transitions[index]!,
          child: widget.builder(context, index, transitions[index]!),
        ),
    };
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          for (final index in _order)
            KeyedSubtree(
              key: ValueKey('${widget.keyPrefix}-$index'),
              child: _layer(index, pages[index]!),
            ),
        ],
      ),
    );
  }

  Widget _layer(int index, Widget child) {
    final active = index == _active;
    final alpha = _reduced
        ? (active ? 1.0 : 0.0)
        : _layers[index]!.opacity(_clock.value);
    final hidden = !active && alpha <= .001;
    return Offstage(
      offstage: hidden,
      child: TickerMode(
        enabled: !hidden && active,
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: Opacity(
              opacity: alpha.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(
                  _reduced ? 0 : _layers[index]!.x(_clock.value),
                  0,
                ),
                child: _DeferredPageLayout(frozen: hidden, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeferredPageLayout extends SingleChildRenderObjectWidget {
  const _DeferredPageLayout({required this.frozen, required super.child});
  final bool frozen;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _DeferredPageBox(frozen);
  @override
  void updateRenderObject(
    BuildContext context,
    _DeferredPageBox renderObject,
  ) => renderObject.frozen = frozen;
}

class _DeferredPageBox extends RenderProxyBox {
  _DeferredPageBox(this._frozen);
  bool _frozen;
  set frozen(bool value) {
    if (_frozen == value) return;
    _frozen = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (_frozen) {
      size = constraints.constrain(Size.zero);
    } else {
      super.performLayout();
    }
  }
}
