import 'package:orbit/core/widgets/statistics_deletion_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';
import 'package:orbit/features/grid/grid_delete_targets.dart';
import 'package:orbit/features/grid/grid_selection.dart';
import 'package:orbit/features/session/deletion_feedback.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_action_text.dart';
import 'package:orbit/providers/app_providers.dart';

Future<bool> confirmGridDeletion(
  BuildContext context, {
  required List<CourseSession> targets,
  required ValueChanged<Set<String>> onSelectionChanged,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GridDeleteConfirmation(
        targets: targets,
        onSelectionChanged: onSelectionChanged,
      ),
    ) ??
    false;

String gridDeleteSessionDescription(
  CourseSession session,
  GridActionText text,
) =>
    '${session.courseCode} · ${session.section} · ${session.semester}\n'
    '${formatDateTimeMinute(session.startAt)} – ${formatDateTimeMinute(session.endAt)}'
    '${session.archived ? '\n${text.archive}' : ''}';

class _GridDeleteConfirmation extends ConsumerStatefulWidget {
  const _GridDeleteConfirmation({
    required this.targets,
    required this.onSelectionChanged,
  });
  final List<CourseSession> targets;
  final ValueChanged<Set<String>> onSelectionChanged;
  @override
  ConsumerState<_GridDeleteConfirmation> createState() =>
      _GridDeleteConfirmationState();
}

class _GridDeleteConfirmationState
    extends ConsumerState<_GridDeleteConfirmation> {
  late List<CourseSession> _targets;
  bool _expanded = false;
  bool _busy = false;
  bool _deleteStatistics = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _targets = [...widget.targets]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  void _notify() =>
      widget.onSelectionChanged(_targets.map((s) => s.id).toSet());

  Future<void> _delete() async {
    if (_busy || _targets.isEmpty) return;
    final text = GridActionText.of(context);
    final l10n = AppLocalizations.of(context)!;
    final container = ProviderScope.containerOf(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    if (ref.read(gridSelectionProvider).active) {
      ref.read(gridSelectionProvider.notifier).setBusy(true);
    }
    try {
      final repository = ref.read(scheduleRepositoryProvider);
      final ids = _targets.map((s) => s.id).toSet();
      final current = (await repository.getAllSessions())
          .where((s) => ids.contains(s.id))
          .toList();
      if (!mounted) return;
      if (!sameGridDeletionSnapshot(_targets, current)) {
        setState(() {
          _targets = current..sort((a, b) => a.startAt.compareTo(b.startAt));
          _error = text.changed;
          _expanded = true;
        });
        _notify();
        return;
      }
      final deleted = await repository.deleteSessionIds(
        ids,
        deleteStatistics: _deleteStatistics,
      );
      // A successful delete stays successful even if reminder resync fails.
      refreshScheduleContainer(container);
      var failures = 0;
      try {
        failures = await rescheduleAllReminders(ref);
        if (failures == 0 &&
            container.read(lastRescheduleErrorProvider) != null) {
          failures = 1;
        }
      } catch (_) {
        failures = 1;
        container.read(reminderSettingsProvider.notifier).scheduleResync();
      }
      if (!mounted) return;
      final message =
          l10n.gridBatchDeleteDone(deleted) +
          (failures > 0 ? ' ${l10n.resyncPartialFailed(failures)}' : '');
      showDeletionUndo(
        context: context,
        container: container,
        ids: ids.toList(),
        message: message,
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = l10n.gridBatchDeleteFailed('$error'));
      }
    } finally {
      if (container.read(gridSelectionProvider).active) {
        container.read(gridSelectionProvider.notifier).setBusy(false);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = GridActionText.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(text.deleting(_targets.length)),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text.trashHint),
              StatisticsDeletionChoice(onChanged: (v) => _deleteStatistics = v),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: colors.error)),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(text.list),
                trailing: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                ),
                onTap: _busy
                    ? null
                    : () => setState(() => _expanded = !_expanded),
              ),
              if (_expanded)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * .4,
                  child: ListView.builder(
                    itemCount: _targets.length,
                    itemBuilder: (context, index) {
                      final session = _targets[index];
                      return CheckboxListTile(
                        key: ValueKey('delete-preview-${session.id}'),
                        value: true,
                        title: Text(session.courseName),
                        subtitle: Text(
                          gridDeleteSessionDescription(session, text),
                        ),
                        onChanged: _busy
                            ? null
                            : (_) {
                                setState(() => _targets.removeAt(index));
                                _notify();
                              },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('grid-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: _busy || _targets.isEmpty ? null : _delete,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(text.confirm),
          ),
        ],
      ),
    );
  }
}
