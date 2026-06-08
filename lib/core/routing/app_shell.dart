import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/grid/grid_page.dart';
import 'package:orbit/features/import/import_page.dart';
import 'package:orbit/features/settings/settings_page.dart';
import 'package:orbit/features/upcoming/upcoming_page.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/navigation_providers.dart';

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
          MaterialBanner(
            content: Text(l10n.reminderResyncFailedBanner),
            leading: Icon(Icons.warning_amber, color: colorScheme.error),
            actions: [
              TextButton(
                onPressed: () =>
                    ref.read(lastRescheduleErrorProvider.notifier).state = null,
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(reminderSettingsProvider.notifier).resyncReminders(),
                child: Text(l10n.resyncReminders),
              ),
            ],
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
                    IndexedStack(
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
            IndexedStack(
              index: selectedIndex,
              children: _pages,
            ),
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
