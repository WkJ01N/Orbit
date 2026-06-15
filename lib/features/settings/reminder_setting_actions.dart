import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/providers/reminder_providers.dart';

Future<void> applyReminderUpdate(
  BuildContext context,
  WidgetRef ref,
  Future<int> Function() action,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final failures = await action();
    if (!context.mounted) {
      return;
    }
    final syncError = ref.read(lastRescheduleErrorProvider);
    // Sentinels written by the reschedule flow:
    //  - 'partial:N' : some individual notifications failed to schedule.
    //  - 'verify'    : the OS reported no pending alarms despite no exception
    //                  (typical of OEMs silently dropping exact alarms).
    // Any other non-null value is a real exception string.
    final isPartialFailure =
        syncError != null && syncError.startsWith('partial:');
    final isVerifyFailure = syncError == 'verify';
    if (isVerifyFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reminderScheduleVerifyFailed)),
      );
    } else if (syncError != null && !isPartialFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reminderSyncFailed(syncError))),
      );
    } else if (failures > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resyncPartialFailed(failures))),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reminderSyncFailed('$e'))),
      );
    }
  }
}
