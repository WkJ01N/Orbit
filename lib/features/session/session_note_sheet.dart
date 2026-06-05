import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';

class SessionNoteSheet extends ConsumerStatefulWidget {
  const SessionNoteSheet({super.key, required this.session});

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
        child: SessionNoteSheet(session: session),
      ),
    );
  }

  @override
  ConsumerState<SessionNoteSheet> createState() => _SessionNoteSheetState();
}

class _SessionNoteSheetState extends ConsumerState<SessionNoteSheet> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.session.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final note = _noteController.text.trim();
    final updated = widget.session.copyWith(
      note: note.isEmpty ? null : note,
      clearNote: note.isEmpty,
    );

    try {
      await ref.read(scheduleRepositoryProvider).updateSession(
            widget.session,
            updated,
          );
      refreshSchedule(ref);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sessionNoteSaved)),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.sessionNoteTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: l10n.sessionNoteHint,
              border: const OutlineInputBorder(),
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
