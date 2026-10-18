import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/features/session/course_quick_action_bar.dart';
import 'package:orbit/models/course_quick_actions.dart';
import 'package:orbit/models/v163_text.dart';
import 'package:orbit/providers/quick_action_providers.dart';

class CourseQuickActionSettingsTile extends ConsumerWidget {
  const CourseQuickActionSettingsTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = V163Text.of(context);
    return PageModule(
      child: ListTile(
        key: const Key('course-quick-actions-settings'),
        leading: const Icon(Icons.touch_app_outlined),
        title: Text(text.quickActions),
        subtitle: Text(text.quickActionsHint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const CourseQuickActionSettingsPage(),
          ),
        ),
      ),
    );
  }
}

class CourseQuickActionSettingsPage extends ConsumerWidget {
  const CourseQuickActionSettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = V163Text.of(context);
    final settings = ref.watch(courseQuickActionsProvider);
    final notifier = ref.read(courseQuickActionsProvider.notifier);
    Future<void> select(int direction) async {
      final action = await showDialog<SessionAction>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(text.directions[direction]),
          children: [
            for (final action in SessionAction.values)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, action),
                child: ListTile(
                  leading: Icon(quickActionIcon(action)),
                  title: Text(quickActionLabel(c, action)),
                ),
              ),
          ],
        ),
      );
      if (action != null) await notifier.save(settings.swap(direction, action));
    }

    return Scaffold(
      appBar: BackgroundAppBar(child: AppBar(title: Text(text.quickActions))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          PageModule(
            child: SwitchListTile(
              key: const Key('course-quick-actions-enabled'),
              title: Text(text.quickActions),
              subtitle: Text(text.quickActionsHint),
              value: settings.enabled,
              onChanged: (v) => notifier.save(settings.copyWith(enabled: v)),
            ),
          ),
          const SizedBox(height: 12),
          PageModule(
            child: DropdownButtonFormField<QuickActionEdgeMode>(
              key: ValueKey(settings.edgeMode),
              initialValue: settings.edgeMode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: text.edgeMode,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: QuickActionEdgeMode.merge,
                  child: Text(
                    text.merge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: QuickActionEdgeMode.floatInward,
                  child: Text(
                    text.floatInward,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: settings.enabled
                  ? (value) {
                      if (value != null) {
                        notifier.save(settings.copyWith(edgeMode: value));
                      }
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          PageModule(
            child: Text(
              text.actionPositions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          PageModule(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: AspectRatio(
                  aspectRatio: 1.15,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 84,
                          height: 108,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_view_week_outlined),
                        ),
                        for (var i = 0; i < 4; i++)
                          Align(
                            alignment: [
                              Alignment.topCenter,
                              Alignment.centerRight,
                              Alignment.bottomCenter,
                              Alignment.centerLeft,
                            ][i],
                            child: SizedBox(
                              width: 98,
                              child: OutlinedButton(
                                onPressed: settings.enabled
                                    ? () => select(i)
                                    : null,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(text.directions[i]),
                                    Icon(
                                      quickActionIcon(settings.positions[i]),
                                    ),
                                    Text(
                                      quickActionLabel(
                                        context,
                                        settings.positions[i],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          PageModule(
            child: TextButton.icon(
              onPressed: settings.enabled
                  ? () => notifier.save(
                      settings.copyWith(
                        positions: const CourseQuickActionSettings().positions,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.restart_alt),
              label: Text(text.resetPositions),
            ),
          ),
        ],
      ),
    );
  }
}
