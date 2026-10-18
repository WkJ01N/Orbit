import 'package:orbit/services/semester_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/orbit_feature_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/course_catalog.dart';
import 'package:orbit/features/session/course_history_list.dart';

/// Uses the latest occurrence as a template; historical rows are never edited.
List<({CourseSession course, bool archivedOnly})> existingCourses(
  List<CourseSession> sessions,
) {
  final groups = <String, List<CourseSession>>{};
  final semesters = SemesterService(sessions: sessions);
  for (final s in sessions.where((s) => !s.isExam && s.deletedAt == null)) {
    groups
        .putIfAbsent(
          '${semesters.resolve(name: s.semester, id: s.semesterId, at: s.startAt)!.id}|${CourseSeriesKey.fromSession(s).value}',
          () => [],
        )
        .add(s);
  }
  final result = groups.values.map((values) {
    final sorted = [...values]..sort((a, b) => b.startAt.compareTo(a.startAt));
    return (
      course: sorted.first,
      archivedOnly: sorted.every((s) => s.archived),
    );
  }).toList();
  result.sort((a, b) {
    if (a.archivedOnly != b.archivedOnly) return a.archivedOnly ? 1 : -1;
    return a.course.courseName.toLowerCase().compareTo(
      b.course.courseName.toLowerCase(),
    );
  });
  return result;
}

Future<CourseSession?> chooseExistingCourse(BuildContext context) =>
    showDialog<CourseSession>(
      context: context,
      builder: (_) => const _ExistingCoursePicker(),
    );

class _ExistingCoursePicker extends ConsumerStatefulWidget {
  const _ExistingCoursePicker();
  @override
  ConsumerState<_ExistingCoursePicker> createState() =>
      _ExistingCoursePickerState();
}

class _ExistingCoursePickerState extends ConsumerState<_ExistingCoursePicker> {
  String _query = '';
  List<CourseSession>? _source;
  List<({CourseSession course, bool archivedOnly})> _courses = const [];
  @override
  Widget build(BuildContext context) {
    final text = OrbitFeatureText.of(context);
    final sessions = ref.watch(sessionsProvider);
    final catalog = ref.watch(courseCatalogProvider);
    return AlertDialog(
      title: Text(text.existing),
      content: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * .55,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: text.search,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sessions.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(sessionsProvider),
                    child: Text(text.refresh),
                  ),
                ),
                data: (values) {
                  if (!identical(values, _source)) {
                    _source = values;
                    _courses = existingCourses(values);
                  }
                  final courses = _courses
                      .where(
                        (c) =>
                            '${c.course.courseName} ${c.course.courseCode} ${c.course.section} ${c.course.semester}'
                                .toLowerCase()
                                .contains(_query),
                      )
                      .toList();
                  if (courses.isEmpty) {
                    return Center(child: Text(text.noCourses));
                  }
                  return CourseHistoryList(
                    items: courses,
                    isEnded: (item) => catalog.isEnded(item.course),
                    itemBuilder: (_, item) {
                      final s = item.course;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.archivedOnly)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                item.archivedOnly
                                    ? text.archivedCourses
                                    : text.courses,
                              ),
                            ),
                          ListTile(
                            title: Text(s.courseName),
                            subtitle: Text(
                              '${s.courseCode} · ${s.section} · ${s.semester}',
                            ),
                            onTap: () => Navigator.pop(context, s),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
