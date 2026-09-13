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
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _location = ValueNotifier(_ButtonLocation.hidden);
  late final _progress = AnimationController(vsync: this);
  bool _refreshScheduled = false;
  bool _hasOverflow = false;
  bool _shown = false;
  bool _atBottom = false;
  bool _returning = false;
  bool _reduceMotion = false;
  bool _transferring = false;
  double _progressTarget = 0;
  double? _scrollExtentBasis;
  bool _scrolling = false;
  bool _offsetChanged = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _scrollExtentBasis = null;
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(UpcomingScrollToTop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollExtentBasis = null;
    _scheduleRefresh();
  }

  void _onScroll() {
    _offsetChanged = true;
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) _refreshMetrics(scrolling: _offsetChanged);
      _offsetChanged = false;
    });
  }

  void _refreshMetrics({bool scrolling = false}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final extent = position.maxScrollExtent - position.minScrollExtent;
    // SliverList's estimated extent changes as differently sized rows appear.
    // Keep its denominator stable through a drag and the following ballistic
    // scroll, then reconcile once motion ends.
    if (!_scrolling || _scrollExtentBasis == null) _scrollExtentBasis = extent;
    final offset = (position.pixels - position.minScrollExtent).clamp(
      0.0,
      math.max(0.0, extent),
    );
    final remaining = math.max(0.0, extent - offset);
    final basis = _scrollExtentBasis ?? extent;
    final progress = remaining <= .5 && extent > 0
        ? 1.0
        : basis > 0
        ? (offset / basis).clamp(0.0, 1.0)
        : 0.0;
    if (_reduceMotion ||
        _scrolling ||
        scrolling ||
        progress == 0 ||
        progress == 1) {
      _progress.value = progress;
    } else if (_progressTarget != progress) {
      _progress.animateTo(
        progress,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    }
    _progressTarget = progress;

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
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth != 0) return false;
            if (notification is ScrollStartNotification) {
              _scrolling = true;
              if (_scrollController.hasClients) {
                _scrollExtentBasis =
                    _scrollController.position.maxScrollExtent -
                    _scrollController.position.minScrollExtent;
              }
            } else if (notification is ScrollEndNotification) {
              _scrolling = false;
              _scheduleRefresh();
            }
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
