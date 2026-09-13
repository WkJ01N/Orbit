import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/grid/grid_page.dart';
import 'package:orbit/features/import/import_page.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/features/upcoming/upcoming_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/core/widgets/reminder_resync_banner.dart';
import 'package:orbit/providers/app_providers.dart';

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

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
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view,
        label: l10n.navGrid,
      ),
      _NavItem(
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
        label: l10n.navUpcoming,
      ),
      _NavItem(
        icon: Icons.upload_file_outlined,
        selectedIcon: Icons.upload_file,
        label: l10n.navImport,
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: l10n.navSettings,
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = _navItems(l10n);
    final selectedIndex = ref.watch(appNavIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    void onDestinationSelected(int index) {
      ref.read(appNavIndexProvider.notifier).state = index;
    }

    // The settings page renders its own banner inside the reminders section, so
    // suppress the global one there to avoid showing it twice.
    final rescheduleError = ref.watch(lastRescheduleErrorProvider);
    final showReminderBanner =
        rescheduleError != null && selectedIndex != AppShell._settingsIndex;

    Widget wrapWithBanner(Widget content) {
      if (!showReminderBanner) {
        return content;
      }
      return Column(
        children: [
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
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= kNavigationRailBreakpoint;

        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.selected,
                  leading: Padding(
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
                  destinations: [
                    for (final item in items)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
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
          body: wrapWithBanner(
            _AnimatedIndexedStack(index: selectedIndex, children: _pages),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              for (final item in items)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
            ],
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
              _destinationLayer(index: index, offstage: true),
            _destinationLayer(
              index: _activeIndex,
              offset: Offset(_direction * (1 - progress) * 14, 0),
              scale: 0.996 + progress * 0.004,
              interactive: true,
            ),
            if (!reduceMotion && _previousIndex != null)
              _destinationLayer(
                index: _previousIndex!,
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
    bool offstage = false,
    bool interactive = false,
    double opacity = 1,
    double scale = 1,
    Offset offset = Offset.zero,
  }) {
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
                child: Transform.translate(
                  offset: offset,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.center,
                    child: widget.children[index],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
