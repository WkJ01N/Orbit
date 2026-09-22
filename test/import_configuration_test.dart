import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/providers/import_providers.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const custom = ScheduleImportTemplate(
  id: 'custom',
  name: 'School',
  layout: ImportLayout.grid,
  firstRow: 1,
  firstColumn: 1,
  lastColumn: 1,
  weekdayColumns: {1: 1},
  periodRows: {
    1: [1, 2],
  },
  fields: {
    ImportField.courseName: FieldMapping(
      source: FieldSource.text,
      regex: RegexRule(pattern: r'(?<course>[^\n]+)', group: 'course'),
    ),
    ImportField.weekday: FieldMapping(source: FieldSource.weekday),
    ImportField.periods: FieldMapping(source: FieldSource.periods),
  },
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'template sharing round trip contains rules but no schedule context',
    () {
      final encoded = encodeTemplate(custom);
      expect(decodeTemplate(encoded).toJson(), custom.toJson());
      expect(encoded, isNot(contains('firstWeekMonday')));
      expect(encoded, isNot(contains('source_file')));
      expect(decodeTemplate(encoded).builtIn, isFalse);
      expect(
        () => decodeTemplate(
          jsonEncode({'kind': 'orbit-import-template', 'version': 2}),
        ),
        throwsFormatException,
      );
    },
  );
  test('versioned settings persist all plans and field rules', () async {
    final service = SettingsService();
    final config = ImportConfiguration(
      templates: [custom],
      semesters: [
        SemesterPlan(
          id: 'fall',
          name: 'Fall',
          firstWeekMonday: DateTime(2026, 9, 14),
        ),
      ],
      periodTimes: const [
        PeriodTimePlan(
          id: 'time',
          name: 'Time',
          periods: [PeriodTime(number: 1, startMinute: 480, endMinute: 525)],
        ),
      ],
    );
    await service.saveImportConfiguration(config);
    expect(
      (await SettingsService().loadImportConfiguration()).toJson(),
      config.toJson(),
    );
    final portable = await service.exportPortableSettings();
    final backup = ScheduleBackupService().decodeBackup(
      ScheduleBackupService().encodeToJson([], settings: portable),
    );
    expect(backup.version, 6);
    expect(backup.sessions, isEmpty);
    expect(backup.settings!.importConfiguration!.toJson(), config.toJson());
    expect(
      backup.settings!
          .withReminders(portable.reminders)
          .importConfiguration!
          .toJson(),
      config.toJson(),
    );
  });
  test(
    'old backups preserve local import configuration and v5 replaces it',
    () async {
      final service = SettingsService();
      await service.saveImportConfiguration(
        const ImportConfiguration(templates: [custom]),
      );
      final settings = await service.exportPortableSettings();
      for (var version = 1; version <= 4; version++) {
        final map =
            jsonDecode(
                  ScheduleBackupService().encodeToJson([], settings: settings),
                )
                as Map<String, dynamic>;
        map['version'] = version;
        (map['settings'] as Map).remove('importConfiguration');
        final old = ScheduleBackupService().decodeBackup(jsonEncode(map));
        await service.importPortableSettings(old.settings!);
        expect(
          (await service.loadImportConfiguration()).templates.single.id,
          'custom',
        );
      }
      final map =
          jsonDecode(
                ScheduleBackupService().encodeToJson([], settings: settings),
              )
              as Map<String, dynamic>;
      (map['settings'] as Map)['importConfiguration'] =
          const ImportConfiguration().toJson();
      await service.importPortableSettings(
        ScheduleBackupService().decodeBackup(jsonEncode(map)).settings!,
      );
      expect((await service.loadImportConfiguration()).templates, isEmpty);
    },
  );
  test('serialized provider edits do not lose neighboring changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(importConfigurationProvider.future);
    final notifier = container.read(importConfigurationProvider.notifier);
    await Future.wait([
      notifier.saveChange((c) => c.copy(templates: [...c.templates, custom])),
      notifier.saveChange(
        (c) => c.copy(
          semesters: [
            SemesterPlan(
              id: 'fall',
              name: 'Fall',
              firstWeekMonday: DateTime(2026, 9, 14),
            ),
          ],
        ),
      ),
    ]);
    final config = await container.read(importConfigurationProvider.future);
    expect(config.templates, hasLength(1));
    expect(config.semesters, hasLength(1));
    expect(
      (await SettingsService().loadImportConfiguration()).toJson(),
      config.toJson(),
    );
  });
  test(
    'invalid plan and template snapshots rejected before persisted data changes',
    () async {
      final service = SettingsService();
      await service.saveImportConfiguration(
        const ImportConfiguration(templates: [custom]),
      );
      expect(
        () => service.saveImportConfiguration(
          ImportConfiguration(
            semesters: [
              SemesterPlan(
                id: 'bad',
                name: 'Bad',
                firstWeekMonday: DateTime(2026, 9, 15),
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(
        (await service.loadImportConfiguration()).templates.single.id,
        'custom',
      );
      expect(
        () => const PeriodTimePlan(
          id: 'p',
          name: 'p',
          periods: [PeriodTime(number: 1, startMinute: 600, endMinute: 500)],
        ).validate(),
        throwsFormatException,
      );
      expect(() => custom.copy(id: ''), throwsFormatException);
      final map = custom.toJson();
      map['version'] = 2;
      expect(() => ScheduleImportTemplate.fromJson(map), throwsFormatException);
    },
  );
}
