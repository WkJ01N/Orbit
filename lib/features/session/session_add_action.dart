import 'package:flutter/material.dart';
import 'package:orbit/features/session/batch_session_edit_sheet.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';

enum SessionAddKind { single, batch }

Future<void> showSessionAddAction(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final kind = await showModalBottomSheet<SessionAddKind>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              l10n.addSessionChoiceTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.addSingleSession),
            onTap: () => Navigator.pop(sheetContext, SessionAddKind.single),
          ),
          ListTile(
            leading: const Icon(Icons.event_repeat_outlined),
            title: Text(l10n.addBatchSessions),
            onTap: () => Navigator.pop(sheetContext, SessionAddKind.batch),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted || kind == null) return;
  if (kind == SessionAddKind.single) {
    await SessionEditSheet.showCreate(context);
  } else {
    await BatchSessionEditSheet.show(context);
  }
}
