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

Future<void> exportScheduleJson(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final repository = ref.read(scheduleRepositoryProvider);
    final sessions = await repository.getAllSessions();
    if (sessions.isEmpty) {
      _showSnackBar(context, l10n.exportNothingToExport);
      return;
    }

    final json = await repository.exportToJsonBackup();
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
      _showSnackBar(context, l10n.exportFailed('$e'));
    }
  }
}

Future<void> exportScheduleXlsx(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final repository = ref.read(scheduleRepositoryProvider);
    final sessions = await repository.getAllSessions();
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
      _showSnackBar(context, l10n.exportFailed('$e'));
    }
  }
}

Future<void> restoreFromBackup(
  BuildContext context,
  WidgetRef ref,
) async {
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
        _showSnackBar(context, l10n.restoreFailed(l10n.importPickMissingPath(file.name)));
      }
      return;
    }

    List<CourseSession> previewSessions;
    try {
      previewSessions = ScheduleBackupService().decodeFromJson(raw);
    } on ScheduleBackupException catch (e) {
      if (context.mounted) {
        _showSnackBar(context, _backupErrorMessage(l10n, e.message));
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmContent(previewSessions.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionContinue),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final restored = await ref.read(scheduleRepositoryProvider).importFromJsonBackup(raw);
    final failures =
        await ref.read(reminderSettingsProvider.notifier).resyncReminders();
    refreshSchedule(ref);

    if (context.mounted) {
      final message = failures > 0
          ? '${l10n.restoreDone(restored.length)} ${l10n.resyncPartialFailed(failures)}'
          : l10n.restoreDone(restored.length);
      _showSnackBar(context, message);
    }
  } catch (e) {
    if (context.mounted) {
      _showSnackBar(context, l10n.restoreFailed('$e'));
    }
  }
}

String _backupErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    'unsupported_version' => l10n.backupUnsupportedVersion,
    _ => l10n.backupInvalidFormat,
  };
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
