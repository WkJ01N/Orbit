import 'package:orbit/providers/typography_providers.dart';
import 'package:orbit/services/background_package_service.dart';
import 'package:orbit/services/backup_file_export.dart';
import 'package:orbit/providers/background_providers.dart';
import 'package:orbit/models/background_text.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/statistics_text.dart';
import 'package:orbit/core/widgets/statistics_deletion_choice.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/providers/course_color_providers.dart';
import 'package:orbit/providers/account_sync_providers.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/archive_providers.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';

Future<void> exportScheduleJson(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final database = ref.read(appDatabaseProvider);
    await database.refreshStatistics();
    final sessions = await database.getAllSessions(includeDeleted: true);
    if (!context.mounted) {
      return;
    }
    await ref
        .read(automaticCourseColorIdsProvider.notifier)
        .ensureSaved(sessions);
    final settings = await ref
        .read(settingsServiceProvider)
        .exportPortableSettings(
          accountUid: (await database.activeSyncAccount())?.uid,
        );
    final json = await ScheduleBackupService().encodeWithAudio(
      sessions,
      settings,
      deadlines: await ref
          .read(appDatabaseProvider)
          .getDeadlines(includeDeleted: true),
      statistics: await ref.read(appDatabaseProvider).statisticsRecords(),
      sessionAliases: await ref
          .read(appDatabaseProvider)
          .reminderSessionAliases(),
      seriesMemberships: await ref
          .read(appDatabaseProvider)
          .reminderSeriesMemberships(),
    );
    if (!context.mounted) return;
    var includeMedia = false;
    final text = BackgroundText(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(l10n.exportScheduleJson),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(utf8.encode(json).length / 1024 / 1024).toStringAsFixed(2)} MiB',
              ),
              CheckboxListTile(
                value: includeMedia,
                onChanged: (value) =>
                    update(() => includeMedia = value ?? false),
                title: Text(
                  text.t(
                    'Include background media (.orbit)',
                    '包含背景素材（.orbit）',
                    '包含背景素材（.orbit）',
                  ),
                ),
              ),
            ],
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
      ),
    );
    if (proceed != true) return;
    if (includeMedia) {
      final staging = await Directory.systemTemp.createTemp('orbit-export-');
      try {
        final package = await BackgroundPackageService(
          ref.read(backgroundAssetServiceProvider),
        ).create(json, staging);
        if (await exportBackupPackage(package) && context.mounted) {
          _showSnackBar(context, l10n.exportDone(sessions.length));
        }
      } finally {
        await staging.delete(recursive: true);
      }
      return;
    }
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
  Directory? staging;
  PreparedBackgroundPackage? package;
  var committed = false;
  try {
    final result = await FilePicker.platform.pickFiles(
      // Android has no registered MIME mapping for the .orbit extension.
      type: Platform.isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: Platform.isAndroid ? null : ['json', 'orbit'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    String? raw;
    if (file.path != null && file.extension?.toLowerCase() == 'orbit') {
      staging = await Directory.systemTemp.createTemp('orbit-restore-');
      package = await BackgroundPackageService(
        ref.read(backgroundAssetServiceProvider),
      ).prepare(File(file.path!), staging);
    } else if (file.path != null) {
      raw = await File(file.path!).readAsString();
    } else {
      throw FormatException(l10n.importPickMissingPath(file.name));
    }

    OrbitBackup backup;
    try {
      backup = package?.backup ?? ScheduleBackupService().decodeBackup(raw!);
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

    final settingsService = ref.read(settingsServiceProvider);
    final accountUid =
        (await ref.read(appDatabaseProvider).activeSyncAccount())?.uid;
    final previousPreferences = await settingsService.snapshotPreferences();
    final previousSettings =
        selection.restoreSettings &&
            backup.settings != null &&
            selection.strategy == ImportMergeStrategy.mergeOverwrite
        ? await settingsService.exportPortableSettings(accountUid: accountUid)
        : null;
    final restoredSettings =
        selection.restoreSettings && backup.settings != null
        ? await ScheduleBackupService().restoreAudio(backup)
        : null;
    PortableSettings? effectiveSettings;
    var missingBackgrounds = false;
    final restored = selection.restoreCourses
        ? backup.sessions
        : const <CourseSession>[];
    try {
      if (restoredSettings != null) {
        await package?.install(ref.read(backgroundAssetServiceProvider));
        effectiveSettings = previousSettings == null
            ? restoredSettings.settings
            : restoredSettings.settings.mergeWith(previousSettings);
        final backgrounds = effectiveSettings.backgrounds;
        if (backgrounds != null) {
          final available = await ref
              .read(backgroundAssetServiceProvider)
              .resolveAvailable(backgrounds);
          missingBackgrounds =
              jsonEncode(available.toJson()) !=
              jsonEncode(backgrounds.toJson());
          effectiveSettings = PortableSettings.fromJson({
            ...effectiveSettings.toJson(),
            'backgrounds': available.toJson(),
          });
        }
      }
      await ref
          .read(appDatabaseProvider)
          .restoreUserBackup(
            sessions: selection.restoreCourses ? backup.sessions : null,
            deadlines: selection.restoreDeadlines ? backup.deadlines : null,
            statistics: selection.restoreStatistics ? backup.statistics : null,
            aliases: backup.sessionAliases,
            memberships: backup.seriesMemberships,
            replace: selection.strategy == ImportMergeStrategy.replaceWeek,
            deleteStatistics: selection.deleteStatistics,
            restoreSettings: restoredSettings == null
                ? null
                : () => settingsService.importPortableSettings(
                    effectiveSettings!,
                    accountUid: accountUid,
                  ),
          );
    } catch (_) {
      if (restoredSettings != null) {
        try {
          await settingsService.restorePreferences(previousPreferences);
        } finally {
          await ScheduleBackupService().discardImportedAudio(
            restoredSettings.importedFiles,
          );
          for (final font in restoredSettings.importedFonts) {
            await ref.read(fontServiceProvider).deleteFile(font);
          }
        }
      }
      rethrow;
    }
    committed = true;
    if (missingBackgrounds && context.mounted) {
      _showSnackBar(
        context,
        BackgroundText(context).t(
          'Some background media is missing. Choose it again in Page backgrounds.',
          '部分背景素材缺失，相关页面已停用背景，请在页面背景中补选。',
          '部分背景素材遺失，相關頁面已停用背景，請在頁面背景中補選。',
        ),
      );
    }
    if (selection.restoreCourses || selection.restoreDeadlines) {
      refreshSchedule(ref);
    }
    if (restoredSettings != null) {
      await ref.read(appDatabaseProvider).clearReminderHistory();
      if (restoredSettings.soundFallback && context.mounted) {
        _showSnackBar(context, l10n.reminderSoundFallback);
      }
      final typography = await ref.read(fontServiceProvider).initialize();
      ref.read(typographySettingsProvider.notifier).restoreLoaded(typography);
      ref.invalidate(backgroundSettingsProvider);
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
      ref.invalidate(archiveSettingsProvider);
      ref.invalidate(importConfigurationProvider);
      ref.invalidate(autoSyncSettingsProvider);
      ref.invalidate(reminderSettingsProvider);
      await ref.read(reminderSettingsProvider.future);
      await ref.read(startupServiceProvider).syncWithPreference();
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
  } finally {
    if (!committed) await package?.rollback();
    if (staging != null && await staging.exists()) {
      await staging.delete(recursive: true);
    }
  }
}

class _RestoreSelection {
  const _RestoreSelection({
    required this.restoreCourses,
    required this.restoreDeadlines,
    required this.restoreSettings,
    required this.restoreStatistics,
    required this.deleteStatistics,
    required this.strategy,
  });

  final bool restoreCourses;
  final bool restoreDeadlines;
  final bool restoreSettings;
  final bool restoreStatistics;
  final bool deleteStatistics;
  final ImportMergeStrategy strategy;
}

Future<_RestoreSelection?> _showRestoreOptions(
  BuildContext context,
  OrbitBackup backup,
) {
  final l10n = AppLocalizations.of(context)!;
  var restoreCourses = backup.version >= 9 || backup.sessions.isNotEmpty;
  var restoreStatistics = backup.version >= 9;
  var deleteStatistics = false;
  var restoreDeadlines = backup.version >= 9 || backup.deadlines.isNotEmpty;
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
                onChanged: backup.version < 9 && backup.sessions.isEmpty
                    ? null
                    : (value) =>
                          setState(() => restoreCourses = value ?? false),
              ),
              if (backup.version >= 9 || backup.deadlines.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: restoreDeadlines,
                  title: Text(
                    '${DeadlineText.of(context).ddl} (${backup.deadlines.length})',
                  ),
                  onChanged: (value) =>
                      setState(() => restoreDeadlines = value ?? false),
                ),
              if (backup.version >= 9)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: restoreStatistics,
                  title: Text(
                    '${StatisticsText.of(context).selectStatistics} (${backup.statistics.length})',
                  ),
                  onChanged: (v) =>
                      setState(() => restoreStatistics = v ?? false),
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
              if (restoreCourses || restoreDeadlines || restoreStatistics)
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
              if (restoreCourses)
                StatisticsDeletionChoice(
                  onChanged: (v) => deleteStatistics = v,
                ),
              if (!restoreCourses &&
                  !restoreDeadlines &&
                  !restoreSettings &&
                  !restoreStatistics) ...[
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
            onPressed:
                !restoreCourses &&
                    !restoreDeadlines &&
                    !restoreSettings &&
                    !restoreStatistics
                ? null
                : () => Navigator.pop(
                    context,
                    _RestoreSelection(
                      restoreCourses: restoreCourses,
                      restoreDeadlines: restoreDeadlines,
                      restoreSettings: restoreSettings,
                      restoreStatistics: restoreStatistics,
                      deleteStatistics: deleteStatistics,
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
