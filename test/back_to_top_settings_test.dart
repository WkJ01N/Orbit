import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/portable_settings.dart';
import 'package:orbit/models/schedule_display_settings.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/settings_sync_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('old and unrecognized settings default to smart', () async {
    final service = SettingsService();
    expect(
      (await service.loadScheduleDisplaySettings()).backToTopPosition,
      BackToTopPosition.smart,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('upcoming_back_to_top_position', 'future-value');
    expect(
      (await service.loadScheduleDisplaySettings()).backToTopPosition,
      BackToTopPosition.smart,
    );
    final json = (await service.exportPortableSettings()).toJson();
    (json['scheduleDisplay'] as Map).remove('backToTopPosition');
    expect(
      PortableSettings.fromJson(json).scheduleDisplay.backToTopPosition,
      BackToTopPosition.smart,
    );
  });

  for (final position in BackToTopPosition.values) {
    test('${position.name} survives disk, backup and display sync', () async {
      final service = SettingsService();
      await service.saveScheduleDisplaySettings(
        ScheduleDisplaySettings(backToTopPosition: position),
      );
      expect(
        (await SettingsService().loadScheduleDisplaySettings())
            .backToTopPosition,
        position,
      );
      final portable = await service.exportPortableSettings();
      final restored = PortableSettings.fromJson(portable.toJson());
      await service.saveScheduleDisplaySettings(
        const ScheduleDisplaySettings(),
      );
      await service.importPortableSettings(restored);
      expect(
        (await service.loadScheduleDisplaySettings()).backToTopPosition,
        position,
      );
      final payload = SettingsSyncCodec.groups(portable)['display']!;
      final merged = SettingsSyncCodec.merge(
        await service.exportPortableSettings(),
        SyncEntity(
          type: SyncEntityType.settingGroup,
          id: 'display',
          payload: payload,
        ),
      );
      expect(merged.scheduleDisplay.backToTopPosition, position);
    });
  }
}
