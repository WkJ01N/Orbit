import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/import/import_labels.dart';
import 'package:orbit/features/import/import_plan_editor.dart';
import 'package:orbit/features/import/import_template_editor.dart';
import 'package:orbit/features/import/import_templates_page.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/services/schedule_import_service.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});
  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _SelectedSheet {
  _SelectedSheet(this.sheet, this.bytes, this.encoding, this.candidates)
    : selected = candidates.isNotEmpty;
  final ImportSheet sheet;
  final List<int> bytes;
  final String encoding;
  List<ScheduleImportTemplate> candidates;
  bool selected;
  ScheduleImportTemplate? template;
  ScheduleParseResult? result;
}

class _ImportPageState extends ConsumerState<ImportPage> {
  bool _busy = false, _importing = false, _skip = false;
  int _generation = 0;
  String _encoding = 'auto', _delimiter = '';
  String? _error;
  final List<String> _fileErrors = [];
  List<_SelectedSheet> _sheets = [];
  ScheduleParseResult? _result;
  ImportContext _context = const ImportContext();
  ImportWorker<dynamic>? _worker;
  @override
  void dispose() {
    _generation++;
    _worker?.cancel();
    super.dispose();
  }

  void _invalidate() {
    _generation++;
    _worker?.cancel();
    setState(() {
      _result = null;
      _skip = false;
      _error = null;
      _busy = false;
      for (final s in _sheets) {
        s.result = null;
      }
    });
  }

  Future<void> _pick() async {
    if (_busy || _importing) return;
    _invalidate();
    final generation = ++_generation;
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted || generation != _generation) return;
      final config = await ref.read(importConfigurationProvider.future);
      final sheets = <_SelectedSheet>[], errors = <String>[];
      for (final file in result.files) {
        if (!mounted || generation != _generation) return;
        try {
          final bytes =
              file.bytes ??
              (file.path == null ? null : await File(file.path!).readAsBytes());
          if (bytes == null) throw const FormatException('unsupportedFile');
          final read = await ref
              .read(scheduleImportServiceProvider)
              .readFile(
                bytes,
                file.name,
                encoding: _encoding,
                delimiter: _delimiter,
                onWorker: (w) => _worker = w,
              );
          if (!mounted || generation != _generation) return;
          for (final sheet in read.sheets) {
            final worker = createCandidateWorker(sheet, config.templates);
            _worker = worker;
            final candidates = await worker.run();
            if (!mounted || generation != _generation) return;
            sheets.add(_SelectedSheet(sheet, bytes, read.encoding, candidates));
          }
        } catch (e) {
          if (!mounted || generation != _generation) return;
          errors.add(
            '${file.name}: ${importErrorMessage(importL10n(context), e)}',
          );
        }
      }
      if (mounted && generation == _generation) {
        setState(() {
          _sheets = sheets;
          _fileErrors
            ..clear()
            ..addAll(errors);
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = importErrorMessage(importL10n(context), e));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _redecode() async {
    _invalidate();
    final generation = ++_generation;
    setState(() => _busy = true);
    final copies = [..._sheets];
    try {
      final config = await ref.read(importConfigurationProvider.future);
      for (var i = 0; i < copies.length; i++) {
        final s = copies[i];
        if (!s.sheet.file.toLowerCase().endsWith('.csv')) continue;
        final read = await ref
            .read(scheduleImportServiceProvider)
            .readFile(
              s.bytes,
              s.sheet.file,
              encoding: _encoding,
              delimiter: _delimiter,
              onWorker: (w) => _worker = w,
            );
        if (!mounted || generation != _generation) return;
        final sheet = read.sheets.single;
        final worker = createCandidateWorker(sheet, config.templates);
        _worker = worker;
        final candidates = await worker.run();
        copies[i] = _SelectedSheet(sheet, s.bytes, read.encoding, candidates)
          ..selected = s.selected;
      }
      if (mounted && generation == _generation) {
        setState(() => _sheets = copies);
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = importErrorMessage(importL10n(context), e));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _parse() async {
    if (_busy || _importing) return;
    _invalidate();
    final generation = ++_generation;
    setState(() => _busy = true);
    try {
      final chosen = _sheets.where((s) => s.selected).toList();
      if (chosen.isEmpty) {
        setState(() => _error = importL10n(context).importNoSelection);
        return;
      }
      for (final s in chosen) {
        final template =
            s.template ??
            (s.candidates.length == 1 ? s.candidates.single : null);
        ScheduleParseResult parsed;
        if (template == null) {
          parsed = ScheduleParseResult(
            diagnostics: [
              ImportDiagnostic(
                code: s.candidates.length > 1 ? 'ambiguous' : 'templateInvalid',
                file: s.sheet.file,
                sheet: s.sheet.name,
                fatal: true,
              ),
            ],
          );
        } else {
          try {
            final worker = createSheetWorker(s.sheet, template, _context);
            _worker = worker;
            parsed = await worker.run();
          } catch (e) {
            if (!mounted || generation != _generation) return;
            parsed = ScheduleParseResult(
              diagnostics: [
                ImportDiagnostic(
                  code: e is FormatException ? e.message : '$e',
                  file: s.sheet.file,
                  sheet: s.sheet.name,
                  fatal: true,
                ),
              ],
            );
          }
        }
        if (!mounted || generation != _generation) return;
        setState(() => s.result = parsed);
      }
      final combined = ScheduleImportService.deduplicate(
        chosen.expand((s) => s.result!.sessions).toList(),
        locations: {for (final s in chosen) ...s.result!.locations},
      );
      if (mounted && generation == _generation) {
        setState(
          () => _result = ScheduleParseResult(
            sessions: combined.sessions,
            duplicates:
                combined.duplicates +
                chosen.fold(0, (n, s) => n + s.result!.duplicates),
            diagnostics: [
              ...chosen.expand((s) => s.result!.diagnostics),
              ...combined.diagnostics,
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = importErrorMessage(importL10n(context), e));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _edit(_SelectedSheet s, ImportConfiguration config) async {
    _invalidate();
    final t = s.template ?? s.candidates.firstOrNull ?? builtinListTemplate;
    final result = await Navigator.push<ScheduleImportTemplate>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportTemplateEditor(
          template: t,
          sheet: s.sheet,
          configuration: config,
          importContext: _context,
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(importConfigurationProvider.notifier)
          .saveChange(
            (c) => c.copy(
              templates: [
                ...c.templates.where((t) => t.id != result.id),
                result,
              ],
            ),
          );
      if (!mounted) return;
      _invalidate();
      setState(() => s.template = result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = importErrorMessage(importL10n(context), e));
      }
    }
  }

  Future<void> _confirm() async {
    final result = _result;
    if (_importing ||
        _busy ||
        result == null ||
        result.sessions.isEmpty ||
        result.hasFatal ||
        (result.diagnostics.isNotEmpty && !_skip)) {
      return;
    }
    final l = importL10n(context);
    setState(() => _importing = true);
    try {
      final repository = ref.read(scheduleRepositoryProvider);
      final overlapping = await repository.findOverlappingWeeks(
        result.sessions,
      );
      if (!mounted) return;
      var strategy = ImportMergeStrategy.mergeOverwrite;
      if (overlapping.isNotEmpty) {
        final chosen = await showDialog<ImportMergeStrategy>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.importStrategyTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.importStrategyMessage(overlapping.length)),
                ListTile(
                  title: Text(l.importStrategyReplaceWeek),
                  subtitle: Text(l.importStrategyReplaceWeekDesc),
                  onTap: () =>
                      Navigator.pop(ctx, ImportMergeStrategy.replaceWeek),
                ),
                ListTile(
                  title: Text(l.importStrategyMerge),
                  subtitle: Text(l.importStrategyMergeDesc),
                  onTap: () =>
                      Navigator.pop(ctx, ImportMergeStrategy.mergeOverwrite),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.importCancel),
              ),
            ],
          ),
        );
        if (chosen == null || !mounted) return;
        strategy = chosen;
      }
      await repository.importParsedSessionsWithStrategy(
        result.sessions,
        strategy,
      );
      final failures = await ref
          .read(reminderSettingsProvider.notifier)
          .resyncReminders();
      refreshSchedule(ref);
      if (!mounted) return;
      setState(() {
        _result = null;
        _sheets = [];
        _skip = false;
      });
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            '${l.importSuccess(result.sessions.length)}${failures > 0 ? ' ${l.resyncPartialFailed(failures)}' : ''}',
          ),
          action: SnackBarAction(
            label: l.importViewGrid,
            onPressed: () => navigateToAppTab(ref, AppTab.grid),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = l.importFailed(importErrorMessage(l, e)));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = importL10n(context);
    ref.listen(importConfigurationProvider, (previous, next) {
      if (previous?.valueOrNull == next.valueOrNull ||
          next.valueOrNull == null) {
        return;
      }
      _invalidate();
      for (final s in _sheets) {
        s.candidates = ScheduleImportService.candidates(
          s.sheet,
          next.requireValue.templates,
        );
        if (s.template?.builtIn == false) {
          s.template = next.requireValue.templates
              .where((t) => t.id == s.template!.id)
              .firstOrNull;
        }
      }
    });
    final config = ref.watch(importConfigurationProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.importTitle)),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(importErrorMessage(l, e)),
              TextButton(
                onPressed: () => ref.invalidate(importConfigurationProvider),
                child: Text(l.actionRetry),
              ),
            ],
          ),
        ),
        data: (c) => _importing
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    Text(l.importInProgress),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ExpansionTile(
                    title: Text(l.importFormatTitle),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(l.importHelp),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.upload_file),
                    label: Text(l.importPickTitle),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ImportTemplatesPage(),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.rule),
                        label: Text(l.importTemplates),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ImportPlansPage(),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.schedule),
                        label: Text(l.importPlans),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final chosen = await chooseImportContext(
                                  context,
                                  c,
                                  _context,
                                );
                                if (chosen != null && mounted) {
                                  _invalidate();
                                  setState(() => _context = chosen);
                                }
                              },
                        child: Text(l.importConfirmContext),
                      ),
                    ],
                  ),
                  if (_context.confirmed)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${_context.semester?.name ?? ''} · ${_context.periodTimes?.name ?? ''} · ${_context.defaultWeeks.join(',')}',
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _encoding,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.importEncoding),
                    items:
                        {
                              'auto': l.importAuto,
                              'utf-8': 'UTF-8',
                              'gbk': 'GBK',
                              'gb18030': 'GB18030',
                            }.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                    onChanged: _busy
                        ? null
                        : (v) {
                            _encoding = v!;
                            if (_sheets.isNotEmpty) {
                              _redecode();
                            } else {
                              setState(() {});
                            }
                          },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _delimiter,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.importDelimiter),
                    items:
                        {
                              '': l.importAuto,
                              ',': l.importComma,
                              ';': l.importSemicolon,
                              '\t': l.importTab,
                            }.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                    onChanged: _busy
                        ? null
                        : (v) {
                            _delimiter = v!;
                            if (_sheets.isNotEmpty) {
                              _redecode();
                            } else {
                              setState(() {});
                            }
                          },
                  ),
                  const SizedBox(height: 16),

                  if (_busy) ...[
                    const LinearProgressIndicator(),
                    TextButton(
                      onPressed: _invalidate,
                      child: Text(l.importCancelTask),
                    ),
                  ],
                  for (final e in _fileErrors)
                    Text(
                      e,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_sheets.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l.importSelectSheet),
                  ],
                  for (final s in _sheets) _sheetCard(s, c),
                  if (_sheets.isNotEmpty)
                    FilledButton.icon(
                      onPressed: _busy ? null : _parse,
                      icon: const Icon(Icons.preview_outlined),
                      label: Text(l.importPreview),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_result != null) ...[
                    Text(
                      '${l.importValid}: ${_result!.sessions.length} · ${l.importDuplicates}: ${_result!.duplicates} · ${l.importErrors}: ${_result!.diagnostics.length}',
                    ),
                    for (final d in _result!.diagnostics.where(
                      (d) => d.code == 'idConflict',
                    ))
                      Text(
                        '${d.location}: ${importErrorMessage(l, d.code)} · ${d.detail}',
                      ),
                    if (_result!.diagnostics.isNotEmpty && !_result!.hasFatal)
                      CheckboxListTile(
                        value: _skip,
                        title: Text(l.importSkipErrors),
                        subtitle: Text(l.importSkipDescription),
                        onChanged: (v) => setState(() => _skip = v ?? false),
                      ),
                    FilledButton.icon(
                      onPressed:
                          _busy ||
                              _result!.hasFatal ||
                              _result!.sessions.isEmpty ||
                              (_result!.diagnostics.isNotEmpty && !_skip)
                          ? null
                          : _confirm,
                      icon: const Icon(Icons.save_alt),
                      label: Text(l.importConfirm),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _sheetCard(_SelectedSheet s, ImportConfiguration config) {
    final l = importL10n(context);
    final options = <String, ScheduleImportTemplate>{
      for (final t in [
        ...builtinImportTemplates,
        ...s.candidates,
        ...config.templates,
      ])
        t.id: t,
    };
    if (s.template != null) options[s.template!.id] = s.template!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: s.selected,
              title: Text('${s.sheet.file} · ${s.sheet.name}'),
              subtitle: s.encoding.isEmpty ? null : Text(s.encoding),
              onChanged: _busy
                  ? null
                  : (v) {
                      _invalidate();
                      setState(() => s.selected = v ?? false);
                    },
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(
                '${s.sheet.file}-${s.sheet.name}-${s.template?.id}',
              ),
              initialValue: s.template?.id ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: l.importTemplates),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(
                    '${l.importAuto}${s.candidates.length == 1 ? ' · ${templateLabel(l, s.candidates.single)}' : ''}',
                  ),
                ),
                ...options.values.map(
                  (t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(
                      '${templateLabel(l, t)}${t.builtIn && t.layout == ImportLayout.list ? ' (${t.headerRow + 1})' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (id) {
                      _invalidate();
                      setState(() => s.template = options[id]);
                    },
            ),
            if (s.candidates.length != 1 && s.template == null)
              Text(
                importErrorMessage(
                  l,
                  s.candidates.length > 1 ? 'ambiguous' : 'templateInvalid',
                ),
              ),
            TextButton.icon(
              onPressed: _busy ? null : () => _edit(s, config),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.importFieldsStep),
            ),
            ImportRawTable(sheet: s.sheet),
            if (s.result != null) ...[
              Text(
                '${l.importTemplates}: ${templateLabel(l, s.template ?? s.candidates.firstOrNull ?? builtinListTemplate)}',
              ),
              ImportResultView(result: s.result!),
            ],
          ],
        ),
      ),
    );
  }
}
