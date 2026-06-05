import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/core/widgets/step_confirm_dialog.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/providers/app_providers.dart';

Future<void> showGridBatchDeleteDialog(
  BuildContext context,
  WidgetRef ref, {
  required DateTime displayedWeekStart,
}) async {
  final useSheet = MediaQuery.sizeOf(context).width < kNarrowDialogBreakpoint;
  if (useSheet) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _GridBatchDeleteSheet(displayedWeekStart: displayedWeekStart),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _GridBatchDeleteSheet(displayedWeekStart: displayedWeekStart),
        ),
      ),
    );
  }
}

class _GridBatchDeleteSheet extends ConsumerStatefulWidget {
  const _GridBatchDeleteSheet({required this.displayedWeekStart});

  final DateTime displayedWeekStart;

  @override
  ConsumerState<_GridBatchDeleteSheet> createState() =>
      _GridBatchDeleteSheetState();
}

class _GridBatchDeleteSheetState extends ConsumerState<_GridBatchDeleteSheet> {
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  int? _previewCount;
  bool _loadingCount = false;

  @override
  void initState() {
    super.initState();
    final defaults = defaultBatchDeleteRange(widget.displayedWeekStart);
    _rangeStart = defaults.start;
    _rangeEnd = defaults.end;
    _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    if (!mounted) {
      return;
    }
    setState(() => _loadingCount = true);
    try {
      final count = await ref
          .read(scheduleRepositoryProvider)
          .countSessionsFullyInRange(_rangeStart, _rangeEnd);
      if (mounted) {
        setState(() {
          _previewCount = count;
          _loadingCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _loadingCount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gridLoadFailed('$e'))),
        );
      }
    }
  }

  Future<void> _pickDateTime({
    required DateTime initial,
    required ValueChanged<DateTime> onChanged,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }
    onChanged(combineDateAndTime(date, time));
    await _refreshPreview();
  }

  bool _isValidRange() => _rangeEnd.isAfter(_rangeStart);

  Future<bool> _confirmDeletion(int count) {
    final l10n = AppLocalizations.of(context)!;
    return confirmWithSteps(
      context,
      steps: [
        (
          l10n.gridBatchDeleteConfirm1Title,
          l10n.gridBatchDeleteConfirm1Content(count),
        ),
        (l10n.gridBatchDeleteConfirm2Title, l10n.gridBatchDeleteConfirm2Content),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_isValidRange()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.gridBatchDeleteInvalidRange)),
      );
      return;
    }

    final count = _previewCount ?? 0;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.gridBatchDeleteNone)),
      );
      return;
    }

    final confirmed = await _confirmDeletion(count);
    if (!confirmed || !mounted) {
      return;
    }

    try {
      final deleted = await ref
          .read(scheduleRepositoryProvider)
          .deleteSessionsFullyInRange(_rangeStart, _rangeEnd);
      await rescheduleAllReminders(ref);
      refreshSchedule(ref);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gridBatchDeleteDone(deleted))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gridLoadFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.gridBatchDeleteTitle,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          _RangeField(
            label: l10n.gridBatchDeleteStart,
            value: formatDateTimeMinute(_rangeStart),
            onTap: () => _pickDateTime(
              initial: _rangeStart,
              onChanged: (value) => setState(() => _rangeStart = value),
            ),
          ),
          const SizedBox(height: 12),
          _RangeField(
            label: l10n.gridBatchDeleteEnd,
            value: formatDateTimeMinute(_rangeEnd),
            onTap: () => _pickDateTime(
              initial: _rangeEnd,
              onChanged: (value) => setState(() => _rangeEnd = value),
            ),
          ),
          const SizedBox(height: 16),
          if (!_isValidRange())
            Text(
              l10n.gridBatchDeleteInvalidRange,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (_loadingCount)
            const Center(child: CircularProgressIndicator())
          else
            Text(
              l10n.gridBatchDeletePreview(_previewCount ?? 0),
              style: theme.textTheme.bodyLarge,
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.actionCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                child: Text(l10n.actionDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeField extends StatelessWidget {
  const _RangeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.edit_calendar),
        ),
        child: Text(value),
      ),
    );
  }
}
