import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/orbit_feature_text.dart';
import 'package:orbit/providers/app_providers.dart';

Future<bool?> confirmArchive(BuildContext context, String label, int count) {
  final text = OrbitFeatureText.of(context);
  final l = AppLocalizations.of(context)!;
  var hide = true;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text.count(count)),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(text.hideArchive),
              value: hide,
              onChanged: (value) => setState(() => hide = value ?? true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, hide),
            child: Text(text.archive),
          ),
        ],
      ),
    ),
  );
}

Future<void> archiveAllEndedCoursesAction(
  BuildContext context,
  WidgetRef ref,
) async {
  final text = OrbitFeatureText.of(context);
  final now = DateTime.now();
  final container = ProviderScope.containerOf(context);
  final repository = ref.read(scheduleRepositoryProvider);
  try {
    final sessions = await repository.getUnarchivedEndedSessions(at: now);
    if (!context.mounted) return;
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(text.noEndedToArchive)));
      return;
    }
    final hide = await confirmArchive(
      context,
      text.archiveAllEnded,
      sessions.length,
    );
    if (hide == null || !context.mounted) return;
    final changed = await repository.archiveEndedSessions(
      sessionIds: sessions.map((session) => session.id).toList(),
      hide: hide,
      at: now,
    );
    if (changed > 0) {
      refreshScheduleContainer(container);
      container.read(reminderSettingsProvider.notifier).scheduleResync();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(SnackBar(content: Text(text.archivedClasses(changed))));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(text.failed)));
    }
  }
}

Future<bool> archiveCourseAction(
  BuildContext context,
  ProviderContainer container,
  CourseSession session,
) async {
  final text = OrbitFeatureText.of(context);
  final now = DateTime.now();
  final all = await container.read(scheduleRepositoryProvider).getAllSessions();
  final matching = all
      .where(
        (s) =>
            !s.archived &&
            !s.endAt.isAfter(now) &&
            s.semester == session.semester &&
            CourseSeriesKey.fromSession(s) ==
                CourseSeriesKey.fromSession(session),
      )
      .toList();
  if (!context.mounted || matching.isEmpty) return false;
  final whole = await showDialog<bool>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(text.archive),
      children: [
        if (!session.archived && !session.endAt.isAfter(now))
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(text.singleArchive),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(text.seriesArchive),
        ),
      ],
    ),
  );
  if (whole == null || !context.mounted) return false;
  final hide = await confirmArchive(
    context,
    whole ? text.seriesArchive : text.singleArchive,
    whole ? matching.length : 1,
  );
  if (hide == null || !context.mounted) return false;
  try {
    await container
        .read(scheduleRepositoryProvider)
        .archiveCourse(session, wholeCourse: whole, hide: hide);
    refreshScheduleContainer(container);
    container.read(reminderSettingsProvider.notifier).scheduleResync();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(text.failed)));
    }
    return false;
  }
}

Future<bool> archiveDeadlineAction(
  BuildContext context,
  WidgetRef ref,
  Deadline value,
) async {
  if (!value.completed || value.archived) return false;
  final hide = await confirmArchive(
    context,
    OrbitFeatureText.of(context).archive,
    1,
  );
  if (hide == null || !context.mounted) return false;
  try {
    await ref
        .read(appDatabaseProvider)
        .updateArchive(
          deadlineIds: [value.id],
          action: ArchiveMutation.archive,
          hide: hide,
        );
    refreshSchedule(ref);
    ref.read(reminderSettingsProvider.notifier).scheduleResync();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(OrbitFeatureText.of(context).failed)),
      );
    }
    return false;
  }
}
