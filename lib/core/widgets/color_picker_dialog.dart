import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Shows a dialog to pick a preset or custom HEX color.
Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required Color initialColor,
  Color? defaultColor,
  VoidCallback? onUseDefault,
}) {
  return showDialog<Color>(
    context: context,
    builder: (dialogContext) => _ColorPickerDialog(
      initialColor: initialColor,
      defaultColor: defaultColor,
      onUseDefault: onUseDefault,
    ),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.initialColor,
    this.defaultColor,
    this.onUseDefault,
  });

  final Color initialColor;
  final Color? defaultColor;
  final VoidCallback? onUseDefault;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late final TextEditingController _controller;
  late Color _preview;

  @override
  void initState() {
    super.initState();
    _preview = widget.initialColor;
    _controller = TextEditingController(
      text: formatThemeHexColor(widget.initialColor).substring(1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updatePreview(String value) {
    final parsed = parseThemeHexColor(value);
    setState(() {
      _preview = parsed ?? widget.initialColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    var errorText = '';
    final parsed = parseThemeHexColor(_controller.text);
    if (parsed == null && _controller.text.trim().isNotEmpty) {
      errorText = l10n.themeColorInvalidHex;
    }

    return AlertDialog(
      title: Text(l10n.themeColorCustomTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in kThemePresetColors)
                _PresetSwatch(
                  color: color,
                  selected: colorsMatchTheme(color, _preview),
                  onTap: () {
                    setState(() {
                      _preview = color;
                      _controller.text = formatThemeHexColor(
                        color,
                      ).substring(1);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _preview,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.outline),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    prefixText: '#',
                    labelText: 'HEX',
                    errorText: errorText.isEmpty ? null : errorText,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f#]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  onChanged: _updatePreview,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.defaultColor != null && widget.onUseDefault != null)
          TextButton.icon(
            onPressed: () {
              widget.onUseDefault!();
              Navigator.pop(context);
            },
            icon: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: widget.defaultColor,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outline),
              ),
            ),
            label: Text(l10n.courseColorDefault),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final color = parseThemeHexColor(_controller.text);
            if (color == null) {
              setState(() {});
              return;
            }
            Navigator.pop(context, color);
          },
          child: Text(l10n.actionApply),
        ),
      ],
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                size: 16,
                color: color.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}
