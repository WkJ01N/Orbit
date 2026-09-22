import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:uuid/uuid.dart';

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
    return ListTile(
      key: Key('deadline-${deadline.id}'),
      leading: Icon(deadline.completed ? Icons.task_alt : Icons.flag_outlined),
      title: Text(deadline.title, maxLines: 2),
      subtitle: Text(
        '${deadline.subject} · ${_dateTime(context, deadline.dueAt)}'
        '${status == null ? '' : ' · $status'}',
      ),
      trailing: const Icon(Icons.chevron_right),
      textColor: deadline.completed ? theme.colorScheme.onSurfaceVariant : null,
      onTap: onTap ?? () => showDeadlineDetails(context, deadline),
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
  String _courseKey = '';
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
    _courseKey = value?.courseKey ?? '';
  }

  @override
  void dispose() {
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
      await ref
          .read(appDatabaseProvider)
          .saveDeadline(
            Deadline(
              id: widget.deadline?.id ?? const Uuid().v4(),
              subject: _subject.text.trim(),
              title: _title.text.trim(),
              dueAt: _dueAt,
              leadMinutes: leads,
              courseKey: _courseKey.isEmpty ? null : _courseKey,
              completedAt: widget.deadline?.completedAt,
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    final text = DeadlineText.of(context);
    final sessions =
        ref.watch(sessionsProvider).valueOrNull ?? const <CourseSession>[];
    final courses = <String, String>{};
    for (final session in sessions) {
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
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: InputDecoration(labelText: text.chooseSubject),
                items: [
                  DropdownMenuItem(value: '', child: Text(text.customSubject)),
                  for (final entry in courses.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (key) => setState(() {
                        _courseKey = key ?? '';
                        if (_courseKey.isNotEmpty) {
                          _subject.text = courses[_courseKey]!;
                        }
                      }),
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
        FilledButton(onPressed: _saving ? null : _save, child: Text(text.save)),
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
      title: Text(deadline.title),
      content: Text(
        '${deadline.subject}\n${text.due}: ${_dateTime(context, deadline.dueAt)}'
        '${deadline.completed
            ? '\n${text.completed}'
            : deadline.dueAt.isBefore(DateTime.now())
            ? '\n${text.overdue}'
            : ''}',
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
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
            ),
          ),
          child: Text(deadline.completed ? text.reopen : text.complete),
        ),
      ],
    );
  }
}
