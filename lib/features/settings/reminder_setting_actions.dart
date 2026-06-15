import 'dart:io';

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

String reminderResyncSuccessMessage(AppLocalizations l10n, WidgetRef ref) {
  final failures = ref.read(reminderSchedulerProvider).lastScheduleFailureCount;
  if (failures > 0) {
    return l10n.resyncPartialFailed(failures);
  }

  if (Platform.isAndroid) {
    final alarmCount = ref.read(lastRegisteredAlarmCountProvider);
    if (alarmCount > 0) {
      return '${l10n.resyncDone} ${l10n.reminderRegisteredAlarmCount(alarmCount)}';
    }
  }

  final pending = ref.read(lastScheduledCountProvider);
  if (pending > 0) {
    return '${l10n.resyncDone} ${l10n.reminderScheduledCount(pending)}';
  }

  return l10n.resyncDone;
}
