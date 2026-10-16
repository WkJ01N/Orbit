import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/providers/background_providers.dart';
import 'package:orbit/providers/navigation_providers.dart';
import 'package:orbit/core/background/background_media.dart';
import 'package:orbit/core/background/background_scope.dart';

/// Full-page routes capture their originating tab; popup routes leave the owner alone.
class BackgroundRouteObserver extends NavigatorObserver with ChangeNotifier {
  BackgroundPage Function()? mainPage;
  BackgroundSettings Function()? settingsSnapshot;
  final _routes = <Route<dynamic>>[];
  final _owners = <Route<dynamic>, BackgroundPage>{};
  final _snapshots = <Route<dynamic>, BackgroundSettings>{};
  PageRoute<dynamic>? get _page =>
      _routes.whereType<PageRoute<dynamic>>().lastOrNull;
  bool get secondary => _routes.whereType<PageRoute<dynamic>>().length > 1;
  bool get editing => _page?.settings.name == 'orbit-background-editor';
  BackgroundSettings? get capturedSettings =>
      secondary ? _snapshots[_page] : null;
  BackgroundPage get owner => secondary
      ? _owners[_page] ?? BackgroundPage.grid
      : mainPage?.call() ?? BackgroundPage.grid;
  void _changed() => WidgetsBinding.instance.addPostFrameCallback((_) {
    notifyListeners();
  });
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final origin = owner;
    final snapshot = capturedSettings ?? settingsSnapshot?.call();
    _routes.add(route);
    if (snapshot != null) _snapshots[route] = snapshot;
    _owners[route] = route.settings.arguments is BackgroundPage
        ? route.settings.arguments as BackgroundPage
        : origin;
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _owners.remove(route);
    _snapshots.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _owners.remove(route);
    _snapshots.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final origin = _owners[oldRoute] ?? owner;
    final snapshot = _snapshots[oldRoute] ?? capturedSettings;
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    _routes.remove(oldRoute);
    _owners.remove(oldRoute);
    _snapshots.remove(oldRoute);
    if (newRoute != null) {
      _routes.insert(index < 0 ? _routes.length : index, newRoute);
      _owners[newRoute] = origin;
      if (snapshot != null) _snapshots[newRoute] = snapshot;
    }
    _changed();
  }
}

class BackgroundHost extends ConsumerWidget {
  const BackgroundHost({required this.routes, required this.child, super.key});
  final BackgroundRouteObserver routes;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedSettings =
        ref.watch(backgroundSettingsProvider).valueOrNull ??
        const BackgroundSettings();
    final index = ref.watch(appNavIndexProvider);
    return ListenableBuilder(
      listenable: routes,
      builder: (context, _) {
        final settings = routes.capturedSettings ?? savedSettings;
        final owner = routes.secondary
            ? routes.owner
            : BackgroundPage.values[index.clamp(0, 3)];
        final asset = settings.asset(owner);
        final plane = asset == null
            ? const SizedBox.expand(key: ValueKey('background-none'))
            : BackgroundMedia(
                key: ValueKey(settings.continuityKey(owner)),
                asset: asset,
                framing: settings.resolved(owner).framing,
                service: ref.read(backgroundAssetServiceProvider),
                animate: settings.animate,
                active: !routes.editing,
              );
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BackgroundTransition(
                identity: settings.continuityKey(owner),
                page: owner.index,
                child: plane,
              ),
              routes.secondary && !routes.editing
                  ? BackgroundPageTheme(
                      settings: settings,
                      owner: owner,
                      child: child,
                    )
                  : child,
            ],
          ),
        );
      },
    );
  }
}

class BackgroundTransition extends StatefulWidget {
  const BackgroundTransition({
    super.key,
    required this.identity,
    required this.page,
    required this.child,
  });
  final String identity;
  final int page;
  final Widget child;
  @override
  State<BackgroundTransition> createState() => _BackgroundTransitionState();
}

class _BackgroundTransitionState extends State<BackgroundTransition>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
        value: 1,
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed && _previous != null) {
          setState(() => _previous = null);
        }
      });
  Widget? _previous;
  String? _previousIdentity;
  int _direction = 1;
  @override
  void didUpdateWidget(BackgroundTransition old) {
    super.didUpdateWidget(old);
    if (old.identity != widget.identity) {
      _previous = old.child;
      _previousIdentity = old.identity;
      _direction = widget.page >= old.page ? 1 : -1;
      _controller.forward(from: 0);
    } else if (old.page != widget.page && _controller.isAnimating) {
      _previous = null;
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final progress = MediaQuery.disableAnimationsOf(context)
          ? 1.0
          : Curves.easeOutCubic.transform(_controller.value);
      Widget layer(Widget child, String identity, {required bool incoming}) =>
          KeyedSubtree(
            key: ValueKey(identity),
            child: Opacity(
              opacity: incoming ? 1 : 1 - progress,
              child: Transform.translate(
                offset: Offset(
                  incoming
                      ? _direction * (1 - progress) * 14
                      : -_direction * progress * 6,
                  0,
                ),
                child: Transform.scale(
                  scale: incoming ? .996 + progress * .004 : 1,
                  child: child,
                ),
              ),
            ),
          );
      return Stack(
        fit: StackFit.expand,
        children: [
          layer(widget.child, widget.identity, incoming: true),
          if (_previous != null && progress < 1)
            layer(_previous!, _previousIdentity!, incoming: false),
        ],
      );
    },
  );
}
