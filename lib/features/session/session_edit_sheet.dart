import 'package:orbit/models/v162_text.dart';
import 'package:uuid/uuid.dart';
import 'package:orbit/core/widgets/statistics_deletion_choice.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';
import 'package:orbit/features/session/course_scope_dialog.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/features/session/existing_course_picker.dart';
import 'package:orbit/models/orbit_feature_text.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/providers/app_providers.dart';

class SessionEditSheet extends ConsumerStatefulWidget {
  const SessionEditSheet({super.key, this.session, this.exam = false});

  final CourseSession? session;
  final bool exam;
  bool get isExam => exam || (session?.isExam ?? false);

  bool get isCreateMode => session == null;

  static Future<bool?> showEdit(BuildContext context, CourseSession session) {
    return _show(context, SessionEditSheet(session: session));
  }

  static Future<bool?> showCreateExam(BuildContext context) =>
      _show(context, const SessionEditSheet(exam: true));

  static Future<bool?> showCreate(BuildContext context) {
    return _show(context, const SessionEditSheet());
  }

  static Future<bool?> _show(BuildContext context, SessionEditSheet sheet) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= kNarrowDialogBreakpoint) {
      return showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 32,
          ),
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
  bool _examReminder = true, _examStrong = true, _nextDay = false;
  bool _pickedDate = false, _pickedStart = false, _pickedEnd = false;
  int _examLead = 30;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session != null) {
      _pickedDate = _pickedStart = _pickedEnd = true;
      _examReminder = session.examReminderEnabled;
      _examStrong = session.examStrongReminder;
      _examLead = session.examLeadMinutes;
      _nextDay = session.endAt.day != session.startAt.day;
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

  CourseSession? _selectedCourse;
  Future<void> _chooseCourse() async {
    final course = await chooseExistingCourse(context);
    if (course == null || !mounted) return;
    setState(() {
      _selectedCourse = course;
      _nameController.text = course.courseName;
      _courseCodeController.text = course.courseCode;
      _sectionController.text = course.section;
      if (!widget.isExam) _roomController.text = course.room;
      _teachersController.text = course.teachers.join(', ');
      _facultyController.text = course.faculty;
      _semesterController.text = course.semester;
      _classTypeController.text = course.classType;
    });
  }

  void _newCourse() => setState(() {
    _selectedCourse = null;
    _nameController.clear();
    _courseCodeController.clear();
    _sectionController.text = '1';
    _semesterController.clear();
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _pickedDate = true;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _pickedStart = true;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _pickedEnd = true;
      });
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
    final endAt = _combineDateTime(
      _nextDay ? _date.add(const Duration(days: 1)) : _date,
      _endTime,
    );
    final name = _nameController.text.trim();
    final courseCode =
        _selectedCourse == null && _courseCodeController.text.trim().isEmpty
        ? 'MANUAL|${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        : _courseCodeController.text.trim();
    final section = _sectionController.text.trim().isEmpty
        ? '1'
        : _sectionController.text.trim();

    final base = widget.session;
    final session = CourseSession(
      id: widget.isExam ? base?.id ?? 'exam|${const Uuid().v4()}' : '',
      kind: widget.isExam ? SessionKind.exam : SessionKind.course,
      semesterId: _selectedCourse?.semesterId ?? base?.semesterId,
      examReminderEnabled: _examReminder,
      examStrongReminder: _examStrong,
      examLeadMinutes: _examLead,
      classType: widget.isExam
          ? V162Text.of(context).exam
          : _classTypeController.text.trim().isEmpty
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
      teachers: widget.isExam
          ? const []
          : _parseTeachers(_teachersController.text),
      faculty: _facultyController.text.trim(),
      semester: _semesterController.text.trim(),
      archivedAt: base?.archivedAt,
      archiveHidden: base?.archiveHidden ?? false,
      autoArchivePaused: base != null && base.endAt == endAt
          ? base.autoArchivePaused
          : false,
      linkedCourseKey: _selectedCourse == null
          ? base?.linkedCourseKey
          : CourseSeriesKey.fromSession(_selectedCourse!).value,
      recurrenceSeriesId: widget.isExam
          ? null
          : _selectedCourse?.recurrenceSeriesId ?? base?.recurrenceSeriesId,
      recurrenceMeetingId: widget.isExam
          ? null
          : _selectedCourse?.recurrenceSeriesId == null
          ? base?.recurrenceMeetingId
          : 'extra-${DateTime.now().microsecondsSinceEpoch}',
      startPeriod:
          base != null &&
              base.startAt.hour == startAt.hour &&
              base.startAt.minute == startAt.minute
          ? base.startPeriod
          : null,
      periodTimePlanId:
          _selectedCourse?.periodTimePlanId ?? base?.periodTimePlanId,
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
    if (name.isEmpty ||
        room.isEmpty ||
        (widget.isExam && !(_pickedDate && _pickedStart && _pickedEnd))) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            widget.isExam
                ? V162Text.of(context).examRequired
                : l10n.sessionCreateRequiredFields,
          ),
        ),
      );
      return;
    }

    if (widget.isExam && (_examLead < 0 || _examLead > 10080)) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(V162Text.of(context).leadInvalid)),
      );
      return;
    }
    final finalSession = _buildSession();
    if (!finalSession.endAt.isAfter(finalSession.startAt)) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(l10n.editSessionEndBeforeStart),
        ),
      );
      return;
    }

    final repository = ref.read(scheduleRepositoryProvider);

    setState(() => _saving = true);
    try {
      var deleteStatistics = false;
      var scope = CourseOperationScope.single;
      var recurringScope = RecurringCourseEditScope.single;
      var isRecurringEdit = false;
      CourseOperationResult? operationResult;
      int overwritten;
      final original = widget.session;
      if (widget.isExam) {
        await repository.insertSession(finalSession);
        overwritten = 0;
      } else if (original != null) {
        final matching = await repository.getCourseSeries(
          original,
          CourseOperationScope.all,
        );
        if (matching.length > 1 && mounted) {
          if (original.recurrenceSeriesId != null &&
              original.recurrenceMeetingId != null) {
            final selectedScope = await showRecurringCourseEditScopeDialog(
              context,
            );
            if (selectedScope == null || !mounted) {
              setState(() => _saving = false);
              return;
            }
            recurringScope = selectedScope;
            isRecurringEdit = true;
          } else {
            final selectedScope = await showCourseScopeDialog(context);
            if (selectedScope == null || !mounted) {
              setState(() => _saving = false);
              return;
            }
            scope = selectedScope;
          }
        }
        final preview = isRecurringEdit
            ? await repository.previewRecurringCourseUpdate(
                selected: original,
                changes: finalSession,
                scope: recurringScope,
              )
            : await repository.previewCourseSeriesUpdate(
                selected: original,
                changes: finalSession,
                scope: scope,
              );
        if ((preview.targetCount > 1 || preview.conflictCount > 0) && mounted) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.courseScopeTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.courseOperationSummary(
                      preview.targetCount,
                      DateFormat('yyyy-MM-dd').format(preview.firstDate),
                      DateFormat('yyyy-MM-dd').format(preview.lastDate),
                      preview.conflictCount,
                    ),
                  ),
                  if (preview.conflictCount > 0)
                    StatisticsDeletionChoice(
                      onChanged: (v) => deleteStatistics = v,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.actionApply),
                ),
              ],
            ),
          );
          if (confirmed != true || !mounted) {
            setState(() => _saving = false);
            return;
          }
        }
        operationResult = isRecurringEdit
            ? await repository.updateRecurringCourse(
                selected: original,
                changes: finalSession,
                scope: recurringScope,
                deleteStatistics: deleteStatistics,
              )
            : await repository.updateCourseSeries(
                selected: original,
                changes: finalSession,
                scope: scope,
                deleteStatistics: deleteStatistics,
              );
        overwritten = operationResult.conflictCount;
      } else {
        final existing = await repository.getAllSessions();
        final conflicts = existing
            .where(
              (s) =>
                  !s.isExam &&
                  s.id != finalSession.id &&
                  s.startAt.isBefore(finalSession.endAt) &&
                  finalSession.startAt.isBefore(s.endAt),
            )
            .toList();
        if (conflicts.isNotEmpty) {
          if (!mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(l10n.batchOverwriteConflicts),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.batchPreviewSummary(1, conflicts.length)),
                  StatisticsDeletionChoice(
                    onChanged: (v) => deleteStatistics = v,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(l10n.actionApply),
                ),
              ],
            ),
          );
          if (confirmed != true || !mounted) return;
        }
        overwritten = await repository.saveSessionWithConflictResolution(
          finalSession,
          deleteStatistics: deleteStatistics,
        );
      }
      refreshSchedule(ref);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        final baseMessage =
            operationResult != null && operationResult.affectedCount > 1
            ? l10n.courseBatchUpdated(operationResult.affectedCount)
            : overwritten > 0
            ? l10n.sessionSavedWithOverride(overwritten)
            : (widget.isCreateMode ? l10n.sessionCreated : l10n.sessionUpdated);
        messenger.showAppSnackBar(
          SnackBar(
            content: Text(baseMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      ref.read(reminderSettingsProvider.notifier).scheduleResync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(l10n.sessionSaveFailed('$e')),
          ),
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
    final dateLabel = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(_date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isExam
                  ? (widget.isCreateMode
                        ? V162Text.of(context).addExam
                        : V162Text.of(context).editExam)
                  : widget.isCreateMode
                  ? l10n.addSessionTitle
                  : l10n.editSessionTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (widget.isExam) Text(V162Text.of(context).examHint),
            if (widget.isCreateMode) ...[
              OutlinedButton.icon(
                onPressed: _saving ? null : _chooseCourse,
                icon: const Icon(Icons.playlist_add),
                label: Text(OrbitFeatureText.of(context).existing),
              ),
              if (_selectedCourse != null)
                TextButton(
                  onPressed: _saving ? null : _newCourse,
                  child: Text(OrbitFeatureText.of(context).newCourse),
                ),
            ],
            if (widget.isCreateMode || widget.isExam)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.fieldDate),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: Text(
                    widget.isExam && !_pickedDate ? l10n.fieldDate : dateLabel,
                  ),
                ),
              ),
            TextField(
              controller: _nameController,
              readOnly: _selectedCourse != null,
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
                readOnly: _selectedCourse != null,
                decoration: InputDecoration(
                  labelText: l10n.fieldCourseCode,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sectionController,
                readOnly: _selectedCourse != null,
                decoration: InputDecoration(
                  labelText: l10n.fieldSection,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!widget.isExam)
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
                child: Text(
                  widget.isExam && !_pickedStart
                      ? l10n.fieldStartTime
                      : startLabel,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.fieldEndTime),
              trailing: TextButton(
                onPressed: _pickEndTime,
                child: Text(
                  widget.isExam && !_pickedEnd ? l10n.fieldEndTime : endLabel,
                ),
              ),
            ),
            if (widget.isExam) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(V162Text.of(context).nextDay),
                value: _nextDay,
                onChanged: _saving ? null : (v) => setState(() => _nextDay = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(V162Text.of(context).reminder),
                value: _examReminder,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _examReminder = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(V162Text.of(context).strong),
                value: _examStrong,
                onChanged: !_examReminder || _saving
                    ? null
                    : (v) => setState(() => _examStrong = v),
              ),
              TextFormField(
                initialValue: '$_examLead',
                enabled: !_saving && _examReminder,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: V162Text.of(context).lead,
                ),
                onChanged: (v) => _examLead = int.tryParse(v) ?? -1,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.isCreateMode
                          ? l10n.actionCreate
                          : l10n.actionApply,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
