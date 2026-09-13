import 'package:orbit/core/widgets/app_snack_bar.dart';

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
  refreshScheduleContainer(container);
  container.read(reminderSettingsProvider.notifier).scheduleResync();
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
  messenger.hideCurrentSnackBar();
  messenger.showAppSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      persist: false,
      action: SnackBarAction(
        label: l10n.actionUndo,
        onPressed: () async {
          final result = await restoreDeletedWithRefresh(container, ids);
          messenger.showAppSnackBar(
            SnackBar(
              duration: const Duration(seconds: 4),
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
