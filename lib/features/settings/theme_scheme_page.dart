import 'package:orbit/core/widgets/settings_app_bar.dart';
// Color grid, scheme selection and palette dialog interactions adapted from
// FlClash (GPL-3.0), chen08209/FlClash, lib/views/theme.dart.
// https://github.com/chen08209/FlClash/blob/main/lib/views/theme.dart
// Orbit uses independently generated coordinated HCT role colors.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/hct/hct.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/core/widgets/settings_group.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/providers/reminder_providers.dart';

class ThemeSchemePage extends ConsumerWidget {
  const ThemeSchemePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final value = ref.watch(multicolorSettingsProvider);
    final notifier = ref.read(multicolorSettingsProvider.notifier);
    final names = [l.paletteTonalSpot, ...l.themeSchemeNames.split('|')];
    final descriptions = l.paletteSchemeDescriptions.split('|');
    Future<void> save(MulticolorSettings v) async {
      try {
        await notifier.setValue(v);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            SnackBar(content: Text(l.reminderInvalid)),
            isError: true,
          );
        }
      }
    }

    Future<void> editRole(int role, Color initial) async {
      final picked = await showPaletteDialog(context, initialColor: initial);
      if (picked == null) return;
      final latest = ref.read(multicolorSettingsProvider);
      await save(latest.withRoleColor(role, picked));
    }

    Future<void> editEntry(PaletteColor? entry) async {
      final picked = await showPaletteDialog(
        context,
        initialColor: entry?.color ?? value.primary,
      );
      if (picked == null) return;
      final latest = ref.read(multicolorSettingsProvider);
      if (latest.palette.any(
        (e) => e.id != entry?.id && colorsMatchTheme(e.color, picked),
      )) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showAppSnackBar(SnackBar(content: Text(l.paletteDuplicate)));
        }
        return;
      }
      if (entry != null && !latest.palette.any((e) => e.id == entry.id)) return;
      await save(
        latest.copyWith(
          palette: entry == null
              ? [...latest.palette, PaletteColor(latest.nextId, picked)]
              : [
                  for (final e in latest.palette)
                    e.id == entry.id ? PaletteColor(e.id, picked) : e,
                ],
          nextId: entry == null ? latest.nextId + 1 : latest.nextId,
        ),
      );
    }

    Future<void> remove(PaletteColor entry) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.reminderDelete),
          content: Text(formatThemeHexColor(entry.color)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.reminderDelete),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        final latest = ref.read(multicolorSettingsProvider);
        await save(
          latest.copyWith(
            palette: latest.palette.where((e) => e.id != entry.id).toList(),
            retiredIds: {...latest.retiredIds, entry.id},
          ),
        );
      }
    }

    final colors = value.colors(Theme.of(context).brightness);
    final roleColors = [
      value.isCustom ? value.primary : colors.primary,
      value.secondary ?? colors.secondary,
      value.tertiary ?? colors.tertiary,
    ];
    final roleNames = [l.palettePrimary, l.paletteSecondary, l.paletteTertiary];
    return Scaffold(
      appBar: settingsAppBar(
        context,
        title: l.themeMulticolor,
        actions: [
          IconButton(
            tooltip: l.paletteReset,
            icon: const Icon(Icons.restore),
            onPressed: () async {
              final reset = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.paletteReset),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.actionCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.actionConfirm),
                    ),
                  ],
                ),
              );
              if (reset == true) {
                final latest = ref.read(multicolorSettingsProvider);
                // Fresh identities prevent reset from recoloring an unrelated old slot.
                final defaults = const MulticolorSettings();
                await save(
                  defaults.copyWith(
                    enabled: latest.enabled,
                    palette: [
                      for (var i = 0; i < defaults.palette.length; i++)
                        PaletteColor(
                          latest.nextId + i,
                          defaults.palette[i].color,
                        ),
                    ],
                    nextId: latest.nextId + defaults.palette.length,
                    retiredIds: {
                      ...latest.retiredIds,
                      ...latest.palette.map((e) => e.id),
                    },
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          SettingsGroup(
            title: l.paletteMode,
            children: [
              SwitchListTile(
                title: Text(l.themeMulticolor),
                subtitle: Text(
                  value.enabled ? l.themeMulticolor : l.paletteSingle,
                ),
                value: value.enabled,
                onChanged: (v) => save(value.copyWith(enabled: v)),
              ),
            ],
          ),
          SettingsGroup(
            title: l.themeMulticolor,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<AppColorScheme>(
                  initialValue: value.isCustom ? null : value.scheme,
                  key: ValueKey((value.scheme, value.isCustom)),
                  isExpanded: true,
                  hint: Text(l.paletteCustom),
                  decoration: InputDecoration(labelText: l.paletteScheme),
                  onChanged: (scheme) {
                    if (scheme != null) {
                      save(value.copyWith(scheme: scheme, clearCustom: true));
                    }
                  },
                  items: [
                    for (final scheme in AppColorScheme.values)
                      DropdownMenuItem(
                        value: scheme,
                        child: Row(
                          children: [
                            for (final color in (() {
                              final preview = value
                                  .copyWith(scheme: scheme, clearCustom: true)
                                  .colors(Theme.of(context).brightness);
                              return [
                                preview.primary,
                                preview.secondary,
                                preview.tertiary,
                              ];
                            })())
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: _Swatch(color: color, size: 16),
                              ),
                            const SizedBox(width: 4),
                            Expanded(child: Text(names[scheme.index])),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (!value.isCustom)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    descriptions[value.scheme.index],
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              for (var role = 0; role < 3; role++)
                ListTile(
                  title: Text(roleNames[role]),
                  subtitle: Text(
                    !value.isCustom ||
                            role > 0 &&
                                (role == 1
                                        ? value.secondary
                                        : value.tertiary) ==
                                    null
                        ? l.paletteAutomatic
                        : formatThemeHexColor(roleColors[role]),
                  ),
                  leading: _Swatch(color: roleColors[role]),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => editRole(role, roleColors[role]),
                ),
            ],
          ),
          SettingsGroup(
            title: l.paletteColors,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.paletteHint),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final label = TextPainter(
                          text: TextSpan(
                            text: '#FFFFFF',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout();
                        final minimumWidth = (label.width + 16).clamp(
                          88.0,
                          double.infinity,
                        );
                        final tileHeight = (label.height + 56).clamp(
                          72.0,
                          double.infinity,
                        );
                        final columns =
                            ((constraints.maxWidth + 12) / (minimumWidth + 12))
                                .floor()
                                .clamp(1, 12);
                        final width =
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final entry in value.palette)
                              SizedBox(
                                width: width,
                                height: tileHeight,
                                child: InkWell(
                                  key: ValueKey('palette-${entry.id}'),
                                  borderRadius: BorderRadius.circular(12),
                                  onLongPress: () => remove(entry),
                                  onTap: () async {
                                    final action =
                                        await showModalBottomSheet<String>(
                                          context: context,
                                          builder: (ctx) => SafeArea(
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  for (final action in [
                                                    ('edit', l.paletteEdit),
                                                    (
                                                      'primary',
                                                      l.paletteUsePrimary,
                                                    ),
                                                    (
                                                      'secondary',
                                                      l.paletteUseSecondary,
                                                    ),
                                                    (
                                                      'tertiary',
                                                      l.paletteUseTertiary,
                                                    ),
                                                    (
                                                      'earlier',
                                                      l.paletteMoveEarlier,
                                                    ),
                                                    (
                                                      'later',
                                                      l.paletteMoveLater,
                                                    ),
                                                    (
                                                      'delete',
                                                      l.reminderDelete,
                                                    ),
                                                  ])
                                                    ListTile(
                                                      title: Text(action.$2),
                                                      onTap: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            action.$1,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                    if (action == 'edit') {
                                      await editEntry(entry);
                                      return;
                                    }
                                    if (action == 'delete') {
                                      if (context.mounted) await remove(entry);
                                      return;
                                    }
                                    final latest = ref.read(
                                      multicolorSettingsProvider,
                                    );
                                    if (action == 'primary') {
                                      await save(
                                        latest.withRoleColor(0, entry.color),
                                      );
                                    }
                                    if (action == 'secondary') {
                                      await save(
                                        latest.withRoleColor(1, entry.color),
                                      );
                                    }
                                    if (action == 'tertiary') {
                                      await save(
                                        latest.withRoleColor(2, entry.color),
                                      );
                                    }
                                    if (action == 'earlier' ||
                                        action == 'later') {
                                      final list = [...latest.palette];
                                      final index = list.indexWhere(
                                        (e) => e.id == entry.id,
                                      );
                                      final target =
                                          index +
                                          (action == 'earlier' ? -1 : 1);
                                      if (index >= 0 &&
                                          target >= 0 &&
                                          target < list.length) {
                                        list.insert(
                                          target,
                                          list.removeAt(index),
                                        );
                                        await save(
                                          latest.copyWith(palette: list),
                                        );
                                      }
                                    }
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _Swatch(color: entry.color),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatThemeHexColor(entry.color),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: width,
                              height: tileHeight,
                              child: IconButton.filledTonal(
                                key: const Key('palette-add'),
                                tooltip: l.reminderAdd,
                                onPressed: () => editEntry(null),
                                icon: const Icon(Icons.add),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (final brightness in Brightness.values)
            SettingsGroup(
              title:
                  '${l.palettePreview} · ${brightness == Brightness.light ? l.themeModeLight : l.themeModeDark}',
              children: [
                Theme(
                  data: brightness == Brightness.light
                      ? AppTheme.light(
                          multicolor: value.copyWith(enabled: true),
                        )
                      : AppTheme.dark(
                          multicolor: value.copyWith(enabled: true),
                        ),
                  child: _PalettePreview(colors: value.colors(brightness)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.size = 36});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

class _PalettePreview extends StatelessWidget {
  const _PalettePreview({required this.colors});
  final ColorScheme colors;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    color: colors.surface,
    child: Row(
      children: [
        for (final pair in [
          (colors.primary, colors.onPrimary, colors.primaryContainer),
          (colors.secondary, colors.onSecondary, colors.secondaryContainer),
          (colors.tertiary, colors.onTertiary, colors.tertiaryContainer),
        ])
          Expanded(
            child: Container(
              height: 72,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: pair.$3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: pair.$1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.check, color: pair.$2),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Future<Color?> showPaletteDialog(
  BuildContext context, {
  required Color initialColor,
}) => showDialog<Color>(
  context: context,
  builder: (_) => _PaletteDialog(initialColor: initialColor),
);

class _PaletteDialog extends StatefulWidget {
  const _PaletteDialog({required this.initialColor});
  final Color initialColor;
  @override
  State<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteDialogState extends State<_PaletteDialog> {
  late Color _color;
  late double _hue, _chroma, _tone;
  late TextEditingController _hex;
  @override
  void initState() {
    super.initState();
    _setColor(widget.initialColor);
    _hex = TextEditingController(text: formatThemeHexColor(_color));
  }

  void _setColor(Color color) {
    _color = color;
    final hct = Hct.fromInt(color.toARGB32());
    _hue = hct.hue;
    _chroma = hct.chroma;
    _tone = hct.tone;
  }

  void _change(double hue, double chroma, double tone) {
    setState(() {
      _hue = hue;
      _chroma = chroma;
      _tone = tone;
      _color = Color(Hct.from(hue, chroma, tone).toInt());
      _hex.text = formatThemeHexColor(_color);
    });
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.paletteEdit),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Swatch(color: _color),
              TextField(
                controller: _hex,
                decoration: InputDecoration(
                  labelText: 'HEX',
                  errorText: parseThemeHexColor(_hex.text) == null
                      ? l.themeColorInvalidHex
                      : null,
                ),
                onChanged: (text) => setState(() {
                  final color = parseThemeHexColor(text);
                  if (color != null) _setColor(color);
                }),
              ),
              Text(l.paletteHue),
              Slider(
                value: _hue.clamp(0, 360),
                max: 360,
                label: l.paletteHue,
                onChanged: (v) => _change(v, _chroma, _tone),
              ),
              Text(l.paletteChroma),
              Slider(
                value: _chroma.clamp(0, 120),
                max: 120,
                label: l.paletteChroma,
                onChanged: (v) => _change(_hue, v, _tone),
              ),
              Text(l.paletteTone),
              Slider(
                value: _tone.clamp(0, 100),
                max: 100,
                label: l.paletteTone,
                onChanged: (v) => _change(_hue, _chroma, v),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in kThemePresetColors)
                    InkWell(
                      onTap: () => setState(() {
                        _setColor(c);
                        _hex.text = formatThemeHexColor(c);
                      }),
                      child: _Swatch(color: c),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.actionCancel),
        ),
        TextButton(
          onPressed: parseThemeHexColor(_hex.text) == null
              ? null
              : () => Navigator.pop(context, _color),
          child: Text(l.actionConfirm),
        ),
      ],
    );
  }
}
