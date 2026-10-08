import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/data/repositories/schedule_repository.dart';
import 'package:orbit/features/archive/archive_page.dart';
import 'package:orbit/features/session/existing_course_picker.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/archive_settings.dart';
import 'package:orbit/models/batch_course.dart';
import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/notification_copy.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/services/custom_reminder_planner.dart';
import 'package:orbit/services/reminder_alarm_planner.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/strong_reminder_resolver.dart';
import 'package:orbit/services/xlsx_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CourseSession sampleClass(
  String id,
  DateTime start, {
  String code = 'MATH',
  String semester = '2026A',
  int? period,
}) => CourseSession(
  id: id,
  classType: 'Lecture',
  room: 'A1',
  date: DateTime(start.year, start.month, start.day),
  weekday: start.weekday,
  courseName: 'Mathematics',
  courseCode: code,
  section: '1',
  startAt: start,
  endAt: start.add(const Duration(hours: 1)),
  teachers: const ['Teacher'],
  faculty: 'Science',
  semester: semester,
  startPeriod: period,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 8, 12);
  late Directory directory;
  late AppDatabase db;
  late ScheduleRepository repo;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('orbit_archive_');
    db = await AppDatabase.open(directory.path);
    repo = ScheduleRepository(db, XlsxParser());
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'whole-course archive excludes ongoing, future and other semesters',
    () async {
      final ended = sampleClass(
        'ended',
        now.subtract(const Duration(hours: 2)),
      );
      final boundary = sampleClass(
        'boundary',
        now.subtract(const Duration(hours: 1)),
      );
      final ongoing = sampleClass(
        'ongoing',
        now.subtract(const Duration(minutes: 30)),
      );
      final future = sampleClass('future', now.add(const Duration(days: 1)));
      final other = sampleClass('other', ended.startAt, semester: '2025A');
      await db.upsertSessions([ended, boundary, ongoing, future, other]);
      expect(
        await repo.archiveCourse(
          ended,
          wholeCourse: true,
          hide: false,
          at: now,
        ),
        2,
      );
      final values = await db.getAllSessions();
      expect(values.where((s) => s.archived).map((s) => s.id).toSet(), {
        'ended',
        'boundary',
      });
      expect(
        values.every((s) => !s.archiveHidden && s.deletedAt == null),
        isTrue,
      );
      expect(await db.getDeletedSessions(), isEmpty);
      expect(await repo.archiveCourse(ended, wholeCourse: true, at: now), 0);
    },
  );

  test(
    'archive all ended classes keeps ongoing, future, archived and trash',
    () async {
      final ended = sampleClass(
        'ended',
        now.subtract(const Duration(hours: 2)),
      );
      final boundary = sampleClass(
        'boundary',
        now.subtract(const Duration(hours: 1)),
        code: 'OTHER',
        semester: '2025A',
      );
      final paused = sampleClass(
        'paused',
        now.subtract(const Duration(days: 3)),
      ).copyWith(autoArchivePaused: true);
      final archived =
          sampleClass(
            'archived',
            now.subtract(const Duration(days: 2)),
          ).copyWith(
            archivedAt: now.subtract(const Duration(days: 1)),
            archiveHidden: false,
          );
      final trash = sampleClass(
        'trash',
        now.subtract(const Duration(days: 1)),
      ).copyWith(deletedAt: now);
      final ongoing = sampleClass(
        'ongoing',
        now.subtract(const Duration(minutes: 30)),
      );
      final future = sampleClass('future', now.add(const Duration(days: 1)));
      await db.upsertSessions([
        ended,
        boundary,
        paused,
        archived,
        trash,
        ongoing,
        future,
      ]);
      expect(
        (await repo.getUnarchivedEndedSessions(
          at: now,
        )).map((s) => s.id).toSet(),
        {'ended', 'boundary', 'paused'},
      );
      expect(await repo.archiveEndedSessions(at: now), 3);
      for (final id in ['ended', 'boundary', 'paused']) {
        final value = (await db.getSessionById(id))!;
        expect(value.archivedAt, now);
        expect(value.archiveHidden, isTrue);
        expect(value.deletedAt, isNull);
      }
      expect((await db.getSessionById('ongoing'))!.archived, isFalse);
      expect((await db.getSessionById('future'))!.archived, isFalse);
      expect(
        (await db.getSessionById('archived'))!.archivedAt,
        archived.archivedAt,
      );
      expect((await db.getSessionById('archived'))!.archiveHidden, isFalse);
      expect((await db.getDeletedSessions()).map((s) => s.id), ['trash']);
      expect(await repo.archiveEndedSessions(at: now), 0);
    },
  );

  test(
    'archive confirmation snapshot excludes new and rescheduled classes',
    () async {
      final changed = sampleClass(
        'changed',
        now.subtract(const Duration(hours: 2)),
      );
      final ended = sampleClass(
        'ended',
        now.subtract(const Duration(hours: 2)),
      );
      await db.upsertSessions([changed, ended]);
      final ids = (await repo.getUnarchivedEndedSessions(
        at: now,
      )).map((s) => s.id).toList();
      await db.upsertSessions([
        sampleClass('changed', now.add(const Duration(days: 1))),
        sampleClass('new', now.subtract(const Duration(days: 1))),
      ]);
      expect(
        await repo.archiveEndedSessions(sessionIds: ids, hide: false, at: now),
        1,
      );
      expect((await db.getSessionById('ended'))!.archived, isTrue);
      expect((await db.getSessionById('ended'))!.visible, isTrue);
      expect((await db.getSessionById('changed'))!.archived, isFalse);
      expect((await db.getSessionById('new'))!.archived, isFalse);
    },
  );

  test('single archive, batch visibility and restore keep all data', () async {
    final a = sampleClass('a', now.subtract(const Duration(days: 1)));
    final b = sampleClass('b', now.subtract(const Duration(days: 2)));
    await db.upsertSessions([a, b]);
    await repo.archiveCourse(a, wholeCourse: false, at: now);
    expect((await db.getSessionById('b'))!.archived, isFalse);
    expect((await db.getSessionById('a'))!.visible, isFalse);
    await db.updateArchive(sessionIds: ['a'], action: ArchiveMutation.show);
    expect((await db.getSessionById('a'))!.visible, isTrue);
    await repo.archiveCourse(b, wholeCourse: false, hide: false, at: now);
    await db.updateArchive(
      sessionIds: ['a', 'b', 'a'],
      action: ArchiveMutation.hide,
    );
    expect((await db.getAllSessions()).every((s) => !s.visible), isTrue);
    await db.updateArchive(
      sessionIds: ['a', 'b'],
      action: ArchiveMutation.restore,
    );
    expect(
      (await db.getAllSessions()).every(
        (s) => !s.archived && s.visible && s.autoArchivePaused,
      ),
      isTrue,
    );
  });

  test('DDL must be completed; archive is not a deletion', () async {
    final ddl = Deadline(
      id: 'd',
      subject: 'Math',
      title: 'Task',
      dueAt: now.add(const Duration(days: 1)),
      leadMinutes: const [60],
    );
    await db.saveDeadline(ddl);
    expect(
      await db.updateArchive(
        deadlineIds: ['d'],
        action: ArchiveMutation.archive,
        at: now,
      ),
      0,
    );
    await db.saveDeadline(ddl.copyWith(completedAt: now));
    expect(
      await db.updateArchive(
        deadlineIds: ['d'],
        action: ArchiveMutation.archive,
        hide: false,
        at: now,
      ),
      1,
    );
    final stored = (await db.getDeadlines()).single;
    expect(stored.archived && stored.completed && stored.visible, isTrue);
    expect(stored.deleted, isFalse);
  });

  test(
    'auto archive applies separate delay and visibility preferences once',
    () async {
      final old = sampleClass('old', now.subtract(const Duration(days: 2)));
      final recent = sampleClass(
        'recent',
        now.subtract(const Duration(hours: 2)),
      );
      await db.upsertSessions([old, recent]);
      await db.saveDeadline(
        Deadline(
          id: 'd',
          subject: 'Math',
          title: 'Task',
          dueAt: now,
          leadMinutes: const [60],
          completedAt: now.subtract(const Duration(days: 7)),
        ),
      );
      expect(await repo.runAutoArchive(const ArchiveSettings(), at: now), 0);
      const settings = ArchiveSettings(
        autoCourses: true,
        autoDeadlines: true,
        deadlineDelayDays: 7,
        hideCourses: false,
      );
      expect(await repo.runAutoArchive(settings, at: now), 2);
      expect((await db.getSessionById('old'))!.visible, isTrue);
      expect((await db.getSessionById('recent'))!.archived, isFalse);
      expect((await db.getDeadlines()).single.archiveHidden, isTrue);
      expect(await repo.runAutoArchive(settings, at: now), 0);
    },
  );

  test('restored courses stay paused until their end time changes', () async {
    final a = sampleClass('a', now.subtract(const Duration(days: 3)));
    await db.upsertSessions([a]);
    const settings = ArchiveSettings(autoCourses: true);
    await repo.runAutoArchive(settings, at: now);
    await db.updateArchive(sessionIds: ['a'], action: ArchiveMutation.restore);
    expect(await repo.runAutoArchive(settings, at: now), 0);
    final restored = (await db.getSessionById('a'))!;
    await db.updateSession(
      restored.copyWith(endAt: restored.endAt.add(const Duration(minutes: 5))),
    );
    expect(await repo.runAutoArchive(settings, at: now), 1);
  });

  test(
    'recompleting restored DDL restarts automatic archive eligibility',
    () async {
      await db.saveDeadline(
        Deadline(
          id: 'd',
          subject: 'Math',
          title: 'Task',
          dueAt: now,
          leadMinutes: const [60],
          completedAt: now.subtract(const Duration(days: 2)),
        ),
      );
      const settings = ArchiveSettings(
        autoDeadlines: true,
        deadlineDelayDays: 0,
      );
      await repo.runAutoArchive(settings, at: now);
      await db.updateArchive(
        deadlineIds: ['d'],
        action: ArchiveMutation.restore,
      );
      expect(await repo.runAutoArchive(settings, at: now), 0);
      var restored = (await db.getDeadlines()).single;
      restored = restored
          .copyWith(clearCompleted: true)
          .copyWith(completedAt: now);
      await db.saveDeadline(restored);
      expect(await repo.runAutoArchive(settings, at: now), 1);
    },
  );

  test(
    'archive metadata survives reopen and sync to a second database',
    () async {
      final a = sampleClass('a', now.subtract(const Duration(days: 1)))
          .copyWith(
            linkedCourseKey: 'recurrence:original',
            startPeriod: 1,
            periodTimePlanId: 'plan',
          );
      await db.upsertSessions([a]);
      await repo.archiveCourse(a, wholeCourse: false, at: now);
      await db.close();
      db = await AppDatabase.open(directory.path);
      final source = (await db.getAllSessions()).single;
      expect(source.archived, isTrue);
      final targetDir = await Directory.systemTemp.createTemp(
        'orbit_archive_remote_',
      );
      final target = await AppDatabase.open(targetDir.path);
      try {
        await target.applyRemoteEntities([
          SyncEntity(
            type: SyncEntityType.courseSession,
            id: source.id,
            revision: 1,
            payload: courseSessionSyncPayload(source),
          ),
        ]);
        final remote = (await target.getAllSessions()).single;
        expect(remote.archiveHidden, isTrue);
        expect(remote.linkedCourseKey, 'recurrence:original');
        expect(remote.startPeriod, 1);
        expect(remote.periodTimePlanId, 'plan');
      } finally {
        await target.close();
        await targetDir.delete(recursive: true);
      }
    },
  );

  test('backup v8 round trip and older backups use safe defaults', () async {
    final a = sampleClass('a', now).copyWith(
      archivedAt: now,
      archiveHidden: true,
      autoArchivePaused: true,
      linkedCourseKey: 'original',
      startPeriod: 1,
    );
    final ddl = Deadline(
      id: 'd',
      subject: 'Math',
      title: 'Task',
      dueAt: now,
      leadMinutes: const [60],
      archivedAt: now,
      archiveHidden: true,
      completedAt: now,
    );
    final service = ScheduleBackupService();
    final decoded = service.decodeBackup(
      service.encodeToJson([a], deadlines: [ddl]),
    );
    expect(decoded.version, ScheduleBackupService.backupVersion);
    expect(decoded.sessions.single.featurePayload, a.featurePayload);
    expect(decoded.deadlines.single.toSyncPayload(), ddl.toSyncPayload());
    final legacy = service.decodeBackup('{"version":1,"sessions":[]}');
    expect(legacy.sessions, isEmpty);
    expect(
      StrongReminderSettings.fromJson({'enabled': true}).onlyFirstClass,
      isFalse,
    );
  });

  test(
    'portable backup restores archive display and automatic settings',
    () async {
      final settings = ArchiveSettings(
        groupCourses: false,
        courseSort: ArchiveSort.manual,
        orders: const {
          'sessions': ['b', 'a'],
        },
        autoCourses: true,
        courseDelayDays: 7,
      );
      final service = SettingsService();
      await service.saveArchiveSettings(settings);
      final portable = await service.exportPortableSettings();
      final backup = ScheduleBackupService();
      final restored = backup
          .decodeBackup(backup.encodeToJson([], settings: portable))
          .settings!;
      await service.saveArchiveSettings(const ArchiveSettings());
      await service.importPortableSettings(restored);
      expect((await service.loadArchiveSettings()).toJson(), settings.toJson());
    },
  );

  test('grouping separates semesters and merged sort uses newest archive', () {
    final old = sampleClass(
      'old',
      now,
    ).copyWith(archivedAt: now.subtract(const Duration(days: 1)));
    final newer = sampleClass('new', now).copyWith(archivedAt: now);
    final otherSemester = sampleClass(
      'other',
      now,
      semester: '2025',
    ).copyWith(archivedAt: now.subtract(const Duration(days: 2)));
    final grouped = buildArchiveEntries(
      [old, newer, otherSemester],
      [],
      false,
      const ArchiveSettings(),
    );
    expect(grouped.length, 2);
    expect(grouped.first.count, 2);
    expect(grouped.first.archivedAt, now);
    expect(
      buildArchiveEntries(
        [old, newer],
        [],
        false,
        const ArchiveSettings(groupCourses: false),
      ).length,
      2,
    );
    final manual = buildArchiveEntries(
      [old, newer],
      [],
      false,
      const ArchiveSettings(
        groupCourses: false,
        courseSort: ArchiveSort.manual,
        orders: {
          'sessions': ['session:old'],
        },
      ),
    );
    expect(manual.map((e) => e.key), ['session:new', 'session:old']);
  });

  test(
    'reusing archived course creates unarchived classes in original group',
    () async {
      final original = sampleClass('old', now.subtract(const Duration(days: 2)))
          .copyWith(
            archivedAt: now,
            archiveHidden: true,
            recurrenceSeriesId: 'original',
            recurrenceMeetingId: 'meeting-old',
          );
      await db.upsertSessions([original]);
      final generated = generateBatchCourseSessions(
        BatchCourseDraft(
          courseName: original.courseName,
          courseCode: original.courseCode,
          section: original.section,
          teachers: original.teachers,
          faculty: original.faculty,
          classType: original.classType,
          semester: original.semester,
          linkedCourseKey: CourseSeriesKey.fromSession(original).value,
          firstWeekMonday: DateTime(2026, 10, 12),
          totalWeeks: 2,
          selectedWeeks: {1, 2},
          meetings: const [
            BatchMeeting(
              id: 'new-meeting',
              weekday: 1,
              room: 'New room',
              startMinute: 540,
              endMinute: 600,
            ),
          ],
        ),
        seriesId: 'original',
      );
      await repo.saveBatchSessions(
        generated,
        strategy: BatchConflictStrategy.skip,
      );
      expect(generated.every((s) => !s.archived && s.visible), isTrue);
      expect(
        (await repo.getCourseSeries(original, CourseOperationScope.all)).length,
        3,
      );
      expect((await db.getSessionById('old'))!.archiveHidden, isTrue);
      final repeated = await repo.saveBatchSessions(
        generated,
        strategy: BatchConflictStrategy.skip,
      );
      expect(repeated.createdCount, 0);
      expect(
        existingCourses(await db.getAllSessions()).single.archivedOnly,
        isFalse,
      );
    },
  );

  test('existing picker separates identical names by course and semester', () {
    final a = sampleClass('a', now).copyWith(archivedAt: now);
    final b = sampleClass('b', now, semester: '2025');
    final c = sampleClass('c', now, code: 'OTHER');
    final courses = existingCourses([a, b, c]);
    expect(courses.length, 3);
    expect(courses.last.archivedOnly, isTrue);
  });

  test(
    'legacy default fields do not create artificial first-login conflicts',
    () {
      final modern = courseSessionSyncPayload(sampleClass('a', now));
      final legacy = {...modern}
        ..removeWhere(
          (key, _) => const [
            'archivedAt',
            'archiveHidden',
            'autoArchivePaused',
            'linkedCourseKey',
            'startPeriod',
            'periodTimePlanId',
          ].contains(key),
        );
      expect(canonicalSyncPayload(modern), canonicalSyncPayload(legacy));
      final archived = {
        ...modern,
        'archivedAt': now.toUtc().toIso8601String(),
        'archiveHidden': true,
      };
      expect(
        canonicalSyncPayload(archived),
        isNot(canonicalSyncPayload(legacy)),
      );
    },
  );

  group('first class strong reminders', () {
    final first = sampleClass('first', DateTime(2026, 10, 8, 9));
    final second = sampleClass('second', DateTime(2026, 10, 8, 10));
    final noon = sampleClass('noon', DateTime(2026, 10, 8, 12));
    const cutoff = StrongReminderSettings(
      enabled: true,
      onlyFirstClass: true,
      firstClassMode: FirstClassMode.beforeTime,
    );
    test(
      'uses full daily schedule, strict cutoff and simultaneous earliest classes',
      () {
        expect(matchesFirstClass(cutoff, first, [first, second], []), isTrue);
        expect(matchesFirstClass(cutoff, second, [first, second], []), isFalse);
        expect(matchesFirstClass(cutoff, noon, [noon], []), isFalse);
        expect(
          matchesFirstClass(cutoff, first.copyWith(id: 'conflict'), [
            first,
          ], []),
          isTrue,
        );
        expect(
          matchesFirstClass(cutoff.copyWith(cutoffMinute: 900), noon, [
            noon,
          ], []),
          isTrue,
        );
      },
    );
    test('trusts period metadata including first-period double classes', () {
      const settings = StrongReminderSettings(onlyFirstClass: true);
      expect(
        matchesFirstClass(
          settings,
          first.copyWith(startPeriod: 1, endAt: DateTime(2026, 10, 8, 11)),
          [first, second],
          [],
        ),
        isTrue,
      );
      expect(
        matchesFirstClass(settings, second.copyWith(startPeriod: 2), [
          second,
        ], []),
        isFalse,
      );
      expect(
        first
            .copyWith(startPeriod: 1)
            .copyWith(startAt: second.startAt)
            .startPeriod,
        isNull,
      );
    });
    test(
      'matches timetable plans and falls back for unknown or ambiguous times',
      () {
        final plan = PeriodTimePlan(
          id: 'p',
          name: 'Plan',
          periods: const [
            PeriodTime(number: 1, startMinute: 540, endMinute: 600),
            PeriodTime(number: 2, startMinute: 600, endMinute: 660),
          ],
        );
        final conflicting = PeriodTimePlan(
          id: 'q',
          name: 'Other',
          periods: const [
            PeriodTime(number: 2, startMinute: 540, endMinute: 600),
          ],
        );
        const settings = StrongReminderSettings(onlyFirstClass: true);
        expect(
          matchesFirstClass(settings, first, [first, second], [plan]),
          isTrue,
        );
        expect(matchesFirstClass(settings, second, [second], [plan]), isFalse);
        expect(
          matchesFirstClass(settings, first, [first], [plan, conflicting]),
          isTrue,
        );
        expect(
          matchesFirstClass(
            settings.copyWith(periodTimePlanId: 'q'),
            first,
            [first],
            [plan, conflicting],
          ),
          isFalse,
        );
        expect(matchesFirstClass(settings, second, [second], []), isTrue);
      },
    );
    test('rule overrides and summaries preserve priority', () {
      StrongReminderSettings resolve({
        CustomReminderRule? rule,
        StrongReminderType type = StrongReminderType.custom,
      }) => resolveStrongReminder(
        global: cutoff,
        type: type,
        session: second,
        dailySessions: [first, second],
        rule: rule,
      );
      final rule = CustomReminderRule(
        id: 'r',
        name: 'Rule',
        activeFrom: now,
        strength: ReminderStrength.strong,
      );
      expect(resolve().enabled, isFalse);
      expect(resolve(rule: rule).enabled, isTrue);
      expect(
        resolve(rule: rule.copyWith(strength: ReminderStrength.normal)).enabled,
        isFalse,
      );
      expect(resolve(type: StrongReminderType.summary).enabled, isTrue);
    });
    test(
      'builtin and custom planners keep ordinary second-class reminders',
      () {
        final copy = NotificationCopy.fromL10n(lookupL10n(const Locale('en')));
        final specs = buildReminderAlarmSpecs(
          upcomingSessions: [second],
          allSessions: [first, second],
          settings: const ReminderSettings(strong: cutoff),
          now: DateTime(2026, 10, 8, 8),
          copy: copy,
        );
        expect(specs.length, 2);
        expect(specs.every((s) => !s.strong.enabled), isTrue);
        final rule = CustomReminderRule(
          id: 'r',
          name: 'Rule',
          activeFrom: DateTime(2026, 10, 7),
        );
        final custom = planCustomReminders(
          sessions: [first, second],
          rules: [rule],
          strong: cutoff,
          now: DateTime(2026, 10, 8, 8),
        );
        expect(custom.length, 2);
        expect(custom.first.strong.enabled, isTrue);
        expect(custom.last.strong.enabled, isFalse);
      },
    );
    test('archived records do not produce reminders or custom catch-up', () {
      final archived = first.copyWith(archivedAt: now, archiveHidden: false);
      final copy = NotificationCopy.fromL10n(lookupL10n(const Locale('en')));
      expect(
        buildReminderAlarmSpecs(
          upcomingSessions: [archived],
          settings: const ReminderSettings(),
          now: DateTime(2026, 10, 8, 8),
          copy: copy,
        ),
        isEmpty,
      );
      final rule = CustomReminderRule(
        id: 'r',
        name: 'Rule',
        activeFrom: DateTime(2026, 10, 7),
      );
      expect(
        planCustomReminders(
          sessions: [archived],
          rules: [rule],
          strong: cutoff,
          now: now,
        ),
        isEmpty,
      );
    });
  });
}
