import 'package:flutter/material.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/models/background_settings.dart';

/// The configuration belongs to a route, including while that route exits.
class BackgroundRouteSnapshot {
  const BackgroundRouteSnapshot(this.owner, this.settings);
  final BackgroundPage owner;
  final BackgroundSettings settings;
  bool get hasBackground => settings.asset(owner) != null;
}

class BackgroundRouteObserver extends NavigatorObserver with ChangeNotifier {
  BackgroundPage Function()? mainPage;
  BackgroundSettings Function()? settingsSnapshot;
  final _routes = <Route<dynamic>>[];
  final _paintRoutes = <PageRoute<dynamic>>[];
  final _snapshots = <Route<dynamic>, BackgroundRouteSnapshot>{};
  PageRoute<dynamic>? _primary;
  bool _pending = false;
  bool _disposed = false;

  PageRoute<dynamic>? get _page =>
      _routes.whereType<PageRoute<dynamic>>().lastOrNull;
  bool get secondary => _page != null && _page != _primary;
  BackgroundSettings? get capturedSettings => snapshotFor(_page)?.settings;
  BackgroundPage get owner =>
      snapshotFor(_page)?.owner ?? mainPage?.call() ?? BackgroundPage.grid;

  BackgroundRouteSnapshot? snapshotFor(Route<dynamic>? route) =>
      route == _primary || route?.settings.name == 'orbit-background-editor'
      ? null
      : _snapshots[route];

  /// Navigator.didPop runs before the reverse animation. The media plane must
  /// continue to serve the exiting page until its overlay has been removed.
  BackgroundRouteSnapshot? get paintingSnapshot =>
      snapshotFor(_paintRoutes.lastOrNull);
  bool get editing =>
      _paintRoutes.lastOrNull?.settings.name == 'orbit-background-editor';
  bool get hasPaintedBackground => _paintRoutes.any((route) {
    if (route.settings.name == 'orbit-background-editor') return false;
    if (route == _primary) {
      return settingsSnapshot?.call().asset(
            mainPage?.call() ?? BackgroundPage.grid,
          ) !=
          null;
    }
    return _snapshots[route]?.hasBackground ?? false;
  });

  void _changed() {
    if (_pending || _disposed) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!_disposed) notifyListeners();
    });
  }

  void _forget(Route<dynamic> route) {
    _snapshots.remove(route);
    _paintRoutes.remove(route);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final origin = owner;
    final settings = capturedSettings ?? settingsSnapshot?.call();
    _routes.add(route);
    if (route is PageRoute<dynamic>) {
      _primary ??= route;
      _paintRoutes.add(route);
      if (settings != null) {
        _snapshots[route] = BackgroundRouteSnapshot(
          route.settings.arguments is BackgroundPage
              ? route.settings.arguments as BackgroundPage
              : origin,
          settings,
        );
      }
    }
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    if (route is PageRoute<dynamic>) {
      route.completed.then((_) {
        if (_disposed) return;
        _forget(route);
        _changed();
      });
    }
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _forget(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final snapshot = _snapshots[oldRoute];
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    final paintIndex = oldRoute is PageRoute<dynamic>
        ? _paintRoutes.indexOf(oldRoute)
        : -1;
    _routes.remove(oldRoute);
    if (oldRoute != null) _forget(oldRoute);
    if (newRoute != null) {
      _routes.insert(index < 0 ? _routes.length : index, newRoute);
      if (newRoute is PageRoute<dynamic>) {
        _paintRoutes.insert(
          paintIndex < 0 ? _paintRoutes.length : paintIndex,
          newRoute,
        );
        if (oldRoute == _primary) _primary = newRoute;
        if (snapshot != null) _snapshots[newRoute] = snapshot;
      }
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A stable ancestor of Navigator; page-specific themes live inside each route.
class BackgroundRouteBinding
    extends InheritedNotifier<BackgroundRouteObserver> {
  const BackgroundRouteBinding({
    required BackgroundRouteObserver routes,
    required super.child,
    super.key,
  }) : super(notifier: routes);

  static BackgroundRouteObserver? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BackgroundRouteBinding>()
      ?.notifier;
}

class _BackgroundRouteTheme extends StatefulWidget {
  const _BackgroundRouteTheme({required this.route, required this.child});
  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_BackgroundRouteTheme> createState() => _BackgroundRouteThemeState();
}

class _BackgroundRouteThemeState extends State<_BackgroundRouteTheme> {
  BackgroundRouteSnapshot? _snapshot;
  Widget? _content;
  Widget? _wrapped;

  @override
  Widget build(BuildContext context) {
    final snapshot = BackgroundRouteBinding.maybeOf(
      context,
    )?.snapshotFor(widget.route);
    // MaterialPageRoute calls buildTransitions on each animation tick. Reuse
    // its themed content rather than copying ThemeData on every tick.
    if (_wrapped == null ||
        !identical(snapshot, _snapshot) ||
        !identical(widget.child, _content)) {
      _snapshot = snapshot;
      _content = widget.child;
      _wrapped = RepaintBoundary(
        child: snapshot == null
            ? widget.child
            : BackgroundPageTheme(
                settings: snapshot.settings,
                owner: snapshot.owner,
                child: widget.child,
              ),
      );
    }
    return _wrapped!;
  }
}

/// Keep Flutter's native motion and predictive back. Its default transition
/// surfaces would otherwise cover the media plane outside Navigator.
class BackgroundPageTransitionsBuilder extends PageTransitionsBuilder {
  const BackgroundPageTransitionsBuilder({required this.platform});
  final TargetPlatform platform;

  PageTransitionsBuilder _delegate(BuildContext context) {
    final transparent =
        BackgroundRouteBinding.maybeOf(context)?.hasPaintedBackground ?? false;
    return platform == TargetPlatform.android
        ? PredictiveBackPageTransitionsBuilder(
            fallbackColor: transparent ? Colors.transparent : null,
          )
        : _BackgroundZoomTransitionsBuilder(showScrim: !transparent);
  }

  @override
  Duration get transitionDuration => platform == TargetPlatform.android
      ? const PredictiveBackPageTransitionsBuilder().transitionDuration
      : const ZoomPageTransitionsBuilder().transitionDuration;

  @override
  DelegatedTransitionBuilder get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          _delegate(context).delegatedTransition?.call(
            context,
            animation,
            secondaryAnimation,
            allowSnapshotting,
            child,
          );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _delegate(context).buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    _BackgroundRouteTheme(route: route, child: child),
  );
}

// Zoom motion adapted from Flutter's material/page_transitions_theme.dart.
// Copyright 2014 The Flutter Authors. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
//       copyright notice, this list of conditions and the following
//       disclaimer in the documentation and/or other materials provided
//       with the distribution.
//     * Neither the name of Google Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
// ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

/// Flutter's zoom painter replaces the color's alpha when painting its scrim,
/// so even Colors.transparent becomes an opaque black overlay. Keep its motion
/// but omit that paint entirely for wallpaper routes. RepaintBoundary in the
/// route child lets these compositor animations reuse the page's display list.
class _BackgroundZoomTransitionsBuilder extends PageTransitionsBuilder {
  const _BackgroundZoomTransitionsBuilder({required this.showScrim});
  final bool showScrim;

  Widget _behind(
    BuildContext context,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) => DualTransitionBuilder(
    animation: ReverseAnimation(secondaryAnimation),
    forwardBuilder: (context, animation, child) => _ZoomMotion(
      animation: animation,
      entering: true,
      reverse: true,
      child: child,
    ),
    reverseBuilder: (context, animation, child) =>
        _ZoomMotion(animation: animation, entering: false, child: child),
    child: child,
  );

  @override
  DelegatedTransitionBuilder get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          _behind(context, secondaryAnimation, child);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => DualTransitionBuilder(
    animation: animation,
    forwardBuilder: (context, animation, child) => _ZoomMotion(
      animation: animation,
      entering: true,
      showScrim: showScrim,
      child: child,
    ),
    reverseBuilder: (context, animation, child) => _ZoomMotion(
      animation: animation,
      entering: false,
      reverse: true,
      child: child,
    ),
    child: _behind(context, secondaryAnimation, child),
  );
}

class _ZoomMotion extends StatelessWidget {
  const _ZoomMotion({
    required this.animation,
    required this.entering,
    this.reverse = false,
    this.showScrim = false,
    this.child,
  });
  final Animation<double> animation;
  final bool entering, reverse, showScrim;
  final Widget? child;

  // Match ZoomPageTransitionsBuilder's two-stage scale and fade intervals.
  static final _curve = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: .4,
      ).chain(CurveTween(curve: const Cubic(.05, 0, .133333, .06))),
      weight: .166666,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: .4,
        end: 1.0,
      ).chain(CurveTween(curve: const Cubic(.208333, .82, .25, 1))),
      weight: 1 - .166666,
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: entering ? (reverse ? 1.1 : .85) : 1,
      end: entering ? 1 : (reverse ? .9 : 1.05),
    ).chain(_curve).animate(animation);
    final fade = entering && !reverse
        ? Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: const Interval(.125, .25)))
              .animate(animation)
        : !entering && reverse
        ? Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: const Interval(.0825, .2075)))
              .animate(animation)
        : kAlwaysCompleteAnimation;
    final color = Theme.of(context).colorScheme.surface;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => ColoredBox(
        color: showScrim && !animation.isCompleted
            ? color.withValues(
                alpha:
                    const Interval(.2075, .4175).transform(animation.value) *
                    .6,
              )
            : Colors.transparent,
        child: child,
      ),
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          filterQuality: FilterQuality.medium,
          child: child,
        ),
      ),
    );
  }
}
