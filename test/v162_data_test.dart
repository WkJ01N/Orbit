import 'package:orbit/services/xlsx_exporter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:orbit/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/models/statistics.dart';
import 'package:orbit/models/typography_settings.dart';
import 'package:orbit/services/font_coverage.dart';
import 'package:orbit/services/font_service.dart';
import 'package:orbit/services/downgrade_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/reminder_alarm_planner.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/semester_service.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CourseSession sample({
  String id = 'class',
  SessionKind kind = SessionKind.course,
}) => CourseSession(
  id: id,
  kind: kind,
  classType: kind == SessionKind.exam ? '考试' : '',
  room: 'A101',
  date: DateTime(2026, 10, 18),
  weekday: 7,
  courseName: 'Math',
  courseCode: 'MATH100',
  section: '1',
  startAt: DateTime(2026, 10, 18, 10),
  endAt: DateTime(2026, 10, 18, 12),
  teachers: const [],
  faculty: '',
  semester: '2026 Autumn',
);

NotificationCopy get copy => NotificationCopy.fromL10n(AppLocalizationsEn());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDatabase db;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('orbit-v162-');
    db = await AppDatabase.open(root.path);
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'exams round trip through SQLite, sync and backup with stable identity',
    () async {
      final exam = sample(id: 'exam|one', kind: SessionKind.exam).copyWith(
        semesterId: 'term',
        examLeadMinutes: 45,
        examStrongReminder: false,
      );
      await db.upsertSessions([exam]);
      expect((await db.getAllSessions()).single.toMap(), exam.toMap());
      expect(
        courseSessionFromSyncPayload(courseSessionSyncPayload(exam)).toMap(),
        exam.toMap(),
      );
      final service = ScheduleBackupService();
      final restored = service
          .decodeBackup(service.encodeToJson([exam]))
          .sessions
          .single;
      expect(restored.toMap(), exam.toMap());
      expect(
        exam
            .copyWith(startAt: exam.startAt.add(const Duration(days: 1)))
            .computeId(),
        exam.id,
      );
      expect(
        CourseSeriesKey.fromSession(exam),
        isNot(CourseSeriesKey.fromSession(sample())),
      );
    },
  );

  test(
    'exam ends automatically count once, never add class time or block finished courses',
    () async {
      final exam = sample(id: 'exam|one', kind: SessionKind.exam);
      await db.upsertSessions([sample(), exam]);
      await db.refreshStatistics(now: DateTime(2026, 10, 18, 11));
      expect(
        OrbitStatistics(records: await db.statisticsRecords()).completedExams,
        0,
      );
      await db.refreshStatistics(now: DateTime(2026, 10, 18, 13));
      await db.refreshStatistics(now: DateTime(2026, 10, 18, 14));
      final stats = OrbitStatistics(records: await db.statisticsRecords());
      expect(stats.completedExams, 1);
      expect(stats.attendedSessions, 1);
      expect(stats.classMinutes, 120);
      expect(stats.learnedCourses, hasLength(1));
      await db.assignSemester([exam.id], 'new-term', 'New term');
      expect(
        OrbitStatistics(records: await db.statisticsRecords()).completedExams,
        1,
      );
      expect(
        (await db.statisticsRecords()).singleWhere(
          (r) => r['kind'] == 'exam',
        )['semesterId'],
        'new-term',
      );
    },
  );

  test('import and ordinary course edits preserve overlapping exams', () async {
    final repository = ScheduleRepository(db, XlsxParser());
    final exam = sample(id: 'exam|one', kind: SessionKind.exam);
    await repository.insertSession(exam);
    await repository.importParsedSessionsWithStrategy([
      sample(),
    ], ImportMergeStrategy.replaceWeek);
    expect((await db.getAllSessions()).where((s) => s.isExam), hasLength(1));
    await repository.saveSessionWithConflictResolution(
      sample().copyWith(room: 'B2'),
    );
    expect((await db.getAllSessions()).where((s) => s.isExam), hasLength(1));
  });

  test('exam reminder is independent of course global switch and check-in', () {
    final exam = sample(id: 'exam|one', kind: SessionKind.exam);
    final settings = const ReminderSettings(
      enabled: false,
      checkInReminderEnabled: true,
    );
    List<dynamic> reminders(CourseSession s) => buildReminderAlarmSpecs(
      upcomingSessions: [s],
      settings: settings,
      now: DateTime(2026, 10, 18, 8),
      copy: copy,
    );
    final specs = reminders(exam);
    expect(specs, hasLength(1));
    expect(specs.single.fireAt, DateTime(2026, 10, 18, 9, 30));
    expect(specs.single.strong.enabled, true);
    expect(reminders(exam.copyWith(examReminderEnabled: false)), isEmpty);
    expect(
      reminders(exam.copyWith(examStrongReminder: false)).single.strong.enabled,
      false,
    );
    expect(
      buildReminderAlarmSpecs(
        upcomingSessions: [exam],
        settings: settings,
        now: DateTime(2026, 10, 18, 13),
        copy: copy,
      ),
      isEmpty,
    );
  });

  test(
    'calendar boundaries, imported names and manual identity survive renaming',
    () {
      expect(
        SemesterService.calendar(DateTime(2027, 1, 31)).id,
        'calendar|2026|autumn',
      );
      expect(
        SemesterService.calendar(DateTime(2027, 2, 1)).id,
        'calendar|2027|spring',
      );
      expect(
        SemesterService.calendar(DateTime(2027, 7, 31)).id,
        'calendar|2027|spring',
      );
      expect(
        SemesterService.calendar(DateTime(2027, 8, 1)).id,
        'calendar|2027|autumn',
      );
      final service = SemesterService(sessions: [sample()]);
      expect(service.current(DateTime(2026, 10, 18)).name, '2026 Autumn');
      final plan = SemesterPlan(
        id: 'stable',
        name: 'Renamed',
        firstWeekMonday: DateTime(2026, 9, 7),
        rangeStart: DateTime(2026, 9, 1),
        rangeEnd: DateTime(2027, 2, 20),
        source: 'manual',
      );
      final configured = SemesterService(
        plans: [SemesterPlan.fromJson(plan.toJson())],
      );
      expect(configured.current(DateTime(2027, 2, 10)).id, 'stable');
      expect(
        configured
            .resolve(id: 'stable', name: 'Old name', at: DateTime(2026, 10))!
            .name,
        'Renamed',
      );
    },
  );

  test(
    'finished courses sort by latest class completion, with cached aggregation',
    () {
      final records = [
        for (var i = 0; i < 1000; i++)
          <String, dynamic>{
            'kind': 'course',
            'counted': true,
            'courseKey': 'c$i',
            'name': 'Course $i',
            'semester': 'Term',
            'minutes': 60,
            'endAt': DateTime(
              2026,
              1,
              1,
            ).add(Duration(hours: i)).toUtc().toIso8601String(),
          },
      ];
      final stats = OrbitStatistics(records: records);
      expect(stats.learnedCourses.first.name, 'Course 999');
      expect(stats.learnedCourses, hasLength(1000));
      expect(identical(stats.learnedCourses, stats.learnedCourses), true);
    },
  );

  test('fallback order, limits and unavailable fonts are deterministic', () {
    final value = TypographySettings.fromJson(const {
      'fallbackFontIds': ['huninn', 'rounded', 'maiyuan'],
    });
    expect(value.fallbackFamilies('huninn').take(2), [
      'OrbitFont_rounded',
      'OrbitFont_maiyuan',
    ]);
    expect(
      value
          .copyWith(unavailableFontIds: {'rounded'})
          .fallbackFamilies('huninn')
          .first,
      'OrbitFont_maiyuan',
    );
    expect(
      TypographySettings.fromJson(value.toJson()).fallbackFontIds,
      value.fallbackFontIds,
    );
    expect(
      () => TypographySettings.fromJson(const {
        'fallbackFontIds': ['huninn', 'huninn'],
      }),
      throwsFormatException,
    );
    expect(
      () => TypographySettings.fromJson(const {
        'fallbackFontIds': ['huninn', 'rounded', 'maiyuan', 'nunito'],
      }),
      throwsFormatException,
    );
  });

  test(
    'coverage detection checks actual glyph mappings, including supplementary Chinese',
    () async {
      expect(
        fontContainsChinese(
          await File('assets/fonts/Nunito.ttf').readAsBytes(),
        ),
        false,
      );
      Uint8List cmap(int glyph) {
        final bytes = Uint8List(80);
        final d = ByteData.sublistView(bytes);
        d.setUint16(4, 1);
        d.setUint32(12, 0x636d6170);
        d.setUint32(20, 28);
        d.setUint32(24, 40);
        d.setUint16(30, 1);
        d.setUint16(32, 3);
        d.setUint16(34, 10);
        d.setUint32(36, 12);
        d.setUint16(40, 12);
        d.setUint32(44, 28);
        d.setUint32(52, 1);
        d.setUint32(56, 0x20000);
        d.setUint32(60, 0x20000);
        d.setUint32(64, glyph);
        return bytes;
      }

      expect(fontContainsChinese(cmap(1)), true);
      expect(fontContainsChinese(cmap(0)), false);
      expect(fontContainsChinese(Uint8List(2)), false);
    },
  );

  test(
    'unavailable fallback is skipped while later fallback still loads',
    () async {
      final registered = <String>[];
      final fonts = FontService(
        directory: root,
        register: (family, _) async => registered.add(family),
      );
      final settings = await fonts.prepare(
        const TypographySettings(fallbackFontIds: ['rounded', 'nunito']),
        recover: true,
      );
      expect(settings.unavailableFontIds, contains('rounded'));
      expect(registered, contains('OrbitBrand'));
      expect(
        settings.fallbackFamilies('system'),
        isNot(contains('OrbitFont_rounded')),
      );
    },
  );

  test('animation defaults and icon edits preserve all individual choices', () {
    final defaults = LaunchSettings.fromJson({});
    expect(defaults.brandEnabled, true);
    expect(defaults.onStartup, true);
    expect(defaults.onResume, false);
    expect(defaults.onPageSwitch, false);
    expect(defaults.pageEnabled, everyElement(true));
    final next = defaults.copyWith(
      brandEnabled: false,
      onResume: true,
      pageEnabled: [false, true, false, true],
    );
    final saved = LaunchSettings.fromJson(
      next.copyWith(iconPath: 'icon.png').toJson(),
    );
    expect(saved.brandEnabled, false);
    expect(saved.onResume, true);
    expect(saved.pageEnabled, [false, true, false, true]);
  });

  test('reused generic semester names stay separate across academic years', () {
    final service = SemesterService();
    final first = service.resolve(name: '秋季学期', at: DateTime(2025, 9))!;
    final second = service.resolve(name: '秋季学期', at: DateTime(2026, 9))!;
    expect(first.id, isNot(second.id));
    expect(service.current(DateTime(2026, 10)).id, second.id);
  });

  test(
    'renaming one generic semester does not move a different academic year',
    () async {
      final oldStart = DateTime(2025, 10, 18, 10);
      await db.upsertSessions([
        sample(id: 'old').copyWith(
          semester: '秋季学期',
          startAt: oldStart,
          endAt: oldStart.add(const Duration(hours: 2)),
        ),
        sample(id: 'new').copyWith(semester: '秋季学期'),
      ]);
      await db.refreshStatistics(now: DateTime(2026, 12));
      final id = SemesterService.namedId('秋季学期', oldStart);
      await db.renameSemesterStatistics(
        id,
        '秋季学期',
        '2025 Fall',
        start: DateTime(2025, 8),
        end: DateTime(2026, 1, 31),
      );
      final records = await db.statisticsRecords();
      expect(
        records.singleWhere((r) => r['id'] == 'course|old')['semester'],
        '2025 Fall',
      );
      expect(
        records.singleWhere((r) => r['id'] == 'course|new')['semester'],
        '秋季学期',
      );
      expect(OrbitStatistics(records: records).attendedSessions, 2);
    },
  );

  test('cross-midnight exam keeps the semester of its start', () async {
    final start = DateTime(2027, 1, 31, 23);
    final exam = sample(id: 'exam|midnight', kind: SessionKind.exam).copyWith(
      semester: '',
      startAt: start,
      endAt: start.add(const Duration(hours: 2)),
    );
    await db.upsertSessions([exam]);
    await db.refreshStatistics(now: DateTime(2027, 2, 1, 2));
    final records = await db.statisticsRecords();
    final terms = SemesterService(records: records);
    expect(terms.recordSemester(records.single), 'calendar|2026|autumn');
  });

  test(
    'animation preferences survive protection backup and old downgrade excludes exams',
    () async {
      const settings = LaunchSettings(
        brandEnabled: false,
        onResume: true,
        pageEnabled: [false, true, false, true],
      );
      final service = SettingsService();
      await service.saveLocalJson('launch_presentation_v1', settings.toJson());
      final encoder = ScheduleBackupService();
      final json = await encoder.encodeWithAudio(
        [sample(id: 'exam|one', kind: SessionKind.exam)],
        await service.exportPortableSettings(),
        protectLocalResources: true,
      );
      final backup = encoder.decodeBackup(json);
      expect(
        LaunchSettings.fromJson(backup.localPresentation!).toJson(),
        settings.toJson(),
      );
      final old = DowngradeService.convert(json, '1.6.1')!;
      expect(old.losses, contains('exams'));
      expect(encoder.decodeBackup(old.json).sessions, isEmpty);
      expect(old.backupVersion, 12);
    },
  );
  test(
    'native spreadsheet round trip preserves exam type, ID, settings and next-day end',
    () {
      final start = DateTime(2026, 10, 18, 23);
      final exam = sample(id: 'exam|xlsx', kind: SessionKind.exam).copyWith(
        startAt: start,
        endAt: start.add(const Duration(hours: 2)),
        semesterId: 'stable',
        examLeadMinutes: 45,
        examStrongReminder: false,
      );
      final restored = XlsxParser()
          .parseBytes(XlsxExporter().exportBytes([exam]))
          .single;
      expect(restored.kind, SessionKind.exam);
      expect(restored.id, exam.id);
      expect(restored.endAt, exam.endAt);
      expect(restored.examLeadMinutes, 45);
      expect(restored.examStrongReminder, false);
      expect(restored.semesterId, 'stable');
    },
  );
}
