import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  static const _cancelDuration = Duration(milliseconds: 160);
  static const _programmaticDuration = Duration(milliseconds: 220);

  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
  );
  double _viewportWidth = 0;
  bool _settling = false;

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
    if (oldWidget.pageKey != widget.pageKey && !_settling) {
      _cancelInteraction();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _position.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (_settling) return;
    _position.stop();
    widget.onInteractionStart?.call();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_settling || _viewportWidth <= 0) return;
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
    if (_settling || _viewportWidth <= 0) return;
    final threshold = _viewportWidth * _commitFraction;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if ((_position.value <= -threshold || velocity < -_minFlingVelocity) &&
        _canGoNext) {
      await _settleTo(1);
    } else if ((_position.value >= threshold || velocity > _minFlingVelocity) &&
        _canGoPrevious) {
      await _settleTo(-1);
    } else {
      await _snapBack();
    }
  }

  Future<void> _navigate(int direction) async {
    if (_settling || _viewportWidth <= 0) return;
    if (direction < 0 && !_canGoPrevious) return;
    if (direction > 0 && !_canGoNext) return;
    widget.onInteractionStart?.call();
    if (widget.reduceMotion) {
      _position.value = 0;
      _commit(direction);
      return;
    }
    _settling = true;
    await _position.animateTo(
      direction > 0 ? -_viewportWidth : _viewportWidth,
      duration: _programmaticDuration,
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    _commit(direction);
    _position.value = 0;
    _settling = false;
  }

  Future<void> _settleTo(int direction) async {
    _settling = true;
    if (widget.reduceMotion) {
      _commit(direction);
      _position.value = 0;
      _settling = false;
      return;
    }
    final target = direction > 0 ? -_viewportWidth : _viewportWidth;
    final remainingFraction =
        ((target - _position.value).abs() / _viewportWidth).clamp(0.0, 1.0);
    final duration = Duration(
      milliseconds: (120 + 100 * remainingFraction).round(),
    );
    await _position.animateTo(
      target,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    _commit(direction);
    _position.value = 0;
    _settling = false;
  }

  Future<void> _snapBack() async {
    if (_position.value == 0) return;
    if (widget.reduceMotion) {
      _position.value = 0;
      return;
    }
    _settling = true;
    await _position.animateTo(
      0,
      duration: _cancelDuration,
      curve: Curves.easeOutCubic,
    );
    _settling = false;
  }

  void _commit(int direction) {
    if (direction < 0) {
      widget.onSwipeToPrevious?.call();
    } else {
      widget.onSwipeToNext?.call();
    }
  }

  void _cancelInteraction() {
    _position.stop();
    _position.value = 0;
    _settling = false;
  }

  void _onDragCancel() {
    if (!_settling) _snapBack();
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
