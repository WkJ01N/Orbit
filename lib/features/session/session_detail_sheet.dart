import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';
import 'package:orbit/features/session/session_action_menu.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/features/session/session_note_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';

class SessionDetailSheet extends ConsumerWidget {
  const SessionDetailSheet({super.key, required this.session});

  final CourseSession session;

  static Future<void> show(BuildContext context, CourseSession session) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SessionDetailSheet(session: session),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final startLabel = formatTimeHm(session.startAt);
    final endLabel = formatTimeHm(session.endAt);
    final dateLabel = formatIsoDate(session.date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(session.courseName, style: Theme.of(context).textTheme.titleLarge),
          Text(
            '${session.courseCode} · ${session.section}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          _DetailRow(icon: Icons.calendar_today, text: dateLabel),
          _DetailRow(icon: Icons.access_time, text: '$startLabel – $endLabel'),
          _DetailRow(icon: Icons.room, text: session.room),
          if (session.teachers.isNotEmpty)
            _DetailRow(icon: Icons.person, text: session.teachers.join('、')),
          _DetailRow(icon: Icons.school, text: session.faculty),
          if (session.note != null && session.note!.trim().isNotEmpty)
            _DetailRow(icon: Icons.sticky_note_2_outlined, text: session.note!),
          const SizedBox(height: 20),
          _SessionActionButtons(session: session),
        ],
      ),
    );
  }
}

enum _ActionButtonMode { full, short, iconOnly }

class _SessionActionButtons extends ConsumerWidget {
  const _SessionActionButtons({required this.session});

  final CourseSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mode = width >= 420
            ? _ActionButtonMode.full
            : width >= 300
                ? _ActionButtonMode.short
                : _ActionButtonMode.iconOnly;

        final editLabel = mode == _ActionButtonMode.full
            ? l10n.editSession
            : l10n.editSessionShort;
        final noteLabel = mode == _ActionButtonMode.full
            ? l10n.addSessionNote
            : l10n.addSessionNoteShort;
        final deleteLabel = mode == _ActionButtonMode.full
            ? l10n.deleteSession
            : l10n.deleteSessionShort;

        Widget buildButton({
          required VoidCallback onPressed,
          required IconData icon,
          required String label,
          required String tooltip,
          Color? foregroundColor,
        }) {
          if (mode == _ActionButtonMode.iconOnly) {
            return OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: foregroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              child: Tooltip(
                message: tooltip,
                child: Icon(icon, size: 18, color: foregroundColor),
              ),
            );
          }

          return OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: foregroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            icon: Icon(icon, size: 18, color: foregroundColor),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mode == _ActionButtonMode.short
                  ? const TextStyle(fontSize: 13)
                  : null,
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: buildButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await SessionEditSheet.showEdit(context, session);
                },
                icon: Icons.edit_outlined,
                label: editLabel,
                tooltip: l10n.editSession,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: buildButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await SessionNoteSheet.show(context, session);
                },
                icon: Icons.sticky_note_2_outlined,
                label: noteLabel,
                tooltip: l10n.addSessionNote,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: buildButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await SessionActionMenu.confirmAndDelete(
                    context: context,
                    ref: ref,
                    session: session,
                  );
                },
                icon: Icons.delete_outline,
                label: deleteLabel,
                tooltip: l10n.deleteSession,
                foregroundColor: colorScheme.error,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
