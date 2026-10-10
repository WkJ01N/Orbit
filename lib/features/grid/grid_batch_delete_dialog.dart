import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/features/grid/grid_delete_confirmation.dart';
import 'package:orbit/features/grid/grid_delete_targets.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/grid_action_text.dart';
import 'package:orbit/providers/app_providers.dart';

enum GridBatchDeleteMode { course, timeRange, manual }

Future<bool> showGridBatchDeleteDialog(
  BuildContext context,
  WidgetRef ref, {
  required DateTime displayedWeekStart,
}) async {
  final text = GridActionText.of(context);
  final mode = await showModalBottomSheet<GridBatchDeleteMode>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.of(context)!.gridBatchDeleteTitle),
            ),
            ListTile(
              key: const Key('delete-by-course'),
              leading: const Icon(Icons.school_outlined),
              title: Text(text.byCourse),
              subtitle: Text(text.courseHint),
              onTap: () => Navigator.pop(context, GridBatchDeleteMode.course),
            ),
            ListTile(
              key: const Key('delete-by-range'),
              leading: const Icon(Icons.date_range),
              title: Text(text.byRange),
              subtitle: Text(text.rangeHint),
              onTap: () =>
                  Navigator.pop(context, GridBatchDeleteMode.timeRange),
            ),
            ListTile(
              key: const Key('delete-manually'),
              leading: const Icon(Icons.checklist),
              title: Text(text.manually),
              subtitle: Text(text.manualHint),
              onTap: () => Navigator.pop(context, GridBatchDeleteMode.manual),
            ),
          ],
        ),
      ),
    ),
  );
  if (mode == GridBatchDeleteMode.manual) return true;
  if (mode == null || !context.mounted) return false;
  if (MediaQuery.sizeOf(context).width < kNarrowDialogBreakpoint) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _GridBatchDeleteForm(mode: mode, weekStart: displayedWeekStart),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: _GridBatchDeleteForm(mode: mode, weekStart: displayedWeekStart),
      ),
    );
  }
  return false;
}

class _GridBatchDeleteForm extends ConsumerStatefulWidget {
  const _GridBatchDeleteForm({required this.mode, required this.weekStart});
  final GridBatchDeleteMode mode;
  final DateTime weekStart;
  @override
  ConsumerState<_GridBatchDeleteForm> createState() =>
      _GridBatchDeleteFormState();
}

class _GridBatchDeleteFormState extends ConsumerState<_GridBatchDeleteForm> {
  List<CourseSession>? _sessions;
  String? _error;
  bool _includeArchived = false;
  final _courseKeys = <String>{};
  final _boundaryIds = <String>{};
  final _excludedIds = <String>{};
  String _query = '';
  late DateTime _start;
  late DateTime _end;
  bool get _timeRange => widget.mode == GridBatchDeleteMode.timeRange;
  @override
  void initState() {
    super.initState();
    final defaults = defaultBatchDeleteRange(widget.weekStart);
    _start = defaults.start;
    _end = defaults.end;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final sessions = await ref
          .read(scheduleRepositoryProvider)
          .getAllSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.gridLoadFailed('$e'),
        );
      }
    }
  }

  void _resetChoices() {
    _boundaryIds.clear();
    _excludedIds.clear();
  }

  Future<void> _pick(bool start) async {
    final initial = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = combineDateAndTime(date, time);
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
      _resetChoices();
    });
  }

  List<CourseSession> _targets() {
    final candidates = gridDeleteTargets(
      _sessions ?? [],
      courseKeys: _courseKeys,
      includeArchived: _includeArchived,
      start: _timeRange ? _start : null,
      end: _timeRange ? _end : null,
    );
    return [
      ...candidates.contained,
      ...candidates.crossing.where((s) => _boundaryIds.contains(s.id)),
    ].where((s) => !_excludedIds.contains(s.id)).toList();
  }

  Future<void> _preview() async {
    final targets = _targets();
    if (targets.isEmpty) return;
    final deleted = await confirmGridDeletion(
      context,
      targets: targets,
      onSelectionChanged: (ids) {
        if (!mounted) return;
        setState(
          () => _excludedIds.addAll(
            targets.map((s) => s.id).where((id) => !ids.contains(id)),
          ),
        );
      },
    );
    if (deleted && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = GridActionText.of(context);
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final groups = gridDeleteCourseGroups(
      _sessions ?? [],
      includeArchived: _includeArchived,
    );
    final shown =
        groups.entries
            .where(
              (entry) => entry.value.any(
                (s) =>
                    '${s.courseName} ${s.courseCode} ${s.section} ${s.semester}'
                        .toLowerCase()
                        .contains(_query.toLowerCase()),
              ),
            )
            .toList()
          ..sort((a, b) {
            final semester = b.value.first.semester.compareTo(
              a.value.first.semester,
            );
            return semester != 0
                ? semester
                : a.value.first.courseName.compareTo(b.value.first.courseName);
          });
    final candidates = gridDeleteTargets(
      _sessions ?? [],
      courseKeys: _courseKeys,
      includeArchived: _includeArchived,
      start: _timeRange ? _start : null,
      end: _timeRange ? _end : null,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          width: 560,
          height: (size.height * .85).clamp(0, 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _timeRange ? text.byRange : text.byCourse,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: text.searchCourses,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                Expanded(
                  child: _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(
                                onPressed: _load,
                                child: Text(l10n.actionRetry),
                              ),
                            ],
                          ),
                        )
                      : _sessions == null
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(text.includeArchived),
                              value: _includeArchived,
                              onChanged: (value) => setState(() {
                                _includeArchived = value;
                                _resetChoices();
                              }),
                            ),
                            if (_timeRange) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.gridBatchDeleteStart),
                                subtitle: Text(formatDateTimeMinute(_start)),
                                trailing: const Icon(Icons.edit_calendar),
                                onTap: () => _pick(true),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.gridBatchDeleteEnd),
                                subtitle: Text(formatDateTimeMinute(_end)),
                                trailing: const Icon(Icons.edit_calendar),
                                onTap: () => _pick(false),
                              ),
                              if (!_end.isAfter(_start))
                                Text(
                                  l10n.gridBatchDeleteInvalidRange,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                            ],
                            Wrap(
                              children: [
                                TextButton(
                                  onPressed: shown.isEmpty
                                      ? null
                                      : () => setState(() {
                                          _courseKeys.addAll(
                                            shown.map((entry) => entry.key),
                                          );
                                          _resetChoices();
                                        }),
                                  child: Text(text.selectAll),
                                ),
                                TextButton(
                                  onPressed: _courseKeys.isEmpty
                                      ? null
                                      : () => setState(() {
                                          _courseKeys.clear();
                                          _resetChoices();
                                        }),
                                  child: Text(text.clearAll),
                                ),
                              ],
                            ),
                            if (shown.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(text.noCourses),
                              ),
                            ...shown.map((entry) {
                              final session = entry.value.first;
                              final archived = entry.value
                                  .where((s) => s.archived)
                                  .length;
                              return CheckboxListTile(
                                key: ValueKey('delete-course-${entry.key}'),
                                contentPadding: EdgeInsets.zero,
                                title: Text(session.courseName),
                                subtitle: Text(
                                  '${session.courseCode} · ${session.section} · ${session.semester}\n'
                                  '${text.classCount(entry.value.length)}${archived > 0 ? ' · ${text.archivedCount(archived)}' : ''}',
                                ),
                                value: _courseKeys.contains(entry.key),
                                onChanged: (_) => setState(() {
                                  if (!_courseKeys.remove(entry.key)) {
                                    _courseKeys.add(entry.key);
                                  }
                                  _resetChoices();
                                }),
                              );
                            }),
                            if (candidates.crossing.isNotEmpty) ...[
                              const Divider(),
                              Text(
                                text.boundary,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(text.boundaryHint),
                              ...candidates.crossing.map(
                                (session) => CheckboxListTile(
                                  key: ValueKey(
                                    'delete-boundary-${session.id}',
                                  ),
                                  title: Text(session.courseName),
                                  subtitle: Text(
                                    gridDeleteSessionDescription(session, text),
                                  ),
                                  value:
                                      _boundaryIds.contains(session.id) &&
                                      !_excludedIds.contains(session.id),
                                  onChanged: (_) => setState(() {
                                    _excludedIds.remove(session.id);
                                    if (!_boundaryIds.remove(session.id)) {
                                      _boundaryIds.add(session.id);
                                    }
                                  }),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                Text(text.deleting(_targets().length)),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.actionCancel),
                    ),
                    FilledButton(
                      key: const Key('grid-delete-preview'),
                      onPressed: _targets().isEmpty ? null : _preview,
                      child: Text(text.preview),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
