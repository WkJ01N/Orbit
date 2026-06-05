import 'package:flutter/material.dart';

typedef SwipeAvailability = bool Function();

/// Detects horizontal swipes and commits navigation instantly (no animation).
class AdjacentPagePager extends StatefulWidget {
  const AdjacentPagePager({
    super.key,
    required this.child,
    this.onSwipeToPrevious,
    this.onSwipeToNext,
    this.canSwipePrevious,
    this.canSwipeNext,
  });

  final Widget child;
  final VoidCallback? onSwipeToPrevious;
  final VoidCallback? onSwipeToNext;
  final SwipeAvailability? canSwipePrevious;
  final SwipeAvailability? canSwipeNext;

  @override
  State<AdjacentPagePager> createState() => AdjacentPagePagerState();
}

class AdjacentPagePagerState extends State<AdjacentPagePager> {
  static const _commitFraction = 0.25;
  static const _minFlingVelocity = 400.0;
  static const _axisLockRatio = 1.5;

  double _viewportWidth = 0;
  double _dragDistance = 0;
  bool _axisLocked = false;
  bool _isHorizontalDrag = false;

  bool get _canGoPrevious =>
      widget.onSwipeToPrevious != null &&
      (widget.canSwipePrevious?.call() ?? true);

  bool get _canGoNext =>
      widget.onSwipeToNext != null && (widget.canSwipeNext?.call() ?? true);

  void _onDragStart(DragStartDetails details) {
    _axisLocked = false;
    _isHorizontalDrag = false;
    _dragDistance = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_axisLocked) {
      final dx = details.delta.dx.abs();
      final dy = details.delta.dy.abs();
      if (dx > dy * _axisLockRatio || dy > dx * _axisLockRatio) {
        _axisLocked = true;
        _isHorizontalDrag = dx > dy;
      }
    }
    if (_isHorizontalDrag) {
      _dragDistance += details.delta.dx;
    }
  }

  void _commitSwipe({required bool forward}) {
    if (forward) {
      if (_canGoNext) {
        widget.onSwipeToNext?.call();
      }
    } else if (_canGoPrevious) {
      widget.onSwipeToPrevious?.call();
    }
    _dragDistance = 0;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isHorizontalDrag || _viewportWidth <= 0) {
      _dragDistance = 0;
      return;
    }

    final threshold = _viewportWidth * _commitFraction;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_dragDistance <= -threshold || velocity < -_minFlingVelocity) {
      _commitSwipe(forward: true);
    } else if (_dragDistance >= threshold || velocity > _minFlingVelocity) {
      _commitSwipe(forward: false);
    }

    _dragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: widget.child,
        );
      },
    );
  }
}
