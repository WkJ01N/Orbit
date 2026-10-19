import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/v162_text.dart';
import 'package:orbit/features/settings/typography_settings_page.dart';
import 'package:orbit/models/typography_text.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/motion/launch_motion.dart';
import 'package:orbit/core/routing/app_shell.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/features/settings/avatar_crop_dialog.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/models/launch_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/launch_providers.dart';
import 'package:orbit/providers/course_color_providers.dart';
import 'package:orbit/services/grid_builder.dart';
import 'package:orbit/services/launch_icon_service.dart';

class LaunchSettingsPage extends ConsumerStatefulWidget {
  const LaunchSettingsPage({super.key});
  @override
  ConsumerState<LaunchSettingsPage> createState() => _LaunchSettingsPageState();
}

class _LaunchSettingsPageState extends ConsumerState<LaunchSettingsPage> {
  bool _busy = false;

  Future<void> _save(LaunchSettings next, {String? newFile}) async {
    final previous = ref.read(launchSettingsProvider);
    try {
      await ref
          .read(launchSettingsProvider.notifier)
          .update(
            (current) => current.copyWith(
              iconPath: next.iconPath,
              clearIcon: next.iconPath == null,
            ),
          );
    } catch (_) {
      await deleteLaunchIcon(newFile);
      rethrow;
    }
    if (previous.iconPath != next.iconPath) {
      await deleteLaunchIcon(previous.iconPath);
    }
  }

  Future<void> _update(LaunchSettings Function(LaunchSettings) change) async {
    try {
      await ref.read(launchSettingsProvider.notifier).update(change);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showAppSnackBar(SnackBar(content: Text(LaunchText(context).failed)));
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: PageModule(child: Text(LaunchText(context).failed)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() => _run(() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    if (file.size > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: PageModule(child: Text(LaunchText(context).tooLarge)),
        ),
      );
      return;
    }
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || !mounted) return;
    final cropped = await showAvatarCropDialog(
      context,
      bytes,
      circular: true,
      title: LaunchText(context).crop,
    );
    if (cropped == null || !mounted) return;
    final path = await saveLaunchIcon(cropped);
    if (!mounted) {
      await deleteLaunchIcon(path);
      return;
    }
    await _save(
      ref.read(launchSettingsProvider).copyWith(iconPath: path),
      newFile: path,
    );
  });

  @override
  Widget build(BuildContext context) {
    final text = LaunchText(context);
    final settings = ref.watch(launchSettingsProvider);
    final v = V162Text.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: PageModule(child: Text(v.animationTitle))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PageModule(
                key: const ValueKey('launch-setting-1'),
                child: SwitchListTile(
                  title: Text(v.brandAnimation),
                  value: settings.brandEnabled,
                  onChanged: (b) => _update((s) => s.copyWith(brandEnabled: b)),
                ),
              ),
              PageModule(
                key: const ValueKey('launch-setting-2'),
                child: Text(
                  v.pageAnimations,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (var i = 0; i < 4; i++)
                PageModule(
                  key: ValueKey('launch-page-$i'),
                  child: SwitchListTile(
                    title: Text(
                      [
                        l10n.navGrid,
                        l10n.navUpcoming,
                        l10n.navImport,
                        l10n.navSettings,
                      ][i],
                    ),
                    value: settings.pageEnabled[i],
                    onChanged: (b) => _update((s) {
                      final pages = [...s.pageEnabled];
                      pages[i] = b;
                      return s.copyWith(pageEnabled: pages);
                    }),
                  ),
                ),
              const Divider(),
              PageModule(
                key: const ValueKey('launch-setting-3'),
                child: Text(
                  v.animationTriggers,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PageModule(
                key: const ValueKey('launch-setting-4'),
                child: SwitchListTile(
                  title: Text(v.onStartup),
                  value: settings.onStartup,
                  onChanged: (b) => _update((s) => s.copyWith(onStartup: b)),
                ),
              ),
              PageModule(
                key: const ValueKey('launch-setting-5'),
                child: SwitchListTile(
                  title: Text(v.onResume),
                  value: settings.onResume,
                  onChanged: (b) => _update((s) => s.copyWith(onResume: b)),
                ),
              ),
              PageModule(
                key: const ValueKey('launch-setting-6'),
                child: ListTile(
                  title: Text(text.transition),
                  trailing: DropdownButton<PageTransitionStyle>(
                    value: settings.pageTransitionStyle,
                    items: [
                      DropdownMenuItem(
                        value: PageTransitionStyle.compact,
                        child: Text(text.compact),
                      ),
                      DropdownMenuItem(
                        value: PageTransitionStyle.fluid,
                        child: Text(text.fluid),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _update((s) => s.copyWith(pageTransitionStyle: value));
                      }
                    },
                  ),
                ),
              ),
              if (settings.onPageSwitch)
                PageModule(
                  key: const ValueKey('launch-setting-7'),
                  child: ListTile(
                    title: Text(text.speed),
                    trailing: DropdownButton<PageTransitionSpeed>(
                      value: settings.pageTransitionSpeed,
                      items: [
                        for (final speed in PageTransitionSpeed.values)
                          DropdownMenuItem(
                            value: speed,
                            child: Text(
                              [
                                text.fast,
                                text.standard,
                                text.relaxed,
                              ][speed.index],
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _update(
                            (s) => s.copyWith(pageTransitionSpeed: value),
                          );
                        }
                      },
                    ),
                  ),
                ),
              const Divider(),
              PageModule(
                key: const ValueKey('launch-setting-8'),
                child: ListTile(
                  leading: const Icon(Icons.font_download_outlined),
                  title: Text(TypographyText(context).launch),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const FontPickerPage(launch: true),
                    ),
                  ),
                ),
              ),
              PageModule(
                key: const ValueKey('launch-icon'),
                child: Center(child: LaunchIcon(path: settings.iconPath)),
              ),
              const SizedBox(height: 16),
              PageModule(
                key: const ValueKey('launch-setting-9'),
                child: Text(
                  text.icon,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 4),
              PageModule(child: Text(text.iconHint)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  PageModule(
                    key: const ValueKey('launch-setting-10'),
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(text.choose),
                    ),
                  ),
                  PageModule(
                    key: const ValueKey('launch-setting-11'),
                    child: TextButton(
                      onPressed: _busy || settings.iconPath == null
                          ? null
                          : () => _run(
                              () => _save(settings.copyWith(clearIcon: true)),
                            ),
                      child: Text(text.restore),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              PageModule(
                key: const ValueKey('launch-setting-12'),
                child: Text(
                  text.cards,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              for (final mode in CardEntranceMode.values)
                PageModule(
                  key: ValueKey('launch-card-mode-${mode.name}'),
                  child: ListTile(
                    key: ValueKey('launch-mode-${mode.name}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      settings.cardEntrance == mode
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(
                      mode == CardEntranceMode.edge ? text.edge : text.nearby,
                    ),
                    onTap: () => _update((s) => s.copyWith(cardEntrance: mode)),
                  ),
                ),
              PageModule(
                key: const ValueKey('launch-setting-13'),
                child: Text(
                  text.stagger,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 24),
              PageModule(
                key: const ValueKey('launch-setting-14'),
                child: FilledButton.icon(
                  key: const Key('launch-preview'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _LaunchPreview(),
                          ),
                        ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(text.preview),
                ),
              ),
              const SizedBox(height: 12),
              PageModule(
                key: const ValueKey('launch-setting-15'),
                child: Text(
                  text.hint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The production shell and timetable run with isolated navigation and sample
/// data. Previewing never changes the real selected week or starts reminders.
class _LaunchPreview extends ConsumerStatefulWidget {
  const _LaunchPreview();
  @override
  ConsumerState<_LaunchPreview> createState() => _LaunchPreviewState();
}

class _LaunchPreviewState extends ConsumerState<_LaunchPreview> {
  late final DateTime _monday = weekStartFor(DateTime.now());
  late final List<CourseSession> _samples = [
    for (var day = 0; day < 5; day++)
      for (var item = 0; item < 2; item++)
        CourseSession(
          id: 'preview-$day-$item',
          classType: '',
          room: 'A${day + 1}01',
          date: _monday.add(Duration(days: day)),
          weekday: day + 1,
          courseName: [
            'Mathematics',
            'Physics',
            'Design',
            'English',
            'Computing',
          ][day],
          courseCode: 'ORBIT$day',
          section: '1',
          startAt: _monday.add(
            Duration(days: day, hours: 9 + item * 4 + day % 2),
          ),
          endAt: _monday.add(
            Duration(days: day, hours: 11 + item * 4 + day % 2),
          ),
          teachers: const [],
          faculty: '',
          semester: '',
        ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: PageModule(child: Text(LaunchText(context).preview))),
    body: ProviderScope(
      overrides: [
        launchAnimationsEnabledProvider.overrideWithValue(true),
        appNavIndexProvider.overrideWith((ref) => 0),
        selectedScheduleDateProvider.overrideWith((ref) => _monday),
        selectedWeekStartProvider.overrideWith((ref) => _monday),
        currentTimeProvider.overrideWith(
          () => _PreviewTime(_monday.add(const Duration(hours: 10))),
        ),
        sessionsProvider.overrideWith((ref) async => _samples),
        weekGridProvider.overrideWithValue(
          GridBuilder().buildWeekGrid(weekStart: _monday, sessions: _samples),
        ),
        resolvedAutomaticCourseColorIdsProvider.overrideWithValue(const {}),
        deadlinesProvider.overrideWith((ref) async => []),
        strongCourseIdsProvider.overrideWith((ref) async => {}),
      ],
      child: const OrbitLaunchHost(child: IgnorePointer(child: AppShell())),
    ),
  );
}

class _PreviewTime extends CurrentTimeNotifier {
  _PreviewTime(this.now);
  final DateTime now;
  @override
  DateTime build() => now;
}
