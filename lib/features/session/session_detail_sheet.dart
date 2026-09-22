import 'package:orbit/providers/course_color_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/core/widgets/adaptive_bottom_sheet.dart';
import 'package:orbit/core/widgets/color_picker_dialog.dart';
import 'package:orbit/features/session/session_action_menu.dart';
import 'package:orbit/features/session/session_edit_sheet.dart';
import 'package:orbit/features/session/session_note_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/course_color_utils.dart';

class SessionDetailSheet extends ConsumerWidget {
  const SessionDetailSheet({super.key, required this.session});

  final CourseSession session;

  static Future<void> show(BuildContext context, CourseSession session) {
    return showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SessionDetailSheet(session: session),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final startLabel = formatTimeHm(session.startAt);
    final endLabel = formatTimeHm(session.endAt);
    final dateLabel = formatIsoDate(session.date);

    // Show drag handle only when rendered as a bottom sheet (narrow screen).
    final isBottomSheet =
        MediaQuery.sizeOf(context).width < kNarrowDialogBreakpoint;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBottomSheet) ...[
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
            ],
            Text(
              session.courseName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${session.courseCode} · ${session.section}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.calendar_today, text: dateLabel),
            _DetailRow(
              icon: Icons.access_time,
              text: '$startLabel – $endLabel',
            ),
            _DetailRow(icon: Icons.room, text: session.room),
            if (session.teachers.isNotEmpty)
              _DetailRow(icon: Icons.person, text: session.teachers.join('、')),
            if (session.faculty.trim().isNotEmpty)
              _DetailRow(icon: Icons.school, text: session.faculty),
            if (session.note != null && session.note!.trim().isNotEmpty)
              _DetailRow(
                icon: Icons.sticky_note_2_outlined,
                text: session.note!,
              ),
            const SizedBox(height: 20),
            _SessionActionButtons(session: session),
          ],
        ),
      ),
    );
  }
}

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
        final columns = width >= 600
            ? 4
            : width >= 250
            ? 2
            : 1;
        final buttonWidth = (width - (columns - 1) * 8) / columns;
        final fullLabels = width >= 600;
        final editLabel = fullLabels ? l10n.editSession : l10n.editSessionShort;
        final noteLabel = fullLabels
            ? l10n.addSessionNote
            : l10n.addSessionNoteShort;
        final deleteLabel = fullLabels
            ? l10n.deleteSession
            : l10n.deleteSessionShort;
        final colorLabel = fullLabels
            ? l10n.sessionColor
            : l10n.sessionColorShort;

        Widget buildButton({
          required VoidCallback onPressed,
          required IconData icon,
          required String label,
          required String tooltip,
          Color? foregroundColor,
        }) {
          return SizedBox(
            width: buttonWidth,
            child: Tooltip(
              message: tooltip,
              child: OutlinedButton.icon(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: foregroundColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                icon: Icon(icon, size: 18, color: foregroundColor),
                label: Text(label, softWrap: true, textAlign: TextAlign.center),
              ),
            ),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            buildButton(
              onPressed: () async {
                // Capture the navigator's own context before popping so the
                // follow-up sheet/dialog is shown on a context that stays
                // mounted after this bottom sheet is removed.
                final navigatorContext = Navigator.of(context).context;
                Navigator.pop(context);
                await SessionEditSheet.showEdit(navigatorContext, session);
              },
              icon: Icons.edit_outlined,
              label: editLabel,
              tooltip: l10n.editSession,
            ),
            buildButton(
              onPressed: () async {
                final key = courseColorKey(session);
                final overrides = ref.read(courseColorOverridesProvider);
                final themeStyle = appThemeStyleOf(context);
                final colorScheme = Theme.of(context).colorScheme;
                final multi = ref.read(multicolorSettingsProvider);
                final defaultColor = resolvedCourseColor(
                  palette: multi.enabled ? multi.palette : const [],
                  session: session,
                  automaticColorId: themeStyle == AppThemeStyle.colorful
                      ? ref.read(
                          resolvedAutomaticCourseColorIdsProvider,
                        )[automaticCourseColorKey(session)]
                      : null,
                  colorScheme: colorScheme,
                  themeStyle: themeStyle,
                );
                final current = overrides[key] ?? defaultColor;
                var useDefault = false;
                final picked = await showColorPickerDialog(
                  context,
                  initialColor: current,
                  defaultColor: defaultColor,
                  onUseDefault: () => useDefault = true,
                );
                if (useDefault) {
                  await ref
                      .read(courseColorOverridesProvider.notifier)
                      .clearColor(key);
                } else if (picked != null && context.mounted) {
                  await ref
                      .read(courseColorOverridesProvider.notifier)
                      .setColor(key, picked);
                }
              },
              icon: Icons.palette_outlined,
              label: colorLabel,
              tooltip: l10n.sessionColor,
            ),
            buildButton(
              onPressed: () async {
                final navigatorContext = Navigator.of(context).context;
                Navigator.pop(context);
                await SessionNoteSheet.show(navigatorContext, session);
              },
              icon: Icons.sticky_note_2_outlined,
              label: noteLabel,
              tooltip: l10n.addSessionNote,
            ),
            buildButton(
              onPressed: () async {
                final container = ProviderScope.containerOf(context);
                final navigatorContext = Navigator.of(context).context;
                Navigator.pop(context);
                await SessionActionMenu.confirmAndDelete(
                  context: navigatorContext,
                  container: container,
                  session: session,
                );
              },
              icon: Icons.delete_outline,
              label: deleteLabel,
              tooltip: l10n.deleteSession,
              foregroundColor: colorScheme.error,
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
