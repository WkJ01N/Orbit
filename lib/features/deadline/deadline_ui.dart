import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/services/course_catalog.dart';
import 'package:orbit/features/session/course_history_list.dart';
import 'package:orbit/models/deadline_strong_text.dart';
import 'package:orbit/models/deadline_recurrence.dart';
import 'package:orbit/models/deadline_batch_text.dart';
import 'package:orbit/models/statistics_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:orbit/features/archive/archive_actions.dart';
import 'package:orbit/models/orbit_feature_text.dart';

const deadlineLeadPresets = [10080, 4320, 1440, 180, 60, 30, 5];

Future<void> showDeadlineEditor(BuildContext context, {Deadline? deadline}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _DeadlineEditor(deadline: deadline),
    );

Future<void> showDeadlineDetails(BuildContext context, Deadline deadline) =>
    showDialog<void>(
      context: context,
      builder: (_) => _DeadlineDetails(deadline: deadline),
    );

Future<void> showDeadlinesForDay(
  BuildContext context,
  List<Deadline> deadlines,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      children: [
        for (final deadline in deadlines)
          DeadlineListTile(
            deadline: deadline,
            onTap: () {
              Navigator.pop(sheetContext);
              showDeadlineDetails(context, deadline);
            },
          ),
      ],
    ),
  ),
);

class DeadlineListTile extends StatelessWidget {
  const DeadlineListTile({super.key, required this.deadline, this.onTap});

  final Deadline deadline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = DeadlineText.of(context);
    final theme = Theme.of(context);
    final status = deadline.completed
        ? text.completed
        : deadline.dueAt.isBefore(DateTime.now())
        ? text.overdue
        : null;
    return PageModule(
      child: ListTile(
        key: Key('deadline-${deadline.id}'),
        leading: Icon(
          deadline.hasStrongReminder
              ? Icons.notifications_active_outlined
              : deadline.completed
              ? Icons.task_alt
              : Icons.flag_outlined,
          color: deadline.hasStrongReminder ? theme.colorScheme.primary : null,
        ),
        title: Text(deadline.title, maxLines: 2),
        subtitle: Text(
          '${deadline.subject} · ${_dateTime(context, deadline.dueAt)}'
          '${status == null ? '' : ' · $status'}',
        ),
        trailing: const Icon(Icons.chevron_right),
        textColor: deadline.completed
            ? theme.colorScheme.onSurfaceVariant
            : null,
        onTap: onTap ?? () => showDeadlineDetails(context, deadline),
      ),
    );
  }
}

String _dateTime(BuildContext context, DateTime value) => DateFormat.yMd(
  Localizations.localeOf(context).toString(),
).add_Hm().format(value);

class _DeadlineEditor extends ConsumerStatefulWidget {
  const _DeadlineEditor({this.deadline});
  final Deadline? deadline;

  @override
  ConsumerState<_DeadlineEditor> createState() => _DeadlineEditorState();
}

class _DeadlineEditorState extends ConsumerState<_DeadlineEditor> {
  late final TextEditingController _subject;
  late final TextEditingController _title;
  final TextEditingController _customMinutes = TextEditingController();
  late DateTime _dueAt;
  late Set<int> _leads;
  bool _strongEnabled = false;
  final Map<int, bool> _strongChoices = {};
  final Set<int> _disabledLeads = {};
  String _courseKey = '';
  bool _batch = false, _reused = false, _counts = true, _useCount = true;
  DeadlineFrequency _frequency = DeadlineFrequency.weekly;
  final _interval = TextEditingController(text: '1');
  final _count = TextEditingController(text: '12');
  final Set<int> _weekdays = {};
  final Map<String, int> _monthDates = {};
  late DateTime _until;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final value = widget.deadline;
    _subject = TextEditingController(text: value?.subject ?? '');
    _title = TextEditingController(text: value?.title ?? '');
    _dueAt =
        value?.dueAt ??
        DateTime.now()
            .add(const Duration(days: 1))
            .copyWith(hour: 23, minute: 59);
    _leads = value?.leadMinutes.toSet() ?? {1440, 60};
    _strongEnabled = value?.strongReminderEnabled ?? false;
    for (final m in _leads) {
      _strongChoices[m] =
          value?.effectiveStrongLeadMinutes.contains(m) ?? (m <= 180);
    }
    _disabledLeads.addAll(value?.disabledReminderLeadMinutes ?? const []);
    _courseKey = value?.courseKey ?? '';
    _counts = value?.countsTowardStatistics ?? true;
    _until = DateTime(_dueAt.year, _dueAt.month + 3, _dueAt.day);
    _weekdays.add(_dueAt.weekday);
  }

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    _subject.dispose();
    _title.dispose();
    _customMinutes.dispose();
    super.dispose();
  }

  Future<void> _pickDueAt() async {
    final firstDate = DateTime.now().subtract(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt.isBefore(firstDate) ? firstDate : _dueAt,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null || !mounted) return;
    setState(
      () => _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  void _addCustomLead() {
    final value = int.tryParse(_customMinutes.text.trim());
    if (value == null || value < 1 || value > 43200 || _leads.length >= 8) {
      setState(() => _error = DeadlineText.of(context).invalid);
      return;
    }
    setState(() {
      _leads.add(value);
      _strongChoices.putIfAbsent(value, () => value <= 180);
      _error = null;
      _customMinutes.clear();
    });
  }

  Future<void> _save() async {
    final now = DateTime.now();
    final leads = _leads.toList()..sort((a, b) => b.compareTo(a));
    if (_subject.text.trim().isEmpty ||
        _title.text.trim().isEmpty ||
        !_dueAt.isAfter(now) ||
        leads.isEmpty) {
      setState(() => _error = DeadlineText.of(context).invalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      List<DateTime> dates = [_dueAt];
      if (_batch) {
        final generated = await _generateDates();
        if (generated == null || !mounted) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        dates = generated;
      }
      if (_batch || _reused) {
        final selected = await _previewDates(dates);
        if (selected == null || !mounted) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        dates = selected;
      }
      final batchId = _batch ? const Uuid().v4() : widget.deadline?.batchId;
      await ref.read(appDatabaseProvider).saveDeadlines([
        for (final date in dates)
          Deadline(
            id: widget.deadline?.id ?? const Uuid().v4(),
            subject: _subject.text.trim(),
            title: _title.text.trim(),
            dueAt: date,
            leadMinutes: leads,
            courseKey: _courseKey.isEmpty ? null : _courseKey,
            completedAt: widget.deadline?.completedAt,
            archivedAt: widget.deadline?.archivedAt,
            archiveHidden: widget.deadline?.archiveHidden ?? false,
            autoArchivePaused: widget.deadline?.autoArchivePaused ?? false,
            countsTowardStatistics: _counts,
            batchId: batchId,
            strongReminderEnabled: _strongEnabled,
            strongLeadMinutes: leads
                .where((m) => _strongChoices[m] == true)
                .toList(),
            disabledReminderLeadMinutes: leads
                .where(_disabledLeads.contains)
                .toList(),
          ),
      ]);
      ref.read(scheduleRefreshProvider.notifier).state++;
      ref.read(reminderSettingsProvider.notifier).scheduleResync();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = DeadlineText.of(context).saveFailed;
        });
      }
    }
  }

  Future<void> _reuse() async {
    final values = await ref.read(appDatabaseProvider).getDeadlines();
    if (!mounted) return;
    final selected = await showDialog<Deadline>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(DeadlineBatchText.of(c).reuse),
        children: [
          for (final value in values)
            ListTile(
              title: Text(value.title),
              subtitle: Text('${value.subject} · ${_dateTime(c, value.dueAt)}'),
              onTap: () => Navigator.pop(c, value),
            ),
          if (values.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(DeadlineBatchText.of(c).none),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _subject.text = selected.subject;
      _title.text = selected.title;
      _courseKey = selected.courseKey ?? '';
      _leads = selected.leadMinutes.toSet();
      _strongEnabled = selected.strongReminderEnabled;
      _strongChoices.clear();
      for (final m in _leads) {
        _strongChoices[m] = selected.effectiveStrongLeadMinutes.contains(m);
      }
      _disabledLeads.clear();
      _counts = true;
      _reused = true;
    });
  }

  Widget _recurrenceFields() {
    final t = DeadlineBatchText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<DeadlineFrequency>(
          initialValue: _frequency,
          decoration: InputDecoration(labelText: t.every),
          items: [
            for (final f in DeadlineFrequency.values)
              DropdownMenuItem(
                value: f,
                child: Text([t.daily, t.weekly, t.monthly][f.index]),
              ),
          ],
          onChanged: _saving ? null : (v) => setState(() => _frequency = v!),
        ),
        TextField(
          controller: _interval,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: t.interval),
        ),
        if (_frequency == DeadlineFrequency.weekly)
          Wrap(
            spacing: 4,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(
                    MaterialLocalizations.of(context).narrowWeekdays[d % 7],
                  ),
                  selected: _weekdays.contains(d),
                  onSelected: _saving
                      ? null
                      : (v) => setState(() {
                          if (v) {
                            _weekdays.add(d);
                          } else {
                            _weekdays.remove(d);
                          }
                        }),
                ),
            ],
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.useCount),
          value: _useCount,
          onChanged: _saving ? null : (v) => setState(() => _useCount = v),
        ),
        if (_useCount)
          TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: t.taskCount),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.until),
            subtitle: Text(_dateTime(context, _until)),
            onTap: _saving
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _until.isBefore(_dueAt) ? _dueAt : _until,
                      firstDate: DateTime(
                        _dueAt.year,
                        _dueAt.month,
                        _dueAt.day,
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null && mounted) {
                      setState(() => _until = date);
                    }
                  },
          ),
      ],
    );
  }

  Future<List<DateTime>?> _generateDates() async {
    final t = DeadlineBatchText.of(context);
    try {
      _monthDates.clear();
      if (_frequency == DeadlineFrequency.weekly && _weekdays.isEmpty) {
        throw ArgumentError('Weekdays required');
      }
      DeadlineRecurrenceResult generate() => DeadlineRecurrence(
        start: _dueAt,
        frequency: _frequency,
        interval: int.tryParse(_interval.text) ?? 0,
        weekdays: _weekdays,
        count: _useCount ? int.tryParse(_count.text) ?? 0 : null,
        until: _useCount ? null : _until,
        monthDates: _monthDates,
      ).generate();
      var result = generate();
      if (result.missingMonths.isNotEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(t.monthly),
            content: Text(
              '${t.missing}\n${result.missingMonths.map(DeadlineRecurrence.monthKey).join(', ')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(DeadlineText.of(c).cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(DeadlineText.of(c).save),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return null;
        for (final month in result.missingMonths) {
          final last = DateTime(month.year, month.month + 1, 0);
          final date = await showDatePicker(
            context: context,
            helpText: '${t.monthly} · ${DeadlineRecurrence.monthKey(month)}',
            initialDate: last,
            firstDate: month,
            lastDate: last,
          );
          if (date == null || !mounted) return null;
          _monthDates[DeadlineRecurrence.monthKey(month)] = date.day;
        }
        result = generate();
      }
      if (result.dates.isEmpty ||
          result.missingMonths.isNotEmpty ||
          result.dates.any((d) => !d.isAfter(DateTime.now()))) {
        throw ArgumentError('Invalid dates');
      }
      return result.dates;
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = t.invalid;
          _saving = false;
        });
      }
      return null;
    }
  }

  Future<List<DateTime>?> _previewDates(List<DateTime> dates) async {
    final existing = await ref.read(appDatabaseProvider).getDeadlines();
    if (!mounted) return null;
    final duplicates = dates
        .where(
          (date) => existing.any(
            (d) =>
                d.subject == _subject.text.trim() &&
                d.title == _title.text.trim() &&
                d.dueAt.isAtSameMomentAs(date),
          ),
        )
        .toSet();
    final chosen = dates.toSet()..removeAll(duplicates);
    return showDialog<List<DateTime>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, change) {
          final t = DeadlineBatchText.of(c);
          return AlertDialog(
            title: Text(t.preview),
            content: SizedBox(
              width: 420,
              height: MediaQuery.sizeOf(c).height * .5,
              child: Column(
                children: [
                  Text(t.previewCount(chosen.length)),
                  if (_strongEnabled)
                    Text(
                      '${DeadlineStrongText.of(c).strong}: ${_leads.where((m) => _strongChoices[m] == true).map(DeadlineText.of(c).leadLabel).join(" · ")}',
                    ),
                  if (_reused)
                    Text(
                      '${StatisticsText.of(c).include}: ${_counts ? MaterialLocalizations.of(c).okButtonLabel : "—"}',
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final date in dates)
                          CheckboxListTile(
                            value: chosen.contains(date),
                            title: Text(_dateTime(c, date)),
                            subtitle: duplicates.contains(date)
                                ? Text(t.duplicate)
                                : null,
                            onChanged: (v) => change(() {
                              if (v == true) {
                                chosen.add(date);
                              } else {
                                chosen.remove(date);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(DeadlineText.of(c).cancel),
              ),
              FilledButton(
                onPressed: chosen.isEmpty
                    ? null
                    : () => Navigator.pop(
                        c,
                        dates.where(chosen.contains).toList(),
                      ),
                child: Text(DeadlineText.of(c).save),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = DeadlineText.of(context);
    final sessions =
        ref.watch(sessionsProvider).valueOrNull ?? const <CourseSession>[];
    final courses = <String, String>{};
    for (final session in sessions.where(
      (s) => !s.isExam && s.deletedAt == null,
    )) {
      final key =
          '${session.semester}|${session.courseCode}|${session.courseName}';
      courses[key] = session.courseName;
    }
    final selected = courses.containsKey(_courseKey) ? _courseKey : '';
    return AlertDialog(
      title: Text(
        widget.deadline == null ? text.addDeadline : text.editDeadline,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.deadline == null) ...[
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(DeadlineBatchText.of(context).single),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(DeadlineBatchText.of(context).batch),
                    ),
                  ],
                  selected: {_batch},
                  onSelectionChanged: _saving
                      ? null
                      : (v) => setState(() => _batch = v.first),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(DeadlineBatchText.of(context).reuse),
                  onPressed: _saving ? null : _reuse,
                ),
              ],
              if (_reused)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _counts,
                  title: Text(StatisticsText.of(context).include),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _counts = v ?? true),
                ),
              ListTile(
                key: const Key('deadline-course-picker'),
                contentPadding: EdgeInsets.zero,
                title: Text(text.chooseSubject),
                subtitle: Text(courses[selected] ?? text.customSubject),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _saving
                    ? null
                    : () async {
                        final representatives = <String, CourseSession>{};
                        for (final s in sessions.where(
                          (s) => !s.isExam && s.deletedAt == null,
                        )) {
                          representatives['${s.semester}|${s.courseCode}|${s.courseName}'] =
                              s;
                        }
                        var query = '';
                        final catalog = CourseCatalog(
                          sessions,
                          DateTime.now(),
                          clock: DateTime.now,
                        );
                        final picked = await showDialog<String>(
                          context: context,
                          builder: (c) => StatefulBuilder(
                            builder: (c, update) => Dialog(
                              child: SizedBox(
                                width: 440,
                                height:
                                    (MediaQuery.sizeOf(c).height -
                                            MediaQuery.viewInsetsOf(c).bottom -
                                            64)
                                        .clamp(220.0, 600.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        text.chooseSubject,
                                        style: Theme.of(c).textTheme.titleLarge,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(Icons.search),
                                          labelText: OrbitFeatureText.of(
                                            c,
                                          ).search,
                                          isDense: true,
                                        ),
                                        onChanged: (v) => update(
                                          () => query = v.trim().toLowerCase(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child:
                                            CourseHistoryList<
                                              MapEntry<String, CourseSession>
                                            >(
                                              header: ListTile(
                                                title: Text(text.customSubject),
                                                onTap: () =>
                                                    Navigator.pop(c, ''),
                                              ),
                                              items: representatives.entries
                                                  .where(
                                                    (e) =>
                                                        '${e.value.courseName} ${e.value.courseCode} ${e.value.semester}'
                                                            .toLowerCase()
                                                            .contains(query),
                                                  )
                                                  .toList(),
                                              isEnded: (e) =>
                                                  catalog.isEnded(e.value),
                                              itemBuilder: (c, e) => ListTile(
                                                title: Text(e.value.courseName),
                                                subtitle: Text(
                                                  e.value.semester,
                                                ),
                                                onTap: () =>
                                                    Navigator.pop(c, e.key),
                                              ),
                                            ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: Text(text.cancel),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _courseKey = picked;
                            if (picked.isNotEmpty) {
                              _subject.text = courses[picked]!;
                            }
                          });
                        }
                      },
              ),
              TextField(
                controller: _subject,
                readOnly: selected.isNotEmpty,
                maxLength: 100,
                decoration: InputDecoration(labelText: text.subject),
                onChanged: (_) {
                  if (_courseKey.isNotEmpty) setState(() => _courseKey = '');
                },
              ),
              TextField(
                controller: _title,
                maxLength: 100,
                decoration: InputDecoration(labelText: text.task),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(text.dueAt),
                subtitle: Text(_dateTime(context, _dueAt)),
                onTap: _saving ? null : _pickDueAt,
              ),
              if (_batch) _recurrenceFields(),
              const SizedBox(height: 8),
              Text(
                text.reminders,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  for (final minutes in deadlineLeadPresets)
                    FilterChip(
                      label: Text(text.leadLabel(minutes)),
                      selected: _leads.contains(minutes),
                      onSelected: _saving
                          ? null
                          : (selected) => setState(() {
                              if (selected && _leads.length < 8) {
                                _leads.add(minutes);
                                _strongChoices.putIfAbsent(
                                  minutes,
                                  () => minutes <= 180,
                                );
                              }
                              if (!selected) _leads.remove(minutes);
                            }),
                    ),
                  for (final minutes in _leads.where(
                    (m) => !deadlineLeadPresets.contains(m),
                  ))
                    InputChip(
                      label: Text(text.leadLabel(minutes)),
                      onDeleted: _saving
                          ? null
                          : () => setState(() => _leads.remove(minutes)),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customMinutes,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: text.customMinutes,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : _addCustomLead,
                    icon: const Icon(Icons.add),
                    tooltip: text.reminders,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _DeadlineReminderSwitch(
                      switchKey: const Key('deadline-strong-enabled'),
                      title: DeadlineStrongText.of(context).enable,
                      description: DeadlineStrongText.of(context).hint,
                      value: _strongEnabled,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _strongEnabled = v),
                    ),
                    AnimatedSize(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: _strongEnabled
                          ? Column(
                              children: [
                                for (final m
                                    in (_leads.toList()
                                      ..sort((a, b) => b.compareTo(a))))
                                  _DeadlineReminderSwitch(
                                    switchKey: ValueKey(
                                      'deadline-strong-lead-$m',
                                    ),
                                    icon: _strongChoices[m] == true
                                        ? Icons.notifications_active_outlined
                                        : Icons.notifications_none,
                                    title: text.leadLabel(m),
                                    description: _disabledLeads.contains(m)
                                        ? DeadlineStrongText.of(
                                            context,
                                          ).disabled
                                        : _strongChoices[m] == true
                                        ? DeadlineStrongText.of(context).strong
                                        : DeadlineStrongText.of(context).normal,
                                    value: _strongChoices[m] == true,
                                    onChanged: _saving
                                        ? null
                                        : (v) => setState(
                                            () => _strongChoices[m] = v,
                                          ),
                                  ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (_disabledLeads.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextButton.icon(
                          key: const Key('deadline-restore-reminders'),
                          icon: const Icon(Icons.restore),
                          label: Text(DeadlineStrongText.of(context).restore),
                          onPressed: _saving
                              ? null
                              : () => setState(() => _disabledLeads.clear()),
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(text.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _batch ? DeadlineBatchText.of(context).preview : text.save,
          ),
        ),
      ],
    );
  }
}

class _DeadlineDetails extends ConsumerWidget {
  const _DeadlineDetails({required this.deadline});
  final Deadline deadline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = DeadlineText.of(context);
    Future<void> change(Deadline value, {bool delete = false}) async {
      if (delete) {
        await ref.read(appDatabaseProvider).deleteDeadline(value);
      } else {
        await ref.read(appDatabaseProvider).saveDeadline(value);
      }
      ref.read(scheduleRefreshProvider.notifier).state++;
      ref.read(reminderSettingsProvider.notifier).scheduleResync();
      if (context.mounted) Navigator.pop(context);
    }

    return AlertDialog(
      scrollable: true,
      title: Text(deadline.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(deadline.subject),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${text.due}: ${_dateTime(context, deadline.dueAt)}'),
              if (deadline.hasStrongReminder)
                Tooltip(
                  message: DeadlineStrongText.of(context).strong,
                  child: Icon(
                    Icons.notifications_active_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          if (deadline.hasStrongReminder)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                DeadlineStrongText.of(context).openHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (deadline.completed)
            Text(text.completed)
          else if (deadline.dueAt.isBefore(DateTime.now()))
            Text(text.overdue),
        ],
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        if (deadline.completed && !deadline.archived)
          TextButton(
            onPressed: () async {
              if (await archiveDeadlineAction(context, ref, deadline) &&
                  context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(OrbitFeatureText.of(context).archive),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(text.cancel),
        ),
        TextButton(
          onPressed: () async {
            final approved = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(text.deleteConfirm),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(text.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(text.delete),
                  ),
                ],
              ),
            );
            if (approved == true) await change(deadline, delete: true);
          },
          child: Text(text.delete),
        ),
        TextButton(
          onPressed: () {
            final nextContext = Navigator.of(context).context;
            Navigator.pop(context);
            showDeadlineEditor(nextContext, deadline: deadline);
          },
          child: Text(text.editDeadline),
        ),
        FilledButton(
          onPressed: () => change(
            deadline.copyWith(
              completedAt: deadline.completed ? null : DateTime.now(),
              clearCompleted: deadline.completed,
              clearArchived: deadline.completed,
            ),
          ),
          child: Text(deadline.completed ? text.reopen : text.complete),
        ),
      ],
    );
  }
}

/// Keep descriptions full width instead of squeezing them beside the switch.
class _DeadlineReminderSwitch extends StatelessWidget {
  const _DeadlineReminderSwitch({
    required this.switchKey,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.icon,
  });
  final Key switchKey;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title)),
                Switch(key: switchKey, value: value, onChanged: onChanged),
              ],
            ),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}
