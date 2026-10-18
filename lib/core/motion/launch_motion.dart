import 'package:orbit/models/typography_settings.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/providers/typography_providers.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/deadline/deadline_strong_host.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:orbit/providers/notification_providers.dart';
import 'package:orbit/providers/navigation_providers.dart';
import 'package:orbit/providers/reminder_providers.dart'
    show themeColorProvider;

const orbitBrandFont = 'OrbitBrand';
const orbitIconAsset = 'assets/icons/orbit.png';

double launchProgress(double milliseconds, double start, double duration) =>
    ((milliseconds - start) / duration).clamp(0.0, 1.0);

class CardEntranceSpec {
  const CardEntranceSpec({required this.fromAbove, required this.delayMs});
  final bool fromAbove;
  final double delayMs;
}

/// Balance each date column and the complete batch, while shuffling directions
/// and start order independently. A supplied Random makes tests reproducible.
Map<String, CardEntranceSpec> planCardEntrances(
  Map<int, List<String>> columns, {
  required math.Random random,
  List<String>? visualOrder,
}) {
  final directions = <String, bool>{};
  var extraAbove = random.nextBool();
  for (final ids in columns.values) {
    final shuffled = ids.toList()..shuffle(random);
    final aboveCount =
        ids.length ~/ 2 + (ids.length.isOdd && extraAbove ? 1 : 0);
    if (ids.length.isOdd) extraAbove = !extraAbove;
    for (var index = 0; index < shuffled.length; index++) {
      directions[shuffled[index]] = index < aboveCount;
    }
  }
  final order = visualOrder ?? (directions.keys.toList()..shuffle(random));
  return {
    for (var index = 0; index < order.length; index++)
      order[index]: CardEntranceSpec(
        fromAbove: directions[order[index]]!,
        // Bounded total duration, even with a very dense timetable.
        delayMs: order.length < 2 ? 0 : index * 140 / (order.length - 1),
      ),
  };
}

double cardEntranceOffset({
  required Rect rect,
  required Rect viewport,
  required CardEntranceSpec spec,
  required CardEntranceMode mode,
}) => mode == CardEntranceMode.nearby
    ? (spec.fromAbove ? -48 : 48)
    : spec.fromAbove
    ? viewport.top - rect.bottom - 8
    : viewport.bottom - rect.top + 8;

/// One clock for the shell and a second clock for the first ready timetable.
/// Data loading never extends the brand overlay's lifetime.
class LaunchMotion {
  LaunchMotion({
    required TickerProvider vsync,
    required this.settings,
    int? seed,
    this.startup = true,
    this.direction = 1,
  }) : random = math.Random(seed),
       timeline = AnimationController(
         vsync: vsync,
         duration: Duration(milliseconds: startup ? 1150 : 680),
       ),
       cards = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 620),
       );

  final LaunchSettings settings;
  final bool startup;
  final int direction;
  final math.Random random;
  final AnimationController timeline;
  final AnimationController cards;
  Object? _gridOwner;
  bool _finished = false;

  double get milliseconds => timeline.value * timeline.duration!.inMilliseconds;
  bool _pausedTimeline = false, _pausedCards = false;
  void pause() {
    _pausedTimeline = timeline.isAnimating;
    _pausedCards = cards.isAnimating;
    timeline.stop();
    cards.stop();
  }

  void resume() {
    if (_finished) return;
    if (_pausedTimeline) timeline.forward();
    if (_pausedCards) cards.forward();
  }

  bool get canClaimGrid => !_finished && _gridOwner == null;
  bool get finished => _finished;
  bool get cardsComplete => _finished || cards.isCompleted;

  bool startGrid(Object owner) {
    if (!canClaimGrid) return false;
    _gridOwner = owner;
    timeline.addListener(_startCardsWhenReady);
    _startCardsWhenReady();
    return true;
  }

  void skipGridEntrance() {
    if (canClaimGrid) _gridOwner = this;
  }

  void _startCardsWhenReady() {
    if (_finished || milliseconds < (startup ? 500 : 60)) return;
    timeline.removeListener(_startCardsWhenReady);
    cards.forward();
  }

  void finish() {
    if (_finished) return;
    _finished = true;
    timeline.removeListener(_startCardsWhenReady);
    timeline.value = 1;
    cards.value = 1;
  }

  void dispose() {
    timeline.removeListener(_startCardsWhenReady);
    timeline.dispose();
    cards.dispose();
  }
}

class LaunchMotionScope extends InheritedWidget {
  const LaunchMotionScope({
    super.key,
    required this.motion,
    required super.child,
  });
  final LaunchMotion motion;
  static LaunchMotion? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LaunchMotionScope>()?.motion;
  @override
  bool updateShouldNotify(LaunchMotionScope oldWidget) =>
      oldWidget.motion != motion;
}

/// Adjacent timetable previews are complete presentations, never entrants.
class LaunchEntranceRegion extends InheritedWidget {
  const LaunchEntranceRegion({
    super.key,
    required this.enabled,
    required super.child,
  });
  final bool enabled;
  static bool enabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LaunchEntranceRegion>()
          ?.enabled ??
      true;
  @override
  bool updateShouldNotify(LaunchEntranceRegion oldWidget) =>
      enabled != oldWidget.enabled;
}

/// The child is cached by AnimatedBuilder; only opacity/paint transforms tick.
class LaunchReveal extends StatelessWidget {
  const LaunchReveal({
    super.key,
    required this.child,
    this.startMs = 350,
    this.durationMs = 230,
    this.offset = Offset.zero,
    this.spring = false,
    this.grow,
    this.pageModule = true,
  });
  final Widget child;
  final double startMs;
  final double durationMs;
  final Offset offset;
  final bool spring;
  final Axis? grow;
  final bool pageModule;

  @override
  Widget build(BuildContext context) {
    final motion = LaunchMotionScope.maybeOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final participates = LaunchEntranceRegion.enabledOf(context);
    // Keep the same element path in every phase. Unwrapping a finished reveal
    // remounts the timetable and discards its scroll position and layout cache.
    return PageModule(
      enabled: participates && motion != null && !motion.startup && pageModule,
      child: AnimatedBuilder(
        animation: motion != null && motion.startup
            ? motion.timeline
            : kAlwaysCompleteAnimation,
        child: child,
        builder: (context, child) {
          final skip =
              motion == null ||
              motion.finished ||
              !participates ||
              !motion.startup ||
              (motion.startup && !motion.settings.onStartup) ||
              reduced;
          final t = skip
              ? 1.0
              : launchProgress(motion.milliseconds, startMs, durationMs);
          final p = (spring ? Curves.easeOutBack : Curves.easeOutCubic)
              .transform(t);
          Widget result = Opacity(
            opacity: (t * 3).clamp(0, 1),
            alwaysIncludeSemantics: true,
            child: Transform.translate(offset: offset * (1 - p), child: child),
          );
          if (grow != null) {
            result = ClipRect(
              clipper: _GrowingClipper(p.clamp(0, 1), grow!),
              clipBehavior: p >= 1 ? Clip.none : Clip.hardEdge,
              child: result,
            );
          }
          // NavigationBar supplies a tab semantic role above its destination.
          // Keep the destination's tap action even while opacity is zero.
          return result;
        },
      ),
    );
  }
}

class _GrowingClipper extends CustomClipper<Rect> {
  const _GrowingClipper(this.progress, this.axis);
  final double progress;
  final Axis axis;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    0,
    size.width * (axis == Axis.horizontal ? progress : 1),
    size.height * (axis == Axis.vertical ? progress : 1),
  );
  @override
  bool shouldReclip(_GrowingClipper oldClipper) =>
      progress != oldClipper.progress || axis != oldClipper.axis;
}

class LaunchCard extends StatelessWidget {
  const LaunchCard({
    super.key,
    required this.child,
    this.spec,
    this.offset = 0,
    this.pending = false,
    this.travel,
  });
  final Widget child;
  final CardEntranceSpec? spec;
  final double offset;
  final Offset? travel;
  final bool pending;
  @override
  Widget build(BuildContext context) {
    final motion = LaunchMotionScope.maybeOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: motion?.cards ?? kAlwaysCompleteAnimation,
      child: child,
      builder: (context, child) {
        final skip = motion == null || motion.finished || reduced;
        final t = skip
            ? 1.0
            : pending
            ? 0.0
            : spec == null
            ? 1.0
            : launchProgress(motion.cards.value * 620, spec!.delayMs, 480);
        return IgnorePointer(
          ignoring: t < 1,
          child: Opacity(
            opacity: Curves.easeOut.transform((t * 3).clamp(0.0, 1.0)),
            child: Transform.translate(
              offset:
                  (travel ?? Offset(0, offset)) *
                  (1 - Curves.easeOutQuint.transform(t)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class LaunchIcon extends StatelessWidget {
  const LaunchIcon({super.key, this.path, this.size = 96});
  final String? path;
  final double size;
  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox.square(
      dimension: size,
      child: path == null
          ? Image.asset(orbitIconAsset, fit: BoxFit.cover, cacheWidth: 512)
          : Image.file(
              File(path!),
              fit: BoxFit.cover,
              cacheWidth: 512,
              errorBuilder: (_, _, _) => Image.asset(
                orbitIconAsset,
                fit: BoxFit.cover,
                cacheWidth: 512,
              ),
            ),
    ),
  );
}

class OrbitLaunchHost extends ConsumerStatefulWidget {
  const OrbitLaunchHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<OrbitLaunchHost> createState() => _OrbitLaunchHostState();
}

class _OrbitLaunchHostState extends ConsumerState<OrbitLaunchHost>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  LaunchMotion? _motion;
  bool _preparing = false;
  Size? _lastViewSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastViewSize = View.of(context).physicalSize;
    _motion ??= LaunchMotion(
      vsync: this,
      settings: ref.read(launchSettingsProvider),
    );
    if (!ref.read(launchAnimationsEnabledProvider) ||
        MediaQuery.disableAnimationsOf(context) ||
        ref.read(pendingNotificationPayloadProvider) != null ||
        ref.read(strongConfirmationVisibleProvider) ||
        ref.read(deadlineStrongEventsProvider).isNotEmpty) {
      _motion!.finish();
    }
    if (!_motion!.settings.onStartup || !_motion!.settings.pageEnabled[0]) {
      _motion!.skipGridEntrance();
    }
    if (!_motion!.settings.brandEnabled && !_motion!.settings.onStartup) {
      _motion!.finish();
    }
    if (!_preparing && !_motion!.finished) {
      _preparing = true;
      unawaited(_prepare());
    }
  }

  Future<void> _prepare() async {
    final path = _motion!.settings.iconPath;
    try {
      await Future.wait([
        precacheImage(
          const AssetImage(orbitIconAsset),
          context,
          onError: (_, _) {},
        ),
        if (path != null)
          precacheImage(FileImage(File(path)), context, onError: (_, _) {}),
        ref
            .read(fontServiceProvider)
            .prepare(ref.read(typographySettingsProvider)),
      ]);
    } catch (error) {
      // A missing optional visual must never leave an opaque overlay stuck.
      debugPrint('Startup image/font preparation failed: $error');
    }
    if (!mounted || _motion!.finished) return;
    // Start on a painted frame rather than during dependency resolution.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_motion!.finished) {
        _motion!.timeline.forward(
          from: _motion!.settings.brandEnabled ? 0 : 350 / 1150,
        );
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didChangeMetrics() {
    final size = View.of(context).physicalSize;
    if (_lastViewSize != null &&
        size != _lastViewSize &&
        (_motion?.milliseconds ?? 0) > 0) {
      _motion?.finish();
    }
    _lastViewSize = size;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _motion?.finish();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appNavIndexProvider, (previous, next) {
      if (previous != next) _motion?.finish();
    });
    ref.listen(pendingNotificationPayloadProvider, (_, value) {
      if (value != null) _motion?.finish();
    });
    ref.listen(strongConfirmationVisibleProvider, (_, value) {
      if (value) _motion?.finish();
    });
    ref.listen(deadlineStrongEventsProvider, (_, value) {
      if (value.isNotEmpty) _motion?.finish();
    });
    final motion = _motion!;
    final typography = ref.watch(typographySettingsProvider);
    final launchFont = typography.effectiveLaunchFontId;
    final launchFamily = launchFont == 'system'
        ? FontCatalog.systemFamily(
            defaultTargetPlatform,
            Localizations.localeOf(context),
          )
        : FontCatalog.family(launchFont);
    final brand = ref.watch(themeColorProvider);
    final foreground =
        ThemeData.estimateBrightnessForColor(brand) == Brightness.dark
        ? Colors.white
        : const Color(0xFF172C2B);
    return LaunchMotionScope(
      motion: motion,
      child: Listener(
        onPointerDown: (_) {
          if (motion.milliseconds >= 450) motion.finish();
        },
        onPointerSignal: (_) => motion.finish(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            AnimatedBuilder(
              animation: motion.timeline,
              builder: (context, _) {
                final ms = motion.milliseconds;
                if (motion.finished ||
                    !motion.settings.brandEnabled ||
                    ms >= 450) {
                  return const SizedBox.shrink();
                }
                final fade = 1 - launchProgress(ms, 300, 150);
                final icon = Curves.easeOutCubic.transform(
                  launchProgress(ms, 0, 200),
                );
                final name = Curves.easeOutCubic.transform(
                  launchProgress(ms, 40, 200),
                );
                return BlockSemantics(
                  child: AbsorbPointer(
                    child: Opacity(
                      opacity: fade,
                      child: ColoredBox(
                        key: const Key('orbit-launch-brand'),
                        color: brand,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: Transform.scale(
                                scale: .99 + .01 * icon,
                                child: LaunchIcon(
                                  path: motion.settings.iconPath,
                                ),
                              ),
                            ),
                            Center(
                              child: Transform.translate(
                                offset: Offset(0, 66 + (1 - name) * 8),
                                child: FractionalTranslation(
                                  translation: const Offset(0, .5),
                                  child: Opacity(
                                    opacity: name,
                                    child: Text(
                                      'Orbit',
                                      style: TextStyle(
                                        inherit: false,
                                        fontFamily: launchFamily,
                                        fontFamilyFallback: typography
                                            .fallbackFamilies(launchFont),
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                        color: foreground,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
