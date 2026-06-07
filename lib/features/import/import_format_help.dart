import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';

class ImportFormatHelp extends StatelessWidget {
  const ImportFormatHelp({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = [
      ('A', l10n.importFormatClassType, l10n.importFormatClassTypeExample),
      ('B', l10n.importFormatRoom, l10n.importFormatRoomExample),
      ('C', l10n.importFormatCapacity, l10n.importFormatCapacityExample),
      ('D', l10n.importFormatFaculty, l10n.importFormatFacultyExample),
      ('E', l10n.importFormatDate, l10n.importFormatDateExample),
      ('F', l10n.importFormatWeekday, l10n.importFormatWeekdayExample),
      ('G', l10n.importFormatCourseName, l10n.importFormatCourseNameExample),
      ('H', l10n.importFormatCourseCode, l10n.importFormatCourseCodeExample),
      ('I', l10n.importFormatSection, l10n.importFormatSectionExample),
      ('J', l10n.importFormatStartTime, l10n.importFormatStartTimeExample),
      ('K', l10n.importFormatEndTime, l10n.importFormatEndTimeExample),
      ('L', l10n.importFormatTeachers, l10n.importFormatTeachersExample),
      ('M', l10n.importFormatSemester, l10n.importFormatSemesterExample),
    ];

    return ExpansionTile(
      title: Text(l10n.importFormatTitle),
      subtitle: Text(l10n.importFormatSubtitle),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(28),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(3),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  _headerCell(context, l10n.importFormatColumn),
                  _headerCell(context, l10n.importFormatField),
                  _headerCell(context, l10n.importFormatExample),
                ],
              ),
              for (final row in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(row.$1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(row.$2),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        row.$3,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCell(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
