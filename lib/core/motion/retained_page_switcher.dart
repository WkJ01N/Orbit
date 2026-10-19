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
    this.fluid = false,
    this.duration = const Duration(milliseconds: 260),
  });
  final Animation<double> animation;
  final int epoch, direction;
  final bool active, visible, continuing;
  final bool fluid;
  final Duration duration;
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
      (toOpacity - fromOpacity) * Curves.easeOutCubic.transform(t);
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
    this.fluid = false,
    this.immediate = false,
    this.keepOutgoingTickers = false,
  });
  final int index, itemCount;
  final Widget Function(BuildContext, int, PageTransitionData) builder;
  final Duration duration;
  final String keyPrefix;
  final bool fluid;
  final bool immediate;

  /// Let live effects such as overscroll springs settle during the exit fade.
  /// Entrance hosts still freeze their own module clocks independently.
  final bool keepOutgoingTickers;
  @override
  State<RetainedPageSwitcher> createState() => _RetainedPageSwitcherState();
}

class _RetainedPageSwitcherState extends State<RetainedPageSwitcher>
    with TickerProviderStateMixin {
  late var _clock = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final Map<int, _PageLayer> _layers;
  late final List<int> _order;
  late int _active;
  int _epoch = 0, _direction = 1;
  bool _continuing = false;
  bool _reduced = false;
  late bool _fluid = widget.fluid;
  late Duration _sessionDuration = widget.duration;
  @override
  void initState() {
    super.initState();
    // Initialize even when reduced motion bypasses all reads of layer alpha.
    // Lazy initialization after the first selection would seed the new index
    // instead of the page actually present in the retained stack.
    _active = widget.index;
    _layers = {widget.index: _PageLayer(1, 1, 0, 0)};
    _order = [widget.index];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context) || widget.immediate;
    if (_reduced) _clock.value = 1;
  }

  @override
  void didUpdateWidget(RetainedPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reduced = MediaQuery.disableAnimationsOf(context) || widget.immediate;
    if (_reduced) _clock.value = 1;
    if (_active == widget.index) return;
    final time = _clock.value;
    final before = {
      for (final entry in _layers.entries)
        entry.key: (opacity: entry.value.opacity(time), x: entry.value.x(time)),
    };
    _direction = widget.index > _active ? 1 : -1;
    _continuing = (before[widget.index]?.opacity ?? 0) > .001;
    _active = widget.index;
    _fluid = widget.fluid;
    _sessionDuration = widget.duration;
    _epoch++;
    // Reordering two translucent visible layers changes the painted pixels even
    // when both keep their alpha. Only fully hidden destinations move beneath
    // the outgoing layers; reversing a visible destination keeps paint order.
    if (!_continuing) {
      _order.remove(_active);
      _order.insert(0, _active);
    }
    for (final index in _order) {
      final state = before[index];
      if (index == _active) {
        _layers[index] = _PageLayer(
          _continuing ? state!.opacity : (_fluid ? 1 : 0),
          1,
          _continuing ? state!.x : (_fluid ? 0 : _direction * 14.0),
          0,
        );
      } else {
        final alpha = state?.opacity ?? 0;
        final x = state?.x ?? 0;
        _layers[index] = _PageLayer(
          alpha,
          0,
          x,
          _fluid ? x : x - _direction * 6,
        );
      }
    }
    final previousClock = _clock..stop();
    _clock = AnimationController(vsync: this, duration: widget.duration);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => previousClock.dispose(),
    );
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
          fluid: _fluid,
          duration: _sessionDuration,
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
        enabled: !hidden && (active || widget.keepOutgoingTickers),
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
