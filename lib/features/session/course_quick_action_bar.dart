import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/session/quick_action_layout.dart';
import 'package:orbit/features/session/session_action_menu.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/orbit_feature_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/quick_action_providers.dart';

final activeQuickActionCourseProvider = StateProvider<String?>((ref) => null);

IconData quickActionIcon(SessionAction action) => switch (action) {
  SessionAction.edit => Icons.edit_outlined,
  SessionAction.note => Icons.sticky_note_2_outlined,
  SessionAction.archive => Icons.archive_outlined,
  SessionAction.delete => Icons.delete_outline,
};
String quickActionLabel(BuildContext context, SessionAction action) {
  final l = AppLocalizations.of(context)!;
  return switch (action) {
    SessionAction.edit => l.editSessionShort,
    SessionAction.note => l.addSessionNoteShort,
    SessionAction.archive => OrbitFeatureText.of(context).archive,
    SessionAction.delete => l.deleteSessionShort,
  };
}

class CourseQuickActionViewport extends ConsumerWidget {
  const CourseQuickActionViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    canPop: ref.watch(activeQuickActionCourseProvider) == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _activeSession?.cancel();
    },
    child: Builder(
      builder: (context) => _QuickViewport(context: context, child: child),
    ),
  );
}

class _QuickViewport extends InheritedWidget {
  const _QuickViewport({required this.context, required super.child});
  final BuildContext context;
  @override
  bool updateShouldNotify(_QuickViewport oldWidget) =>
      context != oldWidget.context;
}

class CourseQuickActionGesture extends ConsumerStatefulWidget {
  const CourseQuickActionGesture({
    super.key,
    required this.session,
    required this.child,
    required this.onFallback,
    this.enabled = true,
    this.sourceRect,
    this.preview,
  });
  final CourseSession session;
  final Widget child;
  final VoidCallback onFallback;
  final bool enabled;
  final Rect Function()? sourceRect;
  final Widget? preview;
  @override
  ConsumerState<CourseQuickActionGesture> createState() =>
      _CourseQuickActionGestureState();
}

_QuickActionSession? _activeSession;

class _CourseQuickActionGestureState
    extends ConsumerState<CourseQuickActionGesture> {
  _QuickActionSession? _session;
  void _start(LongPressStartDetails details) {
    if (!widget.enabled) return;
    final settings = ref.read(courseQuickActionsProvider);
    final phone =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!phone ||
        MediaQuery.sizeOf(context).width >= 600 ||
        !settings.enabled) {
      widget.onFallback();
      return;
    }
    final sourceBox = context.findRenderObject() as RenderBox;
    final viewportContext = context
        .dependOnInheritedWidgetOfExactType<_QuickViewport>()
        ?.context;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    final source =
        widget.sourceRect?.call() ??
        (sourceBox.localToGlobal(Offset.zero) & sourceBox.size);
    final viewport = viewportBox == null
        ? Offset.zero & MediaQuery.sizeOf(context)
        : viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    _activeSession?.close();
    final container = ProviderScope.containerOf(context);
    final navigatorContext = Navigator.of(context).context;
    final session = _QuickActionSession(container, widget.session);
    _session = session;
    _activeSession = session;
    final layout = QuickActionLayout(
      viewport: viewport,
      source: source,
      settings: settings,
    );
    final themes = InheritedTheme.capture(
      from: context,
      to: Overlay.of(context).context,
    );
    session.entry = OverlayEntry(
      builder: (_) => themes.wrap(
        _QuickActionOverlay(
          key: session.key,
          layout: layout,
          preview: widget.preview ?? widget.child,
          pointerOrigin: details.globalPosition,
          onCancel: session.close,
        ),
      ),
    );
    Overlay.of(context).insert(session.entry!);
    container.read(activeQuickActionCourseProvider.notifier).state =
        widget.session.id;
    session.navigation = container.listen(
      appNavIndexProvider,
      (_, _) => session.close(),
    );
    session.perform = (action) => SessionActionMenu.perform(
      context: navigatorContext,
      ref: ref,
      session: widget.session,
      action: action,
    );
  }

  @override
  void dispose() {
    if (_session?.committed != true) _session?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden =
        ref.watch(activeQuickActionCourseProvider) == widget.session.id;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: _start,
      onLongPressMoveUpdate: (details) =>
          _session?.key.currentState?.move(details.globalPosition),
      onLongPressEnd: (_) => unawaited(_session?.release() ?? Future.value()),
      onLongPressCancel: () => _session?.cancel(),
      child: Opacity(opacity: hidden ? 0 : 1, child: widget.child),
    );
  }
}

class _QuickActionSession {
  _QuickActionSession(this.container, this.original);
  final ProviderContainer container;
  final CourseSession original;
  String get courseId => original.id;
  final key = GlobalKey<_QuickActionOverlayState>();
  OverlayEntry? entry;
  ProviderSubscription<int>? navigation;
  Future<bool> Function(SessionAction)? perform;
  bool committed = false, closed = false;
  void close() {
    if (closed) return;
    closed = true;
    navigation?.close();
    entry?.remove();
    entry?.dispose();
    entry = null;
    if (identical(_activeSession, this)) _activeSession = null;
    void clearSelection() {
      try {
        if (container.read(activeQuickActionCourseProvider) == courseId) {
          container.read(activeQuickActionCourseProvider.notifier).state = null;
        }
      } on StateError {
        /* The app/provider container was already disposed. */
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      scheduleMicrotask(clearSelection);
    } else {
      clearSelection();
    }
  }

  void cancel() {
    if (!committed) unawaited(_cancel());
  }

  Future<void> _cancel() async {
    await key.currentState?.finish();
    close();
  }

  Future<void> release() async {
    if (closed || committed) return;
    final action = key.currentState?.selected;
    if (action == null) {
      await _cancel();
      return;
    }
    committed = true;
    key.currentState?.commit(action);
    var deleted = false;
    var changed = false;
    try {
      deleted = await perform!(action);
      if (!closed && !deleted) {
        var courses = container.read(sessionsProvider).valueOrNull;
        if (container.read(sessionsProvider).isLoading) {
          await Future.wait([
            container.read(sessionsProvider.future),
            container.read(deadlinesProvider.future),
          ]);
          courses = container.read(sessionsProvider).valueOrNull;
        }
        final id =
            container.read(scheduleIdentityChangesProvider)[courseId] ??
            courseId;
        final updated = courses?.where((s) => s.id == id).firstOrNull;
        deleted = courses != null && (updated == null || !updated.visible);
        changed =
            updated != null &&
            updated.toMap().toString() != original.toMap().toString();
        if (changed &&
            !deleted &&
            container.read(activeQuickActionCourseProvider) == courseId) {
          container.read(activeQuickActionCourseProvider.notifier).state = null;
        }
      }
    } catch (error) {
      debugPrint('Course quick action failed: $error');
    } finally {
      await key.currentState?.finish(deleted: deleted, changed: changed);
      close();
    }
  }
}

class _QuickActionOverlay extends StatefulWidget {
  const _QuickActionOverlay({
    super.key,
    required this.layout,
    required this.preview,
    required this.pointerOrigin,
    required this.onCancel,
  });
  final QuickActionLayout layout;
  final Widget preview;
  final Offset pointerOrigin;
  final VoidCallback onCancel;
  @override
  State<_QuickActionOverlay> createState() => _QuickActionOverlayState();
}

class _QuickActionOverlayState extends State<_QuickActionOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _buttons = List.generate(
    4,
    (_) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    ),
  );
  late final _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: 1,
  );
  late final _copyFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  final _timers = <Timer>[];
  Map<SessionAction, double> _from = {}, _to = {};
  SessionAction? selected;
  bool _moved = false, _committed = false, _finishing = false;
  Size? _window;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (_window != null && _window != size) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onCancel());
      return;
    }
    if (_window == null) {
      if (_reduced) {
        _lift.value = 1;
        for (final button in _buttons) {
          button.value = 1;
        }
      } else {
        _lift.forward();
        for (var i = 0; i < 4; i++) {
          _timers.add(
            Timer(Duration(milliseconds: i * 35), () {
              if (mounted && !_committed && !_finishing) _buttons[i].forward();
            }),
          );
        }
      }
    }
    _window = size;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      widget.onCancel();
    }
  }

  Map<SessionAction, double> _lightValues() => {
    for (final action in SessionAction.values)
      action:
          (_from[action] ?? 0) +
          ((_to[action] ?? 0) - (_from[action] ?? 0)) *
              Curves.easeOutCubic.transform(_glow.value),
  };
  void _select(SessionAction? action) {
    if (selected == action) return;
    _from = _lightValues();
    _to = {?action: 1};
    selected = action;
    if (_reduced) {
      _glow.value = 1;
    } else {
      _glow.forward(from: 0);
    }
    setState(() {});
  }

  void move(Offset point) {
    if (_committed || _finishing) return;
    _moved |= (point - widget.pointerOrigin).distance >= 10;
    if (widget.layout.floating && !_moved) return;
    _select(widget.layout.hitTest(point, previous: selected)?.action);
  }

  void commit(SessionAction action) {
    _committed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    for (final cell in widget.layout.cells) {
      if (cell.action == action) {
        _buttons[cell.direction].forward();
      } else if (_reduced) {
        _buttons[cell.direction].value = 0;
      } else {
        _buttons[cell.direction].reverse();
      }
    }
  }

  Future<void> finish({bool deleted = false, bool changed = false}) async {
    if (!mounted || _finishing) return;
    _finishing = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _select(null);
    if (_reduced) return;
    try {
      if (deleted) {
        await _fade.reverse().orCancel;
      } else {
        await Future.wait([
          if (changed) _copyFade.reverse().orCancel,
          _lift.reverse().orCancel,
          for (final button in _buttons) button.reverse().orCancel,
        ]);
      }
    } on TickerCanceled {
      /* Overlay was dismissed by navigation or lifecycle. */
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _timers) {
      timer.cancel();
    }
    for (final button in _buttons) {
      button.dispose();
    }
    _lift.dispose();
    _fade.dispose();
    _glow.dispose();
    _copyFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            ..._buttons,
            _lift,
            _fade,
            _glow,
            _copyFade,
          ]),
          builder: (context, _) {
            final lift = Curves.easeOutCubic.transform(_lift.value);
            final rect = layout.floating
                ? Rect.lerp(layout.source, layout.card, lift)!
                : layout.source;
            return Opacity(
              opacity: _fade.value,
              child: ClipPath(
                clipper: _QuickViewportClip(layout.viewport),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _QuickGlowPainter(
                          layout,
                          _lightValues(),
                          colors.primary,
                          colors.error,
                        ),
                      ),
                    ),
                    for (final cell in layout.cells)
                      Builder(
                        builder: (context) {
                          final progress = Curves.easeOutCubic.transform(
                            _buttons[cell.direction].value,
                          );
                          final slot = Rect.fromCenter(
                            center: Offset.lerp(
                              layout.source.center,
                              cell.slot.center,
                              progress,
                            )!,
                            width: cell.slot.width,
                            height: cell.slot.height,
                          );
                          final highlight = _lightValues()[cell.action] ?? 0;
                          final color = cell.action == SessionAction.delete
                              ? colors.error
                              : colors.primary;
                          return Positioned.fromRect(
                            rect: slot,
                            child: Opacity(
                              opacity: progress,
                              child: Transform.scale(
                                scale: .8 + .2 * progress + highlight * .06,
                                child: Material(
                                  key: Key(
                                    'course-quick-action-${cell.action.name}',
                                  ),
                                  elevation: 6 + highlight * 6,
                                  color: Color.lerp(
                                    colors.surfaceContainerHigh,
                                    color,
                                    highlight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          quickActionIcon(cell.action),
                                          size: 20,
                                          color: Color.lerp(
                                            color,
                                            colors.onPrimary,
                                            highlight,
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            quickActionLabel(
                                              context,
                                              cell.action,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color.lerp(
                                                colors.onSurface,
                                                colors.onPrimary,
                                                highlight,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    Positioned.fromRect(
                      rect: rect,
                      child: Opacity(
                        opacity: _copyFade.value,
                        child: Material(
                          elevation: layout.floating ? 14 * lift : 5,
                          shadowColor: Colors.black.withValues(alpha: .45),
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          clipBehavior: Clip.antiAlias,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: layout.source.width,
                              height: layout.source.height,
                              child: widget.preview,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuickGlowPainter extends CustomPainter {
  _QuickGlowPainter(this.layout, this.values, this.color, this.error);
  final QuickActionLayout layout;
  final Map<SessionAction, double> values;
  final Color color, error;
  @override
  void paint(Canvas canvas, Size size) {
    final viewport = layout.viewport;
    canvas.save();
    canvas.clipRect(viewport);
    for (final cell in layout.cells) {
      final opacity = values[cell.action] ?? 0;
      if (opacity < .001) continue;
      final tint = cell.action == SessionAction.delete ? error : color;
      for (final edge in cell.edges) {
        final rect = switch (edge.side) {
          0 => Rect.fromLTRB(
            edge.start,
            viewport.top - 9,
            edge.end,
            viewport.top + 5,
          ),
          1 => Rect.fromLTRB(
            viewport.right - 5,
            edge.start,
            viewport.right + 9,
            edge.end,
          ),
          2 => Rect.fromLTRB(
            edge.start,
            viewport.bottom - 5,
            edge.end,
            viewport.bottom + 9,
          ),
          _ => Rect.fromLTRB(
            viewport.left - 9,
            edge.start,
            viewport.left + 5,
            edge.end,
          ),
        };
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(16)),
          Paint()
            ..color = tint.withValues(alpha: opacity * .7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(5), const Radius.circular(12)),
          Paint()
            ..color = tint.withValues(alpha: opacity * .6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_QuickGlowPainter oldDelegate) => true;
}

class _QuickViewportClip extends CustomClipper<Path> {
  const _QuickViewportClip(this.viewport);
  final Rect viewport;
  @override
  Path getClip(Size size) => Path()..addRect(viewport);
  @override
  bool shouldReclip(_QuickViewportClip oldClipper) =>
      oldClipper.viewport != viewport;
}
