import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/core/widgets/settings_choice_tile.dart';
import 'package:orbit/core/widgets/settings_group.dart';
import 'package:orbit/models/android_widget_settings.dart';
import 'package:orbit/models/android_widget_text.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/providers/widget_providers.dart';
import 'package:orbit/services/android_widget_service.dart';

class AndroidWidgetSettingsPage extends ConsumerStatefulWidget {
  const AndroidWidgetSettingsPage({super.key});

  @override
  ConsumerState<AndroidWidgetSettingsPage> createState() =>
      _AndroidWidgetSettingsPageState();
}

class _AndroidWidgetSettingsPageState
    extends ConsumerState<AndroidWidgetSettingsPage> {
  AndroidWidgetStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await ref.read(androidWidgetServiceProvider).getStatus();
    if (mounted) {
      setState(() => _status = status);
    }
  }

  Future<void> _pin(AndroidWidgetKind kind) async {
    final text = AndroidWidgetText.of(context);
    final accepted = await ref
        .read(androidWidgetServiceProvider)
        .requestPin(kind);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text(accepted ? text.pinAccepted : text.pinManualHint)),
    );
    await _loadStatus();
  }

  Future<void> _refreshNow() async {
    final text = AndroidWidgetText.of(context);
    await ref.read(androidWidgetServiceProvider).refreshWidgets();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(SnackBar(content: Text(text.refreshedToast)));
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final text = AndroidWidgetText.of(context);
    final settings = ref.watch(androidWidgetSettingsProvider);
    final notifier = ref.read(androidWidgetSettingsProvider.notifier);
    final status = _status;

    return Scaffold(
      appBar: BackgroundAppBar(child: AppBar(title: Text(text.title))),
      body: BackgroundRegion(
        region: BackgroundRegionId.content,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SettingsGroup(
              title: text.previewSection,
              children: [_WidgetPreviewCard(settings: settings, text: text)],
            ),
            SettingsGroup(
              title: text.addSection,
              children: [
                PageModule(
                  child: ListTile(
                    key: const Key('pin-next-class-widget'),
                    leading: const Icon(Icons.view_agenda_outlined),
                    title: Text(text.nextClassTitle),
                    subtitle: Text(
                      status == null
                          ? text.nextClassSubtitle
                          : '${text.nextClassSubtitle}\n${text.addedCount(status.nextClassCount)}',
                    ),
                    isThreeLine: status != null,
                    trailing: status?.canPin == true
                        ? FilledButton.tonal(
                            onPressed: () => _pin(AndroidWidgetKind.nextClass),
                            child: Text(text.addAction),
                          )
                        : null,
                  ),
                ),
                PageModule(
                  child: ListTile(
                    key: const Key('pin-today-schedule-widget'),
                    leading: const Icon(Icons.calendar_view_day_outlined),
                    title: Text(text.todayScheduleTitle),
                    subtitle: Text(
                      status == null
                          ? text.todayScheduleSubtitle
                          : '${text.todayScheduleSubtitle}\n${text.addedCount(status.todayScheduleCount)}',
                    ),
                    isThreeLine: status != null,
                    trailing: status?.canPin == true
                        ? FilledButton.tonal(
                            onPressed: () =>
                                _pin(AndroidWidgetKind.todaySchedule),
                            child: Text(text.addAction),
                          )
                        : null,
                  ),
                ),
                if (status != null && !status.canPin)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      text.pinManualHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            SettingsGroup(
              title: text.displaySection,
              children: [
                PageModule(
                  child: SwitchListTile(
                    key: const Key('widget-show-deadlines-switch'),
                    title: Text(text.showDeadlinesTitle),
                    subtitle: Text(text.showDeadlinesSubtitle),
                    value: settings.showDeadlines,
                    onChanged: notifier.setShowDeadlines,
                  ),
                ),
                SettingsChoiceTile(
                  title: Text(text.lookaheadTitle),
                  trailing: DropdownButton<int>(
                    key: const Key('widget-lookahead-dropdown'),
                    value: settings.deadlineLookaheadDays,
                    underline: const SizedBox.shrink(),
                    onChanged: settings.showDeadlines
                        ? (value) {
                            if (value != null) {
                              notifier.setDeadlineLookaheadDays(value);
                            }
                          }
                        : null,
                    items: AndroidWidgetSettings.allowedLookaheadDays
                        .map(
                          (days) => DropdownMenuItem<int>(
                            value: days,
                            child: Text(text.lookaheadDaysLabel(days)),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            text.opacityTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            text.opacitySubtitle(settings.backgroundOpacity),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      Slider(
                        key: const Key('widget-opacity-slider'),
                        value: settings.backgroundOpacity.toDouble(),
                        min: AndroidWidgetSettings.minOpacity.toDouble(),
                        max: AndroidWidgetSettings.maxOpacity.toDouble(),
                        divisions:
                            AndroidWidgetSettings.maxOpacity -
                            AndroidWidgetSettings.minOpacity,
                        label: '${settings.backgroundOpacity}%',
                        onChanged: (value) =>
                            notifier.setBackgroundOpacity(value.round()),
                      ),
                    ],
                  ),
                ),
                PageModule(
                  child: ListTile(
                    key: const Key('widget-refresh-now'),
                    leading: const Icon(Icons.refresh_rounded),
                    title: Text(text.refreshTitle),
                    subtitle: Text(text.refreshSubtitle),
                    onTap: _refreshNow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _WidgetPreviewCard extends StatelessWidget {
  const _WidgetPreviewCard({required this.settings, required this.text});

  final AndroidWidgetSettings settings;
  final AndroidWidgetText text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final opacity = settings.backgroundOpacity / 100.0;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.45),
              scheme.tertiaryContainer.withValues(alpha: 0.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      text.previewNextClassBadge,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text.previewNextClassCountdown,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.previewSampleCourse,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text.previewSampleSubtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (settings.showDeadlines) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow.withValues(
                      alpha: (opacity * 0.92).clamp(0.3, 1.0),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    text.previewSampleDdl,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
