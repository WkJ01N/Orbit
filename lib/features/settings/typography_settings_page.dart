import 'package:orbit/models/v162_text.dart';
import 'package:orbit/services/font_coverage.dart';
import 'package:orbit/models/navigation_assist_text.dart';
import 'dart:async';
import 'package:orbit/features/settings/components_page.dart';
import 'package:orbit/services/component_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/models/typography_settings.dart';
import 'package:orbit/models/typography_text.dart';
import 'package:orbit/providers/typography_providers.dart';
import 'package:orbit/services/font_service.dart';

class TypographySettingsPage extends ConsumerStatefulWidget {
  const TypographySettingsPage({super.key});
  @override
  ConsumerState<TypographySettingsPage> createState() =>
      _TypographySettingsPageState();
}

class _TypographySettingsPageState
    extends ConsumerState<TypographySettingsPage> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text(TypographyText(context).failed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() => _run(() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final source = result.files.single;
    if (source.size > FontService.maxFileBytes) {
      throw const FormatException('Font size');
    }
    final bytes =
        source.bytes ??
        (source.path == null ? null : await File(source.path!).readAsBytes());
    if (bytes == null) throw const FormatException('Font unavailable');
    final service = ref.read(fontServiceProvider);
    final imported = await service.importBytes(source.name, bytes);
    try {
      await ref.read(typographySettingsProvider.notifier).update((value) {
        if (value.imports.containsKey(imported.font.id)) return value;
        if (value.imports.length >= 100) {
          throw const FormatException('Font library full');
        }
        return value.copyWith(
          imports: {...value.imports, imported.font.id: imported.font},
        );
      });
    } catch (_) {
      if (imported.created) await service.deleteFile(imported.font);
      rethrow;
    }
    if (!fontContainsChinese(bytes) && mounted) {
      await _offerFallbacks(context, ref);
    }
  });

  Future<void> _rename(ImportedFont font) async {
    final text = TypographyText(context);
    final controller = TextEditingController(text: font.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.rename),
        content: TextField(
          controller: controller,
          maxLength: 120,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(text.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    await _run(
      () => ref
          .read(typographySettingsProvider.notifier)
          .update(
            (value) => value.copyWith(
              imports: {
                ...value.imports,
                font.id: ImportedFont(
                  id: font.id,
                  name: name,
                  extension: font.extension,
                ),
              },
            ),
          ),
    );
  }

  Future<void> _delete(ImportedFont font) async {
    final text = TypographyText(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${text.delete} ${font.name}'),
        content: Text(text.deleteHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => ref.read(typographySettingsProvider.notifier).remove(font.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = TypographyText(context);
    final value = ref.watch(typographySettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(text.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(text.independent),
              if (value.loadWarning)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(text.warning),
                ),
              for (final launch in [false, true])
                ListTile(
                  key: Key(launch ? 'launch-font-choice' : 'app-font-choice'),
                  enabled: !_busy,
                  title: Text(launch ? text.launch : text.app),
                  subtitle: Text(
                    text.name(
                      launch ? value.launchFontId : value.appFontId,
                      value
                          .imports[launch
                              ? value.launchFontId
                              : value.appFontId]
                          ?.name,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => FontPickerPage(launch: launch),
                    ),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.font_download_outlined),
                title: Text(V162Text.of(context).fallbacks),
                subtitle: Text(V162Text.of(context).fallbackHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FallbackFontsPage(),
                        ),
                      ),
              ),
              const Divider(),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(text.importFont),
              ),
              const SizedBox(height: 8),
              Text(text.importHint),
              const SizedBox(height: 20),
              Text(
                text.imported,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final font in value.imports.values)
                ListTile(
                  title: Text(font.name),
                  subtitle: Text(font.extension.toUpperCase()),
                  trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (value) =>
                        value == 'rename' ? _rename(font) : _delete(font),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'rename', child: Text(text.rename)),
                      PopupMenuItem(value: 'delete', child: Text(text.delete)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _offerFallbacks(BuildContext context, WidgetRef ref) async {
  final t = V162Text.of(context);
  final configure = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text(t.fallbacks),
      content: Text(t.noChinese),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(t.systemFallback),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(t.fallbacks),
        ),
      ],
    ),
  );
  if (configure == false) {
    await ref
        .read(typographySettingsProvider.notifier)
        .update((v) => v.copyWith(fallbackFontIds: []));
  } else if (configure == true && context.mounted) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const FallbackFontsPage()),
    );
  }
}

class FallbackFontsPage extends ConsumerStatefulWidget {
  const FallbackFontsPage({super.key});
  @override
  ConsumerState<FallbackFontsPage> createState() => _FallbackFontsPageState();
}

class _FallbackFontsPageState extends ConsumerState<FallbackFontsPage> {
  bool _busy = false;
  Future<void> _save(List<String> ids) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(typographySettingsProvider.notifier)
          .update((v) => v.copyWith(fallbackFontIds: ids));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text(TypographyText(context).failed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(typographySettingsProvider),
        t = V162Text.of(context);
    final names = TypographyText(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.fallbacks)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t.fallbackHint),
              const SizedBox(height: 16),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: value.fallbackFontIds.length,
                onReorderItem: (old, next) {
                  if (_busy) return;
                  final ids = [...value.fallbackFontIds];
                  ids.insert(next, ids.removeAt(old));
                  _save(ids);
                },
                itemBuilder: (_, index) {
                  final id = value.fallbackFontIds[index];
                  return ListTile(
                    key: ValueKey(id),
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(names.name(id, value.imports[id]?.name)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: names.delete,
                          onPressed: _busy
                              ? null
                              : () => _save(
                                  value.fallbackFontIds
                                      .where((f) => f != id)
                                      .toList(),
                                ),
                          icon: const Icon(Icons.close),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          enabled: !_busy,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (value.fallbackFontIds.length < 3)
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FontPickerPage(
                              launch: false,
                              fallback: true,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.add),
                  label: Text(t.addFallback),
                ),
              ListTile(
                leading: const Icon(Icons.phone_android_outlined),
                title: Text(names.name('system', null)),
                subtitle: Text(t.systemFallback),
              ),
              const SizedBox(height: 20),
              Text(
                '大学課表 · 数学／數學 · Orbit 0123456789，。！？',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FontPickerPage extends ConsumerStatefulWidget {
  const FontPickerPage({
    super.key,
    required this.launch,
    this.fallback = false,
  });
  final bool launch;
  final bool fallback;
  @override
  ConsumerState<FontPickerPage> createState() => _FontPickerPageState();
}

class _FontPickerPageState extends ConsumerState<FontPickerPage> {
  late String _selected;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final value = ref.read(typographySettingsProvider);
    _selected = widget.fallback
        ? 'rounded'
        : widget.launch
        ? value.launchFontId
        : value.appFontId;
    unawaited(
      ref.read(componentServiceProvider).initialize().then((_) {
        if (mounted) setState(() {});
      }, onError: (Object _) {}),
    );
  }

  Future<void> _select(String id, {bool apply = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!apply && const ['rounded', 'huninn', 'maiyuan'].contains(id)) {
        final components = ref.read(componentServiceProvider);
        await components.initialize();
        var installed = false;
        try {
          await components.installed(id);
          installed = true;
        } on ComponentMissing {
          /* Offer explicit download. */
        }
        if (!installed) {
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ComponentsPage(focusId: id),
            ),
          );
          if (!mounted || !components.ready(id)) return;
        }
      }
      TypographySettings next(TypographySettings value) => widget.fallback
          ? value.copyWith(
              fallbackFontIds: [
                ...value.fallbackFontIds.where((f) => f != id),
                id,
              ],
            )
          : widget.launch
          ? value.copyWith(launchFontId: id)
          : value.copyWith(appFontId: id);
      if (apply) {
        await ref.read(typographySettingsProvider.notifier).update(next);
        if (!widget.fallback &&
            mounted &&
            ref.read(typographySettingsProvider).imports.containsKey(id)) {
          final font = ref.read(typographySettingsProvider).imports[id]!;
          final bytes = await (await ref.read(fontServiceProvider).file(font))
              .readAsBytes();
          if (!fontContainsChinese(bytes) &&
              mounted &&
              ref.read(typographySettingsProvider).fallbackFontIds.isEmpty) {
            await _offerFallbacks(context, ref);
          }
        }
        if (mounted) Navigator.pop(context);
      } else {
        await ref
            .read(fontServiceProvider)
            .prepare(next(ref.read(typographySettingsProvider)));
        if (mounted) setState(() => _selected = id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text(TypographyText(context).failed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = TypographyText(context);
    final value = ref.watch(typographySettingsProvider);
    final components = ref.watch(componentServiceProvider);
    final available =
        !const ['rounded', 'huninn', 'maiyuan'].contains(_selected) ||
        components.ready(_selected);
    final family = !available
        ? FontCatalog.systemFamily(
            defaultTargetPlatform,
            Localizations.localeOf(context),
          )
        : _selected == 'system'
        ? FontCatalog.systemFamily(
            defaultTargetPlatform,
            Localizations.localeOf(context),
          )
        : FontCatalog.family(_selected);
    final sample = TextStyle(
      inherit: false,
      fontFamily: family,
      fontFamilyFallback: value.fallbackFamilies(_selected),
      fontSize: 17,
      color: Theme.of(context).colorScheme.onSurface,
      height: 1.5,
    );
    final choices = [
      if (!widget.fallback) 'system',
      if (widget.launch || widget.fallback) 'nunito',
      'rounded',
      'huninn',
      'maiyuan',
      ...value.imports.keys,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fallback
              ? V162Text.of(context).addFallback
              : widget.launch
              ? text.launch
              : text.app,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orbit',
                        style: sample.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('大学课表 · 接下来的课程', style: sample),
                      Text('大學課表 · 接下來的課程', style: sample),
                      Text('Mathematics · 09:00–10:30 · A101', style: sample),
                      const SizedBox(height: 12),
                      Text(
                        '高等数学／高等數學',
                        style: sample.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text('周一／週一  2026-10-17  0123456789', style: sample),
                    ],
                  ),
                ),
              ),
              FilledButton(
                key: const Key('apply-font'),
                onPressed: _busy
                    ? null
                    : () => _select(_selected, apply: available),
                child: Text(
                  available
                      ? text.apply
                      : NavigationAssistText.of(
                          context,
                        ).pick('Download and preview', '下载并预览', '下載並預覽'),
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              for (final id in choices.where(
                (id) => !widget.fallback || !value.fallbackFontIds.contains(id),
              ))
                ListTile(
                  key: ValueKey('font-option-$id'),
                  enabled: !_busy,
                  leading: Icon(
                    _selected == id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(text.name(id, value.imports[id]?.name)),
                  onTap: () => _select(id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Report recovery once without blocking the first screen or notification route.
class TypographyWarningHost extends ConsumerStatefulWidget {
  const TypographyWarningHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  ConsumerState<TypographyWarningHost> createState() =>
      _TypographyWarningHostState();
}

class _TypographyWarningHostState extends ConsumerState<TypographyWarningHost> {
  bool _reported = false;
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(typographySettingsProvider);
    if (value.loadWarning && !_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final text = TypographyText(context);
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(text.warning),
            action: SnackBarAction(
              label: text.title,
              onPressed: () => widget.navigatorKey.currentState?.push(
                MaterialPageRoute<void>(
                  builder: (_) => const TypographySettingsPage(),
                ),
              ),
            ),
          ),
        );
      });
    }
    return widget.child;
  }
}
