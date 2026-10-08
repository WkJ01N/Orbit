import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/providers/database_providers.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/wake_text.dart';
import 'package:orbit/services/strong_session_service.dart';

final strongConfirmationVisibleProvider = StateProvider<bool>((ref) => false);

final strongSessionProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

class StrongReminderHost extends ConsumerStatefulWidget {
  const StrongReminderHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  ConsumerState<StrongReminderHost> createState() => _StrongReminderHostState();
}

class _StrongReminderHostState extends ConsumerState<StrongReminderHost>
    with WidgetsBindingObserver, WindowListener {
  Timer? _timer;
  bool _running = false, _showing = false;
  String? _lastStored, _lastAcknowledged;
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(StrongSessionService.call('strongLeave'));
    }
  }

  @override
  void onWindowFocus() {
    unawaited(_poll());
  }

  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'hide' || eventName == 'close') {
      unawaited(StrongSessionService.call('strongLeave'));
    }
  }

  @override
  void onWindowMinimize() {
    unawaited(StrongSessionService.call('strongLeave'));
  }

  Future<bool> _visible() async {
    if (!Platform.isWindows) return true;
    try {
      return await windowManager.isVisible() &&
          !await windowManager.isMinimized();
    } catch (_) {
      return true;
    }
  }

  Future<void> _poll() async {
    if (_running || !mounted) return;
    _running = true;
    try {
      var state = await StrongSessionService.call('strongState');
      if (!mounted) return;
      ref.read(strongSessionProvider.notifier).state = state;
      if (state != null && jsonEncode(state) != _lastStored) {
        try {
          await ref
              .read(appDatabaseProvider)
              .saveStrongSession(
                state['id'] as String,
                (state['expiresAt'] as num).toInt(),
                state,
              );
        } catch (_) {
          /* Native state remains authoritative. */
        }
      }
      if (state != null &&
          ['completed', 'emergency'].contains(state['phase']) &&
          _lastAcknowledged != state['id']) {
        for (final raw in state['records'] as List? ?? []) {
          final record = raw as Map;
          final meta = record['metadata'] is String
              ? jsonDecode(record['metadata']) as Map
              : record;
          if (meta['ruleId'] is String && meta['sessionId'] is String) {
            await ref
                .read(reminderSchedulerProvider)
                .acknowledgeOccurrence(
                  ref.read(appDatabaseProvider),
                  meta['ruleId'],
                  meta['sessionId'],
                );
          }
        }
        _lastAcknowledged = state['id'] as String;
      }
      if (await _visible() &&
          StrongSessionService.active(state) &&
          !_showing &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
          widget.navigatorKey.currentState != null) {
        state = await StrongSessionService.call('strongOpen');
        if (!mounted) return;
        ref.read(strongSessionProvider.notifier).state = state;
        _showing = true;
        ref.read(strongConfirmationVisibleProvider.notifier).state = true;
        unawaited(
          widget.navigatorKey.currentState!
              .push<void>(
                MaterialPageRoute(
                  builder: (_) => const StrongConfirmationPage(),
                ),
              )
              .whenComplete(() {
                _showing = false;
                if (mounted) {
                  ref.read(strongConfirmationVisibleProvider.notifier).state =
                      false;
                }
              }),
        );
      }
    } catch (error) {
      debugPrint('Strong confirmation unavailable: $error');
    } finally {
      _running = false;
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
  Widget build(BuildContext context) => widget.child;
}

class StrongConfirmationPage extends ConsumerStatefulWidget {
  const StrongConfirmationPage({super.key});
  @override
  ConsumerState<StrongConfirmationPage> createState() =>
      _StrongConfirmationState();
}

class _StrongConfirmationState extends ConsumerState<StrongConfirmationPage> {
  String _input = '';
  bool _busy = false;
  Timer? _hold;
  Future<void> _action(String action, [int? answer]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await StrongSessionService.call(
        action,
        answer == null ? null : {'answer': answer},
      );
      if (!mounted) return;
      ref.read(strongSessionProvider.notifier).state = next;
      setState(() => _input = '');
      if (next != null && ['completed', 'emergency'].contains(next['phase'])) {
        // Stop repeat-until-confirmed custom occurrences on Windows as well.
        for (final raw in next['records'] as List? ?? []) {
          final record = Map<String, dynamic>.from(raw as Map);
          final meta = record['metadata'] is String
              ? jsonDecode(record['metadata']) as Map
              : record;
          final rule = meta['ruleId'] as String?,
              session = meta['sessionId'] as String?;
          if (rule != null && session != null) {
            await ref
                .read(reminderSchedulerProvider)
                .acknowledgeOccurrence(
                  ref.read(appDatabaseProvider),
                  rule,
                  session,
                );
          }
        }
        if (mounted) Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(WakeText.of(context).failed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WakeText.of(context);
    final s = ref.watch(strongSessionProvider);
    final phase = s?['phase'];
    final done = !StrongSessionService.active(s);
    final progress = (s?['progress'] as num?)?.toInt() ?? 0;
    final seq = (s?['settings'] as Map?)?['dismissTask'] == 'sequence';
    final deadline =
        (phase == 'task' ? (s?['answerDeadline']) : (s?['prepareDeadline']))
            as num?;
    final seconds = deadline == null
        ? 0
        : ((deadline.toInt() - DateTime.now().millisecondsSinceEpoch) / 1000)
              .ceil()
              .clamp(0, 120);
    final records = (s?['records'] as List?) ?? [];
    final record = records.isEmpty ? null : records.first as Map;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !done) {
          unawaited(StrongSessionService.call('strongLeave'));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(t.strong)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (record != null) ...[
                Text(
                  _recordName(record),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _recordDescription(context, record),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              for (final extra in records.skip(1))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_recordName(extra as Map)),
                  subtitle: Text(_recordDescription(context, extra)),
                ),
              const SizedBox(height: 20),
              Text(
                done ? t.unconfirmed : t.seconds(seconds),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (!done && phase != 'task') ...[
                if (phase == 'timeout') Text(t.timeout),
                FilledButton(
                  onPressed: _busy ? null : () => _action('strongBegin'),
                  child: Text(phase == 'timeout' ? t.retry : t.ready),
                ),
              ],
              if (!done && phase == 'task') ...[
                Text(t.step(progress + 1, seq ? 12 : 2)),
                if (seq) ...[
                  Text(
                    '${progress % 6 + 1}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      for (final number in (s!['numbers'] as List))
                        FilledButton.tonal(
                          onPressed: _busy
                              ? null
                              : () => _action('strongAnswer', number as int),
                          child: Text(
                            '$number',
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  Builder(
                    builder: (_) {
                      final q =
                          (s!['questions'] as List)[progress.clamp(0, 1)]
                              as Map;
                      return Text(
                        "${q['a']} ${q['subtract'] == true ? '−' : '+'} ${q['b']} = ?",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _input.isEmpty ? '—' : _input,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final key in [
                        '1',
                        '2',
                        '3',
                        '4',
                        '5',
                        '6',
                        '7',
                        '8',
                        '9',
                        '⌫',
                        '0',
                        '✓',
                      ])
                        FilledButton.tonal(
                          onPressed: _busy
                              ? null
                              : () {
                                  if (key == '✓') {
                                    final n = int.tryParse(_input);
                                    if (n != null) {
                                      unawaited(_action('strongAnswer', n));
                                    }
                                  } else {
                                    setState(
                                      () => _input = key == '⌫'
                                          ? (_input.isEmpty
                                                ? ''
                                                : _input.substring(
                                                    0,
                                                    _input.length - 1,
                                                  ))
                                          : (_input.length < 3
                                                ? _input + key
                                                : _input),
                                    );
                                  }
                                },
                          child: Text(
                            key,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                    ],
                  ),
                ],
                if (s?['wrong'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(t.wrong),
                  ),
              ],
              const SizedBox(height: 24),
              Text(t.timing),
              if (!done)
                Listener(
                  onPointerDown: (_) {
                    _hold?.cancel();
                    _hold = Timer(
                      const Duration(seconds: 5),
                      () => unawaited(_action('strongEmergency')),
                    );
                  },
                  onPointerUp: (_) => _hold?.cancel(),
                  onPointerCancel: (_) => _hold?.cancel(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Semantics(
                      label: t.emergency,
                      button: true,
                      child: Text(t.emergency, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              if (done)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    MaterialLocalizations.of(context).closeButtonLabel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Map _recordMetadata(Map record) {
  final raw = record['metadata'];
  if (raw is String) {
    try {
      return jsonDecode(raw) as Map;
    } catch (_) {
      return record;
    }
  }
  return record;
}

String _recordName(Map record) =>
    '${_recordMetadata(record)['courseName'] ?? record['title'] ?? ''}';

String _recordDescription(BuildContext context, Map record) {
  final meta = _recordMetadata(record);
  final start = DateTime.tryParse('${meta['courseStartAt'] ?? ''}')?.toLocal();
  final end = DateTime.tryParse('${meta['courseEndAt'] ?? ''}')?.toLocal();
  if (start == null) return '${record['bigText'] ?? record['body'] ?? ''}';
  final locale = MaterialLocalizations.of(context);
  final date = locale.formatFullDate(start);
  final time = locale.formatTimeOfDay(TimeOfDay.fromDateTime(start));
  final endTime = end == null
      ? ''
      : ' – ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(end))}';
  return '$date · $time$endTime\n${record['body'] ?? ''}';
}
