import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/models/wake_text.dart';
import 'package:orbit/core/widgets/settings_app_bar.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'dart:io';
import 'dart:async';
import 'package:orbit/models/windows_reminder_text.dart';
import 'package:orbit/services/strong_session_service.dart';
import 'package:orbit/models/orbit_feature_text.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/services/reminder_audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/features/settings/reminder_course_picker.dart';
import 'package:orbit/core/widgets/settings_group.dart';

class StrongReminderPage extends ConsumerStatefulWidget {
  const StrongReminderPage({
    super.key,
    required this.initial,
    this.showTargets = true,
  });
  final StrongReminderSettings initial;
  final bool showTargets;
  @override
  ConsumerState<StrongReminderPage> createState() => _StrongReminderPageState();
}

class _StrongReminderPageState extends ConsumerState<StrongReminderPage> {
  static MethodChannel get _channel => StrongSessionService.channel;
  Timer? _previewTimer;
  bool _previewBusy = false;
  late StrongReminderSettings _value;
  late TextEditingController _duration;
  final _form = GlobalKey<FormState>();
  bool _playing = false, _allowPop = false;
  late String _initial;
  Map<String, String> _aliases = {};
  Map<String, List<String>> _memberships = {};
  Future<void> _loadIdentities() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final aliases = await db.reminderSessionAliases();
      final memberships = await db.reminderSeriesMemberships();
      if (mounted) {
        setState(() {
          _aliases = aliases;
          _memberships = memberships;
        });
      }
    } catch (error) {
      debugPrint('Strong reminder identity preview unavailable: $error');
    }
  }

  String _snapshot() => jsonEncode(_value.toJson()) + _duration.text;
  Future<void> _back() async {
    final l = AppLocalizations.of(context)!;
    final discard =
        _initial == _snapshot() ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.reminderDiscard),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l.reminderKeepEditing),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(ctx).colorScheme.error,
                    ),
                    child: Text(l.reminderDiscardAction),
                  ),
                ],
              ),
            ) ==
            true;
    if (discard && mounted) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
    _duration = TextEditingController(text: '${_value.durationSeconds}');
    _initial = _snapshot();
    if (widget.showTargets) _loadIdentities();
  }

  @override
  void dispose() {
    _duration.dispose();
    _previewTimer?.cancel();
    if (Platform.isAndroid || Platform.isWindows) {
      unawaited(
        _channel.invokeMethod<void>('stopPreview').catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  Future<void> _audio(bool system) async {
    try {
      ReminderSound? sound;
      if (system) {
        final json = await _channel.invokeMapMethod<String, dynamic>(
          'chooseRingtone',
        );
        if (json != null) sound = ReminderSound.fromJson(json);
      } else {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'm4a', 'wav'],
        );
        final path = picked?.files.single.path;
        if (path != null) {
          sound = await ReminderAudioService.importFile(File(path));
        }
      }
      if (sound != null && mounted) {
        setState(
          () => _value = _value.copyWith(
            sound: sound,
            soundEnabled: Platform.isWindows ? true : _value.soundEnabled,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(AppLocalizations.of(context)!.reminderAudioInvalid),
          ),
        );
      }
    }
  }

  Future<void> _preview() async {
    if (_previewBusy) return;
    setState(() => _previewBusy = true);
    try {
      final wasPlaying = _playing;
      await _channel.invokeMethod<void>(
        wasPlaying ? 'stopPreview' : 'previewSound',
        Platform.isWindows
            ? {
                'sound': _value.sound.toJson(),
                'windowsSound': _value.windowsSound,
              }
            : _value.sound.toJson(),
      );
      _previewTimer?.cancel();
      if (mounted) setState(() => _playing = !wasPlaying);
      if (Platform.isWindows && !wasPlaying) {
        _previewTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) setState(() => _playing = false);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _playing = false);
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reminderAudioInvalid),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (popped, result) {
        if (!popped) _back();
      },
      child: BackgroundScaffold(
        appBar: settingsAppBar(
          context,
          title: l.reminderStrongConfig,
          actions: [
            TextButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                setState(() => _allowPop = true);
                Navigator.pop(
                  context,
                  _value.copyWith(durationSeconds: int.parse(_duration.text)),
                );
              },
              child: Text(l.reminderSave),
            ),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(l.reminderStrongDescription),
              SettingsGroup(
                title: WakeText.of(context).task,
                horizontalMargin: 0,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<StrongDismissTask>(
                          initialValue: _value.dismissTask,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: StrongDismissTask.arithmetic,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(WakeText.of(context).arithmetic),
                              ),
                            ),
                            DropdownMenuItem(
                              value: StrongDismissTask.sequence,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(WakeText.of(context).sequence),
                              ),
                            ),
                            DropdownMenuItem(
                              value: StrongDismissTask.mixed,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(WakeText.of(context).mixed),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(
                                () => _value = _value.copyWith(dismissTask: v),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          key: ValueKey(_value.dismissTask),
                          initialValue: switch (_value.dismissTask) {
                            StrongDismissTask.arithmetic =>
                              _value.arithmeticRounds,
                            StrongDismissTask.sequence => _value.sequenceRounds,
                            StrongDismissTask.mixed => _value.mixedRounds,
                          },
                          decoration: InputDecoration(
                            labelText: WakeText.of(context).rounds,
                          ),
                          items: [
                            for (var n = 1; n <= 10; n++)
                              DropdownMenuItem(value: n, child: Text('$n')),
                          ],
                          onChanged: (n) {
                            if (n != null) {
                              setState(
                                () => _value = switch (_value.dismissTask) {
                                  StrongDismissTask.arithmetic =>
                                    _value.copyWith(arithmeticRounds: n),
                                  StrongDismissTask.sequence => _value.copyWith(
                                    sequenceRounds: n,
                                  ),
                                  StrongDismissTask.mixed => _value.copyWith(
                                    mixedRounds: n,
                                  ),
                                },
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_value.dismissTask == StrongDismissTask.mixed) ...[
                          Text(
                            WakeText.of(context).mixedHint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_value.dismissTask !=
                            StrongDismissTask.arithmetic) ...[
                          DropdownButtonFormField<int>(
                            key: const Key('strong-number-count'),
                            initialValue: _value.sequenceNumberCount,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: WakeText.of(context).numberCount,
                            ),
                            items: [
                              for (var n = 4; n <= 25; n++)
                                DropdownMenuItem(value: n, child: Text('$n')),
                            ],
                            onChanged: (n) {
                              if (n != null) {
                                setState(
                                  () => _value = _value.copyWith(
                                    sequenceNumberCount: n,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_value.dismissTask !=
                            StrongDismissTask.sequence) ...[
                          DropdownButtonFormField<ArithmeticDifficulty>(
                            key: const Key('strong-arithmetic-difficulty'),
                            initialValue: _value.arithmeticDifficulty,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: WakeText.of(context).difficulty,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: ArithmeticDifficulty.simple,
                                child: Text(WakeText.of(context).simple),
                              ),
                              DropdownMenuItem(
                                value: ArithmeticDifficulty.medium,
                                child: Text(WakeText.of(context).medium),
                              ),
                              DropdownMenuItem(
                                value: ArithmeticDifficulty.hard,
                                child: Text(WakeText.of(context).hard),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(
                                  () => _value = _value.copyWith(
                                    arithmeticDifficulty: v,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            WakeText.of(context).difficultyHint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<ArithmeticAnswerMode>(
                            key: const Key('strong-arithmetic-answer-mode'),
                            initialValue: _value.arithmeticAnswerMode,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: WakeText.of(context).answerMode,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: ArithmeticAnswerMode.input,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(WakeText.of(context).manualInput),
                                ),
                              ),
                              DropdownMenuItem(
                                value: ArithmeticAnswerMode.choice3,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(WakeText.of(context).choice3),
                                ),
                              ),
                              DropdownMenuItem(
                                value: ArithmeticAnswerMode.choice6,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(WakeText.of(context).choice6),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(
                                  () => _value = _value.copyWith(
                                    arithmeticAnswerMode: v,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          initialValue: '${_value.prepareSeconds}',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: WakeText.of(context).prepare,
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n < 5 || n > 60 ? '5–60' : null;
                          },
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null) {
                              setState(
                                () => _value = _value.copyWith(
                                  prepareSeconds: n.clamp(5, 60),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: '${_value.answerSeconds}',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: WakeText.of(context).answer,
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n < 10 || n > 120
                                ? '10–120'
                                : null;
                          },
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null) {
                              setState(
                                () => _value = _value.copyWith(
                                  answerSeconds: n.clamp(10, 120),
                                ),
                              );
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(WakeText.of(context).timing),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (widget.showTargets) ...[
                SwitchListTile(
                  title: Text(OrbitFeatureText.of(context).onlyFirst),
                  value: _value.onlyFirstClass,
                  onChanged: (v) => setState(
                    () => _value = _value.copyWith(onlyFirstClass: v),
                  ),
                ),
                if (_value.onlyFirstClass) ...[
                  DropdownButtonFormField<FirstClassMode>(
                    isExpanded: true,
                    initialValue: _value.firstClassMode,
                    items: [
                      for (final m in FirstClassMode.values)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m == FirstClassMode.firstPeriod
                                ? OrbitFeatureText.of(context).firstPeriod
                                : OrbitFeatureText.of(context).beforeTime,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (m) {
                      if (m != null) {
                        setState(
                          () => _value = _value.copyWith(firstClassMode: m),
                        );
                      }
                    },
                  ),
                  ListTile(
                    title: Text(OrbitFeatureText.of(context).cutoff),
                    trailing: Text(
                      TimeOfDay(
                        hour: _value.cutoffMinute ~/ 60,
                        minute: _value.cutoffMinute % 60,
                      ).format(context),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: _value.cutoffMinute ~/ 60,
                          minute: _value.cutoffMinute % 60,
                        ),
                      );
                      if (time != null && mounted) {
                        setState(
                          () => _value = _value.copyWith(
                            cutoffMinute: time.hour * 60 + time.minute,
                          ),
                        );
                      }
                    },
                  ),
                  if (_value.firstClassMode == FirstClassMode.firstPeriod)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue:
                          (ref
                                      .watch(importConfigurationProvider)
                                      .valueOrNull
                                      ?.periodTimes ??
                                  [])
                              .any((p) => p.id == _value.periodTimePlanId)
                          ? _value.periodTimePlanId
                          : '',
                      decoration: InputDecoration(
                        labelText: OrbitFeatureText.of(context).plan,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(OrbitFeatureText.of(context).automatic),
                        ),
                        for (final p
                            in ref
                                    .watch(importConfigurationProvider)
                                    .valueOrNull
                                    ?.periodTimes ??
                                [])
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) => setState(
                        () => _value = _value.copyWith(
                          periodTimePlanId: id,
                          clearPeriodPlan: id == '',
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(OrbitFeatureText.of(context).firstHint),
                  ),
                ],
              ],
              if (widget.showTargets) ...[
                SettingsGroup(
                  horizontalMargin: 0,
                  title: l.strongTargets,
                  children: [
                    for (final type in StrongReminderType.values)
                      CheckboxListTile(
                        title: Text(
                          [
                            l.strongClassLead,
                            l.strongCheckIn,
                            l.strongSummary,
                            l.strongCustom,
                          ][type.index],
                        ),
                        value: _value.types.contains(type),
                        onChanged: (v) => setState(() {
                          final types = {..._value.types};
                          v == true ? types.add(type) : types.remove(type);
                          _value = _value.copyWith(types: types);
                        }),
                      ),
                  ],
                ),
                if (_value.types.contains(StrongReminderType.custom))
                  SettingsGroup(
                    horizontalMargin: 0,
                    title: l.strongCustom,
                    children: [
                      SwitchListTile(
                        title: Text(l.strongAllRules),
                        value: _value.ruleIds == null,
                        onChanged: (v) => setState(
                          () => _value = _value.copyWith(
                            allRules: v,
                            ruleIds: v
                                ? null
                                : (ref
                                              .read(reminderSettingsProvider)
                                              .value
                                              ?.customRules ??
                                          [])
                                      .map((r) => r.id)
                                      .toSet(),
                          ),
                        ),
                      ),
                      if (_value.ruleIds != null)
                        for (final rule
                            in ref
                                    .watch(reminderSettingsProvider)
                                    .value
                                    ?.customRules ??
                                <CustomReminderRule>[])
                          CheckboxListTile(
                            title: Text(rule.name),
                            subtitle: rule.strength == ReminderStrength.inherit
                                ? null
                                : Text(
                                    rule.strength == ReminderStrength.strong
                                        ? l.reminderStrong
                                        : l.reminderNormal,
                                  ),
                            value: _value.ruleIds!.contains(rule.id),
                            onChanged: (v) => setState(() {
                              final ids = {..._value.ruleIds!};
                              v == true
                                  ? ids.add(rule.id)
                                  : ids.remove(rule.id);
                              _value = _value.copyWith(ruleIds: ids);
                            }),
                          ),
                    ],
                  ),
                SettingsGroup(
                  horizontalMargin: 0,
                  title: l.strongCourses,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<ReminderCourseScope>(
                        initialValue: _value.courseScope,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l.reminderScope),
                        items: [
                          for (final scope in ReminderCourseScope.values)
                            DropdownMenuItem(
                              value: scope,
                              child: Text(
                                [
                                  l.reminderAll,
                                  l.reminderSeries,
                                  l.reminderSessions,
                                ][scope.index],
                              ),
                            ),
                        ],
                        onChanged: (scope) {
                          if (scope != null) {
                            setState(
                              () => _value = _value.copyWith(
                                courseScope: scope,
                                courseKeys: [],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    if (_value.courseScope != ReminderCourseScope.all)
                      ListTile(
                        title: Text(l.strongCourses),
                        subtitle: Text('${_value.courseKeys.length}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final sessions = await ref.read(
                            sessionsProvider.future,
                          );
                          if (!context.mounted) return;
                          final keys = await showReminderCourseSelection(
                            context,
                            sessions: sessions,
                            scope: _value.courseScope,
                            selected: _value.courseKeys,
                            aliases: _aliases,
                            memberships: _memberships,
                          );
                          if (keys != null && mounted) {
                            setState(
                              () => _value = _value.copyWith(courseKeys: keys),
                            );
                          }
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l.strongSummaryNotice),
                    ),
                  ],
                ),
                Text(l.strongRuleOverrideNotice),
              ],
              if (Platform.isWindows)
                TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: WakeText.of(context).roundDuration,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 5 || n > 300 ? '5–300' : null;
                  },
                ),
              if (Platform.isAndroid) ...[
                SwitchListTile(
                  title: Text(l.reminderSound),
                  value: _value.soundEnabled,
                  onChanged: (v) => setState(
                    () => _value = _value.copyWith(
                      soundEnabled: v,
                      vibrationEnabled: !v ? true : _value.vibrationEnabled,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(l.reminderVibration),
                  value: _value.vibrationEnabled,
                  onChanged: (v) => setState(
                    () => _value = _value.copyWith(
                      vibrationEnabled: v,
                      soundEnabled: !v ? true : _value.soundEnabled,
                    ),
                  ),
                ),
                TextFormField(
                  controller: _duration,
                  decoration: InputDecoration(
                    labelText: WakeText.of(context).roundDuration,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (s) {
                    final n = int.tryParse(s ?? '');
                    return n == null || n < 5 || n > 300 ? '5–300' : null;
                  },
                ),
                ListTile(
                  title: Text(l.reminderSystemSound),
                  subtitle: Text(_value.sound.name),
                  onTap: () => _audio(true),
                ),
                ListTile(
                  title: Text(l.reminderImportSound),
                  onTap: () => _audio(false),
                ),
                TextButton.icon(
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                  label: Text(l.reminderPreviewSound),
                  onPressed: _previewBusy ? null : _preview,
                ),
              ] else if (Platform.isWindows) ...[
                SwitchListTile(
                  title: Text(l.reminderSound),
                  value: _value.soundEnabled,
                  onChanged: (v) =>
                      setState(() => _value = _value.copyWith(soundEnabled: v)),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: WindowsReminderText.of(context).source,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _value.sound.kind,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: 'system',
                          child: Text(WindowsReminderText.of(context).system),
                        ),
                        DropdownMenuItem(
                          value: 'file',
                          child: Text(WindowsReminderText.of(context).imported),
                        ),
                      ],
                      onChanged: (v) async {
                        if (_playing) await _preview();
                        if (v == 'file') {
                          await _audio(false);
                        } else if (v == 'system') {
                          setState(
                            () => _value = _value.copyWith(
                              sound: const ReminderSound(),
                              soundEnabled: true,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                if (_value.sound.kind == 'system') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _value.windowsSound,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.reminderSystemSound,
                    ),
                    items: [
                      for (var n = 1; n <= 10; n++)
                        DropdownMenuItem(
                          value: n,
                          child: Text('${l.reminderSound} $n'),
                        ),
                    ],
                    onChanged: (n) {
                      if (n != null) {
                        setState(
                          () => _value = _value.copyWith(windowsSound: n),
                        );
                      }
                    },
                  ),
                ],
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.audio_file_outlined),
                  title: Text(l.reminderImportSound),
                  subtitle: Text(
                    _value.sound.kind == 'file'
                        ? _value.sound.name
                        : WindowsReminderText.of(context).selectFile,
                  ),
                  onTap: () async {
                    if (_playing) await _preview();
                    await _audio(false);
                  },
                ),
                TextButton.icon(
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    _playing
                        ? WindowsReminderText.of(context).stopPreview
                        : WindowsReminderText.of(context).preview,
                  ),
                  onPressed: _previewBusy ? null : _preview,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
