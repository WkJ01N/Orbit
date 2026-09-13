import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/batch_course.dart';
import 'package:orbit/providers/app_providers.dart';

class BatchSessionEditSheet extends ConsumerStatefulWidget {
  const BatchSessionEditSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    final sheet = const BatchSessionEditSheet();
    if (MediaQuery.sizeOf(context).width >= kNarrowDialogBreakpoint) {
      return showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
            child: sheet,
          ),
        ),
      );
    }
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(heightFactor: 0.94, child: sheet),
      ),
    );
  }

  @override
  ConsumerState<BatchSessionEditSheet> createState() =>
      _BatchSessionEditSheetState();
}

class _BatchSessionEditSheetState extends ConsumerState<BatchSessionEditSheet> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _sectionController = TextEditingController(text: '1');
  final _teachersController = TextEditingController();
  final _facultyController = TextEditingController();
  late DateTime _firstWeekMonday;
  int _totalWeeks = 18;
  Set<int> _selectedWeeks = {for (var week = 1; week <= 18; week++) week};
  final List<_MeetingState> _meetings = [];
  var _meetingSequence = 0;
  var _saving = false;
  var _defaultsLoaded = false;

  @override
  void initState() {
    super.initState();
    _firstWeekMonday = _mondayOf(DateTime.now());
    _meetings.add(_newMeeting());
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final defaults = await ref
        .read(settingsServiceProvider)
        .loadBatchCourseDefaults();
    if (!mounted || _defaultsLoaded) return;
    setState(() {
      _firstWeekMonday = defaults.firstWeekMonday == null
          ? _firstWeekMonday
          : _mondayOf(defaults.firstWeekMonday!);
      _totalWeeks = defaults.totalWeeks;
      _selectedWeeks = {for (var week = 1; week <= _totalWeeks; week++) week};
      _defaultsLoaded = true;
    });
  }

  _MeetingState _newMeeting() {
    _meetingSequence++;
    return _MeetingState(
      id: 'meeting-$_meetingSequence',
      weekday: DateTime.monday,
      roomController: TextEditingController(),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 10, minute: 0),
    );
  }

  static DateTime _mondayOf(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _sectionController.dispose();
    _teachersController.dispose();
    _facultyController.dispose();
    for (final meeting in _meetings) {
      meeting.dispose();
    }
    super.dispose();
  }

  List<String> _parseTeachers(String raw) => raw
      .split(RegExp(r'[,，、]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  int _minuteOf(TimeOfDay value) => value.hour * 60 + value.minute;

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(SnackBar(content: Text(message)), isError: true);
  }

  Future<void> _pickFirstWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstWeekMonday,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _firstWeekMonday = _mondayOf(picked));
  }

  Future<void> _pickMeetingTime(
    _MeetingState meeting, {
    required bool start,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? meeting.startTime : meeting.endTime,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        meeting.startTime = picked;
      } else {
        meeting.endTime = picked;
      }
    });
  }

  void _setWeekSelection(Iterable<int> weeks) {
    setState(() => _selectedWeeks = weeks.toSet());
  }

  Future<BatchConflictStrategy?> _confirmPreview(BatchCoursePreview preview) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<BatchConflictStrategy>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.batchPreviewTitle),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(
              l10n.batchPreviewSummary(
                preview.generatedCount,
                preview.conflictCount,
              ),
            ),
          ),
          if (preview.conflictCount > 0)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, BatchConflictStrategy.skip),
              child: Text(l10n.batchSkipConflicts),
            ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, BatchConflictStrategy.overwrite),
            child: Text(
              preview.conflictCount > 0
                  ? l10n.batchOverwriteConflicts
                  : l10n.actionCreate,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty ||
        _meetings.any(
          (meeting) => meeting.roomController.text.trim().isEmpty,
        )) {
      _showMessage(l10n.batchRequiredFields);
      return;
    }
    if (_selectedWeeks.isEmpty) {
      _showMessage(l10n.batchNoWeeks);
      return;
    }
    if (_meetings.isEmpty) {
      _showMessage(l10n.batchNoMeetings);
      return;
    }
    final meetings = _meetings
        .map(
          (meeting) => BatchMeeting(
            id: meeting.id,
            weekday: meeting.weekday,
            room: meeting.roomController.text,
            startMinute: _minuteOf(meeting.startTime),
            endMinute: _minuteOf(meeting.endTime),
          ),
        )
        .toList();
    if (meetings.any((meeting) => meeting.endMinute <= meeting.startMinute)) {
      _showMessage(l10n.batchInvalidTime);
      return;
    }
    if (batchMeetingsOverlap(meetings)) {
      _showMessage(l10n.batchMeetingOverlap);
      return;
    }

    setState(() => _saving = true);
    try {
      final seriesId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      final generated = generateBatchCourseSessions(
        BatchCourseDraft(
          courseName: _nameController.text,
          courseCode: _codeController.text,
          section: _sectionController.text,
          teachers: _parseTeachers(_teachersController.text),
          faculty: _facultyController.text,
          classType: l10n.defaultClassType,
          semester: '',
          firstWeekMonday: _firstWeekMonday,
          totalWeeks: _totalWeeks,
          selectedWeeks: _selectedWeeks,
          meetings: meetings,
        ),
        seriesId: seriesId,
      );
      final repository = ref.read(scheduleRepositoryProvider);
      final preview = await repository.previewBatchCreate(generated);
      if (!mounted) return;
      final strategy = await _confirmPreview(preview);
      if (strategy == null || !mounted) return;
      final result = await repository.saveBatchSessions(
        generated,
        strategy: strategy,
      );
      await ref
          .read(settingsServiceProvider)
          .saveBatchCourseDefaults(
            firstWeekMonday: _firstWeekMonday,
            totalWeeks: _totalWeeks,
          );
      refreshSchedule(ref);
      ref.read(reminderSettingsProvider.notifier).scheduleResync();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showAppSnackBar(
        SnackBar(
          content: Text(
            l10n.batchCreateResult(
              result.createdCount,
              result.skippedCount,
              result.overwrittenCount,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(l10n.sessionSaveFailed('$error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.batchAddTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.fieldCourseName,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            labelText: l10n.fieldCourseCode,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _sectionController,
                          decoration: InputDecoration(
                            labelText: l10n.fieldSection,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _teachersController,
                    decoration: InputDecoration(
                      labelText: l10n.fieldTeachers,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _facultyController,
                    decoration: InputDecoration(
                      labelText: l10n.fieldFaculty,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.batchFirstWeekMonday),
                    trailing: TextButton(
                      onPressed: _pickFirstWeek,
                      child: Text(
                        DateFormat.yMMMd(locale).format(_firstWeekMonday),
                      ),
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey('batch-total-weeks-$_totalWeeks'),
                    initialValue: _totalWeeks,
                    decoration: InputDecoration(
                      labelText: l10n.batchTotalWeeks,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (var value = 1; value <= 30; value++)
                        DropdownMenuItem(value: value, child: Text('$value')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _totalWeeks = value;
                        _selectedWeeks = _selectedWeeks
                            .where((week) => week <= value)
                            .toSet();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.batchSelectedWeeks,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      TextButton(
                        onPressed: () => _setWeekSelection([
                          for (var week = 1; week <= _totalWeeks; week++) week,
                        ]),
                        child: Text(l10n.batchSelectAll),
                      ),
                      TextButton(
                        onPressed: () => _setWeekSelection([
                          for (var week = 1; week <= _totalWeeks; week += 2)
                            week,
                        ]),
                        child: Text(l10n.batchSelectOdd),
                      ),
                      TextButton(
                        onPressed: () => _setWeekSelection([
                          for (var week = 2; week <= _totalWeeks; week += 2)
                            week,
                        ]),
                        child: Text(l10n.batchSelectEven),
                      ),
                      TextButton(
                        onPressed: () => _setWeekSelection(const []),
                        child: Text(l10n.batchClearWeeks),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      for (var week = 1; week <= _totalWeeks; week++)
                        FilterChip(
                          key: Key('batch-week-$week'),
                          label: Text('$week'),
                          tooltip: l10n.batchWeekOption(week),
                          selected: _selectedWeeks.contains(week),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedWeeks.add(week);
                            } else {
                              _selectedWeeks.remove(week);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.batchMeetings,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < _meetings.length; index++) ...[
                    _MeetingCard(
                      key: ValueKey(_meetings[index].id),
                      index: index,
                      meeting: _meetings[index],
                      canRemove: _meetings.length > 1,
                      onChanged: () => setState(() {}),
                      onPickStart: () =>
                          _pickMeetingTime(_meetings[index], start: true),
                      onPickEnd: () =>
                          _pickMeetingTime(_meetings[index], start: false),
                      onRemove: () => setState(() {
                        final removed = _meetings.removeAt(index);
                        removed.dispose();
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    key: const Key('batch-add-meeting'),
                    onPressed: () =>
                        setState(() => _meetings.add(_newMeeting())),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.batchAddMeeting),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('batch-create'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.actionCreate),
          ),
        ],
      ),
    );
  }
}

class _MeetingState {
  _MeetingState({
    required this.id,
    required this.weekday,
    required this.roomController,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  int weekday;
  final TextEditingController roomController;
  TimeOfDay startTime;
  TimeOfDay endTime;

  void dispose() => roomController.dispose();
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    super.key,
    required this.index,
    required this.meeting,
    required this.canRemove,
    required this.onChanged,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onRemove,
  });

  final int index;
  final _MeetingState meeting;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    key: Key('batch-meeting-title-$index'),
                    l10n.batchMeetingTitle(index + 1),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (canRemove)
                  IconButton(
                    tooltip: l10n.batchRemoveMeeting,
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: Key('batch-meeting-weekday-$index'),
              initialValue: meeting.weekday,
              decoration: InputDecoration(
                labelText: l10n.fieldDate,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (var weekday = 1; weekday <= 7; weekday++)
                  DropdownMenuItem(
                    value: weekday,
                    child: Text(weekdayLabel(l10n, weekday)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                meeting.weekday = value;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: meeting.roomController,
              decoration: InputDecoration(
                labelText: l10n.fieldRoom,
                border: const OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.fieldStartTime),
                    subtitle: Text(meeting.startTime.format(context)),
                    onTap: onPickStart,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.fieldEndTime),
                    subtitle: Text(meeting.endTime.format(context)),
                    onTap: onPickEnd,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
