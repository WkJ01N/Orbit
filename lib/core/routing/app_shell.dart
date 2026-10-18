import 'package:orbit/core/motion/page_entrance.dart';
import 'package:flutter/rendering.dart';
import 'package:orbit/features/deadline/deadline_strong_host.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/grid/grid_page.dart';
import 'package:orbit/features/grid/grid_selection.dart';
import 'package:orbit/features/import/import_page.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/features/upcoming/upcoming_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/core/widgets/reminder_resync_banner.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/providers/background_providers.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/core/motion/launch_motion.dart';

class _NavItem {
  const _NavItem({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final AppTab tab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _pages = [
    GridPage(),
    UpcomingPage(),
    ImportPage(),
    SettingsPage(),
  ];

  static const _settingsIndex = 3;

  List<_NavItem> _navItems(AppLocalizations l10n) {
    return [
      _NavItem(
        tab: AppTab.grid,
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view,
        label: l10n.navGrid,
      ),
      _NavItem(
        tab: AppTab.upcoming,
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
        label: l10n.navUpcoming,
      ),
      _NavItem(
        tab: AppTab.import,
        icon: Icons.upload_file_outlined,
        selectedIcon: Icons.upload_file,
        label: l10n.navImport,
      ),
      _NavItem(
        tab: AppTab.settings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: l10n.navSettings,
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final display = ref.watch(scheduleDisplaySettingsProvider);
    final items = _navItems(l10n)
        .where(
          (item) =>
              !(item.tab == AppTab.upcoming && display.hideUpcomingPage) &&
              !(item.tab == AppTab.import && display.hideImportPage),
        )
        .toList();
    final requestedIndex = ref.watch(appNavIndexProvider);
    final selectedIndex = items.any((item) => item.tab.index == requestedIndex)
        ? requestedIndex
        : AppTab.grid.index;
    final navigationIndex = items.indexWhere(
      (item) => item.tab.index == selectedIndex,
    );
    if (requestedIndex != selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            ref.read(appNavIndexProvider) == requestedIndex) {
          ref.read(appNavIndexProvider.notifier).state = selectedIndex;
        }
      });
    }
    final colorScheme = Theme.of(context).colorScheme;
    final backgrounds =
        ref.watch(backgroundSettingsProvider).valueOrNull ??
        const BackgroundSettings();
    final backgroundPage = BackgroundPage.values[selectedIndex];
    final revealNavigation =
        backgrounds.asset(backgroundPage) != null &&
        backgrounds
            .page(backgroundPage)
            .regions
            .contains(BackgroundRegionId.navigation);
    Widget wrapNavigation(Widget child) => BackgroundPageTheme(
      settings: backgrounds,
      owner: backgroundPage,
      child: BackgroundRegion(
        region: BackgroundRegionId.navigation,
        child: child,
      ),
    );

    Future<void> onDestinationSelected(int index) async {
      LaunchMotionScope.maybeOf(context)?.finish();
      final target = items[index].tab.index;
      if (target == selectedIndex) return;
      if (!await cancelGridSelection(context, ref) || !context.mounted) return;
      ref.read(appNavIndexProvider.notifier).state = target;
    }

    // The settings page renders its own banner inside the reminders section, so
    // suppress the global one there to avoid showing it twice.
    final rescheduleError = ref.watch(lastRescheduleErrorProvider);
    final showReminderBanner =
        rescheduleError != null && selectedIndex != AppShell._settingsIndex;

    Widget wrapWithBanner(Widget content) => Column(
      children: [
        const DeadlineStrongBanner(),
        if (showReminderBanner)
          ReminderResyncBanner(
            error: rescheduleError,
            onDismiss: () =>
                ref.read(lastRescheduleErrorProvider.notifier).state = null,
            onResync: () =>
                ref.read(reminderSettingsProvider.notifier).resyncReminders(),
          ),
        Expanded(child: content),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= kNavigationRailBreakpoint;

        if (useRail) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Row(
              children: [
                wrapNavigation(
                  NavigationRail(
                    useIndicator: false,
                    backgroundColor: revealNavigation
                        ? Colors.transparent
                        : null,
                    selectedIndex: navigationIndex,
                    onDestinationSelected: onDestinationSelected,
                    labelType: NavigationRailLabelType.selected,
                    leading: LaunchReveal(
                      startMs: 380,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.calendar_month,
                            color: colorScheme.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    destinations: [
                      for (var index = 0; index < items.length; index++)
                        NavigationRailDestination(
                          icon: LaunchReveal(
                            startMs: 480 + index * 35,
                            durationMs: 350,
                            offset: const Offset(-24, 0),
                            spring: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Icon(items[index].icon),
                            ),
                          ),
                          selectedIcon: LaunchReveal(
                            startMs: 480 + index * 35,
                            durationMs: 350,
                            offset: const Offset(-24, 0),
                            spring: true,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: colorScheme.secondaryContainer,
                                shape: const StadiumBorder(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: Icon(items[index].selectedIcon),
                              ),
                            ),
                          ),
                          label: LaunchReveal(
                            startMs: 480 + index * 35,
                            durationMs: 350,
                            offset: const Offset(-24, 0),
                            spring: true,
                            child: Text(items[index].label),
                          ),
                        ),
                    ],
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: wrapWithBanner(
                    _AnimatedIndexedStack(
                      index: selectedIndex,
                      children: _pages,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: wrapWithBanner(
            _AnimatedIndexedStack(index: selectedIndex, children: _pages),
          ),
          bottomNavigationBar: wrapNavigation(
            NavigationBar(
              backgroundColor: revealNavigation ? Colors.transparent : null,
              surfaceTintColor: revealNavigation ? Colors.transparent : null,
              selectedIndex: navigationIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (var index = 0; index < items.length; index++)
                  LaunchReveal(
                    startMs: 480 + index * 35,
                    durationMs: 350,
                    offset: const Offset(0, 24),
                    spring: true,
                    child: NavigationDestination(
                      icon: Icon(items[index].icon),
                      selectedIcon: Icon(items[index].selectedIcon),
                      label: items[index].label,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Builds destinations on their first visit and retains visited page state.
/// The previous and next pages share a short transition.
class _AnimatedIndexedStack extends StatefulWidget {
  const _AnimatedIndexedStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<_AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1.0,
  )..addStatusListener(_handleAnimationStatus);
  late int _activeIndex = widget.index;
  late final Set<int> _visited = {widget.index};
  int? _previousIndex;
  int _direction = 1;

  @override
  void didUpdateWidget(_AnimatedIndexedStack old) {
    super.didUpdateWidget(old);
    if (widget.index != _activeIndex) {
      _previousIndex = _activeIndex;
      _direction = widget.index > _activeIndex ? 1 : -1;
      _activeIndex = widget.index;
      _visited.add(_activeIndex);
      _controller.forward(from: 0.0);
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previousIndex != null) {
      setState(() => _previousIndex = null);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // These consumers and their page trees stay unchanged on animation ticks.
    final destinations = <int, Widget>{
      for (final index in _visited)
        index: RepaintBoundary(
          child: Consumer(
            builder: (context, ref, _) => BackgroundPageTheme(
              settings:
                  ref.watch(backgroundSettingsProvider).valueOrNull ??
                  const BackgroundSettings(),
              owner: BackgroundPage.values[index],
              child: PageEntranceHost(
                index: index,
                navigation: _controller,
                active: index == _activeIndex,
                startup: _visited.length == 1,
                child: widget.children[index],
              ),
            ),
          ),
        ),
    };
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = reduceMotion
            ? 1.0
            : Curves.easeOutCubic.transform(_controller.value);
        final hiddenIndexes = <int>[
          for (var index = 0; index < widget.children.length; index++)
            if (_visited.contains(index) &&
                index != _activeIndex &&
                (reduceMotion || index != _previousIndex))
              index,
        ];

        return Stack(
          fit: StackFit.expand,
          children: [
            for (final index in hiddenIndexes)
              _destinationLayer(
                index: index,
                child: destinations[index]!,
                offstage: true,
              ),
            _destinationLayer(
              index: _activeIndex,
              child: destinations[_activeIndex]!,
              offset: Offset(_direction * (1 - progress) * 14, 0),
              interactive: true,
            ),
            if (!reduceMotion && _previousIndex != null)
              _destinationLayer(
                index: _previousIndex!,
                child: destinations[_previousIndex]!,
                opacity: 1 - progress,
                offset: Offset(-_direction * progress * 6, 0),
              ),
          ],
        );
      },
    );
  }

  Widget _destinationLayer({
    required int index,
    required Widget child,
    bool offstage = false,
    bool interactive = false,
    double opacity = 1,
    Offset offset = Offset.zero,
  }) {
    child = _DeferredPageLayout(frozen: offstage, child: child);
    return KeyedSubtree(
      key: ValueKey('app-destination-$index'),
      child: Offstage(
        offstage: offstage,
        child: TickerMode(
          enabled: interactive,
          child: IgnorePointer(
            ignoring: !interactive,
            child: ExcludeSemantics(
              excluding: !interactive,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.translate(offset: offset, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Offstage keeps element state but normally still lays out its child. Defer
/// hidden page layout so background provider updates do not rebuild a full grid.
class _DeferredPageLayout extends SingleChildRenderObjectWidget {
  const _DeferredPageLayout({required this.frozen, required super.child});
  final bool frozen;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _DeferredPageBox(frozen);
  @override
  void updateRenderObject(
    BuildContext context,
    _DeferredPageBox renderObject,
  ) => renderObject.frozen = frozen;
}

class _DeferredPageBox extends RenderProxyBox {
  _DeferredPageBox(this._frozen);
  bool _frozen;
  set frozen(bool value) {
    if (_frozen == value) return;
    _frozen = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (_frozen) {
      size = constraints.constrain(Size.zero);
    } else {
      super.performLayout();
    }
  }
}
