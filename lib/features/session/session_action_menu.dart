import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/features/session/session_note_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';

enum SessionAction { edit, note, delete }

class SessionActionMenu {
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required CourseSession session,
    Offset? position,
    VoidCallback? onDeleted,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await _pickAction(context, l10n, position);

    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case SessionAction.edit:
        await SessionEditSheet.showEdit(context, session);
      case SessionAction.note:
        await SessionNoteSheet.show(context, session);
      case SessionAction.delete:
        final deleted = await _confirmDelete(context, ref, session);
        if (deleted) {
          onDeleted?.call();
        }
    }
  }

  static Future<SessionAction?> _pickAction(
    BuildContext context,
    AppLocalizations l10n,
    Offset? position,
  ) async {
    if (Platform.isWindows && position != null) {
      return showMenu<SessionAction>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx + 1,
          position.dy + 1,
        ),
        items: _menuItems(l10n, context),
      );
    }

    return showModalBottomSheet<SessionAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.editSession),
              onTap: () => Navigator.pop(context, SessionAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(l10n.addSessionNote),
              onTap: () => Navigator.pop(context, SessionAction.note),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.deleteSession),
              onTap: () => Navigator.pop(context, SessionAction.delete),
            ),
          ],
        ),
      ),
    );
  }

  static List<PopupMenuEntry<SessionAction>> _menuItems(
    AppLocalizations l10n,
    BuildContext context,
  ) {
    final errorColor = Theme.of(context).colorScheme.error;
    return [
      PopupMenuItem(
        value: SessionAction.edit,
        child: Row(
          children: [
            const Icon(Icons.edit_outlined, size: 20),
            const SizedBox(width: 12),
            Text(l10n.editSession),
          ],
        ),
      ),
      PopupMenuItem(
        value: SessionAction.note,
        child: Row(
          children: [
            const Icon(Icons.sticky_note_2_outlined, size: 20),
            const SizedBox(width: 12),
            Text(l10n.addSessionNote),
          ],
        ),
      ),
      PopupMenuItem(
        value: SessionAction.delete,
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 20, color: errorColor),
            const SizedBox(width: 12),
            Text(l10n.deleteSession),
          ],
        ),
      ),
    ];
  }

  static Future<bool> confirmAndDelete({
    required BuildContext context,
    required WidgetRef ref,
    required CourseSession session,
  }) {
    return _confirmDelete(context, ref, session);
  }

  static Future<bool> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CourseSession session,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final dateLabel = DateFormat('yyyy-MM-dd').format(session.date);
    final timeLabel =
        '${session.startAt.hour.toString().padLeft(2, '0')}:${session.startAt.minute.toString().padLeft(2, '0')}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSessionConfirmTitle),
        content: Text(
          l10n.deleteSessionConfirmContent(
            session.courseName,
            dateLabel,
            timeLabel,
            session.room,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(scheduleRepositoryProvider).deleteSession(session.id);
        final failures = await rescheduleAllReminders(ref);
        refreshSchedule(ref);
        if (context.mounted) {
          final message = failures > 0
              ? '${l10n.sessionDeleted} ${l10n.resyncPartialFailed(failures)}'
              : l10n.sessionDeleted;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        return true;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deleteFailed('$e'))),
          );
        }
        return false;
      }
    }
    return false;
  }
}
