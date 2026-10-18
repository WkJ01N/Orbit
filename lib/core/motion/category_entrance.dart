import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/core/motion/retained_page_switcher.dart';
import 'package:orbit/providers/launch_providers.dart';

/// Category waves are independent; on a main-page entrance their modules
/// participate in the parent's visible-module plan instead.
class CategoryEntranceHost extends ConsumerStatefulWidget {
  const CategoryEntranceHost({
    super.key,
    required this.transition,
    required this.child,
  });
  final PageTransitionData transition;
  final Widget child;
  @override
  ConsumerState<CategoryEntranceHost> createState() =>
      _CategoryEntranceHostState();
}

class _CategoryEntranceHostState extends ConsumerState<CategoryEntranceHost>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    value: 1,
  );
  late final _modules = ModuleEntrance(_clock);
  Animation<double>? _waiting;
  int _generation = 0;
  bool get _allowed =>
      widget.transition.active &&
      ref.read(launchAnimationsEnabledProvider) &&
      ref.read(launchSettingsProvider).onPageSwitch &&
      ref.read(launchSettingsProvider).pageEnabled[3] &&
      !MediaQuery.disableAnimationsOf(context);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _modules.setParent(ModuleEntranceScope.maybeOf(context));
  }

  void _detach() {
    _waiting?.removeListener(_check);
    _waiting = null;
  }

  @override
  void didUpdateWidget(CategoryEntranceHost old) {
    super.didUpdateWidget(old);
    if (!widget.transition.active) {
      _generation++;
      _detach();
      _modules.pause();
      return;
    }
    if (old.transition.epoch == widget.transition.epoch) return;
    if (!_allowed) {
      _detach();
      _modules.finish();
      return;
    }
    if (widget.transition.continuing && !_modules.pending) {
      _modules.resume();
      return;
    }
    _arm();
  }

  void _arm() {
    _detach();
    _modules.reset(fromDirection: widget.transition.direction);
    _waiting = widget.transition.animation;
    _waiting!.addListener(_check);
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) _check();
    });
  }

  void _check() {
    if (!_allowed) {
      _detach();
      _modules.finish();
      return;
    }
    if (_waiting!.value < .5) return;
    _detach();
    if (!_modules.pending) return;
    final box = context.findRenderObject() as RenderBox;
    _modules.start(box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    // Newly visited categories do not receive didUpdateWidget on their first wave.
    if (widget.transition.epoch > 0 &&
        widget.transition.active &&
        !_modules.prepared &&
        !_modules.pending &&
        _generation == 0 &&
        _allowed) {
      _arm();
    }
    return AnimatedBuilder(
      animation: _modules,
      child: ModuleEntranceScope(
        motion: _modules,
        child: Listener(
          onPointerDown: (_) => _modules.sealLate(),
          onPointerSignal: (_) => _modules.sealLate(),
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (event) {
              if (event.dragDetails != null) _modules.sealLate();
              return false;
            },
            child: widget.child,
          ),
        ),
      ),
      builder: (context, child) =>
          Opacity(opacity: _modules.pending ? 0 : 1, child: child),
    );
  }

  @override
  void dispose() {
    _detach();
    _modules.dispose();
    _clock.dispose();
    super.dispose();
  }
}
