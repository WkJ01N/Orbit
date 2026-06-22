import 'package:flutter/material.dart';

/// Pinned table header for week grid vertical scrolling.
class WeekGridTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  WeekGridTableHeaderDelegate({
    required this.headerKey,
    required this.header,
    required this.extent,
    required this.backgroundColor,
  });

  final Key headerKey;
  final Widget header;
  final double extent;
  final Color backgroundColor;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: overlapsContent
            ? Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              )
            : null,
      ),
      child: header,
    );
  }

  @override
  bool shouldRebuild(covariant WeekGridTableHeaderDelegate oldDelegate) {
    return headerKey != oldDelegate.headerKey ||
        extent != oldDelegate.extent ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
