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
  StreamSubscription<void>? _subscription;
  late Future<OrbitStatistics> _data = _load();
  Future<OrbitStatistics> _load() async {
    final db = ref.read(appDatabaseProvider);
    await db.refreshStatistics();
    return OrbitStatistics(records: await db.statisticsRecords());
  }

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(appDatabaseProvider).syncChanges.listen((_) {
      if (mounted) setState(() => _data = _load());
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
    return BackgroundScaffold(
      appBar: AppBar(title: Text(t.title)),
      body: FutureBuilder<OrbitStatistics>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final s = snapshot.data;
          if (s == null) {
            return const Center(child: CircularProgressIndicator());
          }
          Widget metric(String label, String value) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  const SizedBox(height: 8),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              metric(t.activeDays, '${s.activeDays}'),
              Card(
                child: ListTile(
                  title: Text(t.firstUsed),
                  subtitle: Text(s.firstUsedDate ?? '—'),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final today = DateTime.now();
                    final initial =
                        DateTime.tryParse(s.firstUsedDate ?? '') ?? today;
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
                      if (mounted) setState(() => _data = _load());
                    }
                  },
                ),
              ),
              metric(t.sessions, '${s.attendedSessions}'),
              metric(t.duration, t.minutes(s.classMinutes)),
              metric(t.deadlines, '${s.completedDeadlines}'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  t.learned,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (s.learnedCourses.isEmpty) Text(t.noLearnedCourses),
              for (final course in s.learnedCourses)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: Text(course.name),
                    subtitle: Text(course.semester),
                  ),
                ),
              const SizedBox(height: 16),
              Text(t.statisticsHint),
            ],
          );
        },
      ),
    );
  }
}
