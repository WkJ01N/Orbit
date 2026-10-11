import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit/models/wake_text.dart';

/// Owns the gesture and clock independently of the reminder's one-second polls.
class EmergencyHoldButton extends StatefulWidget {
  const EmergencyHoldButton({
    super.key,
    required this.enabled,
    required this.onComplete,
  });
  final bool enabled;
  final Future<void> Function() onComplete;
  @override
  State<EmergencyHoldButton> createState() => _EmergencyHoldButtonState();
}

class _EmergencyHoldButtonState extends State<EmergencyHoldButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
    reverseDuration: const Duration(milliseconds: 200),
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _holding = false, _fired = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed && _holding && !_fired) {
        unawaited(_complete());
      }
    });
  }

  void _start() {
    if (!widget.enabled || _fired || _holding) return;
    setState(() => _holding = true);
    unawaited(HapticFeedback.selectionClick());
    _progress.forward(from: 0);
  }

  void _cancel({bool animate = true}) {
    if (_fired || !_holding) return;
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      _progress.reverse();
    } else {
      _progress.reset();
    }
    setState(() => _holding = false);
  }

  Future<void> _complete() async {
    _fired = true;
    unawaited(HapticFeedback.mediumImpact());
    try {
      await widget.onComplete();
    } finally {
      if (mounted) {
        _progress.reset();
        setState(() {
          _holding = false;
          _fired = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(EmergencyHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && !_fired) _cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel(animate: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WakeText.of(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: t.emergency,
      button: true,
      enabled: widget.enabled,
      child: RawGestureDetector(
        key: const Key('emergency-hold'),
        behavior: HitTestBehavior.opaque,
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: Duration.zero),
                (gesture) {
                  gesture.onLongPressStart = widget.enabled
                      ? (_) => _start()
                      : null;
                  gesture.onLongPressEnd = (_) => _cancel();
                  gesture.onLongPressCancel = _cancel;
                  gesture.onLongPressMoveUpdate = (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null &&
                        !(Offset.zero & box.size).contains(
                          details.localPosition,
                        )) {
                      _cancel();
                    }
                  };
                },
              ),
        },
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) => AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _holding
                  ? colors.errorContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _holding ? colors.error : colors.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _holding
                      ? '${t.emergency}\n${t.seconds((5 * (1 - _progress.value)).ceil())}'
                      : t.emergency,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  key: const Key('emergency-hold-progress'),
                  value: _progress.value,
                  color: colors.error,
                  backgroundColor: colors.outlineVariant,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
