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
          title: l10n.settingsBackupGroup,
          children: const [_ExportBackupSection()],
        ),
        SettingsGroup(
          title: l10n.trashTitle,
          children: [
            ListTile(
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
          ],
        ),
        SettingsGroup(
          title: l10n.settingsDiagnosticsGroup,
          children: [
            ListTile(
              title: Text(l10n.debugTitle),
              subtitle: Text(l10n.debugSubtitle),
              leading: const Icon(Icons.bug_report_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DebugPage()),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l10n.settingsDangerGroup,
          children: [
            ListTile(
              title: Text(l10n.deleteEndedSessions),
              subtitle: Text(l10n.deleteEndedSessionsSubtitle),
              leading: Icon(Icons.event_busy, color: colors.error),
              onTap: () => deleteEndedSessionsWithFeedback(context, ref),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              title: Text(l10n.clearAllData),
              subtitle: Text(l10n.clearAllDataSubtitle),
              leading: Icon(Icons.delete_outline, color: colors.error),
              onTap: () => _confirmClearAll(context, ref),
            ),
          ],
        ),
      ],
    );
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
    if (confirmed != true || !context.mounted) return;

    try {
      final container = ProviderScope.containerOf(context);
      final repository = ref.read(scheduleRepositoryProvider);
      final deletedIds = (await repository.getAllSessions())
          .map((session) => session.id)
          .toList();
      await repository.clearAll();
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
            content: Text(l10n.clearAllFailed('$error')),
          ),
        );
      }
    }
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(l10n.exportScheduleJson),
          subtitle: Text(l10n.backupIncludesSettings),
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
