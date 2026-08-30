import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/app_info.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/core/widgets/reminder_resync_banner.dart';
import 'package:orbit/core/widgets/section_header.dart';
import 'package:orbit/features/settings/battery_disable_dialog.dart';
import 'package:orbit/features/settings/check_in_disable_dialog.dart';
import 'package:orbit/features/settings/check_in_template_sheet.dart';
import 'package:orbit/features/settings/class_lead_template_sheet.dart';
import 'package:orbit/features/settings/next_day_summary_template_sheet.dart';
import 'package:orbit/features/settings/reminder_setting_actions.dart';
import 'package:orbit/features/settings/settings_appearance_section.dart';
import 'package:orbit/features/settings/settings_data_section.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/grid_density.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/models/reminder_permission_status.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/services/alarm_intent_service.dart';
import 'package:orbit/services/android_reminder_guard.dart';
import 'package:orbit/services/schedule_layout_engine.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(reminderSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: settingsAsync.when(
        data: (settings) => _SettingsBody(settings: settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: l10n.settingsLoadFailed('$e'),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(reminderSettingsProvider),
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody({required this.settings});

  final ReminderSettings settings;

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  int _selectedCategory = 0;
  int _transitionDirection = 1;

  void _selectCategory(int value) {
    if (value == _selectedCategory) return;
    setState(() {
      _transitionDirection = value > _selectedCategory ? 1 : -1;
      _selectedCategory = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = widget.settings;
    final currentLocale = ref.watch(localeProvider);
    final rescheduleError = ref.watch(lastRescheduleErrorProvider);
    final notifier = ref.read(reminderSettingsProvider.notifier);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        _SettingsCategoryTabs(
          selectedIndex: _selectedCategory,
          onSelected: _selectCategory,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            reverseDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: currentChild == null
                  ? previousChildren
                  : [...previousChildren, currentChild],
            ),
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey(_selectedCategory);
              final direction = incoming
                  ? _transitionDirection.toDouble()
                  : -_transitionDirection.toDouble();
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(direction * 0.035, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: ListView(
              key: Key('settings-category-content-$_selectedCategory'),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (_selectedCategory == 0) ...[
                  SectionHeader(title: l10n.sectionLanguage),
                  ListTile(
                    title: Text(l10n.languageTitle),
                    subtitle: Text(l10n.languageSubtitle),
                    trailing: _SettingsDropdown<Locale>(
                      value: _matchingLocale(currentLocale),
                      onChanged: (locale) async {
                        if (locale == null) {
                          return;
                        }
                        final targetL10n = lookupL10n(locale);
                        await ref
                            .read(localeProvider.notifier)
                            .setLocale(locale);
                        if (!context.mounted) {
                          return;
                        }
                        await applyReminderUpdate(
                          context,
                          ref,
                          () => ref
                              .read(reminderSettingsProvider.notifier)
                              .resyncReminders(),
                          messages: targetL10n,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(targetL10n.languageChangedResynced),
                            ),
                          );
                        }
                      },
                      items: supportedAppLocales
                          .map(
                            (locale) => DropdownMenuItem(
                              value: locale,
                              child: Text(languageOptionLabel(l10n, locale)),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_selectedCategory == 1) ...[
                  SectionHeader(title: l10n.sectionSchedule),
                  _GridDefaultWeekTile(),
                  const _WeekStartDayTile(),
                  const _GridDensityTile(),
                  const _ScheduleMultiDayCountTile(),
                  const _ScheduleShowEmptyDaysTile(),
                  const _UpcomingCourseDateTile(),
                  const _UpcomingDateDisplayTile(),
                  const SizedBox(height: 8),
                ],
                if (_selectedCategory == 0) ...[
                  const SettingsAppearanceSection(),
                ],
                if (_selectedCategory == 2) ...[
                  SectionHeader(title: l10n.sectionReminders),
                  if (rescheduleError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: ReminderResyncBanner(
                        error: rescheduleError,
                        onResync: () => _resyncReminders(context, ref),
                      ),
                    ),
                  SwitchListTile(
                    title: Text(l10n.enableReminders),
                    subtitle: Text(l10n.enableRemindersSubtitle),
                    value: settings.enabled,
                    onChanged: (enabled) => applyReminderUpdate(
                      context,
                      ref,
                      () => notifier.setEnabled(enabled),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    enabled: settings.enabled,
                    title: Text(l10n.leadTimeTitle),
                    subtitle: Text(l10n.leadTimeSubtitle(settings.leadMinutes)),
                    trailing: _SettingsDropdown<int>(
                      value: _effectiveLeadMinutes(settings.leadMinutes),
                      onChanged: settings.enabled
                          ? (value) {
                              if (value != null) {
                                applyReminderUpdate(
                                  context,
                                  ref,
                                  () => notifier.updateLeadMinutes(value),
                                );
                              }
                            }
                          : null,
                      items: ReminderSettings.leadMinuteOptions
                          .map(
                            (min) => DropdownMenuItem(
                              value: min,
                              child: Text(l10n.leadTimeOption(min)),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  ListTile(
                    enabled: settings.enabled,
                    title: Text(l10n.classLeadCustomizeTemplates),
                    subtitle: Text(l10n.classLeadCustomizeTemplatesSubtitle),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: settings.enabled
                        ? () => ClassLeadTemplateSheet.show(
                            context,
                            settings: settings,
                          )
                        : null,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    enabled:
                        settings.enabled ||
                        settings.checkInReminderEnabled ||
                        settings.nextDaySummaryEnabled,
                    title: Text(l10n.resyncReminders),
                    subtitle: Text(l10n.resyncRemindersSubtitle),
                    trailing: const Icon(Icons.refresh),
                    onTap:
                        (settings.enabled ||
                            settings.checkInReminderEnabled ||
                            settings.nextDaySummaryEnabled)
                        ? () => _resyncReminders(context, ref)
                        : null,
                  ),
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 8),
                    _AndroidBackgroundSection(),
                  ],
                  const SizedBox(height: 16),
                  SectionHeader(title: l10n.sectionAdvancedReminders),
                  SwitchListTile(
                    title: Text(l10n.enableNextDaySummary),
                    subtitle: Text(l10n.enableNextDaySummarySubtitle),
                    value: settings.nextDaySummaryEnabled,
                    onChanged: (enabled) => applyReminderUpdate(
                      context,
                      ref,
                      () => notifier.setNextDaySummaryEnabled(enabled),
                    ),
                  ),
                  ListTile(
                    enabled: settings.nextDaySummaryEnabled,
                    title: Text(l10n.nextDaySummaryTimeTitle),
                    subtitle: Text(
                      l10n.nextDaySummaryTimeSubtitle(
                        settings.nextDaySummaryTimeLabel,
                      ),
                    ),
                    trailing: const Icon(Icons.schedule),
                    onTap: settings.nextDaySummaryEnabled
                        ? () => _pickNextDaySummaryTime(context, ref)
                        : null,
                  ),
                  SwitchListTile(
                    title: Text(l10n.nextDayRemindWhenNoClass),
                    subtitle: Text(l10n.nextDayRemindWhenNoClassSubtitle),
                    value: settings.nextDayRemindWhenNoClass,
                    onChanged: settings.nextDaySummaryEnabled
                        ? (enabled) => applyReminderUpdate(
                            context,
                            ref,
                            () => notifier.setNextDayRemindWhenNoClass(enabled),
                          )
                        : null,
                  ),
                  ListTile(
                    enabled: settings.nextDaySummaryEnabled,
                    title: Text(l10n.nextDayCustomizeTemplates),
                    subtitle: Text(l10n.nextDayCustomizeTemplatesSubtitle),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: settings.nextDaySummaryEnabled
                        ? () => NextDaySummaryTemplateSheet.show(
                            context,
                            settings: settings,
                          )
                        : null,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: Text(l10n.enableCheckInReminder),
                    subtitle: Text(l10n.enableCheckInReminderSubtitle),
                    value: settings.checkInReminderEnabled,
                    onChanged: (enabled) async {
                      if (enabled) {
                        await applyReminderUpdate(
                          context,
                          ref,
                          () => notifier.setCheckInReminderEnabled(true),
                        );
                        return;
                      }
                      final confirmed = await confirmDisableCheckInReminder(
                        context,
                      );
                      if (confirmed && context.mounted) {
                        await applyReminderUpdate(
                          context,
                          ref,
                          () => notifier.setCheckInReminderEnabled(false),
                        );
                      }
                    },
                  ),
                  ListTile(
                    enabled: settings.checkInReminderEnabled,
                    title: Text(l10n.checkInCustomizeTemplates),
                    subtitle: Text(l10n.checkInCustomizeTemplatesSubtitle),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: settings.checkInReminderEnabled
                        ? () => CheckInTemplateSheet.show(
                            context,
                            settings: settings,
                          )
                        : null,
                  ),
                  if (Platform.isAndroid) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text(l10n.enableSystemAlarm),
                      subtitle: Text(l10n.enableSystemAlarmSubtitle),
                      value: settings.systemAlarmEnabled,
                      onChanged: (enabled) {
                        ref
                            .read(reminderSettingsProvider.notifier)
                            .setSystemAlarmEnabled(enabled);
                      },
                    ),
                    ListTile(
                      enabled: settings.systemAlarmEnabled,
                      title: Text(l10n.systemAlarmLeadTitle),
                      subtitle: Text(
                        l10n.systemAlarmLeadSubtitle(
                          settings.systemAlarmLeadMinutes,
                        ),
                      ),
                      trailing: _SettingsDropdown<int>(
                        value: _effectiveAlarmLeadMinutes(
                          settings.systemAlarmLeadMinutes,
                        ),
                        onChanged: settings.systemAlarmEnabled
                            ? (value) {
                                if (value != null) {
                                  ref
                                      .read(reminderSettingsProvider.notifier)
                                      .setSystemAlarmLeadMinutes(value);
                                }
                              }
                            : null,
                        items: ReminderSettings.alarmLeadMinuteOptions
                            .map(
                              (min) => DropdownMenuItem(
                                value: min,
                                child: Text(l10n.leadTimeOption(min)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ListTile(
                      enabled: settings.systemAlarmEnabled,
                      title: Text(l10n.setTomorrowAlarm),
                      trailing: const Icon(Icons.alarm_add),
                      onTap: settings.systemAlarmEnabled
                          ? () => _setTomorrowAlarm(context, ref)
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                if (_selectedCategory == 3) ...[
                  const SettingsDataSection(),
                  const SizedBox(height: 32),
                  _SettingsFooter(l10n: l10n),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _effectiveLeadMinutes(int saved) {
    if (ReminderSettings.leadMinuteOptions.contains(saved)) {
      return saved;
    }
    return ReminderSettings.leadMinuteOptions.first;
  }

  int _effectiveAlarmLeadMinutes(int saved) {
    if (ReminderSettings.alarmLeadMinuteOptions.contains(saved)) {
      return saved;
    }
    return ReminderSettings.alarmLeadMinuteOptions.first;
  }

  Locale _matchingLocale(Locale current) {
    final key = localeStorageKey(current);
    return supportedAppLocales.firstWhere(
      (locale) => localeStorageKey(locale) == key,
      orElse: () => defaultLocale,
    );
  }

  Future<void> _pickNextDaySummaryTime(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current =
        ref.read(reminderSettingsProvider).value ?? const ReminderSettings();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.nextDaySummaryHour,
        minute: current.nextDaySummaryMinute,
      ),
    );
    if (picked != null && context.mounted) {
      await applyReminderUpdate(
        context,
        ref,
        () => ref
            .read(reminderSettingsProvider.notifier)
            .setNextDaySummaryTime(picked),
      );
    }
  }

  Future<void> _setTomorrowAlarm(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final settings =
        ref.read(reminderSettingsProvider).value ?? const ReminderSettings();
    final sessions = await ref
        .read(scheduleRepositoryProvider)
        .getAllSessions();
    final result = await ref
        .read(alarmIntentServiceProvider)
        .setTomorrowFirstClassAlarm(
          allSessions: sessions,
          settings: settings,
          alarmLabel: l10n.notificationNextDayTitle,
        );

    if (!context.mounted) {
      return;
    }

    final message = switch (result) {
      AlarmIntentResult.success => l10n.alarmSetSuccess,
      AlarmIntentResult.noClassTomorrow => l10n.alarmNoClassTomorrow,
      AlarmIntentResult.unsupportedPlatform => l10n.alarmSetFailed,
      AlarmIntentResult.failed => l10n.alarmSetFailed,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resyncReminders(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await applyReminderUpdate(
      context,
      ref,
      () => ref.read(reminderSettingsProvider.notifier).resyncReminders(),
    );
    if (!context.mounted) {
      return;
    }
    final syncError = ref.read(lastRescheduleErrorProvider);
    // 'partial:N' is a partial-failure sentinel (see reminder_providers.dart);
    // a real exception stores the full error string.
    final isFullFailure =
        syncError != null && !syncError.startsWith('partial:');
    if (!isFullFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reminderResyncSuccessMessage(l10n, ref))),
      );
    }
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.value,
    required this.onChanged,
    required this.items,
  });

  final T value;
  final ValueChanged<T?>? onChanged;
  final List<DropdownMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width < 360 ? 132.0 : 156.0;
    return SizedBox(
      width: width,
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        onChanged: onChanged,
        items: items,
      ),
    );
  }
}

class _SettingsCategoryTabs extends StatelessWidget {
  const _SettingsCategoryTabs({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final items = [
      (
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        label: l10n.settingsCategoryGeneral,
      ),
      (
        icon: Icons.calendar_view_week_outlined,
        selectedIcon: Icons.calendar_view_week,
        label: l10n.sectionSchedule,
      ),
      (
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: l10n.sectionReminders,
      ),
      (
        icon: Icons.storage_outlined,
        selectedIcon: Icons.storage,
        label: l10n.sectionData,
      ),
    ];

    return Material(
      key: const Key('settings-category-tabs'),
      color: colors.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 520) {
              return SizedBox(
                height: 52,
                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      Expanded(
                        child: Center(
                          child: Semantics(
                            selected: selectedIndex == index,
                            label: items[index].label,
                            child: IconButton(
                              key: Key('settings-category-$index'),
                              tooltip: items[index].label,
                              isSelected: selectedIndex == index,
                              icon: Icon(items[index].icon),
                              selectedIcon: Icon(items[index].selectedIcon),
                              style: IconButton.styleFrom(
                                backgroundColor: selectedIndex == index
                                    ? colors.secondaryContainer
                                    : Colors.transparent,
                                foregroundColor: selectedIndex == index
                                    ? colors.onSecondaryContainer
                                    : colors.onSurfaceVariant,
                              ),
                              onPressed: () => onSelected(index),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }

            return DefaultTabController(
              length: items.length,
              initialIndex: selectedIndex,
              child: TabBar(
                dividerHeight: 0,
                onTap: onSelected,
                tabs: [
                  for (var index = 0; index < items.length; index++)
                    _SettingsTab(
                      key: Key('settings-category-$index'),
                      icon: items[index].icon,
                      label: items[index].label,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.fade),
        ],
      ),
    );
  }
}

class _GridDefaultWeekTile extends ConsumerWidget {
  const _GridDefaultWeekTile();

  String _modeLabel(AppLocalizations l10n, GridDefaultWeekMode mode) {
    return switch (mode) {
      GridDefaultWeekMode.smart => l10n.gridDefaultWeekSmart,
      GridDefaultWeekMode.current => l10n.gridDefaultWeekCurrent,
      GridDefaultWeekMode.earliest => l10n.gridDefaultWeekEarliest,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(gridDefaultWeekModeProvider);

    return ListTile(
      title: Text(l10n.gridDefaultWeekTitle),
      subtitle: Text(l10n.gridDefaultWeekSubtitle),
      trailing: _SettingsDropdown<GridDefaultWeekMode>(
        value: mode,
        onChanged: (value) {
          if (value != null) {
            ref.read(gridDefaultWeekModeProvider.notifier).setMode(value);
            ref.read(selectedWeekStartProvider.notifier).state = null;
          }
        },
        items: GridDefaultWeekMode.values
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(_modeLabel(l10n, item)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _WeekStartDayTile extends ConsumerWidget {
  const _WeekStartDayTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final startDay = ref.watch(weekStartDayProvider);

    return ListTile(
      title: Text(l10n.weekStartDayTitle),
      subtitle: Text(l10n.weekStartDaySubtitle),
      trailing: _SettingsDropdown<int>(
        value: startDay,
        onChanged: (value) {
          if (value != null) {
            ref.read(weekStartDayProvider.notifier).setWeekStartDay(value);
          }
        },
        items: [
          DropdownMenuItem(
            value: DateTime.monday,
            child: Text(l10n.weekStartMonday),
          ),
          DropdownMenuItem(
            value: DateTime.sunday,
            child: Text(l10n.weekStartSunday),
          ),
        ],
      ),
    );
  }
}

class _GridDensityTile extends ConsumerWidget {
  const _GridDensityTile();

  String _label(AppLocalizations l10n, GridDensity density) {
    return switch (density) {
      GridDensity.compact => l10n.gridDensityCompact,
      GridDensity.standard => l10n.gridDensityStandard,
      GridDensity.comfortable => l10n.gridDensityComfortable,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final density = ref.watch(gridDensityProvider);

    return ListTile(
      title: Text(l10n.gridDensityTitle),
      subtitle: Text(l10n.gridDensitySubtitle),
      trailing: _SettingsDropdown<GridDensity>(
        value: density,
        onChanged: (value) {
          if (value != null) {
            ref.read(gridDensityProvider.notifier).setDensity(value);
          }
        },
        items: GridDensity.values
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(_label(l10n, item)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ScheduleMultiDayCountTile extends ConsumerWidget {
  const _ScheduleMultiDayCountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(scheduleDisplaySettingsProvider);
    final maxCount = maxMultiDayCountForWidth(MediaQuery.sizeOf(context).width);
    final effectiveValue = settings.preferredMultiDayCount.clamp(1, maxCount);
    return ListTile(
      title: Text(l10n.scheduleMultiDayCountTitle),
      subtitle: Text(l10n.scheduleMultiDayCountSubtitle(maxCount)),
      trailing: _SettingsDropdown<int>(
        value: effectiveValue,
        onChanged: maxCount <= 1
            ? null
            : (value) {
                if (value != null) {
                  ref
                      .read(scheduleDisplaySettingsProvider.notifier)
                      .setPreferredMultiDayCount(value);
                }
              },
        items: [
          for (var count = 1; count <= maxCount; count++)
            DropdownMenuItem(
              value: count,
              child: Text(l10n.scheduleDayCountOption(count)),
            ),
        ],
      ),
    );
  }
}

class _ScheduleShowEmptyDaysTile extends ConsumerWidget {
  const _ScheduleShowEmptyDaysTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(scheduleDisplaySettingsProvider);
    return SwitchListTile(
      title: Text(l10n.scheduleShowEmptyDaysTitle),
      subtitle: Text(l10n.scheduleShowEmptyDaysSubtitle),
      value: settings.showEmptyDays,
      onChanged: (value) => ref
          .read(scheduleDisplaySettingsProvider.notifier)
          .setShowEmptyDays(value),
    );
  }
}

class _UpcomingCourseDateTile extends ConsumerWidget {
  const _UpcomingCourseDateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(scheduleDisplaySettingsProvider);
    return SwitchListTile(
      title: Text(l10n.upcomingShowCourseDateTitle),
      subtitle: Text(l10n.upcomingShowCourseDateSubtitle),
      value: settings.showUpcomingCourseDate,
      onChanged: (value) => ref
          .read(scheduleDisplaySettingsProvider.notifier)
          .setShowUpcomingCourseDate(value),
    );
  }
}

class _UpcomingDateDisplayTile extends ConsumerWidget {
  const _UpcomingDateDisplayTile();

  String _label(AppLocalizations l10n, UpcomingDateDisplay display) {
    return switch (display) {
      UpcomingDateDisplay.dateAndWeekday =>
        l10n.upcomingDateDisplayDateAndWeekday,
      UpcomingDateDisplay.dateOnly => l10n.upcomingDateDisplayDateOnly,
      UpcomingDateDisplay.weekdayOnly => l10n.upcomingDateDisplayWeekdayOnly,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(scheduleDisplaySettingsProvider);
    return ListTile(
      enabled: settings.showUpcomingCourseDate,
      title: Text(l10n.upcomingDateDisplayTitle),
      subtitle: Text(l10n.upcomingDateDisplaySubtitle),
      trailing: _SettingsDropdown<UpcomingDateDisplay>(
        value: settings.upcomingDateDisplay,
        onChanged: settings.showUpcomingCourseDate
            ? (value) {
                if (value != null) {
                  ref
                      .read(scheduleDisplaySettingsProvider.notifier)
                      .setUpcomingDateDisplay(value);
                }
              }
            : null,
        items: UpcomingDateDisplay.values
            .map(
              (display) => DropdownMenuItem(
                value: display,
                child: Text(_label(l10n, display)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AndroidBackgroundSection extends ConsumerStatefulWidget {
  const _AndroidBackgroundSection();

  @override
  ConsumerState<_AndroidBackgroundSection> createState() =>
      _AndroidBackgroundSectionState();
}

class _AndroidBackgroundSectionState
    extends ConsumerState<_AndroidBackgroundSection>
    with WidgetsBindingObserver {
  bool _isIgnoringBatteryOptimizations = false;
  ReminderPermissionStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBatteryStatus();
    _loadPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadBatteryStatus();
      _loadPermissionStatus();
    }
  }

  Future<void> _loadPermissionStatus() async {
    final status = await AndroidReminderGuard.instance.queryPermissionStatus();
    if (mounted) {
      setState(() => _permissionStatus = status);
    }
  }

  Future<void> _loadBatteryStatus() async {
    final ignoring = await AndroidReminderGuard.instance
        .isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() => _isIgnoringBatteryOptimizations = ignoring);
    }
  }

  Future<void> _checkPermissions() async {
    await AndroidReminderGuard.instance.ensureReminderPermissions();
    await _loadPermissionStatus();
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final status = _permissionStatus ?? ReminderPermissionStatus.unknown;
    final message = _permissionStatusMessage(l10n, status);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    if (!status.allGranted) {
      await AndroidReminderGuard.instance.openNotificationSettings();
    }
  }

  String _permissionStatusMessage(
    AppLocalizations l10n,
    ReminderPermissionStatus status,
  ) {
    final parts = <String>[
      status.notificationsEnabled
          ? l10n.androidNotificationsEnabled
          : l10n.androidNotificationsDisabled,
      status.exactAlarmsEnabled
          ? l10n.androidExactAlarmsEnabled
          : l10n.androidExactAlarmsDisabled,
    ];
    return parts.join(' · ');
  }

  Future<void> _onBatteryOptimizationChanged(bool enabled) async {
    if (enabled) {
      await AndroidReminderGuard.instance.requestIgnoreBatteryOptimizations();
      return;
    }

    final confirmed = await confirmDisableBatteryOptimization(context);
    if (confirmed && mounted) {
      await AndroidReminderGuard.instance.openAppBatterySettings();
    }
  }

  Future<void> _scheduleTestReminder() async {
    final l10n = AppLocalizations.of(context)!;
    await AndroidReminderGuard.instance.ensureReminderPermissions();
    final ok = await AndroidReminderGuard.instance
        .scheduleBackgroundTestReminder(
          title: l10n.androidTestBackgroundReminder,
          body: l10n.androidTestBackgroundReminderSubtitle,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.androidTestBackgroundReminderScheduled
              : l10n.androidTestBackgroundReminderFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.sectionAndroidBackground),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.androidBackgroundSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          title: Text(l10n.androidCheckReminderPermissions),
          subtitle: _permissionStatus == null
              ? null
              : Text(_permissionStatusMessage(l10n, _permissionStatus!)),
          trailing: const Icon(Icons.notifications_active_outlined),
          onTap: _checkPermissions,
        ),
        SwitchListTile(
          title: Text(l10n.androidBatteryOptimization),
          subtitle: Text(
            _isIgnoringBatteryOptimizations
                ? l10n.androidBatteryOptimizationSubtitleOn
                : l10n.androidBatteryOptimizationSubtitleOff,
          ),
          value: _isIgnoringBatteryOptimizations,
          onChanged: _onBatteryOptimizationChanged,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.androidKillBackgroundHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          title: Text(l10n.androidTestBackgroundReminder),
          subtitle: Text(l10n.androidTestBackgroundReminderSubtitle),
          trailing: const Icon(Icons.alarm_on_outlined),
          onTap: _scheduleTestReminder,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.androidAutostartHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter({required this.l10n});

  final AppLocalizations l10n;

  Future<void> _openGithub(BuildContext context) async {
    final uri = Uri.parse(kGithubRepoUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsGithubOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          Text(
            l10n.settingsVersion(kAppVersion),
            style: mutedStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openGithub(context),
            icon: const Icon(Icons.code, size: 18),
            label: Text(l10n.settingsGithub),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.appTagline, style: mutedStyle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
