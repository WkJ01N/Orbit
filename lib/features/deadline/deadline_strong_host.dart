import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/deadline_text.dart';
import 'package:orbit/models/deadline_strong_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/strong_session_service.dart';

final deadlineStrongEventsProvider = StateProvider<List<Map<String, dynamic>>>(
  (ref) => const [],
);
final deadlineStrongHandledProvider = StateProvider<Set<String>>((ref) => {});
final deadlineStrongRetryProvider = StateProvider<int>((ref) => 0);
final deadlineStrongErrorProvider = StateProvider<bool>((ref) => false);

Future<void> handleDeadlineStrongEvents(
  WidgetRef ref,
  List<Map<String, dynamic>> events,
) async {
  final ids = events.map((e) => e['id'] as String).toSet();
  await StrongSessionService.call('deadlineStrongEventsHandled', {
    'ids': ids.toList(),
  });
  ref.read(deadlineStrongHandledProvider.notifier).state = {
    ...ref.read(deadlineStrongHandledProvider),
    ...ids,
  };
  ref.read(deadlineStrongEventsProvider.notifier).state = ref
      .read(deadlineStrongEventsProvider)
      .where((e) => !ids.contains(e['id']))
      .toList();
}

class DeadlineStrongHost extends ConsumerStatefulWidget {
  const DeadlineStrongHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  ConsumerState<DeadlineStrongHost> createState() => _DeadlineStrongHostState();
}

class _DeadlineStrongHostState extends ConsumerState<DeadlineStrongHost>
    with WidgetsBindingObserver, WindowListener {
  Timer? _timer;
  bool _polling = false;
  final Set<String> _announced = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) windowManager.addListener(this);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_poll()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_poll()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_poll());
  }

  @override
  void onWindowFocus() {
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_polling || !mounted || (!Platform.isAndroid && !Platform.isWindows)) {
      return;
    }
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) return;
    _polling = true;
    try {
      if (Platform.isWindows &&
          (!await windowManager.isVisible() ||
              await windowManager.isMinimized() ||
              !await windowManager.isFocused())) {
        return;
      }
      final result = await StrongSessionService.call('deadlineStrongOpen');
      if (!mounted || result == null) return;
      final handled = ref.read(deadlineStrongHandledProvider);
      final events = (result['events'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => !handled.contains(e['id']))
          .toList();
      if (jsonEncode(events) !=
          jsonEncode(ref.read(deadlineStrongEventsProvider))) {
        ref.read(deadlineStrongEventsProvider.notifier).state = events;
      }
      ref.read(deadlineStrongErrorProvider.notifier).state = false;
      final fresh = events.where((e) => !_announced.contains(e['id'])).toList();
      if (fresh.isNotEmpty) {
        _announced.addAll(fresh.map((e) => e['id'] as String));
        final c = widget.navigatorKey.currentContext;
        if (c != null && c.mounted) {
          final t = DeadlineStrongText.of(c);
          ScaffoldMessenger.of(c).showAppSnackBar(
            SnackBar(
              content: Text(t.stopped),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: t.manage,
                onPressed: () => showDeadlineReminderManagement(
                  c,
                  ref.read(deadlineStrongEventsProvider),
                ),
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) ref.read(deadlineStrongErrorProvider.notifier).state = true;
      debugPrint('DDL strong acknowledgement failed: $error');
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(deadlineStrongRetryProvider, (_, _) => unawaited(_poll()));
    return widget.child;
  }
}

class DeadlineStrongBanner extends ConsumerWidget {
  const DeadlineStrongBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(deadlineStrongEventsProvider);
    final error = ref.watch(deadlineStrongErrorProvider);
    if (events.isEmpty && !error) return const SizedBox.shrink();
    final t = DeadlineStrongText.of(context);
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_off_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error ? t.failed : t.stopped,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (error)
              TextButton.icon(
                onPressed: () =>
                    ref.read(deadlineStrongRetryProvider.notifier).state++,
                icon: const Icon(Icons.refresh),
                label: Text(t.retry),
              ),
            if (events.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () =>
                        showDeadlineReminderManagement(context, events),
                    child: Text(t.manage),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await handleDeadlineStrongEvents(ref, events);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showAppSnackBar(SnackBar(content: Text(t.failed)));
                        }
                      }
                    },
                    child: Text(t.keep),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showDeadlineReminderManagement(
  BuildContext context,
  List<Map<String, dynamic>> events,
) => showDialog<void>(
  context: context,
  builder: (_) => _DeadlineReminderManagement(events: List.of(events)),
);

class _DeadlineReminderManagement extends ConsumerStatefulWidget {
  const _DeadlineReminderManagement({required this.events});
  final List<Map<String, dynamic>> events;
  @override
  ConsumerState<_DeadlineReminderManagement> createState() =>
      _DeadlineReminderManagementState();
}

class _DeadlineReminderManagementState
    extends ConsumerState<_DeadlineReminderManagement> {
  List<Deadline>? _deadlines;
  final Map<String, Set<int>> _options = {}, _selected = {};
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = widget.events.map((e) => e['deadlineId']).toSet();
      final values = (await ref.read(appDatabaseProvider).getDeadlines())
          .where(
            (d) =>
                ids.contains(d.id) && !d.completed && !d.deleted && !d.archived,
          )
          .toList();
      final now = DateTime.now();
      for (final d in values) {
        _options[d.id] = d.leadMinutes
            .where(
              (m) =>
                  d.reminderEnabledAt(m) &&
                  d.dueAt.subtract(Duration(minutes: m)).isAfter(now),
            )
            .toSet();
      }
      if (mounted) {
        setState(() {
          _deadlines = values.where((d) => _options[d.id]!.isNotEmpty).toList();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = DeadlineStrongText.of(context).failed);
      }
    }
  }

  Future<void> _save({bool all = false, bool keep = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!keep) {
        await ref
            .read(appDatabaseProvider)
            .disableDeadlineReminders(all ? _options : _selected);
        ref.read(scheduleRefreshProvider.notifier).state++;
        await ref.read(reminderSettingsProvider.notifier).resyncReminders();
        if (ref.read(lastRescheduleErrorProvider) != null) {
          throw StateError('Reschedule failed');
        }
      }
      await handleDeadlineStrongEvents(ref, widget.events);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = DeadlineStrongText.of(context).failed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DeadlineStrongText.of(context), dt = DeadlineText.of(context);
    final hasSelection = _selected.values.any((v) => v.isNotEmpty);
    return AlertDialog(
      scrollable: true,
      title: Text(t.manage),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_deadlines == null && _error == null)
                const Center(child: CircularProgressIndicator()),
              if (_deadlines?.isEmpty == true) Text(t.noFuture),
              for (final d in _deadlines ?? const <Deadline>[]) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    '${d.subject} · ${d.title}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final m
                    in (_options[d.id]!.toList()
                      ..sort((a, b) => b.compareTo(a))))
                  CheckboxListTile(
                    key: ValueKey('future-reminder-${d.id}-$m'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(dt.leadLabel(m)),
                    subtitle: Text(
                      '${DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hm().format(d.dueAt.subtract(Duration(minutes: m)))} · ${d.usesStrongReminderAt(m) ? t.strong : t.normal}',
                    ),
                    value: _selected[d.id]?.contains(m) ?? false,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            final values = _selected.putIfAbsent(
                              d.id,
                              () => {},
                            );
                            if (v == true) {
                              values.add(m);
                            } else {
                              values.remove(m);
                            }
                          }),
                  ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_deadlines == null && _error != null)
                TextButton(onPressed: _load, child: Text(t.retry)),
            ],
          ),
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _save(keep: true),
          child: Text(t.keep),
        ),
        TextButton(
          onPressed: _busy || _deadlines == null || _deadlines!.isEmpty
              ? null
              : () => _save(all: true),
          child: Text(t.closeAll),
        ),
        FilledButton(
          onPressed: _busy || !hasSelection ? null : () => _save(),
          child: Text(t.closeSelected),
        ),
      ],
    );
  }
}
