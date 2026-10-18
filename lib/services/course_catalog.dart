import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/services/semester_service.dart';

/// A course ends only after its last non-deleted class, including archived ones.
class CourseCatalog {
  CourseCatalog(
    List<CourseSession> sessions,
    DateTime now, {
    List<SemesterPlan> plans = const [],
    this.clock,
  }) {
    final semesters = SemesterService(plans: plans, sessions: sessions);
    final latest = <String, DateTime>{};
    for (final s in sessions.where((s) => s.deletedAt == null && !s.isExam)) {
      final key =
          '${semesters.resolve(name: s.semester, id: s.semesterId, at: s.startAt)!.id}|${CourseSeriesKey.fromSession(s).value}';
      _groups[s.id] = key;
      if (latest[key] == null || s.endAt.isAfter(latest[key]!)) {
        latest[key] = s.endAt;
      }
    }
    _ended.addAll(latest.keys.where((key) => !latest[key]!.isAfter(now)));
    _ends.addAll(latest);
    for (final s in sessions.where((s) => s.isExam && s.deletedAt == null)) {
      _groups[s.id] = 'exam|${s.id}';
      _ends['exam|${s.id}'] = s.endAt;
      if (!s.endAt.isAfter(now)) _ended.add('exam|${s.id}');
    }
  }
  final _groups = <String, String>{};
  final _ended = <String>{};
  final _ends = <String, DateTime>{};
  final DateTime Function()? clock;
  bool isEnded(CourseSession session) {
    final key = _groups[session.id];
    if (clock == null) return _ended.contains(key);
    final end = _ends[key];
    return end != null && !end.isAfter(clock!());
  }
}

final courseCatalogProvider = Provider<CourseCatalog>(
  (ref) => CourseCatalog(
    ref.watch(sessionsProvider).valueOrNull ?? const [],
    ref.watch(currentTimeProvider),
    plans:
        ref.watch(importConfigurationProvider).valueOrNull?.semesters ??
        const [],
  ),
);
