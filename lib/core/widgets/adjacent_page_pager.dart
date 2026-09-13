import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

typedef SwipeAvailability = bool Function();

class AdjacentPagePagerController {
  AdjacentPagePagerState? _state;

  Future<void> animateToPrevious() async => _state?._navigate(-1);

  Future<void> animateToNext() async => _state?._navigate(1);

  void cancelInteraction() => _state?._cancelInteraction();

  void _attach(AdjacentPagePagerState state) => _state = state;

  void _detach(AdjacentPagePagerState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// An interactive three-page viewport for continuous adjacent navigation.
class AdjacentPagePager extends StatefulWidget {
  const AdjacentPagePager({
    super.key,
    required this.pageKey,
    required this.child,
    this.previousChild,
    this.nextChild,
    this.controller,
    this.onSwipeToPrevious,
    this.onSwipeToNext,
    this.canSwipePrevious,
    this.canSwipeNext,
    this.onInteractionStart,
    this.reduceMotion = false,
  });

  final Object pageKey;
  final Widget child;
  final Widget? previousChild;
  final Widget? nextChild;
  final AdjacentPagePagerController? controller;
  final VoidCallback? onSwipeToPrevious;
  final VoidCallback? onSwipeToNext;
  final SwipeAvailability? canSwipePrevious;
  final SwipeAvailability? canSwipeNext;
  final VoidCallback? onInteractionStart;
  final bool reduceMotion;

  @override
  State<AdjacentPagePager> createState() => AdjacentPagePagerState();
}

class AdjacentPagePagerState extends State<AdjacentPagePager>
    with SingleTickerProviderStateMixin {
  static const _commitFraction = 0.25;
  static const _minFlingVelocity = 400.0;
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 38,
  );

  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
  );
  double _viewportWidth = 0;
  bool _settling = false;
  int _generation = 0;
  int _settleDirection = 0;
  bool _committingPageChange = false;
  Future<void> _navigationQueue = Future<void>.value();
  int _navigationEpoch = 0;

  bool get _canGoPrevious =>
      widget.previousChild != null &&
      widget.onSwipeToPrevious != null &&
      (widget.canSwipePrevious?.call() ?? true);

  bool get _canGoNext =>
      widget.nextChild != null &&
      widget.onSwipeToNext != null &&
      (widget.canSwipeNext?.call() ?? true);

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant AdjacentPagePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.pageKey != widget.pageKey) {
      if (!_committingPageChange) _cancelInteraction();
      _committingPageChange = false;
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _position.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _navigationEpoch++;
    _generation++;
    _position.stop();
    // Rebase an almost-completed page before accepting a fresh drag. Both the
    // entering page and its neighbor keep their exact on-screen positions.
    if (_settling &&
        _settleDirection != 0 &&
        _position.value.abs() >= _viewportWidth * .5) {
      final direction = _settleDirection;
      _commit(direction);
      _position.value += direction * _viewportWidth;
    }
    _settling = false;
    _settleDirection = 0;
    widget.onInteractionStart?.call();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_viewportWidth <= 0) return;
    var target = (_position.value + details.delta.dx).clamp(
      -_viewportWidth,
      _viewportWidth,
    );
    if (target > 0 && !_canGoPrevious) {
      target = math.min(32, target * 0.18);
    } else if (target < 0 && !_canGoNext) {
      target = math.max(-32, target * 0.18);
    }
    _position.value = target;
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (_viewportWidth <= 0) return;
    final threshold = _viewportWidth * _commitFraction;
    final velocity = details.velocity.pixelsPerSecond.dx;
    // A decisive fling takes precedence over distance, including reversal.
    final direction = velocity.abs() >= _minFlingVelocity
        ? (velocity < 0 ? 1 : -1)
        : (_position.value.abs() >= threshold
              ? (_position.value < 0 ? 1 : -1)
              : 0);
    if (direction > 0 && _canGoNext || direction < 0 && _canGoPrevious) {
      await _animate(direction, velocity: velocity);
    } else {
      await _animate(0, velocity: velocity);
    }
  }

  Future<void> _navigate(int direction) {
    final epoch = _navigationEpoch;
    final request = _navigationQueue.then((_) async {
      if (!mounted || epoch != _navigationEpoch) return;
      await _performNavigation(direction);
    });
    _navigationQueue = request;
    return request;
  }

  Future<void> _performNavigation(int direction) async {
    if (_viewportWidth <= 0) return;
    if (direction < 0 && !_canGoPrevious || direction > 0 && !_canGoNext) {
      return;
    }
    // Rapid arrow presses complete the preceding navigation before starting
    // another one. Rebuild first so callbacks refer to the new adjacent pages.
    if (_settling && _settleDirection != 0) {
      final previous = _settleDirection;
      _generation++;
      _position.stop();
      _commit(previous);
      _position.value = 0;
      _settling = false;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    widget.onInteractionStart?.call();
    await _animate(direction);
    if (mounted && _committingPageChange && !widget.reduceMotion) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _animate(int direction, {double velocity = 0}) async {
    final generation = ++_generation;
    _position.stop();
    _settling = true;
    _settleDirection = direction;
    final target = -direction * _viewportWidth;
    if (!widget.reduceMotion && (_position.value - target).abs() > .1) {
      try {
        await _position
            .animateWith(
              SpringSimulation(
                _spring,
                _position.value,
                target,
                velocity.clamp(-2400, 2400),
                tolerance: const Tolerance(distance: .2, velocity: 2),
              ),
            )
            .orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted || generation != _generation) return;
    if (direction != 0) _commit(direction);
    _position.value = 0;
    _settling = false;
    _settleDirection = 0;
  }

  void _commit(int direction) {
    _committingPageChange = true;
    if (direction < 0) {
      widget.onSwipeToPrevious?.call();
    } else {
      widget.onSwipeToNext?.call();
    }
  }

  void _cancelInteraction() {
    _navigationEpoch++;
    _generation++;
    _position.stop();
    _position.value = 0;
    _settling = false;
    _settleDirection = 0;
  }

  void _onDragCancel() {
    if (!_settling) _animate(0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (_viewportWidth > 0 && width != _viewportWidth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _cancelInteraction();
          });
        }
        _viewportWidth = width;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _onDragCancel,
          child: AnimatedBuilder(
            animation: _position,
            builder: (context, _) => IgnorePointer(
              ignoring: _settling,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.previousChild case final previous?)
                      Transform.translate(
                        key: const Key('adjacent-page-previous'),
                        offset: Offset(-width + _position.value, 0),
                        child: IgnorePointer(
                          child: ExcludeSemantics(child: previous),
                        ),
                      ),
                    Transform.translate(
                      key: const Key('adjacent-page-current'),
                      offset: Offset(_position.value, 0),
                      child: widget.child,
                    ),
                    if (widget.nextChild case final next?)
                      Transform.translate(
                        key: const Key('adjacent-page-next'),
                        offset: Offset(width + _position.value, 0),
                        child: IgnorePointer(
                          child: ExcludeSemantics(child: next),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
