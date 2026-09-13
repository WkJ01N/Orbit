import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:orbit/services/course_color_utils.dart';
import 'package:orbit/models/course_session.dart';

final automaticCourseColorIdsProvider =
    NotifierProvider<AutomaticCourseColorIdsNotifier, Map<String, int>>(
      AutomaticCourseColorIdsNotifier.new,
    );

class AutomaticCourseColorIdsNotifier extends Notifier<Map<String, int>> {
  bool _ready = false;
  int _generation = 0;
  late Future<void> _loading;
  Future<void> _saves = Future.value();
  @override
  Map<String, int> build() {
    _ready = false;
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    ref.listen(sessionsProvider, (_, next) {
      if (_ready) _sync();
    });
    ref.listen(multicolorSettingsProvider, (_, next) {
      if (_ready) _sync();
    });
    _loading = _load(generation);
    unawaited(_loading);
    return const {};
  }

  Future<void> _load(int generation) async {
    final saved = await ref
        .read(settingsServiceProvider)
        .loadAutomaticCourseColorIds();
    if (generation != _generation) return;
    state = saved;
    _ready = true;
    _sync();
  }

  Future<void> ensureSaved(List<CourseSession> sessions) async {
    await _loading;
    _sync(sessions);
    await _saves;
  }

  void _sync([List<CourseSession>? current]) {
    final sessions = current ?? ref.read(sessionsProvider).value ?? [];
    final keys = sessions.map(automaticCourseColorKey);
    final multi = ref.read(multicolorSettingsProvider);
    final updated = allocateCourseColorIds(
      state,
      keys,
      palette: multi.enabled ? multi.palette : const [],
      retiredIds: multi.enabled ? multi.retiredIds : const {},
      preferred: {
        for (final s in sessions)
          automaticCourseColorKey(s): legacyAutomaticColorId(s),
      },
    );
    if (mapEquals(updated, state)) return;
    state = updated;
    final service = ref.read(settingsServiceProvider);
    _saves = _saves
        .catchError((Object e) {
          debugPrint('Course colors: $e');
        })
        .then((_) => service.saveAutomaticCourseColorIds(updated));
  }
}

final resolvedAutomaticCourseColorIdsProvider = Provider<Map<String, int>>((
  ref,
) {
  final saved = ref.watch(automaticCourseColorIdsProvider);
  final sessions = ref.watch(sessionsProvider).value ?? [];
  final keys = sessions.map(automaticCourseColorKey);
  final multi = ref.watch(multicolorSettingsProvider);
  return allocateCourseColorIds(
    saved,
    keys,
    palette: multi.enabled ? multi.palette : const [],
    retiredIds: multi.enabled ? multi.retiredIds : const {},
    preferred: {
      for (final s in sessions)
        automaticCourseColorKey(s): legacyAutomaticColorId(s),
    },
  );
});
