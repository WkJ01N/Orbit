import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/motion/launch_motion.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/features/deadline/deadline_strong_host.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:orbit/providers/notification_providers.dart';

class PageEntranceRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final _operationRoutes = <List<Future<dynamic>>>[];
  Future<T> untilRoutesClosed<T>(Future<T> Function() operation) async {
    final routes = <Future<dynamic>>[];
    _operationRoutes.add(routes);
    try {
      final result = await operation();
      await Future.wait(routes);
      return result;
    } finally {
      _operationRoutes.remove(routes);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is TransitionRoute<dynamic>) {
      for (final scope in _operationRoutes) {
        scope.add(route.completed);
      }
    }
    super.didPush(route, previousRoute);
  }

  Duration returnDelay = const Duration(milliseconds: 320);
  Animation<double>? returningAnimation;
  bool returningWasInteractive = false;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) {
      returnDelay = route.reverseTransitionDuration;
      returningAnimation = route.animation;
      returningWasInteractive = route.navigator?.userGestureInProgress ?? false;
    }
    super.didPop(route, previousRoute);
  }
}

final pageEntranceRoutes = PageEntranceRouteObserver();

/// Prepare while the destination is still hidden; start at navigation midpoint.
class PageEntranceHost extends ConsumerStatefulWidget {
  const PageEntranceHost({
    super.key,
    required this.index,
    required this.active,
    required this.child,
    this.startup = true,
    this.secondary = false,
    this.navigation,
    this.navigationEpoch = 0,
    this.direction = 1,
    this.continuing = false,
  });
  final int index;
  final bool active, startup, secondary;
  final Widget child;
  final Animation<double>? navigation;
  final int navigationEpoch, direction;
  final bool continuing;
  @override
  ConsumerState<PageEntranceHost> createState() => _PageEntranceHostState();
}

class _PageEntranceHostState extends ConsumerState<PageEntranceHost>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    value: 1,
  );
  late final _modules = ModuleEntrance(_clock);
  LaunchMotion? _gridMotion;
  PageRoute<dynamic>? _route;
  Animation<double>? _waiting;
  bool _reverse = false, _background = false, _initialized = false;
  int _generation = 0;
  Size? _lastSize;
  bool get _grid => widget.index == 0 && !widget.secondary;
  bool get _allowed =>
      mounted &&
      widget.active &&
      (_route?.isCurrent ?? true) &&
      ref.read(launchAnimationsEnabledProvider) &&
      ref.read(launchSettingsProvider).pageEnabled[widget.index] &&
      !MediaQuery.disableAnimationsOf(context) &&
      ref.read(pendingNotificationPayloadProvider) == null &&
      !ref.read(strongConfirmationVisibleProvider) &&
      ref.read(deadlineStrongEventsProvider).isEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (_lastSize != null && _lastSize != size) _finish();
    _lastSize = size;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      pageEntranceRoutes.unsubscribe(this);
      _route = route;
      pageEntranceRoutes.subscribe(this, route);
    }
    if (!_initialized) {
      _initialized = true;
      final settings = ref.read(launchSettingsProvider);
      if (_grid && (!settings.onStartup || !settings.pageEnabled[0])) {
        _gridMotion = LaunchMotion(vsync: this, settings: settings)..finish();
      }
      if (_grid &&
          _gridMotion == null &&
          LaunchMotionScope.maybeOf(context) == null) {
        _gridMotion = LaunchMotion(vsync: this, settings: settings)..finish();
      }
      if (widget.active && widget.startup && !_grid && settings.onStartup) {
        final startup = LaunchMotionScope.maybeOf(context);
        _arm(startup?.timeline, startup: startup != null);
      } else if (widget.active && !widget.startup && settings.onPageSwitch) {
        _arm(widget.navigation ?? _route?.animation);
      }
    } else if (widget.active && !_allowed) {
      if (_route?.isCurrent == false) {
        _modules.pause();
        _gridMotion?.pause();
      } else {
        _finish();
      }
    }
  }

  void _detachWait() {
    _waiting?.removeListener(_checkProgress);
    _waiting = null;
  }

  void _finish() {
    _generation++;
    _detachWait();
    _modules.finish();
    _gridMotion?.finish();
  }

  bool _startupWait = false;
  void _arm(
    Animation<double>? navigation, {
    bool reverse = false,
    bool startup = false,
  }) {
    _detachWait();
    if (!_allowed) {
      _finish();
      return;
    }
    _generation++;
    _modules.reset(fromDirection: reverse ? -1 : widget.direction);
    _reverse = reverse;
    _startupWait = startup;
    if (_grid) {
      final old = _gridMotion;
      _gridMotion = LaunchMotion(
        vsync: this,
        settings: ref.read(launchSettingsProvider),
        startup: false,
        direction: reverse ? -1 : widget.direction,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    }
    _waiting = navigation;
    _waiting?.addListener(_checkProgress);
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) _checkProgress();
    });
  }

  void _checkProgress() {
    if (!_allowed) {
      _finish();
      return;
    }
    final animation = _waiting;
    final threshold = _startupWait ? 480 / 1150 : .5;
    final ready =
        animation == null ||
        (_reverse ? animation.value <= .5 : animation.value >= threshold);
    if (!ready) return;
    _detachWait();
    if (!_modules.pending) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _modules.start(box.localToGlobal(Offset.zero) & box.size);
    _gridMotion?.timeline.forward(from: 0);
  }

  @override
  void didUpdateWidget(PageEntranceHost old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      if (!widget.active) {
        _generation++;
        _detachWait();
        _modules.pause();
        _gridMotion?.pause();
      } else if (ref.read(launchSettingsProvider).onPageSwitch) {
        if (widget.continuing && !_modules.pending) {
          _modules.resume();
          _gridMotion?.resume();
        } else {
          _arm(widget.navigation ?? _route?.animation);
        }
      } else {
        _finish();
      }
    } else if (widget.active && old.navigationEpoch != widget.navigationEpoch) {
      if (ref.read(launchSettingsProvider).onPageSwitch && !widget.continuing) {
        _arm(widget.navigation ?? _route?.animation);
      }
    }
  }

  @override
  void didPushNext() {
    _generation++;
    _detachWait();
    _modules.pause();
    _gridMotion?.pause();
  }

  @override
  void didPopNext() {
    if (ref.read(launchSettingsProvider).onPageSwitch) {
      final returning = pageEntranceRoutes.returningAnimation;
      if (!_modules.pending &&
          (pageEntranceRoutes.returningWasInteractive ||
              (returning?.value ?? 1) < .5)) {
        _modules.resume();
        _gridMotion?.resume();
        return;
      }
      setState(
        () => _arm(pageEntranceRoutes.returningAnimation, reverse: true),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _background = true;
      _finish();
    }
    if (state == AppLifecycleState.resumed && _background) {
      _background = false;
      if (ref.read(launchSettingsProvider).onResume) setState(() => _arm(null));
    }
  }

  @override
  void dispose() {
    _detachWait();
    pageEntranceRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _modules.dispose();
    _clock.dispose();
    _gridMotion?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(strongConfirmationVisibleProvider, (_, next) {
      if (next) _finish();
    });
    ref.listen(deadlineStrongEventsProvider, (_, next) {
      if (next.isNotEmpty) _finish();
    });
    ref.listen(pendingNotificationPayloadProvider, (_, next) {
      if (next != null) _finish();
    });
    ref.listen(launchSettingsProvider, (_, next) {
      if (!next.pageEnabled[widget.index] ||
          (!_startupWait && !next.onPageSwitch)) {
        _finish();
      }
    });
    ref.listen(launchAnimationsEnabledProvider, (_, next) {
      if (!next) _finish();
    });
    Widget child = ModuleEntranceScope(
      motion: _modules,
      child: Listener(
        onPointerDown: (_) => _modules.sealLate(),
        onPointerSignal: (_) => _modules.sealLate(),
        child: NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            if (notification.dragDetails != null) _modules.sealLate();
            return false;
          },
          child: widget.child,
        ),
      ),
    );
    if (_grid) {
      child = LaunchMotionScope(
        motion: _gridMotion ?? LaunchMotionScope.maybeOf(context)!,
        child: child,
      );
    }
    return AnimatedBuilder(
      animation: _modules,
      child: child,
      builder: (_, child) => IgnorePointer(
        ignoring: _modules.pending && _modules.gatePage,
        child: Opacity(
          opacity: _modules.pending && _modules.gatePage ? 0 : 1,
          child: child,
        ),
      ),
    );
  }
}
