import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';

String gridDeleteCourseKey(CourseSession session) =>
    jsonEncode([session.semester, CourseSeriesKey.fromSession(session).value]);

Map<String, List<CourseSession>> gridDeleteCourseGroups(
  List<CourseSession> sessions, {
  required bool includeArchived,
}) {
  final groups = <String, List<CourseSession>>{};
  for (final session in sessions) {
    if (session.deletedAt != null || (!includeArchived && session.archived)) {
      continue;
    }
    groups.putIfAbsent(gridDeleteCourseKey(session), () => []).add(session);
  }
  return groups;
}

({List<CourseSession> contained, List<CourseSession> crossing})
gridDeleteTargets(
  List<CourseSession> sessions, {
  required Set<String> courseKeys,
  required bool includeArchived,
  DateTime? start,
  DateTime? end,
}) {
  final contained = <CourseSession>[];
  final crossing = <CourseSession>[];
  if (start != null && (end == null || !end.isAfter(start))) {
    return (contained: contained, crossing: crossing);
  }
  for (final session in sessions) {
    if (session.deletedAt != null ||
        (!includeArchived && session.archived) ||
        !courseKeys.contains(gridDeleteCourseKey(session))) {
      continue;
    }
    if (start == null ||
        (!session.startAt.isBefore(start) && !session.endAt.isAfter(end!))) {
      contained.add(session);
    } else if (session.startAt.isBefore(end!) && session.endAt.isAfter(start)) {
      crossing.add(session);
    }
  }
  return (contained: contained, crossing: crossing);
}

bool sameGridDeletionSnapshot(
  List<CourseSession> expected,
  List<CourseSession> actual,
) {
  if (expected.length != actual.length) return false;
  final byId = {for (final session in actual) session.id: session};
  return expected.every(
    (session) =>
        byId.containsKey(session.id) &&
        mapEquals(session.toMap(), byId[session.id]!.toMap()),
  );
}
