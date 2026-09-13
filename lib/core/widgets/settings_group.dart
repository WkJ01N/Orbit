import 'package:flutter/material.dart';
import 'package:orbit/core/widgets/section_header.dart';

/// A single spacing and divider policy for related settings.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.horizontalMargin = 16,
  });
  final String title;
  final List<Widget> children;
  final double horizontalMargin;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
          child: SectionHeader(title: title),
        ),
        Card(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: 4,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}
