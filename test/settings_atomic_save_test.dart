import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/reminder_settings.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'save writes single reminder_settings_v2 JSON and round-trips all fields',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();
      final settings = ReminderSettings(
        leadMinutes: 25,
        enabled: false,
        nextDaySummaryEnabled: false,
        nextDaySummaryHour: 21,
        nextDaySummaryMinute: 45,
        nextDayRemindWhenNoClass: false,
        nextDayWithClassTitleTemplate: 'Next Title',
        nextDayWithClassBodyTemplate: 'Next Body',
        nextDayNoClassTitleTemplate: 'Rest Title',
        nextDayNoClassBodyTemplate: 'Rest Body',
        classLeadTitleTemplate: 'Lead Title',
        classLeadBodyTemplate: 'Lead Body',
        checkInTitleTemplate: 'Check Title',
        checkInBodyTemplate: 'Check Body',
        checkInReminderEnabled: false,
        customRules: [
          CustomReminderRule(
            id: 'r1',
            name: 'Morning',
            activeFrom: DateTime(2026, 1, 1),
            offsetSeconds: -1200,
            strength: ReminderStrength.strong,
          ),
        ],
        strong: const StrongReminderSettings(
          enabled: true,
          onlyFirstClass: true,
          cutoffMinute: 540,
        ),
      );

      await service.save(settings);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('reminder_settings_v2'), isTrue);
      expect(prefs.containsKey('reminder_lead_minutes'), isFalse);
      expect(prefs.containsKey('custom_reminder_rules'), isFalse);
      expect(prefs.containsKey('strong_reminder_settings'), isFalse);

      final reloaded = await SettingsService().load();
      expect(reloaded.leadMinutes, 25);
      expect(reloaded.enabled, isFalse);
      expect(reloaded.nextDaySummaryEnabled, isFalse);
      expect(reloaded.nextDaySummaryHour, 21);
      expect(reloaded.nextDaySummaryMinute, 45);
      expect(reloaded.nextDayRemindWhenNoClass, isFalse);
      expect(reloaded.nextDayWithClassTitleTemplate, 'Next Title');
      expect(reloaded.nextDayWithClassBodyTemplate, 'Next Body');
      expect(reloaded.nextDayNoClassTitleTemplate, 'Rest Title');
      expect(reloaded.nextDayNoClassBodyTemplate, 'Rest Body');
      expect(reloaded.classLeadTitleTemplate, 'Lead Title');
      expect(reloaded.classLeadBodyTemplate, 'Lead Body');
      expect(reloaded.checkInTitleTemplate, 'Check Title');
      expect(reloaded.checkInBodyTemplate, 'Check Body');
      expect(reloaded.checkInReminderEnabled, isFalse);
      expect(reloaded.customRules.map((r) => r.id), ['r1']);
      expect(reloaded.customRules.single.strength, ReminderStrength.strong);
      expect(reloaded.customRules.single.offsetSeconds, -1200);
      expect(reloaded.strong.enabled, isTrue);
      expect(reloaded.strong.onlyFirstClass, isTrue);
      expect(reloaded.strong.cutoffMinute, 540);

      // Clearing optional template strings persists as null.
      await service.save(
        settings.copyWith(
          clearNextDayWithClassTitleTemplate: true,
          checkInTitleTemplate: '   ',
        ),
      );
      final cleared = await SettingsService().load();
      expect(cleared.nextDayWithClassTitleTemplate, isNull);
      expect(cleared.checkInTitleTemplate, isNull);
    },
  );

  test(
    'load migrates transparently from legacy 17-key SharedPreferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'reminder_lead_minutes': 45,
        'reminder_enabled': false,
        'next_day_summary_enabled': false,
        'next_day_summary_hour': 20,
        'next_day_summary_minute': 15,
        'next_day_remind_when_no_class': false,
        'class_lead_title_tpl': 'Legacy Lead',
        'check_in_reminder_enabled': false,
        'custom_reminder_rules': jsonEncode([
          {
            'id': 'legacy-rule',
            'name': 'Legacy',
            'activeFrom': '2026-01-01T00:00:00.000',
            'offsetSeconds': -600,
          },
        ]),
        'strong_reminder_settings': jsonEncode({'enabled': true}),
      });

      final service = SettingsService();
      final loaded = await service.load();
      expect(loaded.leadMinutes, 45);
      expect(loaded.enabled, isFalse);
      expect(loaded.nextDaySummaryHour, 20);
      expect(loaded.classLeadTitleTemplate, 'Legacy Lead');
      expect(loaded.checkInReminderEnabled, isFalse);
      expect(loaded.customRules.map((r) => r.id), ['legacy-rule']);
      expect(loaded.strong.enabled, isTrue);

      await service.save(loaded.copyWith(leadMinutes: 15));
      final updated = await SettingsService().load();
      expect(updated.leadMinutes, 15);
      expect(updated.customRules.map((r) => r.id), ['legacy-rule']);
    },
  );

  test(
    'load recovers cleanly from malformed reminder_settings_v2 JSON',
    () async {
      SharedPreferences.setMockInitialValues({
        'reminder_settings_v2': 'not-json',
        'reminder_lead_minutes': 30,
      });
      final loaded = await SettingsService().load();
      expect(loaded.leadMinutes, 30);

      SharedPreferences.setMockInitialValues({
        'reminder_settings_v2': jsonEncode({
          'leadMinutes': 10,
          'customRules': [
            'invalid-entry',
            {
              'id': 'ok',
              'name': 'Valid',
              'activeFrom': '2026-01-01T00:00:00.000',
              'offsetSeconds': -300,
            },
          ],
          'strong': 'not-a-map',
        }),
      });
      final partial = await SettingsService().load();
      expect(partial.leadMinutes, 10);
      expect(partial.customRules.map((r) => r.id), ['ok']);
    },
  );
}
