import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';

enum _ButtonLocation { hidden, floating, footer }

/// Adds scroll progress and a return action without rebuilding course cards
/// on each scroll tick. The footer measures overflow before its own extent.
class UpcomingScrollToTop extends StatefulWidget {
  const UpcomingScrollToTop({super.key, required this.sliver});

  final Widget sliver;

  @override
  State<UpcomingScrollToTop> createState() => _UpcomingScrollToTopState();
}

class _UpcomingScrollToTopState extends State<UpcomingScrollToTop>
    with TickerProviderStateMixin {
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
    _scrollController.addListener(_onScroll);
    _extentCorrection.addListener(_updateProgress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(UpcomingScrollToTop oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _scheduleRefresh();
          return false;
        },
        child: Stack(
          children: [
            CustomScrollView(
              key: const Key('upcoming-scroll-view'),
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
                            ? Center(child: _button(_ButtonLocation.footer))
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: _button(_ButtonLocation.floating),
            ),
          ],
        ),
      ),
    );
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
