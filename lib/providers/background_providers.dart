import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/background_settings.dart';
import 'package:orbit/services/background_asset_service.dart';
import 'package:orbit/providers/reminder_providers.dart';

final backgroundAssetServiceProvider = Provider(
  (ref) => BackgroundAssetService(),
);
final backgroundSettingsProvider =
    AsyncNotifierProvider<BackgroundSettingsNotifier, BackgroundSettings>(
      BackgroundSettingsNotifier.new,
    );

class BackgroundSettingsNotifier extends AsyncNotifier<BackgroundSettings> {
  @override
  Future<BackgroundSettings> build() =>
      ref.watch(settingsServiceProvider).loadBackgroundSettings();
  Future<void> save(BackgroundSettings value) async {
    await ref.read(settingsServiceProvider).saveBackgroundSettings(value);
    state = AsyncData(value);
  }
}
