import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/services/course_catalog.dart';
import 'package:orbit/features/session/course_history_list.dart';
import 'package:orbit/features/session/existing_course_picker.dart';
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
    keepHistorical: true,
  );
  if (scope == ReminderCourseScope.sessions) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) =>
          ReminderCoursePicker(sessions: sessions, selected: normalized),
    );
  }
  final catalog = CourseCatalog(sessions, DateTime.now(), clock: DateTime.now);
  final entries = existingCourses(sessions).map((e) => e.course).toList();
  final choices = normalized.toSet();
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) {
        final l = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: PageModule(child: Text(l.strongCourses)),
          content: SizedBox(
            width: 450,
            height: MediaQuery.sizeOf(ctx).height * .5,
            child: CourseHistoryList<CourseSession>(
              items: entries,
              isEnded: catalog.isEnded,
              itemBuilder: (ctx, s) {
                final key = CourseSeriesKey.fromSession(s).value;
                return PageModule(
                  child: CheckboxListTile(
                    value: choices.contains(key),
                    title: Text(
                      '${s.courseName} · ${s.courseCode} · ${s.section}',
                    ),
                    subtitle: Text(s.semester),
                    onChanged: (v) => update(() {
                      v == true ? choices.add(key) : choices.remove(key);
                    }),
                  ),
                );
              },
            ),
          ),
          actions: [
            PageModule(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.actionCancel),
              ),
            ),
            PageModule(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, choices.toList()),
                child: Text(l.reminderSave),
              ),
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
  late CourseCatalog _catalog;
  bool _historyExpanded = false;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  @override
  void initState() {
    super.initState();
    _sessions = [...widget.sessions]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    _selected = widget.selected.toSet();
    _catalog = CourseCatalog(_sessions, DateTime.now(), clock: DateTime.now);
    _scroll = ScrollController(initialScrollOffset: _nearestOffset(_date));
  }

  double _nearestOffset(DateTime date) {
    _offsets.clear();
    var offset = 0.0;
    for (final session in _sessions.where((s) => !_catalog.isEnded(s))) {
      _offsets.putIfAbsent(DateUtils.dateOnly(session.date), () => offset);
      offset += 112;
    }
    if (_historyExpanded) {
      offset += 56;
      for (final session in _sessions.where(_catalog.isEnded)) {
        _offsets.putIfAbsent(DateUtils.dateOnly(session.date), () => offset);
        offset += 112;
      }
    }
    if (_offsets.isEmpty) return 0;
    final nearest = _offsets.keys.reduce(
      (a, b) => a.difference(date).abs() <= b.difference(date).abs() ? a : b,
    );
    return _offsets[nearest]!;
  }

  void _locate(DateTime date) {
    setState(() {
      _date = DateUtils.dateOnly(date);
      final onDate = _sessions.where((s) => DateUtils.isSameDay(s.date, _date));
      if (onDate.isNotEmpty && onDate.every(_catalog.isEnded)) {
        _historyExpanded = true;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
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
    });
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
    return AlertDialog(
      title: PageModule(child: Text(l.reminderScope)),
      content: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            Row(
              children: [
                PageModule(
                  child: IconButton(
                    tooltip: l.reminderPreviousDay,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _locate(
                      DateTime(_date.year, _date.month, _date.day - 1),
                    ),
                  ),
                ),
                Expanded(
                  child: PageModule(
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
                ),
                PageModule(
                  child: IconButton(
                    tooltip: l.reminderNextDay,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _locate(
                      DateTime(_date.year, _date.month, _date.day + 1),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: CourseHistoryList<CourseSession>(
                controller: _scroll,
                expanded: _historyExpanded,
                onExpanded: (v) => _historyExpanded = v,
                items: _sessions,
                isEnded: _catalog.isEnded,
                itemBuilder: (context, session) => SizedBox(
                  height: 112,
                  child: PageModule(
                    child: CheckboxListTile(
                      key: Key('reminder-course-${session.id}'),
                      value: _selected.contains(session.id),
                      title: Text(
                        session.courseName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${material.formatFullDate(session.date)}\n${material.formatTimeOfDay(TimeOfDay.fromDateTime(session.startAt))} · ${session.room}',
                        maxLines: 2,
                      ),
                      onChanged: (value) => setState(() {
                        value == true
                            ? _selected.add(session.id)
                            : _selected.remove(session.id);
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        PageModule(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
        ),
        PageModule(
          child: TextButton(
            onPressed: () => Navigator.pop(context, _selected.toList()),
            child: Text(l.reminderSave),
          ),
        ),
      ],
    );
  }
}
