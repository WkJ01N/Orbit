import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Retains ScaffoldMessenger's queue/timers while advancing motion by painted
/// frames, so a slow course refresh cannot skip its whole animation.
class AppScaffoldMessenger extends ScaffoldMessenger {
  const AppScaffoldMessenger({
    super.key,
    required super.child,
    this.routeObserver,
  });
  final AppMessageRouteObserver? routeObserver;

  @override
  ScaffoldMessengerState createState() => _AppScaffoldMessengerState();
}

/// A dialog's pop future completes before its overlay finishes exiting.
/// Keep feedback's entry clock paused until those overlays are gone.
class AppMessageRouteObserver extends NavigatorObserver {
  final _exiting = <TransitionRoute<dynamic>>{};
  bool get hasExitingOverlay => _exiting.isNotEmpty;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute<dynamic>) {
      _exiting.add(route);
      route.completed.whenComplete(() => _exiting.remove(route));
    }
  }

  Future<void> waitForOverlays() async {
    while (_exiting.isNotEmpty) {
      await Future.wait(_exiting.map((route) => route.completed).toList());
    }
  }
}

class _AppScaffoldMessengerState extends ScaffoldMessengerState {
  AnimationController? _messageAnimation;
  Ticker? _entryTicker;
  Ticker? _exitTicker;
  AppMessageRouteObserver? get _routes =>
      (widget as AppScaffoldMessenger).routeObserver;

  void _stopExit() {
    _exitTicker?.dispose();
    _exitTicker = null;
  }

  void _stopEntry() {
    _entryTicker?.dispose();
    _entryTicker = null;
  }

  void _beginEntry(AnimationController motion) {
    if (_exitTicker != null || motion.isDismissed) return;
    _stopEntry();
    motion.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.value = 1;
      return;
    }
    final initial = motion.value;
    var previous = Duration.zero;
    var played = Duration.zero;
    _entryTicker = createTicker((elapsed) {
      // An expensive course refresh must not consume the entire animation
      // between two painted frames. Catch up by at most 32 ms per frame.
      final delta = (elapsed - previous).inMicroseconds.clamp(0, 32000);
      previous = elapsed;
      played += Duration(microseconds: delta);
      final progress =
          (initial +
                  played.inMicroseconds /
                      const Duration(milliseconds: 240).inMicroseconds)
              .clamp(0.0, 1.0);
      if (progress >= 1) {
        _stopEntry();
        motion.value = 1;
      } else if (progress > 0) {
        motion.value = progress;
      }
    })..start();
  }

  @override
  void hideCurrentSnackBar({
    SnackBarClosedReason reason = SnackBarClosedReason.hide,
  }) {
    if (_exitTicker != null) return;
    _stopEntry();
    final motion = _messageAnimation;
    if (MediaQuery.disableAnimationsOf(context) ||
        motion == null ||
        motion.isDismissed) {
      super.hideCurrentSnackBar(reason: reason);
      return;
    }
    // Drive intermediate values without reaching dismissed: remove only after
    // the last exit frame so native closed reasons and queue advancement agree.
    // This also avoids Flutter's immediate-removal assistive-navigation branch.
    motion.stop();
    final initial = motion.value;
    var previous = Duration.zero;
    var played = Duration.zero;
    _exitTicker = createTicker((elapsed) {
      final delta = (elapsed - previous).inMicroseconds.clamp(0, 32000);
      previous = elapsed;
      played += Duration(microseconds: delta);
      final progress =
          (played.inMicroseconds /
                  const Duration(milliseconds: 180).inMicroseconds)
              .clamp(0.0, 1.0);
      if (progress >= 1) {
        _stopExit();
        super.removeCurrentSnackBar(reason: reason);
      } else {
        motion.value = (initial * (1 - progress)).clamp(.000001, 1.0);
      }
    })..start();
  }

  @override
  void removeCurrentSnackBar({
    SnackBarClosedReason reason = SnackBarClosedReason.remove,
  }) {
    _stopEntry();
    _stopExit();
    super.removeCurrentSnackBar(reason: reason);
  }

  @override
  void dispose() {
    _stopEntry();
    _stopExit();
    super.dispose();
  }
}

/// ScaffoldMessenger owns the queue and timers, including cancellation on actions.
extension AppSnackBarMessenger on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
    SnackBar message, {
    bool isError = false,
  }) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return showSnackBar(
      _AppSnackBar(
        message,
        isError: isError,
        owner: this is _AppScaffoldMessengerState
            ? this as _AppScaffoldMessengerState
            : null,
      ),
      snackBarAnimationStyle: reduce
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 240),
              reverseDuration: Duration(milliseconds: 180),
            ),
    );
  }
}

class _AppSnackBar extends SnackBar {
  _AppSnackBar(
    SnackBar source, {
    Animation<double>? motion,
    Key? fallbackKey,
    bool isError = false,
    this.owner,
    this.startAfterPaint = false,
  }) : super(
         key: source.key ?? fallbackKey,
         content: source.content,
         action: source.action,
         backgroundColor: source.backgroundColor,
         elevation: source.elevation,
         shape: source.shape,
         margin: source.margin,
         padding: source.padding,
         width: source.width,
         behavior: SnackBarBehavior.floating,
         showCloseIcon: source.showCloseIcon ?? true,
         closeIconColor: source.closeIconColor,
         duration: Duration(
           seconds:
               source.action != null ||
                   isError ||
                   source.duration == const Duration(seconds: 6)
               ? 6
               : 4,
         ),
         persist: false,
         animation: motion,
         actionOverflowThreshold: source.actionOverflowThreshold,
         dismissDirection: source.dismissDirection,
         clipBehavior: source.clipBehavior,
         hitTestBehavior: source.hitTestBehavior,
         onVisible: source.onVisible,
       );
  final _AppScaffoldMessengerState? owner;
  final bool startAfterPaint;
  @override
  SnackBar withAnimation(Animation<double> newAnimation, {Key? fallbackKey}) {
    var defer = false;
    if (newAnimation is AnimationController) {
      owner?._messageAnimation = newAnimation;
      defer =
          newAnimation.isAnimating &&
          newAnimation.value == 0 &&
          newAnimation.status == AnimationStatus.forward;
      if (defer) newAnimation.stop();
    }
    return _AppSnackBar(
      this,
      motion: newAnimation,
      fallbackKey: fallbackKey,
      owner: owner,
      startAfterPaint: defer,
    );
  }

  @override
  State<SnackBar> createState() => _AppMessageState();
}

class _AppMessageState extends State<SnackBar> {
  final _dismissKey = UniqueKey();
  bool _visible = false;
  bool _waitingForPaint = false;

  @override
  void initState() {
    super.initState();
    _waitingForPaint = (widget as _AppSnackBar).startAfterPaint;
    final owner = (widget as _AppSnackBar).owner;
    final motion = widget.animation;
    if (owner != null &&
        motion is AnimationController &&
        motion.status == AnimationStatus.forward) {
      motion.stop();
      _waitingForPaint = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      _visible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        widget.onVisible?.call();
        if (_waitingForPaint) {
          await (widget as _AppSnackBar).owner?._routes?.waitForOverlays();
          if (!mounted) return;
          setState(() => _waitingForPaint = false);
          final motion = widget.animation;
          if (motion is AnimationController &&
              motion.status == AnimationStatus.forward) {
            final owner = (widget as _AppSnackBar).owner;
            if (owner != null) {
              owner._beginEntry(motion);
            } else {
              motion.forward();
            }
          }
        }
      });
    }
    final theme = Theme.of(context);
    final bar = theme.snackBarTheme;
    final colors = theme.colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    void close(SnackBarClosedReason reason) =>
        ScaffoldMessenger.of(context).hideCurrentSnackBar(reason: reason);
    final controls = [
      if (widget.action != null)
        TextButtonTheme(
          data: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: bar.actionTextColor ?? colors.inversePrimary,
            ),
          ),
          child: widget.action!,
        ),
      if (widget.showCloseIcon ?? true)
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          color:
              widget.closeIconColor ??
              bar.closeIconColor ??
              bar.contentTextStyle?.color ??
              colors.onInverseSurface,
          onPressed: () => close(SnackBarClosedReason.dismiss),
          icon: const Icon(Icons.close),
        ),
    ];
    final surface = Material(
      color:
          widget.backgroundColor ??
          bar.backgroundColor ??
          colors.inverseSurface,
      elevation: widget.elevation ?? bar.elevation ?? 3,
      shape:
          widget.shape ??
          bar.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: widget.clipBehavior,
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = DefaultTextStyle(
              style:
                  bar.contentTextStyle ??
                  TextStyle(color: colors.onInverseSurface),
              child: widget.content,
            );
            final actions = Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: controls,
            );
            return constraints.maxWidth < 360 && widget.action != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [content, actions],
                  )
                : Row(
                    children: [
                      Expanded(child: content),
                      actions,
                    ],
                  );
          },
        ),
      ),
    );
    final message = Semantics(
      container: true,
      liveRegion: true,
      onDismiss: () => close(SnackBarClosedReason.dismiss),
      child: Dismissible(
        key: _dismissKey,
        direction:
            widget.dismissDirection ??
            bar.dismissDirection ??
            DismissDirection.down,
        resizeDuration: null,
        onDismissed: (_) => ScaffoldMessenger.of(
          context,
        ).removeCurrentSnackBar(reason: SnackBarClosedReason.swipe),
        child: surface,
      ),
    );
    final framed = Padding(
      padding:
          widget.margin ??
          bar.insetPadding ??
          const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: widget.width == null
          ? message
          : SizedBox(width: widget.width, child: message),
    );
    if (reduce) return framed;
    return AnimatedBuilder(
      animation: widget.animation!,
      child: framed,
      builder: (context, child) {
        // One curve keeps position and opacity continuous when reversed early.
        final progress = Curves.easeInOutCubic.transform(
          widget.animation!.value.clamp(0.0, 1.0),
        );
        return Opacity(
          // Paint the initial surface almost transparently to warm its first
          // raster frame before starting the animation clock.
          // At .001, the renderer rounds alpha to zero and skips paint.
          opacity: _waitingForPaint ? .01 : progress,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}
