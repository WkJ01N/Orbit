import 'package:orbit/core/widgets/reminder_template_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/widgets/adaptive_bottom_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/reminder_providers.dart';

class NextDaySummaryTemplateSheet extends ConsumerStatefulWidget {
  const NextDaySummaryTemplateSheet({super.key, required this.settings});

  final ReminderSettings settings;

  static Future<void> show(
    BuildContext context, {
    required ReminderSettings settings,
  }) {
    return showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => NextDaySummaryTemplateSheet(settings: settings),
    );
  }

  @override
  ConsumerState<NextDaySummaryTemplateSheet> createState() =>
      _NextDaySummaryTemplateSheetState();
}

class _NextDaySummaryTemplateSheetState
    extends ConsumerState<NextDaySummaryTemplateSheet> {
  late final TextEditingController _withClassTitleController;
  late final TextEditingController _withClassBodyController;
  late final TextEditingController _noClassTitleController;
  late final TextEditingController _noClassBodyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _withClassTitleController = TextEditingController(
      text: widget.settings.nextDayWithClassTitleTemplate ?? '',
    );
    _withClassBodyController = TextEditingController(
      text: widget.settings.nextDayWithClassBodyTemplate ?? '',
    );
    _noClassTitleController = TextEditingController(
      text: widget.settings.nextDayNoClassTitleTemplate ?? '',
    );
    _noClassBodyController = TextEditingController(
      text: widget.settings.nextDayNoClassBodyTemplate ?? '',
    );
  }

  @override
  void dispose() {
    _withClassTitleController.dispose();
    _withClassBodyController.dispose();
    _noClassTitleController.dispose();
    _noClassBodyController.dispose();
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
          .updateNextDayTemplates(
            withClassTitle: _withClassTitleController.text,
            withClassBody: _withClassBodyController.text,
            noClassTitle: _noClassTitleController.text,
            noClassBody: _noClassBodyController.text,
          );
      await ref.read(reminderSettingsProvider.notifier).resyncReminders();
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
      _withClassTitleController.clear();
      _withClassBodyController.clear();
      _noClassTitleController.clear();
      _noClassBodyController.clear();
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
                l10n.nextDayTemplateSheetTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.nextDayTemplatePlaceholderHint(
                  '{count}',
                  '{time}',
                  '{date}',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _field(
                l10n.nextDayWithClassTitleLabel,
                _withClassTitleController,
              ),
              _field(l10n.nextDayWithClassBodyLabel, _withClassBodyController),
              _field(l10n.nextDayNoClassTitleLabel, _noClassTitleController),
              _field(l10n.nextDayNoClassBodyLabel, _noClassBodyController),
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
      multiline:
          controller == _withClassBodyController ||
          controller == _noClassBodyController,
      variables:
          controller == _noClassTitleController ||
              controller == _noClassBodyController
          ? const ['date']
          : const ['count', 'time', 'date'],
    );
  }
}
