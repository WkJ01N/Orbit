import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/services/strong_reminder_resolver.dart';

Future<List<String>?> showReminderCourseSelection(
  BuildContext context, {
  required List<CourseSession> sessions,
  required ReminderCourseScope scope,
  required List<String> selected,
  Map<String, String> aliases = const {},
  Map<String, List<String>> memberships = const {},
}) {
  final normalized = normalizeReminderCourseKeys(
    scope: scope,
    keys: selected,
    sessions: sessions,
    aliases: aliases,
    memberships: memberships,
    keepHistorical: false,
  );
  if (scope == ReminderCourseScope.sessions) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) =>
          ReminderCoursePicker(sessions: sessions, selected: normalized),
    );
  }
  final entries = {
    for (final s in sessions)
      CourseSeriesKey.fromSession(s).value:
          '${s.courseName} · ${s.courseCode} · ${s.section}',
  };
  final choices = normalized.toSet();
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) {
        final l = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l.strongCourses),
          content: SizedBox(
            width: 450,
            height: MediaQuery.sizeOf(ctx).height * .5,
            child: ListView(
              children: [
                for (final e in entries.entries)
                  CheckboxListTile(
                    value: choices.contains(e.key),
                    title: Text(e.value),
                    onChanged: (v) => update(() {
                      v == true ? choices.add(e.key) : choices.remove(e.key);
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, choices.toList()),
              child: Text(l.reminderSave),
            ),
          ],
        );
      },
    ),
  );
}

class ReminderCoursePicker extends StatefulWidget {
  const ReminderCoursePicker({
    super.key,
    required this.sessions,
    required this.selected,
  });
  final List<CourseSession> sessions;
  final List<String> selected;
  @override
  State<ReminderCoursePicker> createState() => _ReminderCoursePickerState();
}

class _ReminderCoursePickerState extends State<ReminderCoursePicker> {
  late final List<CourseSession> _sessions;
  late final Set<String> _selected;
  late final ScrollController _scroll;
  final _offsets = <DateTime, double>{};
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  @override
  void initState() {
    super.initState();
    _sessions = [...widget.sessions]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    _selected = widget.selected.toSet();
    double offset = 0;
    for (final session in _sessions) {
      final date = DateUtils.dateOnly(session.date);
      if (!_offsets.containsKey(date)) {
        _offsets[date] = offset;
        offset += 40;
      }
      offset += 80;
    }
    _scroll = ScrollController(initialScrollOffset: _nearestOffset(_date));
  }

  double _nearestOffset(DateTime date) {
    if (_offsets.isEmpty) return 0;
    final nearest = _offsets.keys.reduce(
      (a, b) => a.difference(date).abs() <= b.difference(date).abs() ? a : b,
    );
    return _offsets[nearest]!;
  }

  void _locate(DateTime date) {
    setState(() => _date = DateUtils.dateOnly(date));
    if (!_scroll.hasClients) return;
    final target = _nearestOffset(
      _date,
    ).clamp(0.0, _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final rows = <Widget>[];
    DateTime? previous;
    for (final session in _sessions) {
      final date = DateUtils.dateOnly(session.date);
      if (date != previous) {
        rows.add(
          SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                material.formatFullDate(date),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        );
        previous = date;
      }
      rows.add(
        SizedBox(
          height: 80,
          child: CheckboxListTile(
            key: Key('reminder-course-${session.id}'),
            value: _selected.contains(session.id),
            title: Text(
              session.courseName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${material.formatTimeOfDay(TimeOfDay.fromDateTime(session.startAt))} · ${session.room}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (value) => setState(() {
              value == true
                  ? _selected.add(session.id)
                  : _selected.remove(session.id);
            }),
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(l.reminderScope),
      content: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: l.reminderPreviousDay,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      _locate(DateTime(_date.year, _date.month, _date.day - 1)),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(material.formatCompactDate(_date)),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null && mounted) _locate(date);
                    },
                  ),
                ),
                IconButton(
                  tooltip: l.reminderNextDay,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () =>
                      _locate(DateTime(_date.year, _date.month, _date.day + 1)),
                ),
              ],
            ),
            Expanded(
              child: ListView(controller: _scroll, children: rows),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: Text(l.reminderSave),
        ),
      ],
    );
  }
}
