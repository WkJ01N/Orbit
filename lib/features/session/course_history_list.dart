import 'dart:async';
import 'package:flutter/material.dart';
import 'package:orbit/models/v163_text.dart';

/// The history rows are created lazily and never mounted while folded.
class CourseHistoryList<T> extends StatefulWidget {
  const CourseHistoryList({
    super.key,
    required this.items,
    required this.isEnded,
    required this.itemBuilder,
    this.controller,
    this.onExpanded,
    this.expanded = false,
    this.header,
  });
  final List<T> items;
  final bool Function(T) isEnded;
  final Widget Function(BuildContext, T) itemBuilder;
  final ScrollController? controller;
  final ValueChanged<bool>? onExpanded;
  final bool expanded;
  final Widget? header;
  @override
  State<CourseHistoryList<T>> createState() => _CourseHistoryListState<T>();
}

class _CourseHistoryListState<T> extends State<CourseHistoryList<T>> {
  late bool _expanded = widget.expanded;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  void _scheduleTick() {
    final now = DateTime.now();
    _clock = Timer(
      DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute + 1,
      ).difference(now),
      () {
        if (mounted) {
          setState(() {});
          _scheduleTick();
        }
      },
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(CourseHistoryList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) _expanded = widget.expanded;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.items.where((item) => !widget.isEnded(item)).toList();
    final ended = widget.items.where(widget.isEnded).toList();
    final headerCount = widget.header == null ? 0 : 1;
    return ListView.builder(
      controller: widget.controller,
      itemCount:
          headerCount +
          active.length +
          (ended.isEmpty ? 0 : 1 + (_expanded ? ended.length : 0)),
      itemBuilder: (context, index) {
        if (widget.header != null && index == 0) return widget.header!;
        index -= headerCount;
        if (index < active.length) {
          return widget.itemBuilder(context, active[index]);
        }
        if (index == active.length) {
          return ListTile(
            key: const Key('view-ended-courses'),
            leading: const Icon(Icons.history),
            title: Text(
              V163Text.of(context).endedCourses(ended.length),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: AnimatedRotation(
              turns: _expanded ? .5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.expand_more),
            ),
            onTap: () {
              setState(() => _expanded = !_expanded);
              widget.onExpanded?.call(_expanded);
            },
          );
        }
        return widget.itemBuilder(context, ended[index - active.length - 1]);
      },
    );
  }
}
