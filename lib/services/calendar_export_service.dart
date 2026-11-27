import 'dart:convert';

import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';

/// Serializes course sessions into an RFC 5545 iCalendar document.
///
/// Every timestamp is written in UTC, so the export needs no VTIMEZONE block:
/// each calendar app places the event in whichever zone the device that
/// imports it uses. That keeps the file valid for phones, Outlook and Google
/// Calendar without shipping a zone database snapshot.
class CalendarExportService {
  const CalendarExportService();

  static const _prodid = '-//Orbit//Timetable//ZH';

  String build(
    List<CourseSession> sessions, {
    DateTime? stamp,
    int? defaultLeadMinutes,
    List<Deadline> deadlines = const [],
  }) {
    final generated = _formatUtc(stamp ?? DateTime.now());
    final buffer = StringBuffer()
      ..write('BEGIN:VCALENDAR\r\n')
      ..write('VERSION:2.0\r\n')
      ..write('PRODID:$_prodid\r\n')
      ..write('CALSCALE:GREGORIAN\r\n')
      ..write('METHOD:PUBLISH\r\n');
    for (final session in sessions) {
      if (session.deletedAt != null) continue;
      for (final line in _eventLines(session, generated, defaultLeadMinutes)) {
        buffer
          ..write(_fold(line))
          ..write('\r\n');
      }
    }
    for (final deadline in deadlines) {
      if (deadline.deleted || deadline.completed) continue;
      for (final line in _deadlineLines(deadline, generated)) {
        buffer
          ..write(_fold(line))
          ..write('\r\n');
      }
    }
    buffer.write('END:VCALENDAR\r\n');
    return buffer.toString();
  }

  List<String> _alarmLines(int lead, String description) => [
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'TRIGGER:-PT${lead}M',
    'DESCRIPTION:${_escape(description)}',
    'END:VALARM',
  ];

  List<String> _deadlineLines(Deadline deadline, String generated) {
    final title = '[DDL] ${deadline.title}';
    final leads = {...deadline.leadMinutes}.toList()..sort();
    return [
      'BEGIN:VEVENT',
      'UID:ddl-${_escape(deadline.id)}@orbit',
      'DTSTAMP:$generated',
      'DTSTART:${_formatUtc(deadline.dueAt)}',
      'DTEND:${_formatUtc(deadline.dueAt)}',
      'SUMMARY:${_escape(title)}',
      if (deadline.subject.isNotEmpty)
        'DESCRIPTION:${_escape(deadline.subject)}',
      for (final lead in leads)
        if (lead > 0 && deadline.reminderEnabledAt(lead))
          ..._alarmLines(lead, title),
      'END:VEVENT',
    ];
  }

  List<String> _eventLines(
    CourseSession session,
    String generated,
    int? defaultLeadMinutes,
  ) {
    final summary = session.section.isEmpty
        ? session.courseName
        : '${session.courseName} ${session.section}';
    final description = <String>[
      if (session.teachers.isNotEmpty) session.teachers.join(', '),
      if (session.courseCode.isNotEmpty) session.courseCode,
      if (session.semester.isNotEmpty) session.semester,
      if (session.note != null && session.note!.trim().isNotEmpty)
        session.note!.trim(),
    ].join('\n');
    final lead = defaultLeadMinutes == null
        ? null
        : session.isExam
        ? (session.examReminderEnabled ? session.examLeadMinutes : null)
        : defaultLeadMinutes;
    return [
      'BEGIN:VEVENT',
      'UID:${_escape(session.id)}@orbit',
      'DTSTAMP:$generated',
      'DTSTART:${_formatUtc(session.startAt)}',
      'DTEND:${_formatUtc(session.endAt)}',
      'SUMMARY:${_escape(summary)}',
      if (session.room.isNotEmpty) 'LOCATION:${_escape(session.room)}',
      if (description.isNotEmpty) 'DESCRIPTION:${_escape(description)}',
      if (lead != null && lead > 0) ..._alarmLines(lead, summary),
      'END:VEVENT',
    ];
  }

  String _formatUtc(DateTime value) {
    final utc = value.toUtc();
    return '${_pad(utc.year, 4)}${_pad(utc.month, 2)}${_pad(utc.day, 2)}'
        'T${_pad(utc.hour, 2)}${_pad(utc.minute, 2)}${_pad(utc.second, 2)}Z';
  }

  String _pad(int value, int width) => value.toString().padLeft(width, '0');

  String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll(RegExp(r'\r\n|\r|\n'), '\\n');

  /// Folds at 75 octets as required by RFC 5545, never splitting a UTF-8
  /// sequence: continuation lines carry a leading space and hold 74 octets.
  String _fold(String line) {
    if (utf8.encode(line).length <= 75) return line;
    final out = StringBuffer();
    final current = StringBuffer();
    var octets = 0;
    var continuation = false;
    for (final rune in line.runes) {
      final piece = String.fromCharCode(rune);
      final size = utf8.encode(piece).length;
      if (octets + size > (continuation ? 74 : 75)) {
        out
          ..write(current.toString())
          ..write('\r\n ');
        current.clear();
        octets = 0;
        continuation = true;
      }
      current.write(piece);
      octets += size;
    }
    out.write(current.toString());
    return out.toString();
  }
}
