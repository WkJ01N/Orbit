import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Owns a cached category's scrolling independently of its entrance animation.
/// Cancelling the outgoing drag emits ScrollEndNotification so the native
/// overscroll spring can return while the surrounding page layer fades out.
class SettingsCategoryViewport extends StatefulWidget {
  const SettingsCategoryViewport({
    super.key,
    required this.active,
    required this.scrollKey,
    required this.children,
  });

  final bool active;
  final Key scrollKey;
  final List<Widget> children;

  @override
  State<SettingsCategoryViewport> createState() =>
      _SettingsCategoryViewportState();
}

class _SettingsCategoryViewportState extends State<SettingsCategoryViewport> {
  final _scroll = ScrollController();
  final _pointers = <int>{};
  int _session = 0;

  void _cancelPointers() {
    final pointers = _pointers.toList();
    _pointers.clear();
    for (final pointer in pointers) {
      GestureBinding.instance.cancelPointer(pointer);
    }
  }

  @override
  void didUpdateWidget(SettingsCategoryViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    final session = ++_session;
    if (widget.active) return;
    _cancelPointers();
    // Do not deliver scroll notifications while the retained layer is building.
    // A rapid reversal invalidates this cleanup before it can stop the new drag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || session != _session || widget.active) return;
      for (final position in _scroll.positions.toList()) {
        if (position.hasPixels) position.jumpTo(position.pixels);
      }
    });
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Listener(
      onPointerDown: (event) {
        if (widget.active) _pointers.add(event.pointer);
      },
      onPointerUp: (event) => _pointers.remove(event.pointer),
      onPointerCancel: (event) => _pointers.remove(event.pointer),
      child: ListView(
        key: widget.scrollKey,
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 24),
        children: widget.children,
      ),
    ),
  );

  @override
  void dispose() {
    _session++;
    _cancelPointers();
    _scroll.dispose();
    super.dispose();
  }
}
