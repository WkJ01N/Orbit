import 'package:orbit/core/widgets/settings_app_bar.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/core/widgets/settings_group.dart';
import 'package:orbit/features/settings/reminder_setting_actions.dart';
import 'package:orbit/core/widgets/reminder_template_field.dart';
import 'package:orbit/features/settings/reminder_course_picker.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/services/custom_reminder_planner.dart';
import 'package:orbit/features/settings/strong_reminder_page.dart';

class CustomRemindersPage extends ConsumerWidget {
  const CustomRemindersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final rules = ref.watch(reminderSettingsProvider).value?.customRules ?? [];
    Future<void> save(List<CustomReminderRule> value) async {
      await ref.read(reminderSettingsProvider.notifier).setCustomRules(value);
    }

    Future<void> edit(CustomReminderRule? rule) async {
      final updated = await Navigator.of(context).push<CustomReminderRule>(
        MaterialPageRoute(builder: (_) => CustomReminderEditor(rule: rule)),
      );
      if (updated == null) return;
      final latest = ref.read(reminderSettingsProvider).value!.customRules;
      await save(
        latest.any((r) => r.id == updated.id)
            ? [for (final r in latest) r.id == updated.id ? updated : r]
            : [...latest, updated],
      );
    }

    return Scaffold(
      appBar: settingsAppBar(
        context,
        title: l.customReminders,
        actions: [
          IconButton(
            key: const Key('custom-reminder-add'),
            tooltip: l.reminderAdd,
            onPressed: () => edit(null),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: rules.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.reminderEmpty),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('custom-reminder-empty-add'),
                    onPressed: () => edit(null),
                    icon: const Icon(Icons.add),
                    label: Text(l.reminderAdd),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                final basis = [
                  l.reminderStart,
                  l.reminderEnd,
                  l.reminderDate,
                ][rule.basis.index];
                final scope = [
                  l.reminderAll,
                  l.reminderSeries,
                  l.reminderSessions,
                ][rule.scope.index];
                final strength = [
                  l.reminderInherit,
                  l.reminderNormal,
                  l.reminderStrong,
                ][rule.strength.index];
                return ListTile(
                  title: Text(rule.name),
                  subtitle: Text(
                    '$basis · '
                    '${rule.basis == ReminderTimeBasis.date ? rule.dayOffset : rule.offsetSeconds} '
                    '${rule.basis == ReminderTimeBasis.date ? '${l.reminderDays} · ${(rule.secondOfDay ~/ 3600).toString().padLeft(2, '0')}:${(rule.secondOfDay % 3600 ~/ 60).toString().padLeft(2, '0')}:${(rule.secondOfDay % 60).toString().padLeft(2, '0')}' : l.reminderSeconds}\n'
                    '$scope · ${rule.sendCount} × ${rule.intervalSeconds}s · $strength',
                  ),
                  onTap: () => edit(rule),
                  leading: Semantics(
                    label: rule.name,
                    child: Switch(
                      value: rule.enabled,
                      onChanged: (enabled) async {
                        await save([
                          for (final r
                              in ref
                                  .read(reminderSettingsProvider)
                                  .value!
                                  .customRules)
                            r.id == rule.id
                                ? r.copyWith(
                                    enabled: enabled,
                                    activeFrom: enabled
                                        ? DateTime.now()
                                        : r.activeFrom,
                                  )
                                : r,
                        ]);
                      },
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      final latest = ref
                          .read(reminderSettingsProvider)
                          .value!
                          .customRules;
                      if (action == 'copy') {
                        await save([
                          ...latest,
                          rule.copyWith(
                            enabled: true,
                            id: newReminderId(),
                            name: '${rule.name} (${l.reminderCopy})',
                            activeFrom: DateTime.now(),
                          ),
                        ]);
                      }
                      if (action == 'delete') {
                        await save(
                          latest.where((r) => r.id != rule.id).toList(),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'copy', child: Text(l.reminderCopy)),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l.reminderDelete),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class CustomReminderEditor extends ConsumerStatefulWidget {
  const CustomReminderEditor({super.key, this.rule});
  final CustomReminderRule? rule;
  @override
  ConsumerState<CustomReminderEditor> createState() =>
      _CustomReminderEditorState();
}

class _CustomReminderEditorState extends ConsumerState<CustomReminderEditor> {
  final _form = GlobalKey<FormState>();
  late CustomReminderRule _rule;
  late String _initial;
  final _fields = <String, TextEditingController>{};
  bool _after = false, _allowPop = false;
  int _dateDirection = 0;
  Map<String, String> _aliases = {};
  Map<String, List<String>> _memberships = {};
  Future<void> _loadIdentities() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final aliases = await db.reminderSessionAliases();
      final memberships = await db.reminderSeriesMemberships();
      if (mounted) {
        setState(() {
          _aliases = aliases;
          _memberships = memberships;
        });
      }
    } catch (error) {
      debugPrint("Reminder identity preview unavailable: $error");
    }
  }

  @override
  void initState() {
    super.initState();
    _rule =
        widget.rule ??
        CustomReminderRule(
          id: newReminderId(),
          name: '',
          activeFrom: DateTime.now(),
        );
    _after = _rule.offsetSeconds >= 0;
    _dateDirection = _rule.dayOffset.sign;
    final seconds = _rule.offsetSeconds.abs();
    final values = {
      'name': _rule.name,
      'title': _rule.titleTemplate,
      'body': _rule.bodyTemplate,
      'days': '${seconds ~/ 86400}',
      'hours': '${seconds % 86400 ~/ 3600}',
      'minutes': '${seconds % 3600 ~/ 60}',
      'seconds': '${seconds % 60}',
      'dateDays': '${_rule.dayOffset.abs()}',
      'clockHours': '${_rule.secondOfDay ~/ 3600}',
      'clockMinutes': '${_rule.secondOfDay % 3600 ~/ 60}',
      'clockSeconds': '${_rule.secondOfDay % 60}',
      'count': '${_rule.sendCount}',
      'interval': '${_rule.intervalSeconds}',
    };
    values.forEach(
      (key, value) => _fields[key] = TextEditingController(text: value),
    );
    _initial = _snapshot();
    if (_rule.scope != ReminderCourseScope.all) _loadIdentities();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _snapshot() => jsonEncode({
    'rule': _rule.toJson(),
    'after': _after,
    'dateDirection': _dateDirection,
    'fields': _fields.map((k, v) => MapEntry(k, v.text)),
  });
  int n(String key) => int.tryParse(_fields[key]!.text) ?? 0;
  bool _validNumbers() {
    final ranges = {
      if (_rule.basis == ReminderTimeBasis.date) ...{
        if (_dateDirection != 0) 'dateDays': (0, 9999),
        'clockHours': (0, 23),
        'clockMinutes': (0, 59),
        'clockSeconds': (0, 59),
      } else ...{
        'days': (0, 9999),
        'hours': (0, 9999),
        'minutes': (0, 59),
        'seconds': (0, 59),
      },
      'count': (1, 100),
      'interval': (1, 2147483647),
    };
    return ranges.entries.every((entry) {
      final value = int.tryParse(_fields[entry.key]!.text);
      return value != null &&
          value >= entry.value.$1 &&
          value <= entry.value.$2;
    });
  }

  CustomReminderRule _draft() => _rule.copyWith(
    name: _fields['name']!.text.trim(),
    titleTemplate: _fields['title']!.text,
    bodyTemplate: _fields['body']!.text,
    offsetSeconds:
        (_after ? 1 : -1) *
        (n('days') * 86400 +
            n('hours') * 3600 +
            n('minutes') * 60 +
            n('seconds')),
    dayOffset: _dateDirection * n('dateDays'),
    secondOfDay:
        n('clockHours') * 3600 + n('clockMinutes') * 60 + n('clockSeconds'),
    sendCount: n('count'),
    intervalSeconds: n('interval'),
  );
  Future<void> _back() async {
    final l = AppLocalizations.of(context)!;
    final discard =
        _initial == _snapshot() ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.reminderDiscard),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l.reminderKeepEditing),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(ctx).colorScheme.error,
                    ),
                    child: Text(l.reminderDiscardAction),
                  ),
                ],
              ),
            ) ==
            true;
    if (discard && mounted) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Widget _number(String key, String label, {int min = 0, int max = 9999}) =>
      SizedBox(
        width: 150,
        child: TextFormField(
          key: Key('reminder-field-$key'),
          controller: _fields[key],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => setState(() {}),
          validator: (value) {
            final v = int.tryParse(value ?? '');
            return v == null || v < min || v > max ? '$min–$max' : null;
          },
        ),
      );
  Widget _choice<T>(
    String label,
    T value,
    List<T> values,
    List<String> labels,
    ValueChanged<T> change,
  ) => DropdownButtonFormField<T>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items: [
      for (var i = 0; i < values.length; i++)
        DropdownMenuItem(value: values[i], child: Text(labels[i])),
    ],
    onChanged: (v) {
      if (v != null) setState(() => change(v));
    },
  );
  Future<void> _courses(List<CourseSession> sessions) async {
    final result = await showReminderCourseSelection(
      context,
      sessions: sessions,
      scope: _rule.scope,
      selected: _rule.courseKeys,
      aliases: _aliases,
      memberships: _memberships,
    );
    if (result != null && mounted) {
      setState(() => _rule = _rule.copyWith(courseKeys: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final sessions = ref.watch(sessionsProvider).value ?? <CourseSession>[];
    final draft = _draft();
    final matches = sessions
        .where(
          (s) => matchesCustomReminder(
            draft,
            s,
            sessionAliases: _aliases,
            seriesMemberships: _memberships,
          ),
        )
        .toList();
    final preview = !_validNumbers()
        ? <ReminderAlarmSpec>[]
        : planCustomReminders(
            sessions: matches,
            sessionAliases: _aliases,
            seriesMemberships: _memberships,
            rules: [draft],
            strong:
                ref.watch(reminderSettingsProvider).value?.strong ??
                const StrongReminderSettings(),
            now: DateTime.now(),
            weekdayNames: l.reminderWeekdayNames.split('|'),
          );
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (popped, result) {
        if (!popped) _back();
      },
      child: Scaffold(
        appBar: settingsAppBar(
          context,
          title: widget.rule == null ? l.reminderAdd : l.reminderEdit,
          actions: [
            TextButton(
              onPressed: () {
                final draft = _draft();
                if (!_form.currentState!.validate() ||
                    !_validNumbers() ||
                    invalidReminderVariables(
                      draft.titleTemplate + draft.bodyTemplate,
                    ).isNotEmpty) {
                  ScaffoldMessenger.of(context).showAppSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 6),
                      content: Text(l.reminderInvalid),
                    ),
                  );
                  return;
                }
                setState(() => _allowPop = true);
                Navigator.pop(
                  context,
                  widget.rule == null
                      ? draft.copyWith(activeFrom: DateTime.now())
                      : draft,
                );
              },
              child: Text(l.reminderSave),
            ),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _fields['name'],
                key: const Key('reminder-field-name'),
                decoration: InputDecoration(labelText: l.reminderName),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.reminderInvalid : null,
              ),
              _choice(
                l.reminderBasis,
                _rule.basis,
                ReminderTimeBasis.values,
                [l.reminderStart, l.reminderEnd, l.reminderDate],
                (v) => _rule = _rule.copyWith(basis: v),
              ),
              if (_rule.basis == ReminderTimeBasis.date) ...[
                _choice(
                  l.reminderDateOffset,
                  _dateDirection,
                  [-1, 0, 1],
                  [l.reminderBefore, l.reminderSameDay, l.reminderAfter],
                  (v) => _dateDirection = v,
                ),
                if (_dateDirection != 0) _number('dateDays', l.reminderDays),
                const SizedBox(height: 12),
                Text(l.reminderFixedTime),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _number('clockHours', l.reminderHours, max: 23),
                    _number('clockMinutes', l.reminderMinutes, max: 59),
                    _number('clockSeconds', l.reminderSeconds, max: 59),
                  ],
                ),
              ] else ...[
                _choice(
                  '${l.reminderBefore} / ${l.reminderAfter}',
                  _after,
                  [false, true],
                  [l.reminderBefore, l.reminderAfter],
                  (v) => _after = v,
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _number('days', l.reminderDays),
                    _number('hours', l.reminderHours),
                    _number('minutes', l.reminderMinutes, max: 59),
                    _number('seconds', l.reminderSeconds, max: 59),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _choice(
                l.reminderScope,
                _rule.scope,
                ReminderCourseScope.values,
                [l.reminderAll, l.reminderSeries, l.reminderSessions],
                (v) => _rule = _rule.copyWith(scope: v, courseKeys: []),
              ),
              if (_rule.scope != ReminderCourseScope.all)
                ListTile(
                  title: Text(l.reminderScope),
                  subtitle: Text('${_rule.courseKeys.length}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _courses(sessions),
                ),
              const SizedBox(height: 16),
              Text(l.reminderWeekdays),
              Wrap(
                spacing: 8,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(l.reminderFilterWeekdays.split('|')[d - 1]),
                      selected: _rule.weekdays.contains(d),
                      onSelected: (v) => setState(
                        () => _rule = _rule.copyWith(
                          weekdays: v
                              ? [..._rule.weekdays, d]
                              : _rule.weekdays.where((x) => x != d).toList(),
                        ),
                      ),
                    ),
                ],
              ),
              Text(l.reminderTypes),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in sessions.map((s) => s.classType).toSet())
                    FilterChip(
                      label: Text(t),
                      selected: _rule.classTypes.contains(t),
                      onSelected: (v) => setState(
                        () => _rule = _rule.copyWith(
                          classTypes: v
                              ? [..._rule.classTypes, t]
                              : _rule.classTypes.where((x) => x != t).toList(),
                        ),
                      ),
                    ),
                ],
              ),
              ListTile(
                title: Text(l.reminderDateRange),
                subtitle: Text(
                  '${_rule.dateFrom ?? ''} – ${_rule.dateTo ?? ''}',
                ),
                trailing: const Icon(Icons.date_range),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange:
                        _rule.dateFrom != null && _rule.dateTo != null
                        ? DateTimeRange(
                            start: _rule.dateFrom!,
                            end: _rule.dateTo!,
                          )
                        : null,
                  );
                  if (range != null && mounted) {
                    setState(
                      () => _rule = _rule.copyWith(
                        dateFrom: range.start,
                        dateTo: range.end,
                      ),
                    );
                  }
                },
              ),
              if (_rule.dateFrom != null)
                TextButton(
                  onPressed: () =>
                      setState(() => _rule = _rule.copyWith(clearDates: true)),
                  child: Text(l.reminderClearFilter),
                ),
              for (final entry in {
                'title': l.reminderTitle,
                'body': l.reminderBody,
              }.entries) ...[
                TextFormField(
                  controller: _fields[entry.key],
                  minLines: 1,
                  maxLines: entry.key == 'body' ? 5 : 1,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    labelText: entry.value,
                    errorMaxLines: 3,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: const OutlineInputBorder(),
                    errorText:
                        invalidReminderVariables(
                          _fields[entry.key]!.text,
                        ).isEmpty
                        ? null
                        : '${l.reminderInvalid}: ${invalidReminderVariables(_fields[entry.key]!.text).join(', ')}',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                ReminderVariableButtons(
                  controller: _fields[entry.key]!,
                  variables: reminderVariables,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 12,
                children: [
                  _number('count', l.reminderCount, min: 1, max: 100),
                  _number(
                    'interval',
                    l.reminderInterval,
                    min: 1,
                    max: 2147483647,
                  ),
                ],
              ),
              SwitchListTile(
                title: Text(l.reminderUntilAck),
                value: _rule.repeatMode == ReminderRepeatMode.untilAcknowledged,
                onChanged: (v) => setState(
                  () => _rule = _rule.copyWith(
                    repeatMode: v
                        ? ReminderRepeatMode.untilAcknowledged
                        : ReminderRepeatMode.fixed,
                  ),
                ),
              ),
              _choice(
                l.reminderStrong,
                _rule.strength,
                ReminderStrength.values,
                [l.reminderInherit, l.reminderNormal, l.reminderStrong],
                (v) => _rule = _rule.copyWith(strength: v),
              ),
              if (_rule.strength != ReminderStrength.normal) ...[
                SwitchListTile(
                  title: Text(l.reminderOverride),
                  value: _rule.strongOverride != null,
                  onChanged: (v) => setState(
                    () => _rule = _rule.copyWith(
                      strongOverride: v
                          ? ref.read(reminderSettingsProvider).value!.strong
                          : null,
                      clearStrongOverride: !v,
                    ),
                  ),
                ),
                if (_rule.strongOverride != null)
                  ListTile(
                    title: Text(l.reminderStrongConfig),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final value =
                          await Navigator.push<StrongReminderSettings>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StrongReminderPage(
                                initial: _rule.strongOverride!,
                                showTargets: false,
                              ),
                            ),
                          );
                      if (value != null && mounted) {
                        setState(
                          () => _rule = _rule.copyWith(strongOverride: value),
                        );
                      }
                    },
                  ),
              ],
              const SizedBox(height: 20),
              Text(
                '${l.reminderPreview} (${matches.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final spec in preview.take(5))
                ListTile(
                  title: Text(spec.title),
                  subtitle: Text(
                    '${reminderTimestamp(spec.fireAt)}\n${spec.body}',
                  ),
                ),
              Text(l.reminderTimingNotice),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomRemindersSettingsTiles extends ConsumerWidget {
  const CustomRemindersSettingsTiles({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final strong = ref.watch(reminderSettingsProvider).value!.strong;
    return Column(
      children: [
        SettingsGroup(
          title: l.customReminders,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_notifications_outlined),
              title: Text(l.customReminders),
              subtitle: Text(l.customRemindersSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomRemindersPage()),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l.reminderStrong,
          children: [
            SwitchListTile(
              title: Text(l.reminderStrong),
              subtitle: Text(l.reminderStrongDescription),
              value: strong.enabled,
              onChanged: (v) => applyReminderUpdate(
                context,
                ref,
                () => ref
                    .read(reminderSettingsProvider.notifier)
                    .setStrong(strong.copyWith(enabled: v)),
              ),
            ),
            ListTile(
              title: Text(l.reminderStrongConfig),
              subtitle: Text(l.strongTargets),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final value = await Navigator.push<StrongReminderSettings>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StrongReminderPage(initial: strong),
                  ),
                );
                if (value != null) {
                  if (context.mounted) {
                    await applyReminderUpdate(
                      context,
                      ref,
                      () => ref
                          .read(reminderSettingsProvider.notifier)
                          .setStrong(value),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
