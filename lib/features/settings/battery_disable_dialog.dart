import 'package:flutter/material.dart';
import 'package:orbit/core/widgets/step_confirm_dialog.dart';
import 'package:orbit/l10n/app_localizations.dart';

Future<bool> confirmDisableBatteryOptimization(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  return confirmWithSteps(
    context,
    steps: [
      (
        l10n.androidBatteryOptimizationDisableConfirmTitle,
        l10n.androidBatteryOptimizationDisableConfirmContent,
      ),
    ],
    finalDeleteLabel: l10n.actionConfirmDisable,
  );
}
