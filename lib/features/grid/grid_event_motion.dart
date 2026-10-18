import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:orbit/core/motion/launch_motion.dart';
import 'package:orbit/models/launch_settings.dart';

class GridMotionEvent {
  const GridMotionEvent({
    required this.id,
    required this.signature,
    required this.rect,
    required this.child,
  });
  final String id, signature;
  final Rect rect;
  final Widget child;
}

class _MotionEntry {
  _MotionEntry(
    this.event, {
    required this.serial,
    this.from = 1,
    this.to = 1,
    this.offset = 0,
    this.delay = 0,
    this.duration = 220,
    this.removing = false,
  });
  GridMotionEvent event;
  final int serial;
  final double from, to, offset, delay, duration;
  final bool removing;
  double progress(double ms) =>
      Curves.easeOutQuint.transform(((ms - delay) / duration).clamp(0.0, 1.0));
  double opacity(double ms) => from + (to - from) * progress(ms);
  double displacement(double ms) => offset * (1 - progress(ms));
}

/// Retains outgoing card widgets until their fade finishes. Domain identities
/// supplied by a save distinguish an edit from an insertion even if its ID moves.
class GridEventMotion extends StatefulWidget {
  const GridEventMotion({
    super.key,
    required this.events,
    required this.viewport,
    required this.mode,
    this.identityChanges = const {},
    this.enabled = true,
    this.animateInitial = false,
  });
  final List<GridMotionEvent> events;
  final Rect viewport;
  final CardEntranceMode mode;
  final Map<String, String> identityChanges;
  final bool enabled, animateInitial;
  @override
  State<GridEventMotion> createState() => _GridEventMotionState();
}

class _GridEventMotionState extends State<GridEventMotion>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
    value: 1,
  )..addStatusListener(_settle);
  int _serial = 0;
  late List<_MotionEntry> _entries = [
    for (final event in widget.events)
      _MotionEntry(
        event,
        serial: _serial++,
        from: widget.animateInitial && event.rect.overlaps(widget.viewport)
            ? 0
            : 1,
        duration: 480,
        offset: widget.animateInitial
            ? cardEntranceOffset(
                rect: event.rect,
                viewport: widget.viewport,
                spec: CardEntranceSpec(
                  fromAbove: event.id.hashCode.isEven,
                  delayMs: 0,
                ),
                mode: widget.mode,
              )
            : 0,
      ),
  ];
  @override
  void initState() {
    super.initState();
    if (widget.animateInitial) {
      _clock.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _enabled) _clock.forward();
      });
    }
  }

  bool get _enabled =>
      widget.enabled && !MediaQuery.disableAnimationsOf(context);
  double get _milliseconds => _clock.value * _clock.duration!.inMilliseconds;
  void _settle(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _entries.removeWhere((e) => e.removing));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) {
      _entries = [
        for (final event in widget.events)
          _MotionEntry(event, serial: _serial++),
      ];
      if (_clock.value != 1) _clock.value = 1;
    }
  }

  @override
  void didUpdateWidget(GridEventMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = {for (final event in oldWidget.events) event.id: event};
    if (!_enabled) {
      _clock.stop();
      _entries = [
        for (final event in widget.events)
          _MotionEntry(event, serial: _serial++),
      ];
      return;
    }
    if (old.length == widget.events.length &&
        widget.events.every((e) => old[e.id]?.signature == e.signature)) {
      final latest = {for (final event in widget.events) event.id: event};
      for (final entry in _entries.where((e) => !e.removing)) {
        entry.event = latest[entry.event.id] ?? entry.event;
      }
      return;
    }
    final ms = _milliseconds;
    final previous = {
      for (final entry in _entries.where((e) => !e.removing))
        entry.event.id: entry,
    };
    final next = <_MotionEntry>[];
    for (final entry in _entries.where((e) => e.removing)) {
      if (entry.opacity(ms) > .001) {
        next.add(
          _MotionEntry(
            entry.event,
            serial: _serial++,
            from: entry.opacity(ms),
            to: 0,
            removing: true,
          ),
        );
      }
    }
    final consumed = <String>{};
    final sorted = widget.events.toList()
      ..sort((a, b) {
        final y = a.rect.top.compareTo(b.rect.top);
        return y == 0 ? a.rect.left.compareTo(b.rect.left) : y;
      });
    final additions = sorted
        .where(
          (e) =>
              !old.containsKey(e.id) &&
              !widget.identityChanges.containsValue(e.id) &&
              e.rect.overlaps(widget.viewport),
        )
        .toList();
    for (final event in sorted) {
      final originalId = old.containsKey(event.id)
          ? event.id
          : widget.identityChanges.entries
                .where((e) => e.value == event.id && old.containsKey(e.key))
                .firstOrNull
                ?.key;
      final original = originalId == null ? null : old[originalId];
      if (original != null) consumed.add(original.id);
      if (original != null && original.signature == event.signature) {
        final before = previous[original.id];
        next.add(
          _MotionEntry(
            event,
            serial: before?.serial ?? _serial++,
            from: before?.opacity(ms) ?? 1,
            offset: before?.displacement(ms) ?? 0,
            duration: 480,
          ),
        );
      } else if (original != null) {
        next.add(
          _MotionEntry(
            original,
            serial: _serial++,
            from: previous[original.id]?.opacity(ms) ?? 1,
            to: 0,
            removing: true,
          ),
        );
        next.add(_MotionEntry(event, serial: _serial++, from: 0));
      } else if (event.rect.overlaps(widget.viewport)) {
        final index = additions.indexWhere((e) => e.id == event.id);
        next.add(
          _MotionEntry(
            event,
            serial: _serial++,
            from: 0,
            duration: 480,
            delay: additions.length < 2 || index < 0
                ? 0
                : index * 140 / (additions.length - 1),
            offset: cardEntranceOffset(
              rect: event.rect,
              viewport: widget.viewport,
              spec: CardEntranceSpec(
                fromAbove: event.id.hashCode.isEven,
                delayMs: 0,
              ),
              mode: widget.mode,
            ),
          ),
        );
      } else {
        next.add(_MotionEntry(event, serial: _serial++));
      }
    }
    for (final event in old.values.where((e) => !consumed.contains(e.id))) {
      next.add(
        _MotionEntry(
          event,
          serial: _serial++,
          from: previous[event.id]?.opacity(ms) ?? 1,
          to: 0,
          removing: true,
        ),
      );
    }
    _entries = next;
    _clock.duration = Duration(
      milliseconds: next
          .where((e) => e.from != e.to || e.offset != 0)
          .fold<double>(
            220,
            (duration, e) => math.max(duration, e.duration + e.delay),
          )
          .ceil(),
    );
    _clock.forward(from: 0);
  }

  @override
  void dispose() {
    _clock.removeStatusListener(_settle);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) => Stack(
      children: [
        for (final entry in _entries)
          Positioned.fromRect(
            key: ValueKey(entry.serial),
            rect: entry.event.rect,
            child: IgnorePointer(
              ignoring: entry.removing || entry.opacity(_milliseconds) < .05,
              child: ExcludeSemantics(
                excluding: entry.removing,
                child: Opacity(
                  opacity: entry.opacity(_milliseconds).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, entry.displacement(_milliseconds)),
                    child: entry.event.child,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
