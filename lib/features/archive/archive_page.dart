import 'package:orbit/core/background/background_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/features/deadline/deadline_ui.dart';
import 'package:orbit/features/session/session_detail_sheet.dart';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/orbit_feature_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/archive_providers.dart';

class ArchiveEntry {
  ArchiveEntry({
    required this.key,
    required this.name,
    this.sessions = const [],
    this.deadlines = const [],
  });
  final String key, name;
  final List<CourseSession> sessions;
  final List<Deadline> deadlines;
  DateTime get archivedAt => [
    ...sessions.map((s) => s.archivedAt!),
    ...deadlines.map((d) => d.archivedAt!),
  ].reduce((a, b) => a.isAfter(b) ? a : b);
  DateTime get eventTime => [
    ...sessions.map((s) => s.startAt),
    ...deadlines.map((d) => d.dueAt),
  ].reduce((a, b) => a.isAfter(b) ? a : b);
  int get count => sessions.length + deadlines.length;
  int get hiddenCount =>
      sessions.where((s) => s.archiveHidden).length +
      deadlines.where((d) => d.archiveHidden).length;
}

List<ArchiveEntry> buildArchiveEntries(
  List<CourseSession> sessions,
  List<Deadline> deadlines,
  bool ddl,
  ArchiveSettings settings,
) {
  final entries = <ArchiveEntry>[];
  if (ddl) {
    entries.addAll(
      deadlines
          .where((d) => d.archived)
          .map(
            (d) => ArchiveEntry(
              key: 'ddl:${d.id}',
              name: '${d.subject} · ${d.title}',
              deadlines: [d],
            ),
          ),
    );
  } else if (!settings.groupCourses) {
    entries.addAll(
      sessions
          .where((s) => s.archived)
          .map(
            (s) => ArchiveEntry(
              key: 'session:${s.id}',
              name: s.courseName,
              sessions: [s],
            ),
          ),
    );
  } else {
    final groups = <String, List<CourseSession>>{};
    for (final s in sessions.where((s) => s.archived)) {
      final key = '${s.semester}|${CourseSeriesKey.fromSession(s).value}';
      groups.putIfAbsent(key, () => []).add(s);
    }
    entries.addAll(
      groups.entries.map(
        (e) => ArchiveEntry(
          key: 'course:${e.key}',
          name: e.value.first.courseName,
          sessions: e.value,
        ),
      ),
    );
  }
  final sort = ddl ? settings.deadlineSort : settings.courseSort;
  final descending = ddl
      ? settings.deadlineDescending
      : settings.courseDescending;
  final order =
      settings.orders[ddl
          ? 'ddl'
          : settings.groupCourses
          ? 'groups'
          : 'sessions'] ??
      [];
  final ranks = {for (var i = 0; i < order.length; i++) order[i]: i};
  entries.sort((a, b) {
    int result;
    if (sort == ArchiveSort.manual) {
      final ai = ranks[a.key] ?? -1, bi = ranks[b.key] ?? -1;
      if (ai < 0 && bi >= 0) return -1;
      if (bi < 0 && ai >= 0) return 1;
      result = ai >= 0
          ? ai.compareTo(bi)
          : b.archivedAt.compareTo(a.archivedAt);
    } else {
      result = switch (sort) {
        ArchiveSort.archivedAt => a.archivedAt.compareTo(b.archivedAt),
        ArchiveSort.eventTime => a.eventTime.compareTo(b.eventTime),
        ArchiveSort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        ArchiveSort.manual => 0,
      };
      if (descending) result = -result;
    }
    return result == 0 ? a.key.compareTo(b.key) : result;
  });
  return entries;
}

class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key, this.courseHistory});
  final List<String>? courseHistory;
  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  bool _ddl = false, _busy = false;
  String _query = '';
  final _selected = <String>{};

  Future<void> _apply(
    List<ArchiveEntry> entries,
    ArchiveMutation action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(appDatabaseProvider)
          .updateArchive(
            sessionIds: entries
                .expand((e) => e.sessions.map((s) => s.id))
                .toList(),
            deadlineIds: entries
                .expand((e) => e.deadlines.map((d) => d.id))
                .toList(),
            action: action,
          );
      refreshSchedule(ref);
      ref.read(reminderSettingsProvider.notifier).scheduleResync();
      if (mounted) setState(_selected.clear);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text(OrbitFeatureText.of(context).failed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PopupMenuButton<ArchiveMutation> _actions(List<ArchiveEntry> entries) {
    final text = OrbitFeatureText.of(context);
    return PopupMenuButton<ArchiveMutation>(
      enabled: !_busy,
      onSelected: (a) => _apply(entries, a),
      itemBuilder: (_) => [
        PopupMenuItem(value: ArchiveMutation.hide, child: Text(text.hide)),
        PopupMenuItem(value: ArchiveMutation.show, child: Text(text.show)),
        PopupMenuItem(
          value: ArchiveMutation.restore,
          child: Text(text.restore),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = OrbitFeatureText.of(context);
    final settingsAsync = ref.watch(archiveSettingsProvider);
    final sessionsAsync = ref.watch(sessionsProvider);
    final deadlinesAsync = ref.watch(allDeadlinesProvider);
    final settings = settingsAsync.valueOrNull ?? const ArchiveSettings();
    final history = widget.courseHistory;
    final sessions = (sessionsAsync.valueOrNull ?? <CourseSession>[])
        .where((s) => history == null || history.contains(s.id))
        .toList();
    final entries = buildArchiveEntries(
      sessions,
      deadlinesAsync.valueOrNull ?? [],
      _ddl,
      history == null
          ? settings
          : settings.change({
              'groupCourses': false,
              'courseSort': 'eventTime',
              'courseDescending': true,
            }),
    );
    final filtered = entries
        .where(
          (e) =>
              '${e.name} ${e.sessions.map((s) => '${s.courseCode} ${s.section} ${s.semester}').join(' ')}'
                  .toLowerCase()
                  .contains(_query.toLowerCase().trim()),
        )
        .toList();
    final selected = entries.where((e) => _selected.contains(e.key)).toList();
    final manual =
        history == null &&
        _query.trim().isEmpty &&
        (_ddl ? settings.deadlineSort : settings.courseSort) ==
            ArchiveSort.manual;

    Widget row(ArchiveEntry entry, int index) {
      final sample = entry.sessions.firstOrNull;
      final date = DateFormat.yMd(
        Localizations.localeOf(context).toString(),
      ).add_Hm().format(entry.eventTime);
      return ListTile(
        key: ValueKey(entry.key),
        leading: Checkbox(
          value: _selected.contains(entry.key),
          onChanged: _busy
              ? null
              : (v) => setState(() {
                  if (v == true) {
                    _selected.add(entry.key);
                  } else {
                    _selected.remove(entry.key);
                  }
                }),
        ),
        title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${sample == null ? '' : '${sample.courseCode} · ${sample.section} · ${sample.semester}\n'}'
          '$date · ${text.count(entry.count)} · ${text.hide} ${entry.hiddenCount}/${entry.count}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actions([entry]),
            if (manual)
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
          ],
        ),
        onTap: () {
          if (entry.deadlines.isNotEmpty) {
            showDeadlineDetails(context, entry.deadlines.first);
          } else if (history == null && settings.groupCourses) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ArchivePage(
                  courseHistory: entry.sessions.map((s) => s.id).toList(),
                ),
              ),
            );
          } else {
            SessionDetailSheet.show(context, entry.sessions.first);
          }
        },
      );
    }

    final loading =
        !sessionsAsync.hasValue ||
        !deadlinesAsync.hasValue ||
        !settingsAsync.hasValue;
    final error =
        sessionsAsync.hasError ||
        deadlinesAsync.hasError ||
        settingsAsync.hasError;
    return BackgroundScaffold(
      appBar: AppBar(
        title: Text(text.archive),
        actions: [
          IconButton(
            tooltip: text.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              refreshSchedule(ref);
              ref.invalidate(archiveSettingsProvider);
            },
          ),
          if (history == null)
            IconButton(
              tooltip: text.settings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ArchiveSettingsPage(),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (history == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(text.courses)),
                  const ButtonSegment(value: true, label: Text('DDL')),
                ],
                selected: {_ddl},
                onSelectionChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _ddl = v.first;
                        _selected.clear();
                      }),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: text.search,
              ),
              onChanged: (q) => setState(() {
                _query = q;
                _selected.clear();
              }),
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        if (selected.length == filtered.length) {
                          _selected.clear();
                        } else {
                          _selected.addAll(filtered.map((e) => e.key));
                        }
                      }),
                child: Text(
                  selected.isNotEmpty && selected.length == filtered.length
                      ? text.clearSelection
                      : text.selectAll,
                ),
              ),
              if (selected.isNotEmpty) ...[
                Text(text.count(selected.fold(0, (n, e) => n + e.count))),
                _actions(selected),
              ],
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: error
                ? Center(
                    child: TextButton(
                      onPressed: () {
                        refreshSchedule(ref);
                        ref.invalidate(archiveSettingsProvider);
                      },
                      child: Text(text.refresh),
                    ),
                  )
                : loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(child: Text(text.empty))
                : manual
                ? ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => row(filtered[i], i),
                    onReorderItem: (oldIndex, newIndex) async {
                      if (_busy) return;
                      final reordered = [...filtered];
                      reordered.insert(newIndex, reordered.removeAt(oldIndex));
                      final key = _ddl
                          ? 'ddl'
                          : settings.groupCourses
                          ? 'groups'
                          : 'sessions';
                      try {
                        await ref.read(archiveSettingsProvider.notifier).change(
                          {
                            'orders': {
                              ...settings.orders,
                              key: reordered.map((e) => e.key).toList(),
                            },
                          },
                        );
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showAppSnackBar(
                            SnackBar(content: Text(text.failed)),
                          );
                        }
                      }
                    },
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => row(filtered[i], i),
                  ),
          ),
        ],
      ),
    );
  }
}

class ArchiveSettingsPage extends ConsumerWidget {
  const ArchiveSettingsPage({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> changes,
  ) async {
    try {
      await ref.read(archiveSettingsProvider.notifier).change(changes);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text(OrbitFeatureText.of(context).failed)),
        );
      }
    }
  }

  Future<void> _delay(
    BuildContext context,
    WidgetRef ref,
    String key,
    int current,
  ) async {
    final text = OrbitFeatureText.of(context);
    final controller = TextEditingController(text: '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(text.customDays),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed:
                  int.tryParse(controller.text) != null &&
                      int.parse(controller.text) <= 36500
                  ? () => Navigator.pop(ctx, int.parse(controller.text))
                  : null,
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    // The dialog can still be animating while its TextField is mounted.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (result != null && context.mounted) {
      await _save(context, ref, {key: result});
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = OrbitFeatureText.of(context);
    final value = ref.watch(archiveSettingsProvider);
    return BackgroundScaffold(
      appBar: AppBar(title: Text(text.settings)),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(archiveSettingsProvider),
            child: Text(text.refresh),
          ),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SwitchListTile(
              title: Text(text.group),
              subtitle: Text(text.groupHint),
              value: s.groupCourses,
              onChanged: (v) => _save(context, ref, {'groupCourses': v}),
            ),
            for (final ddl in [false, true]) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  ddl ? 'DDL' : text.courses,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<ArchiveSort>(
                  isExpanded: true,
                  key: ValueKey(
                    '${ddl}_${ddl ? s.deadlineSort : s.courseSort}',
                  ),
                  initialValue: ddl ? s.deadlineSort : s.courseSort,
                  items: [
                    for (final sort in ArchiveSort.values)
                      DropdownMenuItem(
                        value: sort,
                        child: Text(
                          text.sortName(sort.name),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      _save(context, ref, {
                        ddl ? 'deadlineSort' : 'courseSort': v.name,
                      });
                    }
                  },
                ),
              ),
              if ((ddl ? s.deadlineSort : s.courseSort) != ArchiveSort.manual)
                SwitchListTile(
                  title: Text(
                    (ddl ? s.deadlineDescending : s.courseDescending)
                        ? text.descending
                        : text.ascending,
                  ),
                  value: ddl ? s.deadlineDescending : s.courseDescending,
                  onChanged: (v) => _save(context, ref, {
                    ddl ? 'deadlineDescending' : 'courseDescending': v,
                  }),
                ),
              SwitchListTile(
                title: Text(ddl ? text.autoDeadlines : text.autoCourses),
                value: ddl ? s.autoDeadlines : s.autoCourses,
                onChanged: (v) => _save(context, ref, {
                  ddl ? 'autoDeadlines' : 'autoCourses': v,
                }),
              ),
              ListTile(
                title: Text(text.delay),
                trailing: DropdownButton<int>(
                  value:
                      [
                        0,
                        1,
                        7,
                      ].contains(ddl ? s.deadlineDelayDays : s.courseDelayDays)
                      ? (ddl ? s.deadlineDelayDays : s.courseDelayDays)
                      : -1,
                  items: [
                    for (final days in [0, 1, 7])
                      DropdownMenuItem(
                        value: days,
                        child: Text(text.days(days)),
                      ),
                    DropdownMenuItem(
                      value: -1,
                      child: Text(
                        [0, 1, 7].contains(
                              ddl ? s.deadlineDelayDays : s.courseDelayDays,
                            )
                            ? text.custom
                            : text.days(
                                ddl ? s.deadlineDelayDays : s.courseDelayDays,
                              ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == -1) {
                      _delay(
                        context,
                        ref,
                        ddl ? 'deadlineDelayDays' : 'courseDelayDays',
                        ddl ? s.deadlineDelayDays : s.courseDelayDays,
                      );
                    } else if (v != null) {
                      _save(context, ref, {
                        ddl ? 'deadlineDelayDays' : 'courseDelayDays': v,
                      });
                    }
                  },
                ),
              ),
              SwitchListTile(
                title: Text(text.hideAuto),
                value: ddl ? s.hideDeadlines : s.hideCourses,
                onChanged: (v) => _save(context, ref, {
                  ddl ? 'hideDeadlines' : 'hideCourses': v,
                }),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(text.autoHint),
            ),
          ],
        ),
      ),
    );
  }
}
