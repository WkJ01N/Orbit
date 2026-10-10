import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/grid/grid_delete_targets.dart';
import 'package:orbit/features/grid/grid_selection.dart';
import 'package:orbit/features/grid/strong_grid_decoration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/settings_sync_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'archive_and_first_class_test.dart' show sampleClass;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final start = DateTime(2026, 8, 24, 9);
  final a = sampleClass(
    'a',
    start,
  ).copyWith(courseCode: 'CS1', section: 'A', semester: '2026');
  test(
    'course grouping separates semesters and sections, includes linked history and optional archive',
    () {
      final key = gridDeleteCourseKey(a);
      final archived = a.copyWith(
        id: 'archived',
        archivedAt: start,
        archiveHidden: true,
      );
      final otherSemester = a.copyWith(id: 'past', semester: '2025');
      final otherSection = a.copyWith(id: 'section', section: 'B');
      final deleted = a.copyWith(id: 'deleted', deletedAt: start);
      final sessions = [a, archived, otherSemester, otherSection, deleted];
      final ordinary = gridDeleteCourseGroups(sessions, includeArchived: false);
      expect(ordinary.length, 3);
      expect(ordinary[key]!.map((s) => s.id), ['a']);
      final all = gridDeleteCourseGroups(sessions, includeArchived: true);
      expect(all[key]!.map((s) => s.id), ['a', 'archived']);
      final selected = gridDeleteTargets(
        sessions,
        courseKeys: {key, gridDeleteCourseKey(otherSemester)},
        includeArchived: true,
      );
      expect(selected.contained.map((s) => s.id).toSet(), {
        'a',
        'archived',
        'past',
      });
      final linked = a.copyWith(linkedCourseKey: 'original');
      expect(
        gridDeleteCourseKey(linked),
        gridDeleteCourseKey(
          linked.copyWith(id: 'extra', recurrenceSeriesId: 'new-batch'),
        ),
      );
    },
  );
  test(
    'time matching separates contained and crossing, ignores touching and invalid ranges',
    () {
      final end = start.add(const Duration(hours: 1));
      final sessions = [
        a.copyWith(endAt: end),
        a.copyWith(
          id: 'cross-start',
          startAt: start.subtract(const Duration(minutes: 1)),
          endAt: end,
        ),
        a.copyWith(id: 'cross-end', endAt: end.add(const Duration(minutes: 1))),
        a.copyWith(
          id: 'surround',
          startAt: start.subtract(const Duration(hours: 1)),
          endAt: end.add(const Duration(hours: 1)),
        ),
        a.copyWith(
          id: 'touch-start',
          startAt: start.subtract(const Duration(hours: 1)),
          endAt: start,
        ),
        a.copyWith(
          id: 'touch-end',
          startAt: end,
          endAt: end.add(const Duration(hours: 1)),
        ),
      ];
      final targets = gridDeleteTargets(
        sessions,
        courseKeys: {gridDeleteCourseKey(a)},
        includeArchived: false,
        start: start,
        end: end,
      );
      expect(targets.contained.map((s) => s.id), ['a']);
      expect(targets.crossing.map((s) => s.id).toSet(), {
        'cross-start',
        'cross-end',
        'surround',
      });
      expect(
        gridDeleteTargets(
          sessions,
          courseKeys: {gridDeleteCourseKey(a)},
          includeArchived: false,
          start: end,
          end: start,
        ).contained,
        isEmpty,
      );
    },
  );
  test(
    'snapshot detects deleted records, changed time and archive while ignoring order',
    () {
      final b = a.copyWith(id: 'b');
      expect(sameGridDeletionSnapshot([a, b], [b, a]), isTrue);
      expect(sameGridDeletionSnapshot([a, b], [a]), isFalse);
      expect(
        sameGridDeletionSnapshot(
          [a],
          [a.copyWith(startAt: start.add(const Duration(minutes: 1)))],
        ),
        isFalse,
      );
      expect(
        sameGridDeletionSnapshot([a], [a.copyWith(archivedAt: start)]),
        isFalse,
      );
    },
  );
  test(
    'manual selection ignores taps while busy and remains independent of page dates',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gridSelectionProvider.notifier);
      notifier.toggle('a');
      expect(container.read(gridSelectionProvider).ids, isEmpty);
      notifier.enter();
      notifier.toggle('a');
      notifier.toggle('b');
      notifier.setBusy(true);
      notifier.toggle('a');
      expect(container.read(gridSelectionProvider).ids, {'a', 'b'});
      notifier.setBusy(false);
      notifier.toggle('a');
      expect(container.read(gridSelectionProvider).ids, {'b'});
      notifier.exit();
      expect(container.read(gridSelectionProvider).active, isFalse);
    },
  );
  test(
    'gradient extents, settings persistence, backup and display sync retain the preference',
    () async {
      final service = SettingsService();
      expect(
        (await service.loadScheduleDisplaySettings()).strongCardGradient,
        StrongCardGradient.upperHalf,
      );
      for (final extent in StrongCardGradient.values) {
        final gradient = strongGridBackground(
          accent: Colors.blue,
          surface: Colors.white,
          extent: extent,
        );
        expect(
          gradient.colors.first,
          Color.alphaBlend(
            strongGridHighlight(Colors.blue).withValues(alpha: .25),
            Colors.white,
          ),
        );
        expect(gradient.colors.last, Colors.white);
        expect(gradient.stops![1], switch (extent) {
          StrongCardGradient.upperHalf => .5,
          StrongCardGradient.fullCard => 1,
          StrongCardGradient.topQuarter => .25,
        });
        await service.saveScheduleDisplaySettings(
          ScheduleDisplaySettings(strongCardGradient: extent),
        );
        expect(
          (await SettingsService().loadScheduleDisplaySettings())
              .strongCardGradient,
          extent,
        );
        final portable = await service.exportPortableSettings();
        expect(
          PortableSettings.fromJson(
            portable.toJson(),
          ).scheduleDisplay.strongCardGradient,
          extent,
        );
        expect(
          (SettingsSyncCodec.groups(portable)['display']!['scheduleDisplay']
              as Map)['strongCardGradient'],
          extent.name,
        );
        await service.importPortableSettings(
          PortableSettings.fromJson(portable.toJson()),
        );
        expect(
          (await service.loadScheduleDisplaySettings()).strongCardGradient,
          extent,
        );
        final old = portable.toJson();
        (old['scheduleDisplay'] as Map).remove('strongCardGradient');
        expect(
          PortableSettings.fromJson(old).scheduleDisplay.strongCardGradient,
          StrongCardGradient.upperHalf,
        );
      }
    },
  );
}
