import 'package:flutter/material.dart';

/// Pinned table header for week grid vertical scrolling.
class WeekGridTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  WeekGridTableHeaderDelegate({
    required this.header,
    required this.extent,
    required this.backgroundColor,
  });

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
    return ColoredBox(
      color: backgroundColor,
      child: header,
    );
  }

  @override
  bool shouldRebuild(covariant WeekGridTableHeaderDelegate oldDelegate) {
    return header != oldDelegate.header ||
        extent != oldDelegate.extent ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
