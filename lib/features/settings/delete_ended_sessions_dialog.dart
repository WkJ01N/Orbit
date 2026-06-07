import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/widgets/step_confirm_dialog.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/providers/app_providers.dart';

Future<bool> confirmDeleteEndedSessions(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final count = await ref.read(scheduleRepositoryProvider).countEndedSessions();

  if (!context.mounted) {
    return false;
  }

  if (count == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.deleteEndedNone)),
    );
    return false;
  }

  return confirmWithSteps(
    context,
    steps: [
      (l10n.deleteEndedConfirm1Title, l10n.deleteEndedConfirm1Content(count)),
      (l10n.deleteEndedConfirm2Title, l10n.deleteEndedConfirm2Content),
    ],
  );
}

Future<void> deleteEndedSessionsWithFeedback(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await confirmDeleteEndedSessions(context, ref);
  if (!confirmed || !context.mounted) {
    return;
  }

  final deleted =
      await ref.read(scheduleRepositoryProvider).deleteEndedSessions();
  await rescheduleAllReminders(ref);
  refreshSchedule(ref);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.deleteEndedDone(deleted))),
    );
  }
}
