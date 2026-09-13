import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/batch_course.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

BatchCourseDraft _draft({
  Set<int> weeks = const {1, 3},
  List<BatchMeeting>? meetings,
}) {
  return BatchCourseDraft(
    courseName: 'Algorithms',
    courseCode: '',
    section: 'A',
    teachers: const ['Teacher'],
    faculty: 'FIE',
    classType: 'Lecture',
    semester: '2609',
    firstWeekMonday: DateTime(2026, 8, 31),
    totalWeeks: 18,
    selectedWeeks: weeks,
    meetings:
        meetings ??
        const [
          BatchMeeting(
            id: 'monday',
            weekday: DateTime.monday,
            room: 'A101',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
          BatchMeeting(
            id: 'wednesday',
            weekday: DateTime.wednesday,
            room: 'B202',
            startMinute: 14 * 60,
            endMinute: 15 * 60 + 30,
          ),
        ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selected weeks and multiple meetings generate sorted sessions', () {
    final sessions = generateBatchCourseSessions(
      _draft(),
      seriesId: 'series-1',
    );

    expect(sessions, hasLength(4));
    expect(sessions.map((session) => session.date), [
      DateTime(2026, 8, 31),
      DateTime(2026, 9, 2),
      DateTime(2026, 9, 14),
      DateTime(2026, 9, 16),
    ]);
    expect(sessions.map((session) => session.room), [
      'A101',
      'B202',
      'A101',
      'B202',
    ]);
    expect(
      sessions.every((session) => session.recurrenceSeriesId == 'series-1'),
      isTrue,
    );
    expect(sessions.map((session) => session.recurrenceMeetingId).toSet(), {
      'monday',
      'wednesday',
    });
    expect(
      sessions.every((session) => session.courseCode == 'MANUAL|series-1'),
      isTrue,
    );
  });

  test('generation crosses year boundary using semester week numbers', () {
    final sessions = generateBatchCourseSessions(
      BatchCourseDraft(
        courseName: 'Winter class',
        courseCode: 'WIN101',
        section: '1',
        teachers: const [],
        faculty: '',
        classType: 'Lecture',
        semester: '',
        firstWeekMonday: DateTime(2026, 12, 28),
        totalWeeks: 2,
        selectedWeeks: const {2},
        meetings: const [
          BatchMeeting(
            id: 'friday',
            weekday: DateTime.friday,
            room: 'R1',
            startMinute: 8 * 60,
            endMinute: 9 * 60,
          ),
        ],
      ),
      seriesId: 'winter',
    );

    expect(sessions.single.date, DateTime(2027, 1, 8));
  });

  test('overlap validation only rejects intersecting meetings on same day', () {
    expect(
      batchMeetingsOverlap(const [
        BatchMeeting(
          id: 'a',
          weekday: 1,
          room: 'R1',
          startMinute: 540,
          endMinute: 600,
        ),
        BatchMeeting(
          id: 'b',
          weekday: 1,
          room: 'R2',
          startMinute: 570,
          endMinute: 630,
        ),
      ]),
      isTrue,
    );
    expect(
      batchMeetingsOverlap(const [
        BatchMeeting(
          id: 'a',
          weekday: 1,
          room: 'R1',
          startMinute: 540,
          endMinute: 600,
        ),
        BatchMeeting(
          id: 'b',
          weekday: 3,
          room: 'R2',
          startMinute: 570,
          endMinute: 630,
        ),
      ]),
      isFalse,
    );
  });

  test(
    'batch form defaults start at 18 weeks and persist last semester',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();

      final initial = await service.loadBatchCourseDefaults();
      expect(initial.totalWeeks, 18);
      expect(initial.firstWeekMonday, isNull);

      await service.saveBatchCourseDefaults(
        firstWeekMonday: DateTime(2026, 8, 31, 13, 20),
        totalWeeks: 22,
      );
      final restored = await service.loadBatchCourseDefaults();
      expect(restored.totalWeeks, 22);
      expect(restored.firstWeekMonday, DateTime(2026, 8, 31));
    },
  );

  test(
    'narrow schedule layout defaults to compact week and persists',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();

      expect(
        (await service.loadScheduleDisplaySettings()).narrowLayout,
        NarrowScheduleLayout.compactWeek,
      );
      await service.saveScheduleDisplaySettings(
        const ScheduleDisplaySettings(
          narrowLayout: NarrowScheduleLayout.adaptive,
          preferredMultiDayCount: 4,
          showEmptyDays: false,
        ),
      );
      final restored = await service.loadScheduleDisplaySettings();
      expect(restored.narrowLayout, NarrowScheduleLayout.adaptive);
      expect(restored.preferredMultiDayCount, 4);
      expect(restored.showEmptyDays, isFalse);
    },
  );
}
