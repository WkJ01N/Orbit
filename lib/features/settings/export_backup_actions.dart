import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/providers/course_color_providers.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';

Future<void> exportScheduleJson(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final repository = ref.read(scheduleRepositoryProvider);
    final sessions = await repository.getAllSessions();
    if (!context.mounted) {
      return;
    }
    await ref
        .read(automaticCourseColorIdsProvider.notifier)
        .ensureSaved(sessions);
    final settings = await ref
        .read(settingsServiceProvider)
        .exportPortableSettings();
    final json = await ScheduleBackupService().encodeWithAudio(
      sessions,
      settings,
      sessionAliases: await ref
          .read(appDatabaseProvider)
          .reminderSessionAliases(),
      seriesMemberships: await ref
          .read(appDatabaseProvider)
          .reminderSeriesMemberships(),
    );
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exportScheduleJson),
        content: Text(
          '${(utf8.encode(json).length / 1024 / 1024).toStringAsFixed(2)} MiB',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.reminderSave),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportScheduleJson,
      fileName: 'orbit-backup.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(json),
    );
    if (path == null) {
      return;
    }

    if (!Platform.isAndroid) {
      await File(path).writeAsString(json);
    }

    if (context.mounted) {
      _showSnackBar(context, l10n.exportDone(sessions.length));
    }
  } catch (e) {
    if (context.mounted) {
      _showSnackBar(context, l10n.exportFailed('$e'), isError: true);
    }
  }
}

Future<void> exportScheduleXlsx(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final repository = ref.read(scheduleRepositoryProvider);
    final sessions = await repository.getAllSessions();
    if (!context.mounted) {
      return;
    }
    if (sessions.isEmpty) {
      _showSnackBar(context, l10n.exportNothingToExport);
      return;
    }

    final bytes = await repository.exportToXlsxBytes();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportScheduleXlsx,
      fileName: 'orbit-schedule.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: Uint8List.fromList(bytes),
    );
    if (path == null) {
      return;
    }

    if (!Platform.isAndroid) {
      await File(path).writeAsBytes(bytes);
    }

    if (context.mounted) {
      _showSnackBar(context, l10n.exportDone(sessions.length));
    }
  } catch (e) {
    if (context.mounted) {
      _showSnackBar(context, l10n.exportFailed('$e'), isError: true);
    }
  }
}

Future<void> restoreFromBackup(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final raw = file.bytes != null
        ? utf8.decode(file.bytes!)
        : file.path != null
        ? await File(file.path!).readAsString()
        : null;
    if (raw == null) {
      if (context.mounted) {
        _showSnackBar(
          context,
          l10n.restoreFailed(l10n.importPickMissingPath(file.name)),
        );
      }
      return;
    }

    OrbitBackup backup;
    try {
      backup = ScheduleBackupService().decodeBackup(raw);
    } on ScheduleBackupException catch (e) {
      if (context.mounted) {
        _showSnackBar(
          context,
          _backupErrorMessage(l10n, e.message),
          isError: true,
        );
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    final selection = await _showRestoreOptions(context, backup);

    if (selection == null || !context.mounted) {
      return;
    }

    final restoredSettings =
        selection.restoreSettings && backup.settings != null
        ? await ScheduleBackupService().restoreAudio(backup)
        : null;
    List<CourseSession> restored = const [];
    if (selection.restoreCourses) {
      restored = await ref
          .read(scheduleRepositoryProvider)
          .restoreBackupSessions(backup.sessions, strategy: selection.strategy);
    }
    if (selection.restoreCourses) refreshSchedule(ref);
    if (restoredSettings != null) {
      await ref
          .read(settingsServiceProvider)
          .importPortableSettings(restoredSettings.settings);
      await ref.read(appDatabaseProvider).clearReminderHistory();
      if (restoredSettings.soundFallback && context.mounted) {
        _showSnackBar(context, l10n.reminderSoundFallback);
      }
      ref.invalidate(localeProvider);
      ref.invalidate(themeColorProvider);
      ref.invalidate(themeModeProvider);
      ref.invalidate(themeStyleProvider);
      ref.invalidate(colorSchemeProvider);
      ref.invalidate(multicolorSettingsProvider);
      ref.invalidate(automaticCourseColorIdsProvider);
      ref.invalidate(courseColorOverridesProvider);
      ref.invalidate(gridDefaultWeekModeProvider);
      ref.invalidate(weekStartDayProvider);
      ref.invalidate(gridDensityProvider);
      ref.invalidate(scheduleDisplaySettingsProvider);
      ref.invalidate(importConfigurationProvider);
      ref.invalidate(reminderSettingsProvider);
      await ref.read(reminderSettingsProvider.future);
    }
    final failures = await ref
        .read(reminderSettingsProvider.notifier)
        .resyncReminders();

    if (context.mounted) {
      final baseMessage = selection.restoreCourses
          ? l10n.restoreDone(restored.length)
          : l10n.restoreSettingsDone;
      final message = failures > 0
          ? '$baseMessage ${l10n.resyncPartialFailed(failures)}'
          : baseMessage;
      _showSnackBar(context, message);
    }
  } catch (e) {
    if (context.mounted) {
      _showSnackBar(context, l10n.restoreFailed('$e'), isError: true);
    }
  }
}

class _RestoreSelection {
  const _RestoreSelection({
    required this.restoreCourses,
    required this.restoreSettings,
    required this.strategy,
  });

  final bool restoreCourses;
  final bool restoreSettings;
  final ImportMergeStrategy strategy;
}

Future<_RestoreSelection?> _showRestoreOptions(
  BuildContext context,
  OrbitBackup backup,
) {
  final l10n = AppLocalizations.of(context)!;
  var restoreCourses = backup.sessions.isNotEmpty;
  var restoreSettings = backup.settings != null;
  var strategy = ImportMergeStrategy.mergeOverwrite;
  final dates = backup.sessions.map((session) => session.date).toList()..sort();
  final start = dates.isEmpty ? '—' : formatIsoDate(dates.first);
  final end = dates.isEmpty ? '—' : formatIsoDate(dates.last);

  return showDialog<_RestoreSelection>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.restorePreviewSummary(
                  backup.version,
                  backup.sessions.length,
                  start,
                  end,
                ),
              ),
              if (backup.settings != null) ...[
                const SizedBox(height: 8),
                Text(l10n.backupIncludesSettings),
              ],
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: restoreCourses,
                title: Text(l10n.restoreCoursesOption),
                onChanged: backup.sessions.isEmpty
                    ? null
                    : (value) =>
                          setState(() => restoreCourses = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: restoreSettings,
                title: Text(l10n.restoreSettingsOption),
                onChanged: backup.settings == null
                    ? null
                    : (value) =>
                          setState(() => restoreSettings = value ?? false),
              ),
              if (restoreCourses)
                DropdownButtonFormField<ImportMergeStrategy>(
                  initialValue: strategy,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ImportMergeStrategy.mergeOverwrite,
                      child: Text(l10n.restoreModeMerge),
                    ),
                    DropdownMenuItem(
                      value: ImportMergeStrategy.replaceWeek,
                      child: Text(l10n.restoreModeReplace),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () =>
                        strategy = value ?? ImportMergeStrategy.mergeOverwrite,
                  ),
                ),
              if (!restoreCourses && !restoreSettings) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.restoreNothingSelected,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: !restoreCourses && !restoreSettings
                ? null
                : () => Navigator.pop(
                    context,
                    _RestoreSelection(
                      restoreCourses: restoreCourses,
                      restoreSettings: restoreSettings,
                      strategy: strategy,
                    ),
                  ),
            child: Text(l10n.actionContinue),
          ),
        ],
      ),
    ),
  );
}

String _backupErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    'unsupported_version' => l10n.backupUnsupportedVersion,
    _ => l10n.backupInvalidFormat,
  };
}

void _showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(
    context,
  ).showAppSnackBar(SnackBar(content: Text(message)), isError: isError);
}
