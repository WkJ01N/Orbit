import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/auto_sync_settings.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('automatic sync defaults enable each event on any network', () {
    const settings = AutoSyncSettings();

    expect(settings.networkPolicy, SyncNetworkPolicy.any);
    for (final trigger in SyncTrigger.values) {
      expect(settings.allows(trigger), isTrue);
    }
  });

  test('manual sync remains available when automatic sync is disabled', () {
    const settings = AutoSyncSettings(enabled: false);

    expect(settings.allows(SyncTrigger.manual), isTrue);
    expect(settings.allows(SyncTrigger.startup), isFalse);
    expect(settings.allows(SyncTrigger.localChange), isFalse);
  });

  test(
    'settings persist locally and travel in a full settings backup',
    () async {
      final service = SettingsService();
      const settings = AutoSyncSettings(
        onAppResume: false,
        networkPolicy: SyncNetworkPolicy.unmetered,
      );

      await service.saveAutoSyncSettings(settings);
      expect((await service.loadAutoSyncSettings()).onAppResume, isFalse);
      expect(
        (await service.exportPortableSettings())
            .autoSyncSettings
            ?.networkPolicy,
        SyncNetworkPolicy.unmetered,
      );
    },
  );
}
