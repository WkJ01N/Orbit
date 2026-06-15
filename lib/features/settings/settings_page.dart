import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/app_info.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/core/widgets/section_header.dart';
import 'package:orbit/features/settings/battery_disable_dialog.dart';
import 'package:orbit/features/settings/check_in_disable_dialog.dart';
import 'package:orbit/features/settings/delete_ended_sessions_dialog.dart';
import 'package:orbit/features/settings/export_backup_actions.dart';
import 'package:orbit/features/settings/reminder_setting_actions.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/reminder_permission_status.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/services/alarm_intent_service.dart';
import 'package:orbit/services/android_reminder_guard.dart';
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

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.settings});

  final ReminderSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currentLocale = ref.watch(localeProvider);
    final themeColor = ref.watch(themeColorProvider);
    final rescheduleError = ref.watch(lastRescheduleErrorProvider);
    final notifier = ref.read(reminderSettingsProvider.notifier);

    return ListView(
      children: [
        SectionHeader(title: l10n.sectionLanguage),
        ListTile(
          title: Text(l10n.languageTitle),
          subtitle: Text(l10n.languageSubtitle),
          trailing: DropdownButton<Locale>(
            value: _matchingLocale(currentLocale),
            underline: const SizedBox.shrink(),
            onChanged: (locale) async {
              if (locale == null) {
                return;
              }
              await ref.read(localeProvider.notifier).setLocale(locale);
              if (!context.mounted) {
                return;
              }
              await applyReminderUpdate(
                context,
                ref,
                () => ref.read(reminderSettingsProvider.notifier).resyncReminders(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.languageChangedResynced)),
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
        SectionHeader(title: l10n.sectionSchedule),
        _GridDefaultWeekTile(),
        const SizedBox(height: 8),
        SectionHeader(title: l10n.sectionAppearance),
        _ThemeColorTile(
          currentColor: themeColor,
          onColorSelected: (color) =>
              ref.read(themeColorProvider.notifier).setColor(color),
        ),
        const SizedBox(height: 8),
        if (Platform.isWindows) ...[
          SectionHeader(title: l10n.sectionSystem),
          const _LaunchAtStartupTile(),
          const SizedBox(height: 8),
        ],
        SectionHeader(title: l10n.sectionReminders),
        if (rescheduleError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: MaterialBanner(
              content: Text(l10n.reminderResyncFailedBanner),
              leading: Icon(Icons.warning_amber, color: colorScheme.error),
              actions: [
                TextButton(
                  onPressed: () => _resyncReminders(context, ref),
                  child: Text(l10n.resyncReminders),
                ),
              ],
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
          trailing: DropdownButton<int>(
            value: _effectiveLeadMinutes(settings.leadMinutes),
            underline: const SizedBox.shrink(),
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
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          enabled: settings.enabled ||
              settings.checkInReminderEnabled ||
              settings.nextDaySummaryEnabled,
          title: Text(l10n.resyncReminders),
          subtitle: Text(l10n.resyncRemindersSubtitle),
          trailing: const Icon(Icons.refresh),
          onTap: (settings.enabled ||
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
            l10n.nextDaySummaryTimeSubtitle(settings.nextDaySummaryTimeLabel),
          ),
          trailing: const Icon(Icons.schedule),
          onTap: settings.nextDaySummaryEnabled
              ? () => _pickNextDaySummaryTime(context, ref)
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
            final confirmed = await confirmDisableCheckInReminder(context);
            if (confirmed && context.mounted) {
              await applyReminderUpdate(
                context,
                ref,
                () => notifier.setCheckInReminderEnabled(false),
              );
            }
          },
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
              l10n.systemAlarmLeadSubtitle(settings.systemAlarmLeadMinutes),
            ),
            trailing: DropdownButton<int>(
              value: _effectiveAlarmLeadMinutes(settings.systemAlarmLeadMinutes),
              underline: const SizedBox.shrink(),
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
        SectionHeader(title: l10n.sectionData),
        _ExportBackupSection(),
        ListTile(
          title: Text(l10n.deleteEndedSessions),
          subtitle: Text(l10n.deleteEndedSessionsSubtitle),
          leading: Icon(Icons.event_busy, color: colorScheme.error),
          onTap: () => deleteEndedSessionsWithFeedback(context, ref),
        ),
        ListTile(
          title: Text(l10n.clearAllData),
          subtitle: Text(l10n.clearAllDataSubtitle),
          leading: Icon(Icons.delete_outline, color: colorScheme.error),
          onTap: () => _confirmClearAll(context, ref),
        ),
        const SizedBox(height: 32),
        _SettingsFooter(l10n: l10n),
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
    final current = ref.read(reminderSettingsProvider).value ??
        const ReminderSettings();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.nextDaySummaryHour,
        minute: current.nextDaySummaryMinute,
      ),
    );
    if (picked != null) {
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
    final sessions = await ref.read(scheduleRepositoryProvider).getAllSessions();
    final result = await ref.read(alarmIntentServiceProvider).setTomorrowFirstClassAlarm(
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      final failures =
          ref.read(reminderSchedulerProvider).lastScheduleFailureCount;
      final message = failures > 0
          ? l10n.resyncPartialFailed(failures)
          : l10n.resyncDone;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmClearTitle),
        content: Text(l10n.confirmClearContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.actionClear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(scheduleRepositoryProvider).clearAll();
        await ref.read(reminderSchedulerProvider).cancelAll();
        ref.read(selectedWeekStartProvider.notifier).state = null;
        refreshSchedule(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.dataCleared)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.clearAllFailed('$e'))),
          );
        }
      }
    }
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
      trailing: DropdownButton<GridDefaultWeekMode>(
        value: mode,
        underline: const SizedBox.shrink(),
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

class _ExportBackupSection extends ConsumerStatefulWidget {
  const _ExportBackupSection();

  @override
  ConsumerState<_ExportBackupSection> createState() =>
      _ExportBackupSectionState();
}

class _ExportBackupSectionState extends ConsumerState<_ExportBackupSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_busy) {
      return ListTile(
        leading: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(l10n.exportInProgress),
      );
    }

    return Column(
      children: [
        ListTile(
          title: Text(l10n.exportScheduleJson),
          subtitle: Text(l10n.exportScheduleJsonSubtitle),
          leading: const Icon(Icons.backup_outlined),
          onTap: () => _run(() => exportScheduleJson(context, ref)),
        ),
        ListTile(
          title: Text(l10n.exportScheduleXlsx),
          subtitle: Text(l10n.exportScheduleXlsxSubtitle),
          leading: const Icon(Icons.table_view_outlined),
          onTap: () => _run(() => exportScheduleXlsx(context, ref)),
        ),
        ListTile(
          title: Text(l10n.restoreFromBackup),
          subtitle: Text(l10n.restoreFromBackupSubtitle),
          leading: const Icon(Icons.restore_outlined),
          onTap: () => _run(() => restoreFromBackup(context, ref)),
        ),
      ],
    );
  }
}

class _LaunchAtStartupTile extends ConsumerStatefulWidget {
  const _LaunchAtStartupTile();

  @override
  ConsumerState<_LaunchAtStartupTile> createState() =>
      _LaunchAtStartupTileState();
}

class _LaunchAtStartupTileState extends ConsumerState<_LaunchAtStartupTile> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ref.read(startupServiceProvider).loadPreference();
    if (mounted) {
      setState(() => _enabled = enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = _enabled;

    return SwitchListTile(
      title: Text(l10n.launchAtStartup),
      subtitle: Text(l10n.launchAtStartupSubtitle),
      value: enabled ?? false,
      onChanged: enabled == null
          ? null
          : (value) async {
              try {
                await ref.read(startupServiceProvider).setEnabled(value);
                if (mounted) {
                  setState(() => _enabled = value);
                }
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!.launchAtStartupFailed('$e'),
                    ),
                  ),
                );
              }
            },
    );
  }
}

class _ThemeColorTile extends StatelessWidget {
  const _ThemeColorTile({
    required this.currentColor,
    required this.onColorSelected,
  });

  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  bool _isPresetSelected(Color preset) =>
      colorsMatchTheme(preset, currentColor);

  bool get _isCustomSelected {
    return !kThemePresetColors.any(_isPresetSelected);
  }

  Future<void> _showCustomDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: formatThemeHexColor(currentColor).substring(1),
    );
    var preview = currentColor;
    var errorText = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updatePreview(String value) {
              final parsed = parseThemeHexColor(value);
              setDialogState(() {
                preview = parsed ?? currentColor;
                errorText = parsed == null && value.trim().isNotEmpty
                    ? l10n.themeColorInvalidHex
                    : '';
              });
            }

            return AlertDialog(
              title: Text(l10n.themeColorCustomTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: preview,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            prefixText: '#',
                            labelText: 'HEX',
                            errorText: errorText.isEmpty ? null : errorText,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9A-Fa-f#]'),
                            ),
                            LengthLimitingTextInputFormatter(7),
                          ],
                          onChanged: updatePreview,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = parseThemeHexColor(controller.text);
                    if (parsed == null) {
                      setDialogState(() {
                        errorText = l10n.themeColorInvalidHex;
                      });
                      return;
                    }
                    onColorSelected(parsed);
                    Navigator.pop(dialogContext);
                  },
                  child: Text(l10n.actionApply),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.themeColorTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            l10n.themeColorSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final color in kThemePresetColors)
                _ColorSwatch(
                  color: color,
                  selected: _isPresetSelected(color),
                  onTap: () => onColorSelected(color),
                ),
              if (_isCustomSelected)
                _ColorSwatch(
                  color: currentColor,
                  selected: true,
                  onTap: () => _showCustomDialog(context),
                ),
              _CustomColorButton(
                label: l10n.themeColorCustom,
                onTap: () => _showCustomDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 18,
                  color: _contrastIconColor(color),
                )
              : null,
        ),
      ),
    );
  }

  Color _contrastIconColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

class _AndroidBackgroundSection extends ConsumerStatefulWidget {
  const _AndroidBackgroundSection();

  @override
  ConsumerState<_AndroidBackgroundSection> createState() =>
      _AndroidBackgroundSectionState();
}

class _AndroidBackgroundSectionState
    extends ConsumerState<_AndroidBackgroundSection> with WidgetsBindingObserver {
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
    final status =
        await AndroidReminderGuard.instance.queryPermissionStatus();
    if (mounted) {
      setState(() => _permissionStatus = status);
    }
  }

  Future<void> _loadBatteryStatus() async {
    final ignoring =
        await AndroidReminderGuard.instance.isIgnoringBatteryOptimizations();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsGithubOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );

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
          Text(
            l10n.appTagline,
            style: mutedStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  const _CustomColorButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.palette_outlined, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
