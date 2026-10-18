import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/features/statistics/semester_management_page.dart';
import 'package:orbit/models/v162_text.dart';
import 'package:orbit/services/semester_service.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/data/database/app_database.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/statistics.dart';
import 'package:orbit/models/statistics_text.dart';
import 'package:orbit/providers/app_providers.dart';

class StatisticsLifecycleHost extends ConsumerStatefulWidget {
  const StatisticsLifecycleHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<StatisticsLifecycleHost> createState() =>
      _StatisticsLifecycleHostState();
}

class _StatisticsLifecycleHostState
    extends ConsumerState<StatisticsLifecycleHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<void>? _subscription;
  bool _running = false;
  bool _pending = false;
  bool _activity = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = ref
        .read(appDatabaseProvider)
        .syncChanges
        .listen(
          (_) => unawaited(
            _refresh(
              activity:
                  WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed,
            ),
          ),
        );
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_refresh(activity: true));
      }
    });
    unawaited(_refresh(activity: true));
  }

  Future<void> _refresh({bool activity = false}) async {
    _activity |= activity;
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      do {
        _pending = false;
        final record = _activity;
        _activity = false;
        await ref
            .read(appDatabaseProvider)
            .refreshStatistics(recordActivity: record);
      } while (_pending && mounted);
    } catch (error) {
      debugPrint('Statistics refresh failed: $error');
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh(activity: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});
  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  String _selection = 'current';
  SemesterService _semesters = SemesterService();
  StreamSubscription<void>? _subscription;
  late Future<OrbitStatistics> _data = _load();
  Future<OrbitStatistics> _load() async {
    final db = ref.read(appDatabaseProvider);
    await db.refreshStatistics();
    final records = await db.statisticsRecords();
    final config = await ref.read(importConfigurationProvider.future);
    _semesters = SemesterService(
      plans: config.semesters,
      records: records,
      sessions: await db.getAllSessions(),
    );
    _semesters.current(DateTime.now());
    return OrbitStatistics(
      records: [
        for (final r in records)
          if (r['kind'] == 'course' || r['kind'] == 'exam')
            {
              ...r,
              'semester':
                  _semesters
                      .resolve(
                        name: r['semester'] as String? ?? '',
                        id: r['semesterId'] as String?,
                        at: SemesterService.recordDate(r),
                      )
                      ?.name ??
                  r['semester'],
            }
          else
            r,
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      SharedPreferences.getInstance().then((p) {
        if (mounted) {
          setState(
            () =>
                _selection = p.getString('statistics_semester_v1') ?? 'current',
          );
        }
      }),
    );
    _subscription = ref.read(appDatabaseProvider).syncChanges.listen((_) {
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = StatisticsText.of(context);
    final v = V162Text.of(context);
    ref.listen(importConfigurationProvider, (_, next) {
      if (next.hasValue) {
        setState(() {
          _data = _load();
        });
      }
    });
    return BackgroundScaffold(
      appBar: AppBar(
        title: PageModule(child: Text(t.title)),
        actions: [
          PageModule(
            child: IconButton(
              tooltip: v.manageSemesters,
              icon: const Icon(Icons.edit_calendar_outlined),
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SemesterManagementPage(),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _data = _load();
                  });
                }
              },
            ),
          ),
        ],
      ),
      body: FutureBuilder<OrbitStatistics>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: PageModule(child: Text('${snapshot.error}')));
          }
          final all = snapshot.data;
          if (all == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final chosen = _selection == 'current'
              ? _semesters.current(DateTime.now()).id
              : _selection;
          final info = _semesters.semesters
              .where((s) => s.id == chosen)
              .firstOrNull;
          final s = _selection == 'all'
              ? all
              : OrbitStatistics(
                  records: all.records.where((r) {
                    if (r['kind'] == 'profile') return true;
                    if (r['kind'] == 'course' || r['kind'] == 'exam') {
                      return _semesters.recordSemester(r) == chosen ||
                          chosen == 'unknown' &&
                              _semesters.recordSemester(r) == null;
                    }
                    final date = DateTime.tryParse(
                      '${r[r['kind'] == 'day' ? 'date' : 'completedAt']}',
                    )?.toLocal();
                    return date != null && info != null && info.contains(date);
                  }).toList(),
                );
          final learned = s.learnedCourses;
          Widget metric(String label, String value) => PageModule(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageModule(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_selection),
                  initialValue:
                      [
                        'current',
                        'all',
                        'unknown',
                        ..._semesters.semesters.map((s) => s.id),
                      ].contains(_selection)
                      ? _selection
                      : 'current',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: v.semester,
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'all', child: Text(v.allSemesters)),
                    DropdownMenuItem(
                      value: 'current',
                      child: Text(
                        '${v.currentSemester} · ${_semesters.current(DateTime.now()).name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final item in _semesters.semesters)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    DropdownMenuItem(
                      value: 'unknown',
                      child: Text(v.unknownSemester),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selection = value);
                    unawaited(
                      SharedPreferences.getInstance().then(
                        (p) => p.setString('statistics_semester_v1', value),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              metric(t.activeDays, '${s.activeDays}'),
              PageModule(
                child: Card(
                  child: ListTile(
                    title: Text("${t.firstUsed} · ${v.lifetime}"),
                    subtitle: Text(all.firstUsedDate ?? '—'),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final today = DateTime.now();
                      final initial =
                          DateTime.tryParse(all.firstUsedDate ?? '') ?? today;
                      final date = await showDatePicker(
                        context: context,
                        initialDate: initial.isAfter(today) ? today : initial,
                        firstDate: DateTime(1970),
                        lastDate: today,
                      );
                      if (date != null) {
                        await ref
                            .read(appDatabaseProvider)
                            .setFirstUsedDate(date);
                        if (mounted) {
                          setState(() {
                            _data = _load();
                          });
                        }
                      }
                    },
                  ),
                ),
              ),
              metric(t.sessions, '${s.attendedSessions}'),
              metric(t.duration, t.minutes(s.classMinutes)),
              metric(t.deadlines, '${s.completedDeadlines}'),
              metric(v.exams, '${s.completedExams}'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: PageModule(
                  child: Text(
                    '${t.learned} · ${learned.length}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              if (learned.isEmpty) PageModule(child: Text(t.noLearnedCourses)),
              for (final course in learned.take(5))
                PageModule(
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(course.name),
                      subtitle: Text(course.semester),
                    ),
                  ),
                ),
              if (learned.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: PageModule(
                    child: TextButton.icon(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FinishedCoursesPage(
                            courses: learned,
                            scope: _selection == 'all'
                                ? v.allSemesters
                                : info?.name ?? v.unknownSemester,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.chevron_right),
                      label: Text(v.viewAll),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              PageModule(child: Text(t.statisticsHint)),
            ],
          );
        },
      ),
    );
  }
}

class FinishedCoursesPage extends StatelessWidget {
  const FinishedCoursesPage({
    super.key,
    required this.courses,
    required this.scope,
  });
  final List<({String name, String semester})> courses;
  final String scope;
  @override
  Widget build(BuildContext context) => BackgroundScaffold(
    appBar: AppBar(
      title: PageModule(child: Text(V162Text.of(context).allCourses)),
    ),
    body: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: courses.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PageModule(child: Text('$scope · ${courses.length}')),
          );
        }
        final course = courses[index - 1];
        return PageModule(
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(course.name),
              subtitle: Text(course.semester),
            ),
          ),
        );
      },
    ),
  );
}
