import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';

class SessionEditSheet extends ConsumerStatefulWidget {
  const SessionEditSheet({super.key, required this.session});

  final CourseSession session;

  static Future<bool?> show(BuildContext context, CourseSession session) {
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
        child: SessionEditSheet(session: session),
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
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _nameController = TextEditingController(text: session.courseName);
    _roomController = TextEditingController(text: session.room);
    _teachersController = TextEditingController(
      text: session.teachers.join('、'),
    );
    _startTime = TimeOfDay.fromDateTime(session.startAt);
    _endTime = TimeOfDay.fromDateTime(session.endAt);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _teachersController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final room = _roomController.text.trim();
    if (name.isEmpty || room.isEmpty) {
      return;
    }

    final startAt = _combineDateTime(widget.session.date, _startTime);
    final endAt = _combineDateTime(widget.session.date, _endTime);
    if (!endAt.isAfter(startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.editSessionEndBeforeStart)),
      );
      return;
    }

    final withId = widget.session.copyWith(
      courseName: name,
      room: room,
      teachers: _parseTeachers(_teachersController.text),
      startAt: startAt,
      endAt: endAt,
    );
    final finalSession = withId.copyWith(id: withId.computeId());

    try {
      await ref.read(scheduleRepositoryProvider).updateSession(
            widget.session,
            finalSession,
          );
      await rescheduleAllReminders(ref);
      refreshSchedule(ref);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sessionUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final startLabel = _startTime.format(context);
    final endLabel = _endTime.format(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.editSessionTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
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
            child: Text(l10n.actionApply),
          ),
        ],
      ),
    );
  }
}
