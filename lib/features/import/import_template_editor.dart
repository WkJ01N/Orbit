import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbit/features/import/import_labels.dart';
import 'package:orbit/features/import/import_plan_editor.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/services/schedule_import_service.dart';

class ImportTemplateEditor extends StatefulWidget {
  const ImportTemplateEditor({
    super.key,
    this.template,
    this.sheet,
    this.importContext = const ImportContext(),
    this.configuration = const ImportConfiguration(),
  });
  final ScheduleImportTemplate? template;
  final ImportSheet? sheet;
  final ImportContext importContext;
  final ImportConfiguration configuration;
  @override
  State<ImportTemplateEditor> createState() => _ImportTemplateEditorState();
}

class _ImportTemplateEditorState extends State<ImportTemplateEditor> {
  late ImportLayout _layout;
  final _name = TextEditingController(),
      _header = TextEditingController(),
      _first = TextEditingController(),
      _last = TextEditingController();
  final _left = TextEditingController(),
      _right = TextEditingController(),
      _days = TextEditingController(),
      _periods = TextEditingController(),
      _sample = TextEditingController();
  late Map<ImportField, FieldMapping> _fields;
  late Map<ImportField, VisualExtractionHint> _hints;
  late ImportContext _context;
  RegexRule _block = const RegexRule();
  bool _repeat = false, _busy = false;
  int _step = 0, _generation = 0;
  _CellTool _cellTool = _CellTool.headerRow;
  ImportField _selectedField = ImportField.courseName;
  String _blockMode = 'single';
  String? _error;
  ScheduleParseResult? _preview;
  RegexTestResult? _regexResult;
  ImportField? _testField;
  ImportWorker<dynamic>? _worker;
  Timer? _previewDebounce;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _layout = t?.layout == ImportLayout.grid
        ? ImportLayout.grid
        : ImportLayout.list;
    _name.text = t?.builtIn == false ? t!.name : '';
    _header.text = '${(t?.headerRow ?? 0) + 1}';
    _first.text = '${(t?.firstRow ?? 1) + 1}';
    _last.text = t?.lastRow == null ? '' : '${t!.lastRow! + 1}';
    _left.text = '${(t?.firstColumn ?? 1) + 1}';
    _right.text = '${(t?.lastColumn ?? 7) + 1}';
    _days.text =
        t?.weekdayColumns.entries
            .map((e) => '${e.key + 1}:${e.value}')
            .join(',') ??
        '2:1,3:2,4:3,5:4,6:5,7:6,8:7';
    _periods.text =
        t?.periodRows.entries
            .map((e) => '${e.key + 1}:${e.value.join(',')}')
            .join(';') ??
        '2:1-2;3:3-4';
    _fields = Map.of(t?.fields ?? {});
    _hints = Map.of(t?.editorHints.fields ?? {});
    _block = t?.blockRule ?? const RegexRule();
    _repeat = t?.repeatBlocks ?? false;
    _blockMode =
        t?.editorHints.blockMode ??
        (_block.pattern.isEmpty
            ? 'single'
            : _block.pattern == r'\r?\n\s*\r?\n' && !_repeat
            ? 'blankLines'
            : 'regex');
    _context = widget.importContext;
    if (widget.sheet != null && _fields.isEmpty) {
      try {
        _fields = ScheduleImportService.headerFields(widget.sheet!, 0);
      } catch (_) {
        /* Configure manually. */
      }
    }
    _sample.text = _layout == ImportLayout.grid
        ? '课程：高等数学\n教师：张老师\n教室：A101\n周次：1-18'
        : '课程名称,日期,开始时间,结束时间\n高等数学,2026-09-14,08:00,09:35';
    for (final c in [
      _name,
      _header,
      _first,
      _last,
      _left,
      _right,
      _days,
      _periods,
      _sample,
    ]) {
      c.addListener(_invalidate);
    }
  }

  void _invalidate() {
    if (!mounted) return;
    _generation++;
    _worker?.cancel();
    _previewDebounce?.cancel();
    setState(() {
      _preview = null;
      _regexResult = null;
      _error = null;
      _busy = false;
    });
    if (_step == 2 && widget.sheet != null) {
      _previewDebounce = Timer(const Duration(milliseconds: 350), _test);
    }
  }

  @override
  void dispose() {
    _generation++;
    _worker?.cancel();
    _previewDebounce?.cancel();
    for (final c in [
      _name,
      _header,
      _first,
      _last,
      _left,
      _right,
      _days,
      _periods,
      _sample,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _number(TextEditingController c) => (int.tryParse(c.text) ?? 0) - 1;
  ScheduleImportTemplate _template() {
    final days = <int, int>{};
    final periods = <int, List<int>>{};
    if (_layout == ImportLayout.grid) {
      for (final piece in _days.text.split(',')) {
        final parts = piece.trim().split(':');
        if (parts.length != 2) throw const FormatException('templateInvalid');
        days[(int.tryParse(parts[0]) ?? 0) - 1] = int.tryParse(parts[1]) ?? 0;
      }
      for (final piece in _periods.text.split(';')) {
        final parts = piece.trim().split(':');
        if (parts.length != 2) throw const FormatException('templateInvalid');
        periods[(int.tryParse(parts[0]) ?? 0) - 1] = parseNumbers(
          parts[1],
          'periodInvalid',
        );
      }
    }
    final t = ScheduleImportTemplate(
      id: widget.template?.builtIn == false
          ? widget.template!.id
          : newImportId(),
      name: _name.text.trim().isEmpty ? 'preview' : _name.text.trim(),
      layout: _layout,
      enabled: widget.template?.enabled ?? true,
      headerRow: _number(_header),
      firstRow: _number(_first),
      lastRow: _last.text.trim().isEmpty ? null : _number(_last),
      firstColumn: _number(_left),
      lastColumn: _number(_right),
      weekdayColumns: days,
      periodRows: periods,
      fields: Map.of(_fields),
      blockRule: _block,
      repeatBlocks: _repeat,
      editorHints: TemplateEditorHints(
        fields: Map.of(_hints),
        blockMode: _blockMode,
      ),
    );
    t.validate();
    return t;
  }

  Future<void> _editField(ImportField field) async {
    final result = await showDialog<_FieldEditResult>(
      context: context,
      builder: (_) => _FieldMappingDialog(
        field: field,
        mapping:
            _fields[field] ??
            FieldMapping(
              source: _layout == ImportLayout.grid
                  ? FieldSource.text
                  : FieldSource.column,
            ),
        hint:
            _hints[field] ??
            VisualExtractionHint(
              kind: (_fields[field]?.regex.pattern.isNotEmpty ?? false)
                  ? VisualExtractionKind.regex
                  : VisualExtractionKind.identity,
            ),
      ),
    );
    if (result == null || !mounted) return;
    _invalidate();
    setState(() {
      _fields[field] = result.mapping;
      _hints[field] = result.hint;
    });
  }

  Future<void> _test() async {
    _worker?.cancel();
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
      _regexResult = null;
    });
    try {
      final t = _template();
      final rule = _testField == null
          ? _block
          : _fields[_testField]?.regex ?? const RegexRule();
      final text = _sample.text;
      if (rule.pattern.isNotEmpty) {
        final worker = createRegexWorker(
          rule,
          text,
          repeat: _testField == null && _repeat,
        );
        _worker = worker;
        final result = await worker.run();
        if (!mounted || generation != _generation) return;
        setState(() => _regexResult = result);
      }
      ImportSheet sheet;
      if (widget.sheet != null) {
        sheet = widget.sheet!;
      } else if (_layout == ImportLayout.list) {
        sheet = ScheduleImportService.readCsv(text, 'sample.csv').single;
      } else {
        final width = t.lastColumn + 1;
        if (width > 1000 || t.firstRow > 1000) {
          throw const FormatException('templateInvalid');
        }
        final rows = List.generate(
          t.firstRow + 1,
          (_) => List.filled(width, ''),
        );
        rows[t.firstRow][t.firstColumn] = text;
        sheet = ImportSheet(file: '', name: '', rows: rows);
      }
      final worker = createSheetWorker(sheet, t, _context);
      _worker = worker;
      final result = await worker.run();
      if (!mounted || generation != _generation) return;
      setState(() => _preview = result);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = importErrorMessage(importL10n(context), e));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  void _save() {
    try {
      if (_name.text.trim().isEmpty) {
        throw const FormatException('templateInvalid');
      }
      if (_fields.isEmpty || !_fields.containsKey(ImportField.courseName)) {
        throw const FormatException('missingName');
      }
      final hasDate = _fields.containsKey(ImportField.date);
      final hasWeekday = _fields.containsKey(ImportField.weekday);
      final hasPeriods = _fields.containsKey(ImportField.periods);
      final hasTimes =
          _fields.containsKey(ImportField.startTime) &&
          _fields.containsKey(ImportField.endTime);
      if ((!hasDate && !hasWeekday) || (!hasPeriods && !hasTimes)) {
        throw const FormatException('templateInvalid');
      }
      Navigator.pop(context, _template());
    } catch (e) {
      setState(() => _error = importErrorMessage(importL10n(context), e));
    }
  }

  Widget _input(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _workspace({
    required List<Widget> inspector,
    required void Function(int row, int column) onCell,
  }) {
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: inspector,
    );
    final sheet = widget.sheet;
    if (sheet == null) return controls;
    final table = ImportRawTable(
      sheet: sheet,
      onCell: onCell,
      cellColor: _cellColor,
      expanded: true,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: table),
              const SizedBox(width: 16),
              SizedBox(width: 380, child: controls),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [table, const SizedBox(height: 12), controls],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = importL10n(context);
    final titles = [l.importLayoutStep, l.importFieldsStep, l.importTestStep];
    return Scaffold(
      appBar: AppBar(title: Text(l.importTemplates)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${_step + 1}/3 · ${titles[_step]}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (_step == 0) ...[
                      _input(_name, l.importTemplateName),
                      DropdownButtonFormField<ImportLayout>(
                        initialValue: _layout,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: ImportLayout.list,
                            child: Text(l.importListLayout),
                          ),
                          DropdownMenuItem(
                            value: ImportLayout.grid,
                            child: Text(l.importGridLayout),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          _invalidate();
                          setState(() {
                            _layout = v;
                            _testField = null;
                            _fields = Map.of(
                              v == ImportLayout.grid
                                  ? ScheduleImportService.basicGrid.fields
                                  : <ImportField, FieldMapping>{},
                            );
                            _hints = Map.of(
                              v == ImportLayout.grid
                                  ? ScheduleImportService
                                        .basicGrid
                                        .editorHints
                                        .fields
                                  : <ImportField, VisualExtractionHint>{},
                            );
                            _block = v == ImportLayout.grid
                                ? ScheduleImportService.basicGrid.blockRule
                                : const RegexRule();
                            _blockMode = v == ImportLayout.grid
                                ? 'blankLines'
                                : 'single';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _workspace(
                        onCell: _markCell,
                        inspector: [
                          Text(l.importTapCellHint),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _toolChip(_CellTool.headerRow, l.importHeaderRow),
                              _toolChip(_CellTool.firstRow, l.importFirstRow),
                              _toolChip(_CellTool.lastRow, l.importLastRow),
                              if (_layout == ImportLayout.grid) ...[
                                _toolChip(
                                  _CellTool.firstColumn,
                                  l.importFirstColumn,
                                ),
                                _toolChip(
                                  _CellTool.lastColumn,
                                  l.importLastColumn,
                                ),
                                _toolChip(
                                  _CellTool.weekday,
                                  l.importWeekdaySource,
                                ),
                                _toolChip(
                                  _CellTool.period,
                                  l.importPeriodsSource,
                                ),
                              ],
                            ],
                          ),
                          ExpansionTile(
                            title: Text(l.importAdvanced),
                            children: [
                              _input(_header, l.importHeaderRow),
                              _input(_first, l.importFirstRow),
                              _input(_last, l.importLastRow),
                              if (_layout == ImportLayout.grid) ...[
                                _input(_left, l.importFirstColumn),
                                _input(_right, l.importLastColumn),
                                _input(_days, l.importWeekdayColumns),
                                _input(_periods, l.importPeriodRows),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                    if (_step == 1) ...[
                      Text(l.importHelp),
                      const SizedBox(height: 8),
                      _workspace(
                        onCell: _mapSelectedField,
                        inspector: [
                          Text(l.importTapColumnHint),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final field in ImportField.values)
                                ChoiceChip(
                                  label: Text(importFieldLabel(l, field)),
                                  selected: _selectedField == field,
                                  onSelected: (_) =>
                                      setState(() => _selectedField = field),
                                ),
                            ],
                          ),
                          for (final field in ImportField.values)
                            ListTile(
                              selected: _selectedField == field,
                              title: Text(importFieldLabel(l, field)),
                              subtitle: _fields[field] == null
                                  ? Text(l.importNone)
                                  : Text(_mappingLabel(_fields[field]!)),
                              onTap: () => _editField(field),
                              trailing: _fields[field] == null
                                  ? const Icon(Icons.add)
                                  : IconButton(
                                      tooltip: l.actionDelete,
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      onPressed: () {
                                        _invalidate();
                                        setState(() {
                                          _fields.remove(field);
                                          _hints.remove(field);
                                          if (_testField == field) {
                                            _testField = null;
                                          }
                                        });
                                      },
                                    ),
                            ),
                          const Divider(),
                          DropdownButtonFormField<String>(
                            initialValue: _blockMode,
                            decoration: InputDecoration(
                              labelText: l.importBlockPattern,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'single',
                                child: Text(l.importBlockModeSingle),
                              ),
                              DropdownMenuItem(
                                value: 'blankLines',
                                child: Text(l.importBlockModeBlankLines),
                              ),
                              DropdownMenuItem(
                                value: 'regex',
                                child: Text(l.importBlockModeRegex),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              _invalidate();
                              setState(() {
                                _blockMode = value;
                                if (value == 'single') {
                                  _block = const RegexRule();
                                  _repeat = false;
                                } else if (value == 'blankLines') {
                                  _block = const RegexRule(
                                    pattern: r'\r?\n\s*\r?\n',
                                  );
                                  _repeat = false;
                                }
                              });
                            },
                          ),
                          if (_blockMode == 'regex') ...[
                            RegexRuleEditor(
                              initial: _block,
                              onChanged: (rule) {
                                _invalidate();
                                setState(() => _block = rule);
                              },
                            ),
                            SwitchListTile(
                              title: Text(l.importRepeatBlocks),
                              value: _repeat,
                              onChanged: (v) {
                                _invalidate();
                                setState(() => _repeat = v);
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (_step == 2) ...[
                      TextField(
                        controller: _sample,
                        minLines: 4,
                        maxLines: 10,
                        decoration: InputDecoration(
                          labelText: l.importTestText,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ImportField>(
                        initialValue: _testField,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l.importPattern),
                        items: [
                          DropdownMenuItem<ImportField>(
                            value: null,
                            child: Text(l.importBlockPattern),
                          ),
                          ..._fields.keys.map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(importFieldLabel(l, f)),
                            ),
                          ),
                        ],
                        onChanged: (f) {
                          _invalidate();
                          setState(() => _testField = f);
                        },
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final chosen = await chooseImportContext(
                            context,
                            widget.configuration,
                            _context,
                          );
                          if (chosen != null && mounted) {
                            _invalidate();
                            setState(() => _context = chosen);
                          }
                        },
                        child: Text(l.importPlans),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _test,
                        icon: const Icon(Icons.science_outlined),
                        label: Text(l.importRunTest),
                      ),
                      if (_busy) ...[
                        const LinearProgressIndicator(),
                        TextButton(
                          onPressed: _invalidate,
                          child: Text(l.importCancelTask),
                        ),
                      ],
                      if (_regexResult != null) ...[
                        Text(l.importMatches),
                        SelectableText(_regexResult!.groups.join('\n')),
                        SelectableText(_regexResult!.captures.join('\n')),
                      ],
                      if (_preview != null)
                        ImportResultView(result: _preview!, showTraces: true),
                    ],
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_step > 0)
                        TextButton(
                          onPressed: () => setState(() => _step--),
                          child: Text(l.importBack),
                        ),
                      const Spacer(),
                      if (_step < 2)
                        FilledButton(
                          onPressed: () {
                            setState(() => _step++);
                            if (_step == 2) {
                              _previewDebounce?.cancel();
                              _previewDebounce = Timer(
                                const Duration(milliseconds: 100),
                                _test,
                              );
                            }
                          },
                          child: Text(l.importNext),
                        )
                      else
                        FilledButton(
                          onPressed: _busy ? null : _save,
                          child: Text(l.importSave),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _mappingLabel(FieldMapping m) {
    final l = importL10n(context);
    return switch (m.source) {
      FieldSource.column => '${l.importColumnSource} ${columnLabel(m.column)}',
      FieldSource.text => l.importTextSource,
      FieldSource.fixed => m.value,
      FieldSource.weekday => l.importWeekdaySource,
      FieldSource.periods => l.importPeriodsSource,
    };
  }

  Widget _toolChip(_CellTool tool, String label) => ChoiceChip(
    label: Text(label),
    selected: _cellTool == tool,
    onSelected: (_) => setState(() => _cellTool = tool),
  );

  Future<void> _markCell(int r, int c) async {
    try {
      switch (_cellTool) {
        case _CellTool.headerRow:
          _header.text = '${r + 1}';
          return;
        case _CellTool.firstRow:
          _first.text = '${r + 1}';
          return;
        case _CellTool.lastRow:
          _last.text = '${r + 1}';
          return;
        case _CellTool.firstColumn:
          _left.text = '${c + 1}';
          return;
        case _CellTool.lastColumn:
          _right.text = '${c + 1}';
          return;
        case _CellTool.weekday:
          int? day;
          try {
            day = parseWeekday(widget.sheet!.cell(r, c));
          } on FormatException {
            if (!mounted) return;
            final names = importL10n(context).reminderFilterWeekdays.split('|');
            day = await showDialog<int>(
              context: context,
              builder: (dialogContext) => SimpleDialog(
                title: Text(importL10n(context).importWeekdaySource),
                children: [
                  for (var index = 0; index < names.length; index++)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialogContext, index + 1),
                      child: Text(names[index]),
                    ),
                ],
              ),
            );
            if (day == null || !mounted) return;
          }
          final values = <int, int>{};
          for (final piece in _days.text.split(',')) {
            final parts = piece.trim().split(':');
            if (parts.length == 2) {
              values[(int.tryParse(parts[0]) ?? 0) - 1] =
                  int.tryParse(parts[1]) ?? 0;
            }
          }
          values[c] = day;
          _days.text = values.entries
              .map((entry) => '${entry.key + 1}:${entry.value}')
              .join(',');
          _header.text = '${r + 1}';
          return;
        case _CellTool.period:
          final periods = parseNumbers(
            widget.sheet!.cell(r, c),
            'periodInvalid',
          );
          final values = <int, String>{};
          for (final piece in _periods.text.split(';')) {
            final parts = piece.trim().split(':');
            if (parts.length == 2) {
              values[(int.tryParse(parts[0]) ?? 0) - 1] = parts[1];
            }
          }
          values[r] = periods.join(',');
          _periods.text = values.entries
              .map((entry) => '${entry.key + 1}:${entry.value}')
              .join(';');
          return;
      }
    } catch (error) {
      setState(() => _error = importErrorMessage(importL10n(context), error));
    }
  }

  void _mapSelectedField(int row, int column) {
    _invalidate();
    setState(() {
      final source = _layout == ImportLayout.list
          ? FieldSource.column
          : _selectedField == ImportField.weekday
          ? FieldSource.weekday
          : _selectedField == ImportField.periods
          ? FieldSource.periods
          : FieldSource.text;
      _fields[_selectedField] = FieldMapping(source: source, column: column);
      _hints[_selectedField] = const VisualExtractionHint();
      final text = widget.sheet!.cell(row, column);
      if (text.trim().isNotEmpty) _sample.text = text;
    });
  }

  Color? _cellColor(BuildContext context, int row, int column) {
    final scheme = Theme.of(context).colorScheme;
    final header = _number(_header);
    final first = _number(_first);
    final last = _last.text.trim().isEmpty
        ? (widget.sheet?.rows.length ?? 1) - 1
        : _number(_last);
    final left = _number(_left), right = _number(_right);
    if (row == header) return scheme.primaryContainer;
    if (_layout == ImportLayout.grid &&
        _days.text
            .split(',')
            .any(
              (piece) =>
                  int.tryParse(piece.split(':').first.trim()) == column + 1,
            )) {
      return scheme.tertiaryContainer;
    }
    if (_layout == ImportLayout.grid &&
        _periods.text
            .split(';')
            .any(
              (piece) => int.tryParse(piece.split(':').first.trim()) == row + 1,
            )) {
      return scheme.secondaryContainer;
    }
    final inRows = row >= first && row <= last;
    final inColumns =
        _layout == ImportLayout.list || (column >= left && column <= right);
    if (inRows && inColumns) {
      return scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    }
    if (_layout == ImportLayout.list &&
        _fields.values.any(
          (mapping) =>
              mapping.source == FieldSource.column && mapping.column == column,
        )) {
      return scheme.secondaryContainer.withValues(alpha: 0.6);
    }
    return null;
  }
}

enum _CellTool {
  headerRow,
  firstRow,
  lastRow,
  firstColumn,
  lastColumn,
  weekday,
  period,
}

class _FieldMappingDialog extends StatefulWidget {
  const _FieldMappingDialog({
    required this.field,
    required this.mapping,
    required this.hint,
  });
  final ImportField field;
  final FieldMapping mapping;
  final VisualExtractionHint hint;
  @override
  State<_FieldMappingDialog> createState() => _FieldMappingDialogState();
}

class _FieldMappingDialogState extends State<_FieldMappingDialog> {
  late FieldSource _source;
  late RegexRule _regex;
  late VisualExtractionKind _kind;
  late TextEditingController _column, _value, _label, _line, _delimiter;
  @override
  void initState() {
    super.initState();
    _source = widget.mapping.source;
    _regex = widget.mapping.regex;
    _kind = widget.hint.kind;
    _column = TextEditingController(text: '${widget.mapping.column + 1}');
    _value = TextEditingController(text: widget.mapping.value);
    _label = TextEditingController(text: widget.hint.label);
    _line = TextEditingController(text: '${widget.hint.line}');
    _delimiter = TextEditingController(text: widget.hint.delimiter);
  }

  @override
  void dispose() {
    _column.dispose();
    _value.dispose();
    _label.dispose();
    _line.dispose();
    _delimiter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = importL10n(context);
    final sources = {
      FieldSource.column: l.importColumnSource,
      FieldSource.text: l.importTextSource,
      FieldSource.fixed: l.importFixedSource,
      FieldSource.weekday: l.importWeekdaySource,
      FieldSource.periods: l.importPeriodsSource,
    };
    final extractionKinds = {
      VisualExtractionKind.identity: l.importExtractIdentity,
      VisualExtractionKind.firstNonEmptyLine: l.importExtractFirstLine,
      VisualExtractionKind.line: l.importExtractLine,
      VisualExtractionKind.afterLabel: l.importExtractAfterLabel,
      VisualExtractionKind.beforeDelimiter: l.importExtractBeforeDelimiter,
      VisualExtractionKind.afterDelimiter: l.importExtractAfterDelimiter,
      VisualExtractionKind.regex: l.importAdvanced,
    };
    return AlertDialog(
      title: Text(importFieldLabel(l, widget.field)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<FieldSource>(
                initialValue: _source,
                isExpanded: true,
                items: sources.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _source = v!),
              ),
              if (_source == FieldSource.column)
                TextField(
                  controller: _column,
                  decoration: InputDecoration(labelText: l.importColumnNumber),
                ),
              if (_source == FieldSource.fixed)
                TextField(
                  controller: _value,
                  decoration: InputDecoration(labelText: l.importFixedValue),
                ),
              if (_source == FieldSource.column || _source == FieldSource.text)
                DropdownButtonFormField<VisualExtractionKind>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.importVisualExtraction,
                  ),
                  items: extractionKinds.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _kind = value!),
                ),
              if (_kind == VisualExtractionKind.line)
                TextField(
                  controller: _line,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.importExtractLine),
                ),
              if (_kind == VisualExtractionKind.afterLabel)
                TextField(
                  controller: _label,
                  decoration: InputDecoration(
                    labelText: l.importExtractLabel,
                    helperText: l.importExtractLabelHelp,
                  ),
                ),
              if (_kind == VisualExtractionKind.beforeDelimiter ||
                  _kind == VisualExtractionKind.afterDelimiter)
                TextField(
                  controller: _delimiter,
                  decoration: InputDecoration(
                    labelText: l.importExtractDelimiter,
                  ),
                ),
              if (_kind == VisualExtractionKind.regex)
                RegexRuleEditor(
                  key: const ValueKey('advanced-regex'),
                  initial: _regex,
                  onChanged: (rule) => _regex = rule,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.importCancel),
        ),
        FilledButton(
          onPressed: () {
            final column = int.tryParse(_column.text);
            if (_source == FieldSource.column &&
                (column == null || column < 1)) {
              return;
            }
            try {
              final effectiveKind =
                  _source == FieldSource.column || _source == FieldSource.text
                  ? _kind
                  : VisualExtractionKind.identity;
              final hint = VisualExtractionHint(
                kind: effectiveKind,
                label: _label.text,
                line: int.tryParse(_line.text) ?? 1,
                delimiter: _delimiter.text,
              );
              final rule = buildVisualExtractionRule(hint, advanced: _regex);
              Navigator.pop(
                context,
                _FieldEditResult(
                  FieldMapping(
                    source: _source,
                    column: (column ?? 1) - 1,
                    value: _value.text,
                    regex:
                        _source == FieldSource.column ||
                            _source == FieldSource.text
                        ? rule
                        : const RegexRule(),
                  ),
                  hint,
                ),
              );
            } on FormatException {
              return;
            }
          },
          child: Text(l.importSave),
        ),
      ],
    );
  }
}

class _FieldEditResult {
  const _FieldEditResult(this.mapping, this.hint);
  final FieldMapping mapping;
  final VisualExtractionHint hint;
}

class RegexRuleEditor extends StatefulWidget {
  const RegexRuleEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final RegexRule initial;
  final ValueChanged<RegexRule> onChanged;
  @override
  State<RegexRuleEditor> createState() => _RegexRuleEditorState();
}

class _RegexRuleEditorState extends State<RegexRuleEditor> {
  late TextEditingController _pattern, _group;
  late bool _case, _multi, _dot, _unicode;
  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _pattern = TextEditingController(text: r.pattern);
    _group = TextEditingController(text: r.group);
    _case = r.caseSensitive;
    _multi = r.multiLine;
    _dot = r.dotAll;
    _unicode = r.unicode;
  }

  @override
  void dispose() {
    _pattern.dispose();
    _group.dispose();
    super.dispose();
  }

  void _change() => widget.onChanged(
    RegexRule(
      pattern: _pattern.text,
      group: _group.text,
      caseSensitive: _case,
      multiLine: _multi,
      dotAll: _dot,
      unicode: _unicode,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final l = importL10n(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          TextField(
            controller: _pattern,
            minLines: 1,
            maxLines: 4,
            onChanged: (_) => _change(),
            decoration: InputDecoration(labelText: l.importPattern),
          ),
          TextField(
            controller: _group,
            onChanged: (_) => _change(),
            decoration: InputDecoration(labelText: l.importCaptureGroup),
          ),
          Wrap(
            children: [
              FilterChip(
                label: Text(l.importCaseSensitive),
                selected: _case,
                onSelected: (v) {
                  setState(() => _case = v);
                  _change();
                },
              ),
              FilterChip(
                label: Text(l.importMultiLine),
                selected: _multi,
                onSelected: (v) {
                  setState(() => _multi = v);
                  _change();
                },
              ),
              FilterChip(
                label: Text(l.importDotAll),
                selected: _dot,
                onSelected: (v) {
                  setState(() => _dot = v);
                  _change();
                },
              ),
              FilterChip(
                label: Text(l.importUnicode),
                selected: _unicode,
                onSelected: (v) {
                  setState(() => _unicode = v);
                  _change();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ImportRawTable extends StatelessWidget {
  const ImportRawTable({
    super.key,
    required this.sheet,
    this.onCell,
    this.cellColor,
    this.expanded = false,
  });
  final ImportSheet sheet;
  final void Function(int row, int column)? onCell;
  final Color? Function(BuildContext context, int row, int column)? cellColor;
  final bool expanded;

  MergedRegion? _mergeAt(int row, int column) {
    for (final merge in sheet.merges) {
      if (merge.contains(row, column)) return merge;
    }
    return null;
  }

  String _cellLabel(int row, int column) {
    final merge = _mergeAt(row, column);
    if (merge != null &&
        (merge.firstRow != row || merge.firstColumn != column)) {
      return '${columnLabel(column)}: ↳';
    }
    final span = merge == null
        ? ''
        : ' · ${merge.lastRow - merge.firstRow + 1}×${merge.lastColumn - merge.firstColumn + 1}';
    return '${columnLabel(column)}: ${sheet.cell(row, column)}$span';
  }

  @override
  Widget build(BuildContext context) {
    final l = importL10n(context);
    final table = SizedBox(
      height: 300,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: sheet.columnCount.clamp(1, 100) * 140.0 + 45,
          child: ListView.builder(
            itemCount: sheet.rows.length,
            itemBuilder: (context, r) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 45, child: Text('${r + 1}')),
                for (var c = 0; c < sheet.columnCount.clamp(1, 100); c++)
                  SizedBox(
                    width: 140,
                    child: InkWell(
                      onTap: onCell == null ? null : () => onCell!(r, c),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cellColor?.call(context, r, c),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(
                          _cellLabel(r, c),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (expanded) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l.importRawTable),
            ),
            table,
          ],
        ),
      );
    }
    return ExpansionTile(title: Text(l.importRawTable), children: [table]);
  }
}

class ImportResultView extends StatelessWidget {
  const ImportResultView({
    super.key,
    required this.result,
    this.showTraces = false,
  });
  final ScheduleParseResult result;
  final bool showTraces;
  @override
  Widget build(BuildContext context) {
    final l = importL10n(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '${l.importValid}: ${result.sessions.length} · ${l.importDuplicates}: ${result.duplicates} · ${l.importErrors}: ${result.diagnostics.length}',
          ),
        ),
        for (final d in result.diagnostics)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText(
              '${d.location}\n${importErrorMessage(l, d.code)}${d.detail.isEmpty ? '' : ' · ${d.detail}'}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (showTraces)
          for (final t in result.traces.take(10))
            ExpansionTile(
              title: Text(
                '${columnLabel(t.column)}${t.row + 1} · ${l.importExtracted}',
              ),
              children: [
                ListTile(
                  title: Text(l.importOriginal),
                  subtitle: SelectableText(t.text),
                ),
                ListTile(
                  title: Text(l.importMatches),
                  subtitle: SelectableText(
                    t.captures.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                  ),
                ),
                ListTile(
                  title: Text(l.importExtracted),
                  subtitle: SelectableText(
                    t.values.entries
                        .map(
                          (e) =>
                              '${importFieldLabel(l, ImportField.values.byName(e.key))}: ${e.value}',
                        )
                        .join('\n'),
                  ),
                ),
              ],
            ),
        if (result.sessions.isNotEmpty)
          ExpansionTile(
            title: Text(
              '${result.sessions.first.date.toIso8601String().split('T').first} – ${result.sessions.last.date.toIso8601String().split('T').first}',
            ),
            children: [
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: result.sessions.length,
                  itemBuilder: (context, i) {
                    final s = result.sessions[i];
                    return ListTile(
                      title: Text(s.courseName),
                      subtitle: Text(
                        '${s.date.toIso8601String().split('T').first} ${minuteLabel(s.startAt.hour * 60 + s.startAt.minute)}–${minuteLabel(s.endAt.hour * 60 + s.endAt.minute)}\n${s.room} · ${s.teachers.join(', ')}',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }
}
