import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';
import 'package:orbit/core/routing/app_tab.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/xlsx_parser.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  bool _isPicking = false;
  bool _isImporting = false;
  List<_PreviewFile>? _previewFiles;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isImporting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.importInProgress),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PickCard(
            onPick: _pickFiles,
            isPicking: _isPicking,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _errorMessage!),
          ],
          if (_previewFiles != null) ...[
            const SizedBox(height: 16),
            for (final file in _previewFiles!) _FilePreviewCard(file: file),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _confirmImport,
              icon: const Icon(Icons.save_alt),
              label: Text(AppLocalizations.of(context)!.importConfirm),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _previewFiles = null),
              child: Text(AppLocalizations.of(context)!.importCancel),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isPicking = true;
      _errorMessage = null;
      _previewFiles = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final parser = ref.read(xlsxParserProvider);
      final previews = <_PreviewFile>[];
      final errors = <String>[];

      final parseResults = await Future.wait(
        result.files.map((file) async {
          try {
            final bytes = file.bytes ??
                (file.path != null
                    ? await File(file.path!).readAsBytes()
                    : null);
            if (bytes == null) {
              return (error: l10n.importPickMissingPath(file.name), preview: null);
            }
            final sessions = parser.parseBytes(
              bytes,
              sourceFile: file.name,
            );
            return (
              error: null as String?,
              preview: _PreviewFile(
                name: file.name,
                sessions: sessions,
              ),
            );
          } on XlsxParseException catch (e) {
            return (error: '${file.name}: ${e.message}', preview: null);
          } catch (e) {
            return (
              error: '${file.name}: ${l10n.importParseFailed('$e')}',
              preview: null,
            );
          }
        }),
      );

      for (final item in parseResults) {
        if (item.error != null) {
          errors.add(item.error!);
        } else if (item.preview != null) {
          previews.add(item.preview!);
        }
      }

      setState(() {
        _isPicking = false;
        _previewFiles = previews.isNotEmpty ? previews : null;
        _errorMessage = errors.isNotEmpty ? errors.join('\n') : null;
      });
    } catch (e) {
      setState(() {
        _isPicking = false;
        _errorMessage = l10n.importPickFailed('$e');
      });
    }
  }

  Future<void> _confirmImport() async {
    final l10n = AppLocalizations.of(context)!;
    final files = _previewFiles;
    if (files == null || files.isEmpty) {
      return;
    }
    setState(() => _isImporting = true);

    try {
      final repository = ref.read(scheduleRepositoryProvider);
      final allSessions = files.expand((f) => f.sessions).toList();
      await repository.importParsedSessions(allSessions);
      await rescheduleAllReminders(ref);
      refreshSchedule(ref);

      if (mounted) {
        setState(() {
          _isImporting = false;
          _previewFiles = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.importSuccess(allSessions.length)),
            action: SnackBarAction(
              label: l10n.importViewGrid,
              onPressed: () => navigateToAppTab(ref, AppTab.grid),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _errorMessage = l10n.importFailed('$e');
        });
      }
    }
  }
}

class _PreviewFile {
  const _PreviewFile({
    required this.name,
    required this.sessions,
  });

  final String name;
  final List<CourseSession> sessions;
}

class _PickCard extends StatelessWidget {
  const _PickCard({required this.onPick, required this.isPicking});

  final VoidCallback onPick;
  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: isPicking ? null : onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.primary.withAlpha(100),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.primaryContainer.withAlpha(48),
        ),
        child: Column(
          children: [
            Icon(
              Icons.upload_file,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.importPickTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.importPickSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (isPicking) ...[
              const SizedBox(height: 16),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilePreviewCard extends StatelessWidget {
  const _FilePreviewCard({required this.file});

  final _PreviewFile file;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final dates = file.sessions.map((s) => s.date).toList()..sort();
    final dateRange = dates.isEmpty
        ? ''
        : dates.length == 1
            ? formatShortDate(dates.first)
            : '${formatShortDate(dates.first)} – ${formatShortDate(dates.last)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.table_chart_outlined, color: colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${l10n.sessionCount(file.sessions.length)}　$dateRange',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
