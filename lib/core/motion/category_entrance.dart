import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
      widget.transition.fluid &&
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
    _arm();
  }

  void _arm() {
    _detach();
    _modules.follow(
      widget.transition.animation,
      duration: widget.transition.duration,
      fromDirection: widget.transition.direction,
      continuing: widget.transition.continuing,
    );
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
    _detach();
    if (!_modules.pending) return;
    final generation = _generation;
    void prepare() {
      if (!mounted || generation != _generation || !_modules.pending) return;
      if (!_allowed) {
        _modules.finish();
        return;
      }
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        _modules.start(box.localToGlobal(Offset.zero) & box.size);
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.postFrameCallbacks) {
      prepare();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => prepare());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(launchSettingsProvider, (_, next) {
      if (!next.pageEnabled[3] || !next.onPageSwitch) {
        _generation++;
        _detach();
        _modules.finish();
      }
    });
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
      builder: (context, child) => Opacity(
        opacity: _modules.pending && _modules.gatePage ? 0 : 1,
        child: child,
      ),
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
