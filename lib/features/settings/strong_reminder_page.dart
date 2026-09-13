import 'package:orbit/core/widgets/settings_app_bar.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/services/reminder_audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/providers/app_providers.dart';
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
  static const _channel = MethodChannel('com.must.orbit.orbit/reminders');
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
    if (Platform.isAndroid) _channel.invokeMethod<void>('stopPreview');
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
        setState(() => _value = _value.copyWith(sound: sound));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(AppLocalizations.of(context)!.reminderInvalid),
          ),
        );
      }
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
      child: Scaffold(
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
                  _value.copyWith(
                    durationSeconds: Platform.isAndroid
                        ? int.parse(_duration.text)
                        : _value.durationSeconds,
                  ),
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
                  decoration: InputDecoration(labelText: l.reminderDuration),
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
                  onPressed: () async {
                    try {
                      await _channel.invokeMethod<void>(
                        _playing ? 'stopPreview' : 'previewSound',
                        _value.sound.toJson(),
                      );
                      if (mounted) setState(() => _playing = !_playing);
                    } catch (_) {
                      if (context.mounted) {
                        setState(() => _playing = false);
                        ScaffoldMessenger.of(context).showAppSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 6),
                            content: Text(l.reminderAudioInvalid),
                          ),
                        );
                      }
                    }
                  },
                ),
              ] else
                DropdownButtonFormField<int>(
                  initialValue: _value.windowsSound,
                  decoration: InputDecoration(labelText: l.reminderSound),
                  items: [
                    for (var n = 1; n <= 10; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text('${l.reminderSound} $n'),
                      ),
                  ],
                  onChanged: (n) {
                    if (n != null) {
                      setState(() => _value = _value.copyWith(windowsSound: n));
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
