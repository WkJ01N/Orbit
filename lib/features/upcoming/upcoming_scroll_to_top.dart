import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/services/handedness_estimator.dart';
import 'package:orbit/services/hand_motion_service.dart';

import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';

enum _ButtonLocation { hidden, floating, footer }

/// Adds scroll progress and a return action without rebuilding course cards
/// on each scroll tick. The footer measures overflow before its own extent.
class UpcomingScrollToTop extends StatefulWidget {
  const UpcomingScrollToTop({
    super.key,
    required this.sliver,
    this.onRefresh,
    this.position = BackToTopPosition.smart,
    this.active = true,
    this.motionSamples,
  });
  final BackToTopPosition position;
  final bool active;
  final Stream<HandMotionSample>? motionSamples;
  final Future<void> Function()? onRefresh;

  final Widget sliver;

  @override
  State<UpcomingScrollToTop> createState() => _UpcomingScrollToTopState();
}

class _UpcomingScrollToTopState extends State<UpcomingScrollToTop>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _hand = HandednessEstimator();
  final _alignment = ValueNotifier(Alignment.center);
  final _pointers = <int, _TouchTrace>{};
  final _otherPointers = <int>{};
  StreamSubscription<HandMotionSample>? _motionSubscription;
  HandMotionSample? _motion;
  bool _sampling = false;
  bool _foreground = true;
  bool _routeVisible = true;
  bool _oppositeTouches = false;
  _TouchTrace? _primaryTrace;
  Timer? _handExpiry;

  bool get _smartActive =>
      widget.active &&
      _foreground &&
      _routeVisible &&
      widget.position == BackToTopPosition.smart;

  void _syncMotion() {
    if (_sampling == _smartActive) return;
    _sampling = _smartActive;
    if (!_sampling) {
      unawaited(_motionSubscription?.cancel());
      _motionSubscription = null;
      _motion = null;
      _pointers.clear();
      _otherPointers.clear();
      _primaryTrace = null;
      _handExpiry?.cancel();
      return;
    }
    _hand.expire(DateTime.now());
    _motionSubscription =
        (widget.motionSamples ?? const HandMotionService().samples()).listen(
          (sample) => _motion = sample,
          onError: (Object _) {
            _motion = null;
          },
        );
    _scheduleHandExpiry();
  }

  void _scheduleHandExpiry() {
    _handExpiry?.cancel();
    if (!_smartActive) return;
    _handExpiry = Timer(const Duration(seconds: 6), () {
      if (mounted && _pointers.isEmpty) {
        _hand.expire(DateTime.now());
        _updateAlignment();
      }
    });
  }

  void _updateAlignment() {
    if (_pointers.isNotEmpty || _otherPointers.isNotEmpty) return;
    _alignment.value = switch (widget.position) {
      BackToTopPosition.left => Alignment.centerLeft,
      BackToTopPosition.right => Alignment.centerRight,
      BackToTopPosition.center => Alignment.center,
      BackToTopPosition.smart => switch (_hand.estimate.hand) {
        OperatingHand.left => Alignment.centerLeft,
        OperatingHand.right => Alignment.centerRight,
        _ => Alignment.center,
      },
    };
  }

  void _pointerDown(PointerDownEvent event) {
    if (!_smartActive) return;
    if (event.kind != PointerDeviceKind.touch) {
      _otherPointers.add(event.pointer);
      return;
    }
    final size = context.size;
    if (size == null || size.width <= 0) return;
    final x = (event.localPosition.dx / size.width).clamp(0.0, 1.0);
    if (_pointers.isEmpty) {
      _oppositeTouches = false;
      _primaryTrace = _TouchTrace(x, event.localPosition.dy, DateTime.now());
      _handExpiry?.cancel();
    }
    if (_pointers.values.any((p) => (p.lastX - x).abs() > .25)) {
      _oppositeTouches = true;
    }
    _pointers[event.pointer] = _pointers.isEmpty
        ? _primaryTrace!
        : _TouchTrace(x, event.localPosition.dy, DateTime.now());
  }

  void _pointerMove(PointerMoveEvent event) {
    final trace = _pointers[event.pointer];
    final size = context.size;
    if (trace == null || size == null || size.width <= 0) return;
    trace.move(
      (event.localPosition.dx / size.width).clamp(0.0, 1.0),
      event.localPosition.dy,
    );
  }

  void _pointerEnd(PointerEvent event, {bool cancelled = false}) {
    if (_otherPointers.remove(event.pointer)) {
      _hand.reset();
      _updateAlignment();
      return;
    }
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers.remove(event.pointer);
    if (cancelled) _primaryTrace = null;
    if (_pointers.isNotEmpty) return;
    final trace = _primaryTrace;
    _primaryTrace = null;
    if (trace != null &&
        !_returning &&
        _smartActive &&
        (trace.travelY >= 18 || trace.travelX >= .04 || _oppositeTouches)) {
      _hand.add(
        HandGesture(
          at: DateTime.now(),
          startX: trace.startX,
          endX: trace.lastX,
          meanX: trace.sumX / trace.points,
          curvature: trace.midX - (trace.startX + trace.lastX) / 2,
          oppositeTouches: _oppositeTouches,
          gravityZ: _motion?.gravityZ,
          angularSpeed: _motion?.angularSpeed,
        ),
      );
    }
    _hand.expire(DateTime.now());
    _updateAlignment();
    _scheduleHandExpiry();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
    _updateAlignment();
  }

  final _scrollController = ScrollController();
  final _location = ValueNotifier(_ButtonLocation.hidden);
  late final _progress = AnimationController(vsync: this);
  late final _extentCorrection = AnimationController.unbounded(vsync: this);
  bool _refreshScheduled = false;
  bool _hasOverflow = false;
  bool _shown = false;
  bool _atBottom = false;
  bool _returning = false;
  bool _reduceMotion = false;
  bool _transferring = false;
  double _progressTarget = 0;
  double? _previousExtent;
  double _previousOffset = 0;
  // Limit visual deviation to 1.5 percentage points (5.4 degrees of the ring).
  static const _maxCorrection = .015;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _scrollController.addListener(_onScroll);
    _extentCorrection.addListener(_updateProgress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _routeVisible =
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        TickerMode.valuesOf(context).enabled;
    _syncMotion();
    _updateAlignment();
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(UpcomingScrollToTop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motionSamples != widget.motionSamples) {
      _sampling = false;
      unawaited(_motionSubscription?.cancel());
      _motionSubscription = null;
    }
    _syncMotion();
    _updateAlignment();
    _scheduleRefresh();
  }

  void _onScroll() {
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) _refreshMetrics();
    });
  }

  void _updateProgress() {
    _progress.value = (_progressTarget + _extentCorrection.value).clamp(
      0.0,
      1.0,
    );
  }

  void _refreshMetrics() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final extent = position.maxScrollExtent - position.minScrollExtent;
    final offset = (position.pixels - position.minScrollExtent).clamp(
      0.0,
      math.max(0.0, extent),
    );
    final remaining = math.max(0.0, extent - offset);
    // Variable-height rows change SliverList's estimated extent during motion.
    // Use the current range so the ring stays in sync with the scroll metrics.
    final progress = remaining <= .5 && extent > 0
        ? 1.0
        : extent > 0
        ? (offset / extent).clamp(0.0, 1.0)
        : 0.0;
    _progressTarget = progress;
    final previousExtent = _previousExtent;
    if (_reduceMotion || progress == 0 || progress == 1) {
      _extentCorrection.value = 0;
    } else if (previousExtent != null &&
        previousExtent > 0 &&
        extent > 0 &&
        previousExtent != extent) {
      // Offset movement remains immediate. Only changes to the estimated range
      // are eased out, including while dragging and during ballistic scrolling.
      final correction =
          _extentCorrection.value +
          _previousOffset / previousExtent -
          _previousOffset / extent;
      _extentCorrection.value = correction.clamp(
        -_maxCorrection,
        _maxCorrection,
      );
      _extentCorrection.animateTo(
        0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOutCubic,
      );
    }
    _previousExtent = extent;
    _previousOffset = offset.toDouble();
    _updateProgress();

    if (!_hasOverflow || extent <= 0 || offset <= 0) {
      _shown = false;
      _atBottom = false;
    } else {
      _atBottom = remaining <= (_atBottom ? 32 : 8);
      if (_atBottom || offset >= position.viewportDimension * 0.5) {
        _shown = true;
      } else if (offset <= 48) {
        _shown = false;
      }
    }
    final next = !_shown
        ? _ButtonLocation.hidden
        : _atBottom
        ? _ButtonLocation.footer
        : _ButtonLocation.floating;
    if (next != _location.value) {
      _transferring =
          next != _ButtonLocation.hidden &&
          _location.value != _ButtonLocation.hidden;
      _location.value = next;
    }
  }

  Future<void> _returnToTop() async {
    if (_returning || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    if (_reduceMotion) {
      _scrollController.jumpTo(position.minScrollExtent);
      return;
    }
    _returning = true;
    try {
      final screens =
          (position.pixels - position.minScrollExtent) /
          math.max(1.0, position.viewportDimension);
      await _scrollController.animateTo(
        position.minScrollExtent,
        duration: Duration(
          milliseconds: (450 + screens * 60).clamp(450, 900).round(),
        ),
        curve: Curves.easeOutCubic,
      );
    } finally {
      // animateTo also completes when a drag or mouse wheel interrupts it.
      _returning = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_motionSubscription?.cancel());
    _handExpiry?.cancel();
    _alignment.dispose();
    _scrollController.dispose();
    _progress.dispose();
    _extentCorrection.dispose();
    _location.dispose();
    super.dispose();
  }

  Widget _button(_ButtonLocation location) {
    return ValueListenableBuilder<_ButtonLocation>(
      valueListenable: _location,
      builder: (context, current, _) => _ButtonTransition(
        visible: current == location,
        transferring: _transferring,
        reduceMotion: _reduceMotion,
        child: _ReturnToTopButton(
          key: ValueKey('upcoming-back-to-top-${location.name}'),
          progress: _progress,
          onPressed: _returnToTop,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerSignal: (_) {
          if (_smartActive && _pointers.isEmpty && _otherPointers.isEmpty) {
            _hand.reset();
            _updateAlignment();
          }
        },
        onPointerUp: (e) => _pointerEnd(e),
        onPointerCancel: (e) => _pointerEnd(e, cancelled: true),
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) _scheduleRefresh();
            return false;
          },
          child: RefreshIndicator(
            onRefresh: widget.onRefresh ?? () async {},
            child: Stack(
              children: [
                CustomScrollView(
                  key: const Key('upcoming-scroll-view'),
                  physics: widget.onRefresh == null
                      ? null
                      : const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  slivers: [
                    widget.sliver,
                    SliverLayoutBuilder(
                      builder: (context, constraints) {
                        // Excluding the footer avoids manufacturing overflow for
                        // short lists or toggling its height during transitions.
                        _hasOverflow =
                            constraints.precedingScrollExtent + 16 >
                            constraints.viewportMainAxisExtent + 0.5;
                        return SliverToBoxAdapter(
                          child: SizedBox(
                            key: const Key('upcoming-back-to-top-footer-space'),
                            height: _hasOverflow ? 88 : 16,
                            child: _hasOverflow
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: _alignedButton(
                                      _ButtonLocation.footer,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _alignedButton(_ButtonLocation.floating),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _alignedButton(_ButtonLocation location) =>
      ValueListenableBuilder<Alignment>(
        valueListenable: _alignment,
        child: _button(location),
        builder: (context, alignment, child) => AnimatedAlign(
          alignment: alignment,
          duration: _reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      );
}

class _TouchTrace {
  _TouchTrace(this.startX, this.startY, this.at)
    : lastX = startX,
      lastY = startY,
      sumX = startX,
      midX = startX;
  final double startX, startY;
  final DateTime at;
  double lastX, lastY, sumX, midX;
  double travelX = 0, travelY = 0;
  int points = 1;
  void move(double x, double y) {
    travelX += (x - lastX).abs();
    travelY += (y - lastY).abs();
    midX = sumX / points;
    lastX = x;
    lastY = y;
    sumX += x;
    points++;
  }
}

class _ButtonTransition extends StatelessWidget {
  const _ButtonTransition({
    required this.visible,
    required this.transferring,
    required this.reduceMotion,
    required this.child,
  });

  final bool visible;
  final bool transferring;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: visible ? 1 : 0),
            duration: reduceMotion
                ? Duration.zero
                : Duration(milliseconds: transferring ? 240 : 220),
            curve: Curves.easeOutCubic,
            child: child,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: Transform.scale(scale: 0.9 + 0.1 * value, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReturnToTopButton extends StatelessWidget {
  const _ReturnToTopButton({
    super.key,
    required this.progress,
    required this.onPressed,
  });

  final Animation<double> progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      elevation: 3,
      shadowColor: colors.shadow.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: AppLocalizations.of(context)!.backToTop,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 56, height: 56),
        style: IconButton.styleFrom(shape: const CircleBorder()),
        icon: AnimatedBuilder(
          animation: progress,
          builder: (context, _) => CustomPaint(
            size: const Size.square(56),
            painter: _ReturnToTopPainter(
              progress: progress.value,
              color: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReturnToTopPainter extends CustomPainter {
  const _ReturnToTopPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.14);
    canvas.drawCircle(center, radius, paint);
    paint.color = color;
    if (progress >= 1) {
      canvas.drawCircle(center, radius, paint);
    } else if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        paint,
      );
    }
    paint.strokeWidth = 2.5;
    // Equal horizontal and vertical legs give an exact 90-degree apex.
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 8, center.dy + 4)
        ..lineTo(center.dx, center.dy - 4)
        ..lineTo(center.dx + 8, center.dy + 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ReturnToTopPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
