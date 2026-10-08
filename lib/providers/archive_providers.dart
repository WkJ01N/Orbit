import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/providers/app_providers.dart';

final allDeadlinesProvider = FutureProvider<List<Deadline>>((ref) async {
  ref.watch(scheduleRefreshProvider);
  return ref.read(appDatabaseProvider).getDeadlines();
});

final archiveSettingsProvider =
    AsyncNotifierProvider<ArchiveSettingsNotifier, ArchiveSettings>(
      ArchiveSettingsNotifier.new,
    );

class ArchiveSettingsNotifier extends AsyncNotifier<ArchiveSettings> {
  Future<void> _tail = Future.value();
  @override
  Future<ArchiveSettings> build() =>
      ref.read(settingsServiceProvider).loadArchiveSettings();
  Future<void> change(Map<String, dynamic> changes) async {
    final service = ref.read(settingsServiceProvider);
    final save = _tail.then((_) async {
      final current = await future;
      final next = current.change(changes);
      await service.saveArchiveSettings(next);
      state = AsyncData(next);
    });
    _tail = save.catchError((Object _) {});
    await save;
  }
}

/// Only performs data maintenance while the application is running.
class ArchiveLifecycleHost extends ConsumerStatefulWidget {
  const ArchiveLifecycleHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<ArchiveLifecycleHost> createState() =>
      _ArchiveLifecycleHostState();
}

class _ArchiveLifecycleHostState extends ConsumerState<ArchiveLifecycleHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _running = false;
  bool _pending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_check()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  Future<void> _check() async {
    if (!mounted) return;
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      final settings = await ref.read(archiveSettingsProvider.future);
      if (!mounted) return;
      final changed = await ref
          .read(scheduleRepositoryProvider)
          .runAutoArchive(settings);
      if (mounted && changed > 0) {
        refreshSchedule(ref);
        ref.read(reminderSettingsProvider.notifier).scheduleResync();
      }
    } catch (error) {
      debugPrint('Automatic archive failed: $error');
    } finally {
      _running = false;
      if (_pending && mounted) {
        _pending = false;
        unawaited(_check());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(archiveSettingsProvider, (_, next) {
      if (next.hasValue) unawaited(_check());
    });
    return widget.child;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
