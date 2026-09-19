import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/import/import_labels.dart';
import 'package:orbit/features/import/import_plan_editor.dart';
import 'package:orbit/features/import/import_template_editor.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/services/schedule_import_service.dart';

const builtinListTemplate = ScheduleImportTemplate(
  id: 'builtin-list',
  name: 'list',
  layout: ImportLayout.list,
  builtIn: true,
);
const builtinLegacyTemplate = ScheduleImportTemplate(
  id: 'builtin-legacy',
  name: 'legacy',
  layout: ImportLayout.legacy,
  builtIn: true,
  fields: {
    ImportField.classType: FieldMapping(column: 0),
    ImportField.room: FieldMapping(column: 1),
    ImportField.faculty: FieldMapping(column: 3),
    ImportField.date: FieldMapping(column: 4),
    ImportField.weekday: FieldMapping(column: 5),
    ImportField.courseName: FieldMapping(column: 6),
    ImportField.courseCode: FieldMapping(column: 7),
    ImportField.section: FieldMapping(column: 8),
    ImportField.startTime: FieldMapping(column: 9),
    ImportField.endTime: FieldMapping(column: 10),
    ImportField.teachers: FieldMapping(column: 11),
    ImportField.semester: FieldMapping(column: 12),
  },
);
const builtinImportTemplates = [
  builtinLegacyTemplate,
  builtinListTemplate,
  ScheduleImportService.basicGrid,
];

class ImportTemplatesPage extends ConsumerStatefulWidget {
  const ImportTemplatesPage({super.key});
  @override
  ConsumerState<ImportTemplatesPage> createState() =>
      _ImportTemplatesPageState();
}

class _ImportTemplatesPageState extends ConsumerState<ImportTemplatesPage> {
  bool _busy = false;
  Future<void> _edit(
    ImportConfiguration config, [
    ScheduleImportTemplate? t,
  ]) async {
    final result = await Navigator.push<ScheduleImportTemplate>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImportTemplateEditor(template: t, configuration: config),
      ),
    );
    if (result == null || !mounted) return;
    await saveImportChange(
      context,
      ref,
      (c) => c.copy(
        templates: [...c.templates.where((v) => v.id != result.id), result],
      ),
    );
  }

  Future<void> _fileAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(importErrorMessage(importL10n(context), e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw const FormatException('templateInvalid');
    final template = decodeTemplate(utf8.decode(bytes));
    if (!mounted) return;
    final l = importL10n(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.importLoadTemplate),
        content: Text(
          '${template.name}\n${template.layout == ImportLayout.grid ? l.importGridLayout : l.importListLayout}\n${template.fields.keys.map((f) => importFieldLabel(l, f)).join(', ')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.importCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.importLoadTemplate),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final copy = template.copy(id: newImportId());
    await ref
        .read(importConfigurationProvider.notifier)
        .saveChange((c) => c.copy(templates: [...c.templates, copy]));
  }

  Future<void> _export(ScheduleImportTemplate t) async {
    final bytes = utf8.encode(encodeTemplate(t));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: importL10n(context).importShareTemplate,
      fileName: 'orbit-import-template.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (path != null && !Platform.isAndroid) {
      await File(path).writeAsBytes(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = importL10n(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.importTemplates)),
      body: ref
          .watch(importConfigurationProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(importErrorMessage(l, e))),
            data: (config) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _edit(config),
                      icon: const Icon(Icons.add),
                      label: Text(l.importTemplateName),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _fileAction(_load),
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(l.importLoadTemplate),
                    ),
                  ],
                ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 16),
                for (final t in builtinImportTemplates)
                  ListTile(
                    title: Text(templateLabel(l, t)),
                    subtitle: Text(l.importBuiltIn),
                    trailing: IconButton(
                      tooltip: l.importCopy,
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () => _edit(config, t),
                    ),
                  ),
                const Divider(),
                for (final t in config.templates)
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(t.name),
                          subtitle: Text(
                            t.layout == ImportLayout.grid
                                ? l.importGridLayout
                                : l.importListLayout,
                          ),
                          value: t.enabled,
                          onChanged: _busy
                              ? null
                              : (v) => saveImportChange(
                                  context,
                                  ref,
                                  (c) => c.copy(
                                    templates: c.templates
                                        .map(
                                          (p) => p.id == t.id
                                              ? p.copy(enabled: v)
                                              : p,
                                        )
                                        .toList(),
                                  ),
                                ),
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: () => _edit(config, t),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(l.importFieldsStep),
                            ),
                            TextButton.icon(
                              onPressed: () => _edit(
                                config,
                                t.copy(
                                  id: newImportId(),
                                  name: '${t.name} (${l.importCopy})',
                                ),
                              ),
                              icon: const Icon(Icons.copy),
                              label: Text(l.importCopy),
                            ),
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _fileAction(() => _export(t)),
                              icon: const Icon(Icons.ios_share),
                              label: Text(l.importShareTemplate),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                if (await confirmImportDelete(context) &&
                                    mounted) {
                                  if (!context.mounted) return;
                                  await saveImportChange(
                                    context,
                                    ref,
                                    (c) => c.copy(
                                      templates: c.templates
                                          .where((p) => p.id != t.id)
                                          .toList(),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: Text(l.actionDelete),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
