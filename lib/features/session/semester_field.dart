import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/v162_text.dart';
import 'package:orbit/models/v163_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/services/semester_service.dart';

final formSemesterRecordsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      ref.watch(scheduleRefreshProvider);
      return ref.watch(appDatabaseProvider).statisticsRecords();
    }, dependencies: [appDatabaseProvider]);

bool formSemesterLoading(WidgetRef ref) =>
    ref.watch(importConfigurationProvider).isLoading ||
    ref.watch(formSemesterRecordsProvider).isLoading;

SemesterService availableSemesters(WidgetRef ref) => SemesterService(
  plans:
      ref.watch(importConfigurationProvider).valueOrNull?.semesters ?? const [],
  sessions: ref.watch(sessionsProvider).valueOrNull ?? const [],
  records: ref.watch(formSemesterRecordsProvider).valueOrNull ?? const [],
);

SemesterInfo resolveFormSemester(
  WidgetRef ref,
  String name,
  DateTime at, {
  String? id,
}) {
  final service = SemesterService(
    plans:
        ref.read(importConfigurationProvider).valueOrNull?.semesters ??
        const [],
    sessions: ref.read(sessionsProvider).valueOrNull ?? const [],
    records: ref.read(formSemesterRecordsProvider).valueOrNull ?? const [],
  );
  final selected = service.semesters
      .where(
        (s) =>
            s.id == id &&
            SemesterService.normalize(s.name) ==
                SemesterService.normalize(name),
      )
      .firstOrNull;
  return service.resolve(name: name.trim(), id: selected?.id, at: at)!;
}

/// Editing remains local to the form until its normal save transaction.
class SemesterField extends ConsumerWidget {
  const SemesterField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSelected,
  });
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semesters = availableSemesters(ref).semesters;
    return TextField(
      key: const Key('session-semester-field'),
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: V162Text.of(context).semester,
        helperText: V163Text.of(context).semesterHint,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        suffixIcon: PopupMenuButton<SemesterInfo>(
          enabled: enabled && semesters.isNotEmpty,
          tooltip: V162Text.of(context).semester,
          icon: const Icon(Icons.arrow_drop_down),
          itemBuilder: (_) => [
            for (final item in semesters)
              PopupMenuItem(value: item, child: Text(item.name)),
          ],
          onSelected: (item) {
            controller.text = item.name;
            onSelected?.call(item.id);
          },
        ),
      ),
    );
  }
}
