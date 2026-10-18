import 'package:orbit/data/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/models/v162_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/services/semester_service.dart';

class SemesterManagementPage extends ConsumerStatefulWidget {
  const SemesterManagementPage({super.key});
  @override
  ConsumerState<SemesterManagementPage> createState() =>
      _SemesterManagementPageState();
}

class _SemesterManagementPageState
    extends ConsumerState<SemesterManagementPage> {
  late Future<SemesterService> _data = _load();
  Future<SemesterService> _load() async {
    final db = ref.read(appDatabaseProvider);
    final plans = (await ref.read(
      importConfigurationProvider.future,
    )).semesters;
    final service = SemesterService(
      plans: plans,
      records: await db.statisticsRecords(),
      sessions: await db.getAllSessions(),
    );
    service.current(DateTime.now());
    return service;
  }

  Future<void> _edit(SemesterInfo item) async {
    final t = V162Text.of(context);
    final controller = TextEditingController(text: item.name);
    var start = item.start, end = item.end;
    String? error;
    bool saving = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(t.manageSemesters),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    maxLength: 120,
                    decoration: InputDecoration(labelText: t.name),
                  ),
                  for (final isStart in [true, false])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(isStart ? t.start : t.end),
                      subtitle: Text(
                        (isStart ? start : end)
                            .toIso8601String()
                            .split('T')
                            .first,
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: saving
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: isStart ? start : end,
                                firstDate: DateTime(1970),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                update(() {
                                  if (isStart) {
                                    start = date;
                                  } else {
                                    end = date;
                                  }
                                });
                              }
                            },
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final config = await ref.read(
                        importConfigurationProvider.future,
                      );
                      final conflicts = config.semesters
                          .where((p) => p.id != item.id)
                          .map(SemesterInfo.fromPlan)
                          .any(
                            (s) =>
                                !end.isBefore(s.start) && !start.isAfter(s.end),
                          );
                      if (controller.text.trim().isEmpty ||
                          end.isBefore(start) ||
                          conflicts) {
                        update(() => error = t.invalidRange);
                        return;
                      }
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final old = config.semesters
                            .where((p) => p.id == item.id)
                            .firstOrNull;
                        final plan = SemesterPlan(
                          id: item.id,
                          name: controller.text.trim(),
                          firstWeekMonday:
                              old?.firstWeekMonday ??
                              start.subtract(Duration(days: start.weekday - 1)),
                          totalWeeks: old?.totalWeeks ?? 18,
                          rangeStart: start,
                          rangeEnd: end,
                          source: 'manual',
                        );
                        final db = ref.read(appDatabaseProvider);
                        final previous = await _data;
                        final sessions = await db.getAllSessions();
                        final ids = sessions
                            .where(
                              (s) =>
                                  previous
                                      .resolve(
                                        name: s.semester,
                                        id: s.semesterId,
                                        at: s.startAt,
                                      )
                                      ?.id ==
                                  item.id,
                            )
                            .map((s) => s.id)
                            .toList();
                        await db.assignSemester(ids, item.id, plan.name);
                        await db.renameSemesterStatistics(
                          item.id,
                          item.name,
                          plan.name,
                          start: item.start,
                          end: item.end,
                        );
                        await ref
                            .read(importConfigurationProvider.notifier)
                            .saveChange(
                              (c) => c.copy(
                                semesters: [
                                  ...c.semesters.where((s) => s.id != item.id),
                                  plan,
                                ],
                              ),
                            );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          update(() {
                            error = '$e';
                            saving = false;
                          });
                        }
                      }
                    },
              child: Text(t.save),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true && mounted) {
      setState(() {
        _data = _load();
      });
    }
  }

  Future<void> _assign(SemesterInfo semester) async {
    final sessions = await ref.read(appDatabaseProvider).getAllSessions();
    if (!mounted) return;
    final selected = <String>{};
    var query = '';
    final t = V162Text.of(context);
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final matches = sessions
              .where(
                (s) => '${s.courseName} ${s.courseCode} ${s.semester}'
                    .toLowerCase()
                    .contains(query),
              )
              .toList();
          return AlertDialog(
            title: Text('${t.assign} · ${semester.name}'),
            content: SizedBox(
              width: 520,
              height: MediaQuery.sizeOf(context).height * .55,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (s) =>
                        update(() => query = s.trim().toLowerCase()),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (_, i) {
                        final s = matches[i];
                        return CheckboxListTile(
                          value: selected.contains(s.id),
                          title: Text(s.displayName),
                          subtitle: Text(
                            '${s.date.toIso8601String().split('T').first} · ${s.semester}',
                          ),
                          onChanged: (v) => update(() {
                            if (v == true) {
                              selected.add(s.id);
                            } else {
                              selected.remove(s.id);
                            }
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(t.cancel),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: Text('${t.save} (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
    if (apply != true) return;
    try {
      await ref
          .read(appDatabaseProvider)
          .assignSemester(selected.toList(), semester.id, semester.name);
      refreshSchedule(ref);
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showAppSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = V162Text.of(context);
    return BackgroundScaffold(
      appBar: AppBar(title: Text(t.manageSemesters)),
      body: FutureBuilder<SemesterService>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!.semesters;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final s = items[i];
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(s.name),
                      subtitle: Text(
                        '${s.start.toIso8601String().split('T').first} – ${s.end.toIso8601String().split('T').first}',
                      ),
                      trailing: IconButton(
                        tooltip: t.manageSemesters,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(s),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: () => _assign(s),
                        icon: const Icon(Icons.playlist_add_check),
                        label: Text(t.assign),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SemesterAssignmentButton extends ConsumerWidget {
  const SemesterAssignmentButton({super.key, required this.session});
  final CourseSession session;
  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
    icon: const Icon(Icons.calendar_month_outlined),
    label: Text(V162Text.of(context).assign),
    onPressed: () async {
      final db = ref.read(appDatabaseProvider);
      final config = await ref.read(importConfigurationProvider.future);
      final service = SemesterService(
        plans: config.semesters,
        records: await db.statisticsRecords(),
        sessions: await db.getAllSessions(),
      );
      service.current(DateTime.now());
      if (!context.mounted) return;
      final choice = await showDialog<SemesterInfo>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(V162Text.of(c).assign),
          children: [
            for (final semester in service.semesters)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, semester),
                child: Text(semester.name),
              ),
          ],
        ),
      );
      if (choice == null) return;
      await db.assignSemester([session.id], choice.id, choice.name);
      refreshSchedule(ref);
    },
  );
}
