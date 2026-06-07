import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      _date = DateTime(now.year, now.month, now.day);
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
    }
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
    final courseCode = _courseCodeController.text.trim().isEmpty
        ? 'MANUAL'
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
      courseName: _nameController.text.trim(),
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
    final hasConflict = await repository.hasTimeConflict(
      finalSession,
      excludeId: widget.session?.id,
    );
    if (hasConflict && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sessionTimeConflict)),
      );
    }

    try {
      if (widget.isCreateMode) {
        await repository.insertSession(finalSession);
      } else {
        await repository.updateSession(widget.session!, finalSession);
      }
      await rescheduleAllReminders(ref);
      refreshSchedule(ref);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isCreateMode ? l10n.sessionCreated : l10n.sessionUpdated,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sessionSaveFailed('$e'))),
        );
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
              onPressed: _save,
              child: Text(widget.isCreateMode ? l10n.actionCreate : l10n.actionApply),
            ),
          ],
        ),
      ),
    );
  }
}
