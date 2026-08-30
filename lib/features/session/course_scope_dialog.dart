import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_operation.dart';

Future<CourseOperationScope?> showCourseScopeDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<CourseOperationScope>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.courseScopeTitle),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, CourseOperationScope.single),
          child: _ScopeOption(
            icon: Icons.event_outlined,
            label: l10n.courseScopeSingle,
          ),
        ),
        SimpleDialogOption(
          onPressed: () =>
              Navigator.pop(context, CourseOperationScope.fromSelected),
          child: _ScopeOption(
            icon: Icons.event_repeat_outlined,
            label: l10n.courseScopeFromSelected,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, CourseOperationScope.all),
          child: _ScopeOption(
            icon: Icons.calendar_month_outlined,
            label: l10n.courseScopeAll,
          ),
        ),
      ],
    ),
  );
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
