import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/features/statistics/statistics_page.dart';
import 'package:orbit/models/statistics_text.dart';
import 'package:orbit/core/widgets/statistics_deletion_choice.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/widgets/settings_group.dart';
import 'package:orbit/features/session/deletion_feedback.dart';
import 'package:orbit/features/settings/delete_ended_sessions_dialog.dart';
import 'package:orbit/features/settings/debug_page.dart';
import 'package:orbit/features/settings/deleted_sessions_page.dart';
import 'package:orbit/features/settings/export_backup_actions.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/features/import/import_templates_page.dart';
import 'package:orbit/features/import/import_plan_editor.dart';
import 'package:orbit/features/settings/account_sync_page.dart';
import 'package:orbit/features/archive/archive_page.dart';
import 'package:orbit/features/archive/archive_actions.dart';
import 'package:orbit/models/orbit_feature_text.dart';

class SettingsDataSection extends ConsumerWidget {
  const SettingsDataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: StatisticsText.of(context).title,
          children: [
            PageModule(
              child: ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: Text(StatisticsText.of(context).title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const StatisticsPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: _accountSyncLabel(context),
          children: [
            PageModule(
              child: ListTile(
                title: Text(_accountSyncLabel(context)),
                subtitle: Text(_accountSyncSubtitle(context)),
                leading: const Icon(Icons.cloud_sync_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountSyncPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l10n.importTemplates,
          children: [
            PageModule(
              child: ListTile(
                title: Text(l10n.importTemplates),
                leading: const Icon(Icons.rule),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ImportTemplatesPage(),
                  ),
                ),
              ),
            ),
            PageModule(
              child: ListTile(
                title: Text(l10n.importPlans),
                leading: const Icon(Icons.schedule),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ImportPlansPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l10n.settingsBackupGroup,
          children: const [_ExportBackupSection()],
        ),
        SettingsGroup(
          title: OrbitFeatureText.of(context).archive,
          children: [
            PageModule(
              child: ListTile(
                title: Text(OrbitFeatureText.of(context).archive),
                leading: const Icon(Icons.archive_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ArchivePage()),
                ),
              ),
            ),
            const _ArchiveEndedCoursesTile(),
          ],
        ),
        SettingsGroup(
          title: l10n.trashTitle,
          children: [
            PageModule(
              child: ListTile(
                title: Text(l10n.trashTitle),
                subtitle: Text(l10n.trashSubtitle),
                leading: const Icon(Icons.restore_from_trash_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DeletedSessionsPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l10n.settingsDiagnosticsGroup,
          children: [
            PageModule(
              child: ListTile(
                title: Text(l10n.debugTitle),
                subtitle: Text(l10n.debugSubtitle),
                leading: const Icon(Icons.bug_report_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DebugPage()),
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l10n.settingsDangerGroup,
          children: [
            PageModule(
              child: ListTile(
                title: Text(l10n.deleteEndedSessions),
                subtitle: Text(l10n.deleteEndedSessionsSubtitle),
                leading: Icon(Icons.event_busy, color: colors.error),
                onTap: () => deleteEndedSessionsWithFeedback(context, ref),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            PageModule(
              child: ListTile(
                title: Text(l10n.clearAllData),
                subtitle: Text(l10n.clearAllDataSubtitle),
                leading: Icon(Icons.delete_outline, color: colors.error),
                onTap: () => _confirmClearAll(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    var deleteStatistics = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: PageModule(child: Text(l10n.confirmClearTitle)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PageModule(child: Text(l10n.confirmClearContent)),
            StatisticsDeletionChoice(onChanged: (v) => deleteStatistics = v),
          ],
        ),
        actions: [
          PageModule(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel),
            ),
          ),
          PageModule(
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.actionClear),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final container = ProviderScope.containerOf(context);
      final repository = ref.read(scheduleRepositoryProvider);
      final deletedIds = (await repository.getAllSessions())
          .map((session) => session.id)
          .toList();
      await repository.clearAll(deleteStatistics: deleteStatistics);
      await ref.read(reminderSchedulerProvider).cancelAllReminders();
      ref.read(selectedWeekStartProvider.notifier).state = null;
      refreshSchedule(ref);
      if (context.mounted) {
        showDeletionUndo(
          context: context,
          container: container,
          ids: deletedIds,
          message: l10n.dataCleared,
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: PageModule(child: Text(l10n.clearAllFailed('$error'))),
          ),
        );
      }
    }
  }
}

String _accountSyncLabel(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') return 'Account & sync';
  return locale.scriptCode?.toLowerCase() == 'hant' ||
          locale.countryCode == 'TW'
      ? '帳號與同步'
      : '账号与同步';
}

String _accountSyncSubtitle(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') {
    return 'Optionally sync schedules across your devices';
  }
  return locale.scriptCode?.toLowerCase() == 'hant' ||
          locale.countryCode == 'TW'
      ? '選擇性地在不同裝置間同步課表'
      : '可选地在不同设备间同步课表';
}

class _ArchiveEndedCoursesTile extends ConsumerStatefulWidget {
  const _ArchiveEndedCoursesTile();

  @override
  ConsumerState<_ArchiveEndedCoursesTile> createState() =>
      _ArchiveEndedCoursesTileState();
}

class _ArchiveEndedCoursesTileState
    extends ConsumerState<_ArchiveEndedCoursesTile> {
  bool _busy = false;

  Future<void> _archive() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await archiveAllEndedCoursesAction(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = OrbitFeatureText.of(context);
    return PageModule(
      child: ListTile(
        title: Text(text.archiveAllEnded),
        subtitle: Text(text.archiveAllEndedHint),
        leading: const Icon(Icons.inventory_2_outlined),
        trailing: _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: _busy ? null : _archive,
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
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_busy) {
      return PageModule(
        child: ListTile(
          leading: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text(l10n.exportInProgress),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageModule(
          child: ListTile(
            title: Text(l10n.exportScheduleJson),
            subtitle: Text(l10n.backupIncludesSettings),
            leading: const Icon(Icons.backup_outlined),
            onTap: () => _run(() => exportScheduleJson(context, ref)),
          ),
        ),
        PageModule(
          child: ListTile(
            title: Text(l10n.exportScheduleXlsx),
            subtitle: Text(l10n.exportScheduleXlsxSubtitle),
            leading: const Icon(Icons.table_view_outlined),
            onTap: () => _run(() => exportScheduleXlsx(context, ref)),
          ),
        ),
        PageModule(
          child: ListTile(
            title: Text(l10n.restoreFromBackup),
            subtitle: Text(l10n.restoreFromBackupSubtitle),
            leading: const Icon(Icons.restore_outlined),
            onTap: () => _run(() => restoreFromBackup(context, ref)),
          ),
        ),
      ],
    );
  }
}
