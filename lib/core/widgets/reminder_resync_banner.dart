import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/services/reminder_resync_status.dart';

class ReminderResyncBanner extends StatelessWidget {
  const ReminderResyncBanner({
    super.key,
    required this.error,
    required this.onResync,
    this.onDismiss,
  });

  final String error;
  final VoidCallback onResync;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final kind = reminderResyncBannerKind(error);
    if (kind == null) {
      return const SizedBox.shrink();
    }

    final String message;
    final Color iconColor;
    switch (kind) {
      case ReminderResyncBannerKind.verify:
        message = l10n.reminderScheduleVerifyFailedBanner;
        iconColor = colorScheme.error;
      case ReminderResyncBannerKind.partial:
        final count = reminderPartialFailureCount(error) ?? 0;
        message = l10n.resyncPartialFailed(count);
        iconColor = colorScheme.tertiary;
      case ReminderResyncBannerKind.error:
        message = l10n.reminderResyncFailedBanner;
        iconColor = colorScheme.error;
    }

    return MaterialBanner(
      content: Text(message),
      leading: Icon(Icons.warning_amber, color: iconColor),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: Text(l10n.actionCancel),
          ),
        TextButton(
          onPressed: onResync,
          child: Text(l10n.resyncReminders),
        ),
      ],
    );
  }
}
