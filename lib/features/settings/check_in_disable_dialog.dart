import 'package:flutter/material.dart';
import 'package:orbit/core/widgets/step_confirm_dialog.dart';
import 'package:orbit/l10n/app_localizations.dart';

Future<bool> confirmDisableCheckInReminder(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  return confirmWithSteps(
    context,
    steps: [
      (l10n.checkInDisableConfirm1Title, l10n.checkInDisableConfirm1Content),
      (l10n.checkInDisableConfirm2Title, l10n.checkInDisableConfirm2Content),
      (l10n.checkInDisableConfirm3Title, l10n.checkInDisableConfirm3Content),
    ],
    finalDeleteLabel: l10n.actionConfirmDisable,
  );
}
