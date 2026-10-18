import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/motion/launch_motion.dart';
import 'package:orbit/features/deadline/deadline_strong_host.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:orbit/providers/notification_providers.dart';

class PageEntranceRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  Duration returnDelay = const Duration(milliseconds: 320);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) {
      returnDelay =
          route.reverseTransitionDuration + const Duration(milliseconds: 16);
    }
    super.didPop(route, previousRoute);
  }
}

final pageEntranceRoutes = PageEntranceRouteObserver();

/// One activation produces one entrance, after navigation has settled. Kept
/// pages retain their controllers, scroll positions, and form state.
class PageEntranceHost extends ConsumerStatefulWidget {
  const PageEntranceHost({
    super.key,
    required this.index,
    required this.active,
    required this.child,
    this.startup = true,
  });
  final int index;
  final bool active;
  final bool startup;
  final Widget child;
  @override
  ConsumerState<PageEntranceHost> createState() => _PageEntranceHostState();
}

class _PageEntranceHostState extends ConsumerState<PageEntranceHost>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late final AnimationController _controller;
  LaunchMotion? _gridMotion;
  PageRoute<dynamic>? _route;
  Timer? _pending;
  bool _background = false, _initialized = false;
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: 1,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      pageEntranceRoutes.unsubscribe(this);
      _route = route;
      pageEntranceRoutes.subscribe(this, route);
    }
    if (!_initialized) {
      _initialized = true;
      final settings = ref.read(launchSettingsProvider);
      if (widget.index == 0 &&
          (!settings.onStartup || !settings.pageEnabled[0])) {
        _gridMotion = LaunchMotion(vsync: this, settings: settings)..finish();
      }
      if (widget.active &&
          widget.startup &&
          widget.index != 0 &&
          settings.onStartup) {
        _queue(const Duration(milliseconds: 480));
      } else if (widget.active && !widget.startup && settings.onPageSwitch) {
        _queue(const Duration(milliseconds: 270));
      }
    }
  }

  void _finish() {
    _pending?.cancel();
    _controller.value = 1;
    _gridMotion?.finish();
  }

  void _queue(Duration delay) {
    _pending?.cancel();
    if (!_allowed) return;
    _pending = Timer(delay, () {
      if (!_allowed) return;
      if (widget.index == 0) {
        final old = _gridMotion;
        final next = LaunchMotion(
          vsync: this,
          settings: ref.read(launchSettingsProvider),
          startup: false,
        );
        setState(() => _gridMotion = next);
        // Descendants must first detach listeners from the previous clock.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          old?.dispose();
          if (mounted && identical(_gridMotion, next) && _allowed) {
            next.timeline.forward(from: 500 / 1150);
          }
        });
      } else {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void didUpdateWidget(PageEntranceHost old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      _finish();
      if (widget.active && ref.read(launchSettingsProvider).onPageSwitch) {
        _queue(const Duration(milliseconds: 270));
      }
    }
  }

  @override
  void didPushNext() => _finish();
  @override
  void didPopNext() {
    if (ref.read(launchSettingsProvider).onPageSwitch) {
      _queue(pageEntranceRoutes.returnDelay);
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
      if (ref.read(launchSettingsProvider).onResume) _queue(Duration.zero);
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    pageEntranceRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
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
      if (!next.pageEnabled[widget.index]) _finish();
    });
    final settings = ref.watch(launchSettingsProvider);
    Widget child = widget.child;
    if (widget.index == 0 && _gridMotion != null) {
      child = LaunchMotionScope(motion: _gridMotion!, child: child);
    }
    if (widget.index == 0) return child;
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final progress =
            settings.pageEnabled[widget.index] &&
                !MediaQuery.disableAnimationsOf(context)
            ? Curves.easeOutCubic.transform(_controller.value)
            : 1.0;
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}
