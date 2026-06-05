import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';

Future<bool> confirmWithSteps(
  BuildContext context, {
  required List<(String title, String content)> steps,
  String? finalDeleteLabel,
}) async {
  final l10n = AppLocalizations.of(context)!;

  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    final isLast = i == steps.length - 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(step.$1),
        content: Text(step.$2),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: isLast
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(
              isLast
                  ? (finalDeleteLabel ?? l10n.actionDelete)
                  : l10n.actionContinue,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return false;
    }
  }
  return true;
}
