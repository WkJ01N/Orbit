import 'package:flutter/material.dart';

/// Give choice controls a separate row when they would squeeze the description.
class SettingsChoiceTile extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.enabled = true,
    this.onTap,
  });
  final Widget title;
  final Widget? subtitle;
  final Widget trailing;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 480 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      if (!stacked) {
        return ListTile(
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          enabled: enabled,
          onTap: onTap,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: title,
            subtitle: subtitle,
            enabled: enabled,
            onTap: onTap,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: trailing,
            ),
          ),
        ],
      );
    },
  );
}
