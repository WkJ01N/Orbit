import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';

class SessionEditSheet extends ConsumerStatefulWidget {
  const SessionEditSheet({super.key, this.session});

  final CourseSession? session;

  bool get isCreateMode => session == null;

  static Future<bool?> showEdit(BuildContext context, CourseSession session) {
    return _show(context, SessionEditSheet(session: session));
  }

  static Future<bool?> showCreate(BuildContext context) {
    return _show(context, const SessionEditSheet());
  }

  static Future<bool?> _show(BuildContext context, SessionEditSheet sheet) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= kNarrowDialogBreakpoint) {
      return showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(child: sheet),
          ),
        ),
      );
    }
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: sheet,
      ),
    );
  }

  @override
  ConsumerState<SessionEditSheet> createState() => _SessionEditSheetState();
}

class _SessionEditSheetState extends ConsumerState<SessionEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _roomController;
  late final TextEditingController _teachersController;
  late final TextEditingController _courseCodeController;
  late final TextEditingController _sectionController;
  late final TextEditingController _classTypeController;
  late final TextEditingController _facultyController;
  late final TextEditingController _semesterController;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session != null) {
      _nameController = TextEditingController(text: session.courseName);
      _roomController = TextEditingController(text: session.room);
      _teachersController = TextEditingController(
        text: session.teachers.join('、'),
      );
      _courseCodeController = TextEditingController(text: session.courseCode);
      _sectionController = TextEditingController(text: session.section);
      _classTypeController = TextEditingController(text: session.classType);
      _facultyController = TextEditingController(text: session.faculty);
      _semesterController = TextEditingController(text: session.semester);
      _date = session.date;
      _startTime = TimeOfDay.fromDateTime(session.startAt);
      _endTime = TimeOfDay.fromDateTime(session.endAt);
    } else {
      final now = DateTime.now();
      _nameController = TextEditingController();
      _roomController = TextEditingController();
      _teachersController = TextEditingController();
      _courseCodeController = TextEditingController();
      _sectionController = TextEditingController(text: '1');
      _classTypeController = TextEditingController();
      _facultyController = TextEditingController();
      _semesterController = TextEditingController();
      // Default to the next future half-hour so a freshly added class is not
      // silently skipped by the reminder scheduler (which ignores past times).
      final start = _nextHalfHour(now);
      _date = DateTime(start.year, start.month, start.day);
      _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
      final end = start.add(const Duration(hours: 1));
      _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
    }
  }

  static DateTime _nextHalfHour(DateTime now) {
    // Round up to the next :00 or :30 boundary, at least a few minutes ahead.
    final base = now.add(const Duration(minutes: 5));
    var rounded = DateTime(base.year, base.month, base.day, base.hour);
    if (base.minute > 30) {
      rounded = rounded.add(const Duration(hours: 1));
    } else if (base.minute > 0) {
      rounded = rounded.add(const Duration(minutes: 30));
    }
    return rounded;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _teachersController.dispose();
    _courseCodeController.dispose();
    _sectionController.dispose();
    _classTypeController.dispose();
    _facultyController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  List<String> _parseTeachers(String raw) {
    return raw
        .split(RegExp(r'[,，、]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  CourseSession _buildSession() {
    final l10n = AppLocalizations.of(context)!;
    final startAt = _combineDateTime(_date, _startTime);
    final endAt = _combineDateTime(_date, _endTime);
    final name = _nameController.text.trim();
    final courseCode = _courseCodeController.text.trim().isEmpty
        ? 'MANUAL|${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        : _courseCodeController.text.trim();
    final section = _sectionController.text.trim().isEmpty
        ? '1'
        : _sectionController.text.trim();

    final base = widget.session;
    final session = CourseSession(
      id: '',
      classType: _classTypeController.text.trim().isEmpty
          ? l10n.defaultClassType
          : _classTypeController.text.trim(),
      room: _roomController.text.trim(),
      date: _date,
      weekday: _date.weekday,
      courseName: name,
      courseCode: courseCode,
      section: section,
      startAt: startAt,
      endAt: endAt,
      teachers: _parseTeachers(_teachersController.text),
      faculty: _facultyController.text.trim(),
      semester: _semesterController.text.trim(),
      sourceFile: base?.sourceFile,
      note: base?.note,
    );
    return session.copyWith(id: session.computeId());
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final room = _roomController.text.trim();
    if (name.isEmpty || room.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sessionCreateRequiredFields)),
      );
      return;
    }

    final finalSession = _buildSession();
    if (!finalSession.endAt.isAfter(finalSession.startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.editSessionEndBeforeStart)),
      );
      return;
    }

    final repository = ref.read(scheduleRepositoryProvider);

    setState(() => _saving = true);
    try {
      final overwritten = await repository.saveSessionWithConflictResolution(
        finalSession,
        original: widget.session,
      );
      final failures = await rescheduleAllReminders(ref);
      refreshSchedule(ref);

      if (mounted) {
        Navigator.pop(context, true);
        final baseMessage = overwritten > 0
            ? l10n.sessionSavedWithOverride(overwritten)
            : (widget.isCreateMode ? l10n.sessionCreated : l10n.sessionUpdated);
        final syncError = ref.read(lastRescheduleErrorProvider);
        final scheduledCount = ref.read(lastScheduledCountProvider);
        final alarmCount = ref.read(lastRegisteredAlarmCountProvider);
        final String message;
        if (syncError == 'verify') {
          message = '$baseMessage ${l10n.reminderScheduleVerifyFailed}';
        } else if (failures > 0) {
          message = '$baseMessage ${l10n.resyncPartialFailed(failures)}';
        } else if (Platform.isAndroid && alarmCount > 0) {
          message =
              '$baseMessage ${l10n.reminderRegisteredAlarmCount(alarmCount)}';
        } else if (scheduledCount > 0) {
          message = '$baseMessage ${l10n.reminderScheduledCount(scheduledCount)}';
        } else {
          message = baseMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sessionSaveFailed('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final startLabel = _startTime.format(context);
    final endLabel = _endTime.format(context);
    final dateLabel = DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .format(_date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isCreateMode ? l10n.addSessionTitle : l10n.editSessionTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (widget.isCreateMode)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.fieldDate),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: Text(dateLabel),
                ),
              ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.fieldCourseName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomController,
              decoration: InputDecoration(
                labelText: l10n.fieldRoom,
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.isCreateMode) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _courseCodeController,
                decoration: InputDecoration(
                  labelText: l10n.fieldCourseCode,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sectionController,
                decoration: InputDecoration(
                  labelText: l10n.fieldSection,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
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
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.fieldStartTime),
              trailing: TextButton(
                onPressed: _pickStartTime,
                child: Text(startLabel),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.fieldEndTime),
              trailing: TextButton(
                onPressed: _pickEndTime,
                child: Text(endLabel),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isCreateMode ? l10n.actionCreate : l10n.actionApply),
            ),
          ],
        ),
      ),
    );
  }
}
