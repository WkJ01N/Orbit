import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/schedule_import.dart';

class SemesterInfo {
  const SemesterInfo({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    this.source = 'inferred',
  });
  final String id, name, source;
  final DateTime start, end;
  bool contains(DateTime at) {
    final day = DateTime(at.year, at.month, at.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  factory SemesterInfo.fromPlan(SemesterPlan plan) => SemesterInfo(
    id: plan.id,
    name: plan.name,
    start: plan.rangeStart ?? plan.firstWeekMonday,
    end:
        plan.rangeEnd ??
        plan.firstWeekMonday.add(Duration(days: plan.totalWeeks * 7 - 1)),
    source: plan.source,
  );
}

/// Calendar defaults are only used when no explicit identity/configuration exists.
class SemesterService {
  SemesterService({
    List<SemesterPlan> plans = const [],
    List<Map<String, dynamic>> records = const [],
    List<CourseSession> sessions = const [],
  }) {
    for (final plan in plans) {
      final info = SemesterInfo.fromPlan(plan);
      _items[info.id] = info;
    }
    for (final s in sessions) {
      resolve(name: s.semester, id: s.semesterId, at: s.startAt);
    }
    for (final r in records) {
      if (r['kind'] == 'course' || r['kind'] == 'exam') {
        resolve(
          name: r['semester'] as String? ?? '',
          id: r['semesterId'] as String?,
          at: recordDate(r),
        );
      }
    }
  }
  final _items = <String, SemesterInfo>{};
  List<SemesterInfo> get semesters => _items.values.toList()
    ..sort((a, b) {
      final date = b.start.compareTo(a.start);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
  static String normalize(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  static String namedId(String name, [DateTime? at]) =>
      'named|${sha256.convert(utf8.encode("${normalize(name)}${at != null && !RegExp(r'20\d{2}').hasMatch(name) ? '|${calendar(at).id}' : ''}")).toString().substring(0, 24)}';
  static SemesterInfo calendar(DateTime at) {
    final spring = at.month >= 2 && at.month < 8;
    final year = at.month == 1 ? at.year - 1 : at.year;
    return SemesterInfo(
      id: 'calendar|$year|${spring ? 'spring' : 'autumn'}',
      name: spring ? '${year - 1}—$year 学年春季学期' : '$year—${year + 1} 学年秋季学期',
      start: DateTime(year, spring ? 2 : 8),
      end: spring ? DateTime(year, 8, 0) : DateTime(year + 1, 2, 0),
    );
  }

  SemesterInfo? resolve({String name = '', String? id, DateTime? at}) {
    if (id != null &&
        _items.containsKey(id) &&
        !(id.startsWith('calendar|') && _items[id]!.source == 'inferred')) {
      return _items[id];
    }
    final named = _items.values
        .where(
          (s) =>
              name.trim().isNotEmpty &&
              normalize(s.name) == normalize(name) &&
              (at == null ||
                  s.source != 'inferred' ||
                  RegExp(r'20\d{2}').hasMatch(name) ||
                  s.contains(at)),
        )
        .firstOrNull;
    if (named != null) return named;
    if (name.trim().isNotEmpty) {
      final base = calendar(at ?? _yearFromName(name) ?? DateTime(1970, 2));
      final next = SemesterInfo(
        id: id ?? namedId(name, at),
        name: name.trim(),
        start: base.start,
        end: base.end,
      );
      return _items.putIfAbsent(next.id, () => next);
    }
    if (at == null) return null;
    final explicit =
        _items.values
            .where(
              (s) =>
                  (s.source != 'inferred' || s.id.startsWith('named|')) &&
                  s.contains(at),
            )
            .toList()
          ..sort((a, b) {
            if (a.source != b.source) return a.source == 'manual' ? -1 : 1;
            final date = b.start.compareTo(a.start);
            return date != 0 ? date : a.id.compareTo(b.id);
          });
    if (explicit.isNotEmpty) return explicit.first;
    final base = calendar(at);
    return _items.putIfAbsent(base.id, () => base);
  }

  static DateTime? _yearFromName(String name) {
    final match = RegExp(r'(20\d{2})').firstMatch(name);
    return match == null ? null : DateTime(int.parse(match[1]!), 8);
  }

  static DateTime? recordDate(Map<String, dynamic> record) {
    final start = DateTime.tryParse('${record['startAt']}')?.toLocal();
    if (start != null) return start;
    final end = DateTime.tryParse('${record['endAt']}')?.toLocal();
    return end?.subtract(Duration(minutes: record['minutes'] as int? ?? 0));
  }

  SemesterInfo current(DateTime now) => resolve(at: now)!;
  String? recordSemester(Map<String, dynamic> r) => resolve(
    name: r['semester'] as String? ?? '',
    id: r['semesterId'] as String?,
    at: recordDate(r),
  )?.id;
}
