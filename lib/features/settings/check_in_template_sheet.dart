import 'package:orbit/core/widgets/reminder_template_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/widgets/adaptive_bottom_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/reminder_providers.dart';

class CheckInTemplateSheet extends ConsumerStatefulWidget {
  const CheckInTemplateSheet({super.key, required this.settings});

  final ReminderSettings settings;

  static Future<void> show(
    BuildContext context, {
    required ReminderSettings settings,
  }) {
    return showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CheckInTemplateSheet(settings: settings),
    );
  }

  @override
  ConsumerState<CheckInTemplateSheet> createState() =>
      _CheckInTemplateSheetState();
}

class _CheckInTemplateSheetState extends ConsumerState<CheckInTemplateSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.settings.checkInTitleTemplate ?? '',
    );
    _bodyController = TextEditingController(
      text: widget.settings.checkInBodyTemplate ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(reminderSettingsProvider.notifier)
          .updateCheckInTemplates(
            title: _titleController.text,
            body: _bodyController.text,
          );
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _reset() {
    setState(() {
      _titleController.clear();
      _bodyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.checkInTemplateSheetTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.checkInTemplatePlaceholderHint(
                  '{course}',
                  '{room}',
                  '{time}',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _field(l10n.checkInTitleLabel, _titleController),
              _field(l10n.checkInBodyLabel, _bodyController),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : _reset,
                    child: Text(l10n.nextDayTemplateReset),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.actionApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return ReminderTemplateField(
      label: label,
      controller: controller,
      multiline: controller == _bodyController,
      variables: const ['course', 'room', 'time'],
    );
  }
}
