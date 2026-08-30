import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/providers/app_providers.dart';

Future<RestoreDeletedResult> restoreDeletedWithRefresh(
  ProviderContainer container,
  List<String> ids,
) async {
  final result = await container
      .read(scheduleRepositoryProvider)
      .restoreDeletedSessions(ids);
  await container.read(reminderSettingsProvider.notifier).resyncReminders();
  refreshScheduleContainer(container);
  return result;
}

void showDeletionUndo({
  required BuildContext context,
  required ProviderContainer container,
  required List<String> ids,
  required String message,
}) {
  if (ids.isEmpty) return;
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: l10n.actionUndo,
        onPressed: () async {
          final result = await restoreDeletedWithRefresh(container, ids);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.trashRestoreResult(result.restored, result.skipped),
              ),
            ),
          );
        },
      ),
    ),
  );
}
