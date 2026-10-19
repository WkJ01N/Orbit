import 'package:orbit/core/motion/page_module.dart';
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
  ShapeBorder _contentClip(BuildContext context) {
    final shape =
        Theme.of(context).cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return shape is OutlinedBorder
        ? shape.copyWith(side: BorderSide.none)
        : shape;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
          child: PageModule(child: SectionHeader(title: title)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: 4,
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: PageModule(
                  surface: true,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                shape: _contentClip(context),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in children)
                      if (child is Divider) PageModule(child: child) else child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
