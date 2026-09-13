import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/formatters/date_time_formatters.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/error_state.dart';
import 'package:orbit/core/widgets/step_confirm_dialog.dart';
import 'package:orbit/features/session/deletion_feedback.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';

class DeletedSessionsPage extends ConsumerStatefulWidget {
  const DeletedSessionsPage({super.key});

  @override
  ConsumerState<DeletedSessionsPage> createState() =>
      _DeletedSessionsPageState();
}

class _DeletedSessionsPageState extends ConsumerState<DeletedSessionsPage> {
  final Set<String> _selectedIds = {};
  late Future<List<CourseSession>> _sessions = _load();

  Future<List<CourseSession>> _load() async {
    final repository = ref.read(scheduleRepositoryProvider);
    await repository.purgeExpiredDeletedSessions();
    return repository.getDeletedSessions();
  }

  void _reload() {
    setState(() {
      _selectedIds.clear();
      _sessions = _load();
    });
  }

  Future<void> _restore(List<String> ids) async {
    if (ids.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final container = ProviderScope.containerOf(context);
    final result = await restoreDeletedWithRefresh(container, ids);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(l10n.trashRestoreResult(result.restored, result.skipped)),
      ),
    );
    _reload();
  }

  Future<void> _emptyTrash() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmWithSteps(
      context,
      steps: [
        (l10n.trashEmptyConfirm1Title, l10n.trashEmptyConfirm1Content),
        (l10n.trashEmptyConfirm2Title, l10n.trashEmptyConfirm2Content),
      ],
    );
    if (!confirmed || !mounted) return;
    await ref.read(scheduleRepositoryProvider).purgeAllDeletedSessions();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trashTitle),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              tooltip: l10n.trashRestoreSelected,
              icon: const Icon(Icons.restore),
              onPressed: () => _restore(_selectedIds.toList()),
            ),
          IconButton(
            tooltip: l10n.trashEmptyAction,
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: _emptyTrash,
          ),
        ],
      ),
      body: FutureBuilder<List<CourseSession>>(
        future: _sessions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: '${snapshot.error}',
              retryLabel: l10n.actionRetry,
              onRetry: _reload,
            );
          }
          final sessions = snapshot.data ?? const [];
          if (sessions.isEmpty) {
            return EmptyState(
              icon: Icons.delete_sweep_outlined,
              title: l10n.trashEmpty,
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final selected = _selectedIds.contains(session.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selectedIds.add(session.id);
                        } else {
                          _selectedIds.remove(session.id);
                        }
                      }),
                      title: Text(session.courseName),
                      subtitle: Text(
                        '${formatIsoDate(session.date)} · '
                        '${formatTimeHm(session.startAt)}–${formatTimeHm(session.endAt)} · '
                        '${session.room}\n'
                        '${l10n.trashDeletedAt(formatDateTimeMinute(session.deletedAt!))}',
                      ),
                      isThreeLine: true,
                      secondary: IconButton(
                        tooltip: l10n.trashRestoreSelected,
                        icon: const Icon(Icons.restore),
                        onPressed: () => _restore([session.id]),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.restore),
                    label: Text(l10n.trashRestoreAll),
                    onPressed: () => _restore(
                      sessions.map((session) => session.id).toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
