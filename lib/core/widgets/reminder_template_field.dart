import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/services/custom_reminder_planner.dart';

/// Shared editor: variable insertion replaces the selection and keeps the caret.
class ReminderVariableButtons extends StatelessWidget {
  const ReminderVariableButtons({
    super.key,
    required this.controller,
    required this.variables,
    this.onChanged,
  });
  final TextEditingController controller;
  final List<String> variables;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = l.reminderVariableLabels.split('|');
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final variable in variables)
          ActionChip(
            label: Text(switch (variable) {
              'time' => labels[reminderVariables.indexOf('startTime')],
              'minutes' => l.templateLeadMinutes,
              'count' => l.templateCourseCount,
              _ =>
                reminderVariables.contains(variable)
                    ? labels[reminderVariables.indexOf(variable)]
                    : '{$variable}',
            }),
            tooltip: '{$variable}',
            onPressed: () {
              final selection = controller.selection;
              final start = selection.isValid
                  ? selection.start
                  : controller.text.length;
              final end = selection.isValid ? selection.end : start;
              final token = '{$variable}';
              controller.value = TextEditingValue(
                text: controller.text.replaceRange(start, end, token),
                selection: TextSelection.collapsed(
                  offset: start + token.length,
                ),
              );
              onChanged?.call();
            },
          ),
      ],
    );
  }
}

class ReminderTemplateField extends StatelessWidget {
  const ReminderTemplateField({
    super.key,
    required this.controller,
    required this.label,
    required this.variables,
    this.multiline = false,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final List<String> variables;
  final bool multiline;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: multiline ? 5 : 1,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            labelText: label,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => onChanged?.call(),
        ),
        const SizedBox(height: 6),
        ReminderVariableButtons(
          controller: controller,
          variables: variables,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
