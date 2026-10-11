import 'package:flutter/material.dart';
import 'package:orbit/models/statistics_text.dart';

class StatisticsDeletionChoice extends StatefulWidget {
  const StatisticsDeletionChoice({super.key, required this.onChanged});
  final ValueChanged<bool> onChanged;
  @override
  State<StatisticsDeletionChoice> createState() =>
      _StatisticsDeletionChoiceState();
}

class _StatisticsDeletionChoiceState extends State<StatisticsDeletionChoice> {
  bool _value = false;
  @override
  Widget build(BuildContext context) => CheckboxListTile(
    key: const Key('delete-statistics-choice'),
    contentPadding: EdgeInsets.zero,
    value: _value,
    title: Text(StatisticsText.of(context).deleteWithStatistics),
    onChanged: (v) {
      setState(() => _value = v ?? false);
      widget.onChanged(_value);
    },
  );
}
