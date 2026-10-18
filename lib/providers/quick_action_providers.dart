import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/course_quick_actions.dart';
import 'package:orbit/providers/app_providers.dart';

final courseQuickActionsProvider =
    NotifierProvider<CourseQuickActionsNotifier, CourseQuickActionSettings>(
      CourseQuickActionsNotifier.new,
    );

class CourseQuickActionsNotifier extends Notifier<CourseQuickActionSettings> {
  int _generation = 0;
  Future<void> _tail = Future.value();
  @override
  CourseQuickActionSettings build() {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    ref.read(settingsServiceProvider).loadCourseQuickActions().then((raw) {
      if (generation != _generation || raw == null) return;
      try {
        state = CourseQuickActionSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        /* Use safe defaults for old or damaged preferences. */
      }
    });
    return const CourseQuickActionSettings();
  }

  Future<void> save(CourseQuickActionSettings next) {
    _generation++;
    state = next;
    final service = ref.read(settingsServiceProvider);
    final save = _tail.then(
      (_) => service.saveCourseQuickActions(jsonEncode(next.toJson())),
    );
    _tail = save.catchError((Object _) {});
    return save;
  }
}
