import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit/features/grid/week_calendar_utils.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/grid_builder.dart';

const double kWeekPickerMenuWidth = 280;

class GridWeekPicker extends ConsumerStatefulWidget {
  const GridWeekPicker({
    super.key,
    required this.weekStart,
    required this.onChanged,
  });

  final DateTime weekStart;
  final ValueChanged<DateTime> onChanged;

  @override
  ConsumerState<GridWeekPicker> createState() => _GridWeekPickerState();
}

class _GridWeekPickerState extends ConsumerState<GridWeekPicker> {
  final _gridBuilder = GridBuilder();

  Future<void> _openPicker() async {
    final sessions = await ref.read(sessionsProvider.future);
    if (!mounted) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.sizeOf(context);

    final anchorCenterX = offset.dx + size.width / 2;
    final menuLeft = (anchorCenterX - kWeekPickerMenuWidth / 2)
        .clamp(8.0, screenSize.width - kWeekPickerMenuWidth - 8);
    final menuTop = offset.dy + size.height;

    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        menuLeft,
        menuTop,
        screenSize.width - menuLeft - kWeekPickerMenuWidth,
        screenSize.height - menuTop,
      ),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _WeekPickerPanel(
            initialYear: widget.weekStart.year,
            initialMonth: widget.weekStart.month,
            selectedWeekStart: widget.weekStart,
            sessions: sessions,
            onWeekSelected: (weekStart) {
              widget.onChanged(weekStart);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _gridBuilder.formatWeekRange(widget.weekStart);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openPicker,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekPickerPanel extends StatefulWidget {
  const _WeekPickerPanel({
    required this.initialYear,
    required this.initialMonth,
    required this.selectedWeekStart,
    required this.sessions,
    required this.onWeekSelected,
  });

  final int initialYear;
  final int initialMonth;
  final DateTime selectedWeekStart;
  final List<CourseSession> sessions;
  final ValueChanged<DateTime> onWeekSelected;

  @override
  State<_WeekPickerPanel> createState() => _WeekPickerPanelState();
}

class _WeekPickerPanelState extends State<_WeekPickerPanel> {
  late int _year;
  late int _month;
  final _gridBuilder = GridBuilder();

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  void _changeYear(int delta) {
    setState(() => _year += delta);
  }

  void _changeMonth(int delta) {
    setState(() {
      final date = DateTime(_year, _month + delta, 1);
      _year = date.year;
      _month = date.month;
    });
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    final normalizedA = DateTime(a.year, a.month, a.day);
    final normalizedB = DateTime(b.year, b.month, b.day);
    return normalizedA == normalizedB;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final weeks = weeksOverlappingMonth(_year, _month);
    final monthLabel = DateFormat.MMM(Localizations.localeOf(context).toString())
        .format(DateTime(_year, _month, 1));

    return SizedBox(
      width: kWeekPickerMenuWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.gridWeekPickerYear,
                onPressed: () => _changeYear(-1),
              ),
              Expanded(
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.gridWeekPickerYear,
                onPressed: () => _changeYear(1),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.gridWeekPickerMonth,
                onPressed: () => _changeMonth(-1),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.gridWeekPickerMonth,
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const Divider(height: 1),
          if (weeks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.gridNoSessionsThisWeek,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: weeks.length,
                itemBuilder: (context, index) {
                  final weekStart = weeks[index];
                  final hasSessions =
                      weekHasSessions(weekStart, widget.sessions);
                  final isSelected =
                      _isSameWeek(weekStart, widget.selectedWeekStart);
                  final label = _gridBuilder.formatWeekRange(weekStart);

                  return _WeekPickerItem(
                    label: label,
                    hasSessions: hasSessions,
                    isSelected: isSelected,
                    onTap: () => widget.onWeekSelected(weekStart),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekPickerItem extends StatelessWidget {
  const _WeekPickerItem({
    required this.label,
    required this.hasSessions,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool hasSessions;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withAlpha(30)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      hasSessions ? FontWeight.w600 : FontWeight.normal,
                  color: hasSessions
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant.withAlpha(120),
                ),
              ),
              if (isSelected)
                Positioned(
                  right: 12,
                  child: Icon(
                    Icons.check,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
