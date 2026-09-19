import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/import/import_labels.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/services/schedule_import_service.dart';

String newImportId() => DateTime.now().microsecondsSinceEpoch.toString();

class ImportPlansPage extends ConsumerWidget {
  const ImportPlansPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = importL10n(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.importPlans)),
      body: ref
          .watch(importConfigurationProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(importErrorMessage(l, e))),
            data: (config) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l.importTemporaryContext),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _editSemester(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(l.importSemesterName),
                ),
                for (final p in config.semesters)
                  ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.firstWeekMonday.toIso8601String().split('T').first} · ${p.totalWeeks}',
                    ),
                    onTap: () => _editSemester(context, ref, p),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l.actionDelete,
                      onPressed: () => _remove(context, ref, semester: p),
                    ),
                  ),
                const Divider(),
                FilledButton.icon(
                  onPressed: () => _editTimes(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(l.importPeriodPlanName),
                ),
                for (final p in config.periodTimes)
                  ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      p.periods
                          .map(
                            (t) =>
                                '${t.number}: ${minuteLabel(t.startMinute)}–${minuteLabel(t.endMinute)}',
                          )
                          .join('\n'),
                    ),
                    onTap: () => _editTimes(context, ref, p),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l.actionDelete,
                      onPressed: () => _remove(context, ref, times: p),
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _editSemester(
    BuildContext context,
    WidgetRef ref, [
    SemesterPlan? p,
  ]) async {
    final result = await showDialog<ImportContext>(
      context: context,
      builder: (_) => ImportContextDialog(
        initial: ImportContext(semester: p),
        semesterOnly: true,
      ),
    );
    if (result?.semester == null || !context.mounted) return;
    await saveImportChange(
      context,
      ref,
      (c) => c.copy(
        semesters: [
          ...c.semesters.where((v) => v.id != result!.semester!.id),
          result!.semester!,
        ],
      ),
    );
  }

  Future<void> _editTimes(
    BuildContext context,
    WidgetRef ref, [
    PeriodTimePlan? p,
  ]) async {
    final result = await showDialog<ImportContext>(
      context: context,
      builder: (_) => ImportContextDialog(
        initial: ImportContext(periodTimes: p),
        timesOnly: true,
      ),
    );
    if (result?.periodTimes == null || !context.mounted) return;
    await saveImportChange(
      context,
      ref,
      (c) => c.copy(
        periodTimes: [
          ...c.periodTimes.where((v) => v.id != result!.periodTimes!.id),
          result!.periodTimes!,
        ],
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref, {
    SemesterPlan? semester,
    PeriodTimePlan? times,
  }) async {
    if (!await confirmImportDelete(context) || !context.mounted) return;
    await saveImportChange(
      context,
      ref,
      (c) => c.copy(
        semesters: semester == null
            ? null
            : c.semesters.where((p) => p.id != semester.id).toList(),
        periodTimes: times == null
            ? null
            : c.periodTimes.where((p) => p.id != times.id).toList(),
      ),
    );
  }
}

Future<void> saveImportChange(
  BuildContext context,
  WidgetRef ref,
  ImportConfiguration Function(ImportConfiguration) change,
) async {
  try {
    await ref.read(importConfigurationProvider.notifier).saveChange(change);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(importErrorMessage(importL10n(context), e))),
      );
    }
  }
}

Future<bool> confirmImportDelete(BuildContext context) async {
  final l = importL10n(context);
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l.importDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.importCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.actionDelete),
            ),
          ],
        ),
      ) ??
      false;
}

Future<ImportContext?> chooseImportContext(
  BuildContext context,
  ImportConfiguration config,
  ImportContext initial,
) => showDialog<ImportContext>(
  context: context,
  builder: (_) => ImportContextDialog(configuration: config, initial: initial),
);

class ImportContextDialog extends StatefulWidget {
  const ImportContextDialog({
    super.key,
    this.configuration = const ImportConfiguration(),
    this.initial = const ImportContext(),
    this.semesterOnly = false,
    this.timesOnly = false,
  });
  final ImportConfiguration configuration;
  final ImportContext initial;
  final bool semesterOnly, timesOnly;
  @override
  State<ImportContextDialog> createState() => _ImportContextDialogState();
}

class _ImportContextDialogState extends State<ImportContextDialog> {
  final _name = TextEditingController(),
      _monday = TextEditingController(),
      _weeks = TextEditingController();
  final _timesName = TextEditingController(),
      _times = TextEditingController(),
      _defaults = TextEditingController();
  String? _semesterId, _timesId, _error;
  bool _confirmed = false;
  @override
  void initState() {
    super.initState();
    _semesterId = widget.initial.semester?.id;
    _timesId = widget.initial.periodTimes?.id;
    _loadSemester(widget.initial.semester);
    _loadTimes(widget.initial.periodTimes);
    _defaults.text = widget.initial.defaultWeeks.join(',');
    _confirmed = widget.initial.confirmed;
  }

  void _loadSemester(SemesterPlan? p) {
    _name.text = p?.name ?? '';
    _monday.text = p?.firstWeekMonday.toIso8601String().split('T').first ?? '';
    _weeks.text = '${p?.totalWeeks ?? 18}';
  }

  void _loadTimes(PeriodTimePlan? p) {
    _timesName.text = p?.name ?? '';
    _times.text =
        p?.periods
            .map(
              (t) =>
                  '${t.number},${minuteLabel(t.startMinute)},${minuteLabel(t.endMinute)}',
            )
            .join('\n') ??
        '';
  }

  @override
  void dispose() {
    for (final c in [_name, _monday, _weeks, _timesName, _times, _defaults]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _input(
    TextEditingController c,
    String label, {
    int lines = 1,
    String? helperText,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 3,
        alignLabelWithHint: lines > 1,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  void _save() {
    try {
      SemesterPlan? semester;
      PeriodTimePlan? times;
      if (!widget.timesOnly &&
          (_monday.text.trim().isNotEmpty || widget.semesterOnly)) {
        semester = SemesterPlan(
          id: _semesterId ?? newImportId(),
          name: _name.text.trim(),
          firstWeekMonday: parseDate(_monday.text),
          totalWeeks: int.tryParse(_weeks.text) ?? 0,
        );
        semester.validate();
      }
      if (!widget.semesterOnly &&
          (_times.text.trim().isNotEmpty || widget.timesOnly)) {
        final periods = _times.text.trim().split('\n').map((line) {
          final parts = line.trim().split(RegExp(r'[,，]'));
          if (parts.length != 3) throw const FormatException('periodInvalid');
          return PeriodTime(
            number: int.tryParse(parts[0]) ?? 0,
            startMinute: parseMinute(parts[1]),
            endMinute: parseMinute(parts[2]),
          );
        }).toList();
        times = PeriodTimePlan(
          id: _timesId ?? newImportId(),
          name: _timesName.text.trim(),
          periods: periods,
        );
        times.validate();
      }
      final defaults = _defaults.text.trim().isEmpty
          ? <int>{}
          : parseWeeks(_defaults.text, semester?.totalWeeks ?? 30).toSet();
      if (!widget.semesterOnly && !widget.timesOnly && !_confirmed) {
        throw const FormatException('contextRequired');
      }
      Navigator.pop(
        context,
        ImportContext(
          semester: semester,
          periodTimes: times,
          defaultWeeks: defaults,
          confirmed: _confirmed,
        ),
      );
    } catch (e) {
      setState(() => _error = importErrorMessage(importL10n(context), e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = importL10n(context);
    return AlertDialog(
      title: Text(l.importPlans),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.semesterOnly && !widget.timesOnly)
                Text(l.importTemporaryContext),
              if (!widget.timesOnly) ...[
                if (widget.configuration.semesters.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue:
                        widget.configuration.semesters.any(
                          (p) => p.id == _semesterId,
                        )
                        ? _semesterId
                        : '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.importSemesterName,
                    ),
                    items: [
                      DropdownMenuItem(value: '', child: Text(l.importNone)),
                      ...widget.configuration.semesters.map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ),
                    ],
                    onChanged: (id) => setState(() {
                      _semesterId = id == '' ? null : id;
                      _loadSemester(
                        widget.configuration.semesters
                            .where((p) => p.id == id)
                            .firstOrNull,
                      );
                    }),
                  ),
                const SizedBox(height: 12),
                _input(_name, l.importSemesterName),
                _input(_monday, l.importFirstMonday),
                _input(_weeks, l.importTotalWeeks),
              ],
              if (!widget.semesterOnly) ...[
                if (widget.configuration.periodTimes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue:
                        widget.configuration.periodTimes.any(
                          (p) => p.id == _timesId,
                        )
                        ? _timesId
                        : '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.importPeriodPlanName,
                    ),
                    items: [
                      DropdownMenuItem(value: '', child: Text(l.importNone)),
                      ...widget.configuration.periodTimes.map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ),
                    ],
                    onChanged: (id) => setState(() {
                      _timesId = id == '' ? null : id;
                      _loadTimes(
                        widget.configuration.periodTimes
                            .where((p) => p.id == id)
                            .firstOrNull,
                      );
                    }),
                  ),
                const SizedBox(height: 12),
                _input(_timesName, l.importPeriodPlanName),
                _input(
                  _times,
                  l.importFieldPeriods,
                  lines: 6,
                  helperText: l.importPeriodTimeInput,
                ),
              ],
              if (!widget.semesterOnly && !widget.timesOnly) ...[
                _input(_defaults, l.importDefaultWeeks),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  title: Text(l.importConfirmContext),
                  onChanged: (v) => setState(() => _confirmed = v ?? false),
                ),
              ],
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
          onPressed: () => Navigator.pop(context),
          child: Text(l.importCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.importSave)),
      ],
    );
  }
}
