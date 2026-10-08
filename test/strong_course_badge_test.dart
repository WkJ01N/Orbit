import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/features/reminder/strong_badge.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'archive_and_first_class_test.dart' show sampleClass;

class _Db implements AppDatabase {
  @override
  Future<Map<String, String>> reminderSessionAliases() async => {
    'legacy-b': 'stable-b',
    'b': 'stable-b',
  };
  @override
  Future<Map<String, List<String>>> reminderSeriesMemberships() async => {};
  @override
  Future<List<Map<String, Object?>>> reminderDeliveryStates() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ReminderSettings _settings = const ReminderSettings();
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'badges honor first-period filtering, explicit rules, aliases and archive exclusion',
    () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day + 2, 9);
      final a = sampleClass('a', start).copyWith(startPeriod: 1);
      final b = sampleClass(
        'b',
        start.add(const Duration(hours: 1)),
      ).copyWith(startPeriod: 2);
      _settings = ReminderSettings(
        nextDaySummaryEnabled: false,
        checkInReminderEnabled: false,
        strong: const StrongReminderSettings(
          enabled: true,
          onlyFirstClass: true,
          types: {StrongReminderType.classLead},
        ),
        customRules: [
          CustomReminderRule(
            id: 'r',
            name: 'Override',
            activeFrom: now,
            scope: ReminderCourseScope.sessions,
            courseKeys: ['legacy-b'],
            strength: ReminderStrength.strong,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(_Db()),
          effectiveReminderSettingsProvider.overrideWith(
            (_) async => _settings,
          ),
          sessionsProvider.overrideWith(
            (_) async => [
              a,
              b,
              a.copyWith(id: 'archived', archivedAt: now),
              a.copyWith(id: 'deleted', deletedAt: now),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(strongCourseIdsProvider.future), {'a', 'b'});
    },
  );
  test(
    'summary strength does not badge every course; disabling local strong rules removes badges',
    () async {
      final now = DateTime.now();
      _settings = const ReminderSettings(
        strong: StrongReminderSettings(
          enabled: true,
          types: {StrongReminderType.summary},
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(_Db()),
          effectiveReminderSettingsProvider.overrideWith(
            (_) async => _settings,
          ),
          sessionsProvider.overrideWith(
            (_) async => [sampleClass('a', now.add(const Duration(days: 2)))],
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(strongCourseIdsProvider.future), isEmpty);
      _settings = const ReminderSettings();
      container.invalidate(effectiveReminderSettingsProvider);
      expect(await container.read(strongCourseIdsProvider.future), isEmpty);
    },
  );
}
