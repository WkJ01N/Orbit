import 'package:orbit/features/reminder/emergency_hold_button.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/providers/database_providers.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/wake_text.dart';
import 'package:orbit/models/windows_reminder_text.dart';
import 'package:orbit/services/strong_session_service.dart';

final strongConfirmationVisibleProvider = StateProvider<bool>((ref) => false);

final strongSessionProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

final strongSessionActionProvider = Provider(
  (ref) => StrongSessionService.call,
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
  String? _lastStored, _lastAcknowledged, _lastPresented;
  bool _opening = false;
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
          _lastStored = jsonEncode(state);
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
      final request =
          '${state?['id']}:${state?['openRequest'] ?? (state?['opened'] == true ? 1 : 0)}';
      final requested =
          ((state?['openRequest'] as num?)?.toInt() ??
              (state?['opened'] == true ? 1 : 0)) >
          0;
      if (_showing && Platform.isWindows) _lastPresented = request;
      if ((!Platform.isWindows || (requested && request != _lastPresented)) &&
          await _visible() &&
          StrongSessionService.active(state) &&
          !_showing &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
          widget.navigatorKey.currentState != null) {
        if (!Platform.isWindows) {
          state = await StrongSessionService.call('strongOpen');
        }
        _lastPresented = request;
        if (!mounted) return;
        ref.read(strongSessionProvider.notifier).state = state;
        setState(() => _showing = true);
        ref.read(strongConfirmationVisibleProvider.notifier).state = true;
        unawaited(
          widget.navigatorKey.currentState!
              .push<void>(
                MaterialPageRoute(
                  builder: (_) => const StrongConfirmationPage(),
                ),
              )
              .whenComplete(() {
                if (mounted) {
                  setState(() => _showing = false);
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
  Widget build(BuildContext context) {
    final state = ref.watch(strongSessionProvider);
    final show =
        Platform.isWindows && StrongSessionService.active(state) && !_showing;
    final t = WindowsReminderText.of(context);
    return Column(
      children: [
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: show
              ? SafeArea(
                  bottom: false,
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_outlined),
                          const SizedBox(width: 12),
                          Expanded(child: Text(t.ringing)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FilledButton(
                              onPressed: _opening
                                  ? null
                                  : () async {
                                      setState(() => _opening = true);
                                      try {
                                        await StrongSessionService.call(
                                          'strongOpen',
                                        );
                                        await _poll();
                                      } catch (error) {
                                        debugPrint(
                                          'Strong reminder open failed: $error',
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _opening = false);
                                        }
                                      }
                                    },
                              child: Text(t.open),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
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
  Future<void> _action(String action, [int? answer]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await ref.read(strongSessionActionProvider)(
        action,
        answer == null ? null : {'answer': answer},
      );
      if (!mounted) return;
      if (next == null) {
        throw StateError('Strong reminder did not return a state');
      }
      ref.read(strongSessionProvider.notifier).state = next;
      setState(() => _input = '');
      if (['completed', 'emergency'].contains(next['phase'])) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WakeText.of(context);
    final s = ref.watch(strongSessionProvider);
    final phase = s?['phase'];
    final done = !StrongSessionService.active(s);
    final progress = (s?['progress'] as num?)?.toInt() ?? 0;
    final tasks = s?['tasks'] as List?;
    final modern = tasks != null && tasks.isNotEmpty;
    final taskIndex = (s?['taskIndex'] as num?)?.toInt() ?? 0;
    final settings = s?['settings'] as Map?;
    final questions = s?['questions'] as List? ?? [];
    final currentTask = modern
        ? tasks[taskIndex.clamp(0, tasks.length - 1)] as Map
        : settings?['dismissTask'] == 'sequence'
        ? {'type': 'sequence', 'numbers': s?['numbers'] ?? []}
        : questions.isEmpty
        ? <String, dynamic>{}
        : questions[progress.clamp(0, questions.length - 1)] as Map;
    final seq = currentTask['type'] == 'sequence';
    final numbers = currentTask['numbers'] as List? ?? [];
    final numberCount = numbers.isEmpty ? 6 : numbers.length;
    final rounds =
        ((settings?[seq ? 'sequenceRounds' : 'arithmeticRounds'] as num?)
                    ?.toInt() ??
                2)
            .clamp(1, 10);
    final total = modern
        ? tasks.length
        : seq
        ? rounds
        : questions.length;
    final roundIndex = modern
        ? taskIndex
        : seq
        ? progress ~/ numberCount
        : progress;
    final step = modern
        ? (s?['taskProgress'] as num?)?.toInt() ?? 0
        : progress % numberCount;
    final choices = currentTask['choices'] as List? ?? [];
    final operation = switch (currentTask['operator']) {
      'multiply' => '×',
      'subtract' => '−',
      'add' => '+',
      _ => currentTask['subtract'] == true ? '−' : '+',
    };
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
                Text(t.round(roundIndex + 1, total)),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Column(
                    key: ValueKey('$roundIndex-$seq'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (seq) ...[
                        Text(t.sequenceHint(numberCount)),
                        Text(t.step(step + 1, numberCount)),
                        Text(
                          '${step + 1}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        _answerGrid(
                          numbers,
                          keyPrefix: 'strong-number',
                          onAnswer: (n) => _action('strongAnswer', n),
                        ),
                      ] else ...[
                        Text(
                          "${currentTask['a']} $operation ${currentTask['b']} = ?",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (choices.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _answerGrid(
                            choices,
                            keyPrefix: 'strong-choice',
                            preferredColumns: 3,
                            onAnswer: (n) => _action('strongAnswer', n),
                          ),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _input.isEmpty ? '—' : _input,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) => GridView.count(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio:
                                  (constraints.maxWidth - 16) / 3 / 64,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
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
                                    key: ValueKey('strong-key-$key'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.all(8),
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            if (key == '✓') {
                                              final n = int.tryParse(_input);
                                              if (n != null) {
                                                unawaited(
                                                  _action('strongAnswer', n),
                                                );
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
                                                    : (_input.length < 5
                                                          ? _input + key
                                                          : _input),
                                              );
                                            }
                                          },
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        key,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (s?['wrong'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(t.wrong),
                  ),
              ],
              const SizedBox(height: 24),
              Text(t.timing),
              if (!done)
                EmergencyHoldButton(
                  enabled: !_busy,
                  onComplete: () => _action('strongEmergency'),
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

  Widget _answerGrid(
    List values, {
    required String keyPrefix,
    required Future<void> Function(int) onAnswer,
    int? preferredColumns,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final desired =
          preferredColumns ??
          (values.length <= 4
              ? 2
              : values.length <= 9
              ? 3
              : values.length <= 16
              ? 4
              : 5);
      final columns = desired.clamp(
        2,
        ((constraints.maxWidth + 8) / 64).floor().clamp(2, 5),
      );
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              height: 64,
              child: FilledButton.tonal(
                key: ValueKey('$keyPrefix-$value'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(8)),
                onPressed: _busy
                    ? null
                    : () => onAnswer((value as num).toInt()),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$value', style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
        ],
      );
    },
  );
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
