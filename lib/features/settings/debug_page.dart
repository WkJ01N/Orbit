import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/reminder_schedule_report.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/android_native_reminder_service.dart';

class DebugPage extends ConsumerWidget {
  const DebugPage({super.key, this.showAndroidTools});

  final bool? showAndroidTools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.debugTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            title: Text(l10n.androidTestImmediateReminder),
            subtitle: Text(l10n.androidTestImmediateReminderSubtitle),
            leading: const Icon(Icons.notifications_active_outlined),
            onTap: () => _showImmediateTestReminder(context, ref),
          ),
          if (showAndroidTools ?? Platform.isAndroid)
            ListTile(
              title: Text(l10n.androidTestBackgroundReminder),
              subtitle: Text(l10n.androidTestBackgroundReminderSubtitle),
              leading: const Icon(Icons.alarm_on_outlined),
              onTap: () => _scheduleBackgroundTestReminder(context, ref),
            ),
          if (showAndroidTools ?? Platform.isAndroid)
            ListTile(
              title: Text(l10n.androidReminderDiagnostics),
              leading: const Icon(Icons.fact_check_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showReminderDiagnostics(context),
            ),
        ],
      ),
    );
  }

  Future<void> _showReminderDiagnostics(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final status = await AndroidNativeReminderService.instance
        .reliabilityStatus();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.androidReminderDiagnostics),
        content: SizedBox(
          width: 520,
          child: status.events.isEmpty
              ? Text(l10n.androidReminderDiagnosticsEmpty)
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: status.events.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final event = status.events[index];
                    final alarm = event.alarmId == null
                        ? ''
                        : ' · #${event.alarmId}';
                    final reason = event.reason == null
                        ? ''
                        : ' · ${event.reason}';
                    return Text(
                      '${event.timestamp.toLocal()} · ${event.stage}$alarm$reason',
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  String _failureMessage(AppLocalizations l10n, ReminderTestFailure? failure) {
    return switch (failure) {
      ReminderTestFailure.notificationsDenied =>
        l10n.androidTestReminderNotificationsDenied,
      ReminderTestFailure.exactAlarmsDenied =>
        l10n.androidTestReminderExactAlarmsDenied,
      _ => l10n.androidTestBackgroundReminderFailed,
    };
  }

  Future<void> _showImmediateTestReminder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await ref
        .read(reminderSchedulerProvider)
        .showImmediateTest(
          title: l10n.androidTestImmediateReminder,
          body: l10n.androidTestImmediateReminderSubtitle,
          copy: notificationCopyFor(ref.read(localeProvider)),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(
          result.succeeded
              ? l10n.androidTestImmediateReminderShown
              : _failureMessage(l10n, result.failure),
        ),
      ),
    );
  }

  Future<void> _scheduleBackgroundTestReminder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await ref
        .read(reminderSchedulerProvider)
        .scheduleBackgroundTest(
          title: l10n.androidTestBackgroundNotificationTitle,
          body: l10n.androidTestBackgroundNotificationBody,
          copy: notificationCopyFor(ref.read(localeProvider)),
        );
    if (!context.mounted) return;
    final message = result.succeeded
        ? l10n.androidTestBackgroundReminderScheduledAt(
            TimeOfDay.fromDateTime(result.fireAt!).format(context),
          )
        : _failureMessage(l10n, result.failure);
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(SnackBar(content: Text(message)));
  }
}
