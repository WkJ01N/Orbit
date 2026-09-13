import 'package:orbit/core/widgets/settings_choice_tile.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/features/settings/theme_scheme_page.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/widgets/color_picker_dialog.dart';
import 'package:orbit/core/widgets/settings_group.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/providers/app_providers.dart';

class SettingsAppearanceSection extends ConsumerWidget {
  const SettingsAppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final style = ref.watch(themeStyleProvider);
    final mode = ref.watch(themeModeProvider);
    final color = ref.watch(themeColorProvider);
    final multi = ref.watch(multicolorSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: l10n.sectionAppearance,
          children: [
            SettingsChoiceTile(
              title: Text(l10n.themeStyleTitle),
              subtitle: Text(l10n.themeStyleSubtitle),
              trailing: _SettingsDropdown<AppThemeStyle>(
                value: style,
                items: AppThemeStyle.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == AppThemeStyle.standard
                              ? l10n.themeStyleStandard
                              : l10n.themeStyleColorful,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeStyleProvider.notifier).setStyle(value);
                  }
                },
              ),
            ),
            SettingsChoiceTile(
              title: Text(l10n.themeModeTitle),
              subtitle: Text(l10n.themeModeSubtitle),
              trailing: _SettingsDropdown<ThemeMode>(
                value: mode,
                items: ThemeMode.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_themeModeLabel(l10n, value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.paletteMode),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(l10n.paletteSingle),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(l10n.themeMulticolor),
                      ),
                    ],
                    selected: {multi.enabled},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => ref
                        .read(multicolorSettingsProvider.notifier)
                        .setValue(multi.copyWith(enabled: v.first)),
                  ),
                ],
              ),
            ),
            if (!multi.enabled)
              _ThemeColorPicker(
                currentColor: color,
                onSelected: (value) =>
                    ref.read(themeColorProvider.notifier).setColor(value),
              ),
            ListTile(
              title: Text(l10n.themeMulticolor),
              subtitle: Text(
                !multi.enabled
                    ? l10n.paletteSingle
                    : multi.isCustom
                    ? l10n.paletteCustom
                    : multi.scheme == AppColorScheme.original
                    ? l10n.paletteTonalSpot
                    : l10n.themeSchemeNames.split('|')[multi.scheme.index - 1],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemeSchemePage()),
                );
              },
            ),
          ],
        ),
        if (Platform.isWindows) ...[
          SettingsGroup(
            title: l10n.sectionSystem,
            children: const [_LaunchAtStartupTile()],
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  String _themeModeLabel(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => l10n.themeModeSystem,
      ThemeMode.light => l10n.themeModeLight,
      ThemeMode.dark => l10n.themeModeDark,
    };
  }
}

class _ThemeColorPicker extends StatelessWidget {
  const _ThemeColorPicker({
    required this.currentColor,
    required this.onSelected,
  });

  final Color currentColor;
  final ValueChanged<Color> onSelected;

  Future<void> _showCustom(BuildContext context) async {
    final selected = await showColorPickerDialog(
      context,
      initialColor: currentColor,
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isCustom = !kThemePresetColors.any(
      (color) => colorsMatchTheme(color, currentColor),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.themeColorTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.themeColorSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in kThemePresetColors)
                _ColorSwatch(
                  color: color,
                  selected: colorsMatchTheme(color, currentColor),
                  onTap: () => onSelected(color),
                ),
              if (isCustom)
                _ColorSwatch(
                  color: currentColor,
                  selected: true,
                  onTap: () => _showCustom(context),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.colorize, size: 18),
                label: Text(l10n.themeColorCustom),
                onPressed: () => _showCustom(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 18,
                  color: color.computeLuminance() > 0.5
                      ? Colors.black87
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

class _LaunchAtStartupTile extends ConsumerStatefulWidget {
  const _LaunchAtStartupTile();

  @override
  ConsumerState<_LaunchAtStartupTile> createState() =>
      _LaunchAtStartupTileState();
}

class _LaunchAtStartupTileState extends ConsumerState<_LaunchAtStartupTile> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ref.read(startupServiceProvider).loadPreference();
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile(
      title: Text(l10n.launchAtStartup),
      subtitle: Text(l10n.launchAtStartupSubtitle),
      value: _enabled ?? false,
      onChanged: _enabled == null
          ? null
          : (value) async {
              try {
                await ref.read(startupServiceProvider).setEnabled(value);
                if (mounted) setState(() => _enabled = value);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showAppSnackBar(
                    SnackBar(
                      content: Text(l10n.launchAtStartupFailed('$error')),
                    ),
                  );
                }
              }
            },
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width < 360 ? 132 : 156,
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox.shrink(),
      ),
    );
  }
}
