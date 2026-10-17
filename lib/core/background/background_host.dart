import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/providers/background_providers.dart';
import 'package:orbit/providers/navigation_providers.dart';
import 'package:orbit/core/background/background_media.dart';
import 'package:orbit/core/background/background_routes.dart';

export 'package:orbit/core/background/background_routes.dart';

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
    return BackgroundRouteBinding(
      routes: routes,
      child: ListenableBuilder(
        listenable: routes,
        builder: (context, _) {
          final snapshot = routes.paintingSnapshot;
          final settings = snapshot?.settings ?? savedSettings;
          final owner = snapshot != null
              ? snapshot.owner
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
                  identity: asset == null
                      ? 'none'
                      : settings.continuityKey(owner),
                  page: owner.index,
                  child: plane,
                ),
                child,
              ],
            ),
          );
        },
      ),
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
  Widget build(BuildContext context) {
    final incomingPlane = RepaintBoundary(child: widget.child);
    final outgoingPlane = _previous == null
        ? null
        : RepaintBoundary(child: _previous!);
    return AnimatedBuilder(
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
            layer(incomingPlane, widget.identity, incoming: true),
            if (outgoingPlane != null && progress < 1)
              layer(outgoingPlane, _previousIdentity!, incoming: false),
          ],
        );
      },
    );
  }
}
