import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/providers/account_sync_providers.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/schedule_import_service.dart';

final scheduleImportServiceProvider = Provider(
  (ref) => ScheduleImportService(),
);
final importConfigurationProvider =
    AsyncNotifierProvider<ImportConfigurationNotifier, ImportConfiguration>(
      ImportConfigurationNotifier.new,
    );

class ImportConfigurationNotifier extends AsyncNotifier<ImportConfiguration> {
  Future<void> _tail = Future.value();
  bool _disposed = false;
  @override
  Future<ImportConfiguration> build() {
    _disposed = false;
    ref.watch(importConfigurationRefreshProvider);
    ref.onDispose(() => _disposed = true);
    return ref.read(settingsServiceProvider).loadImportConfiguration();
  }

  Future<void> saveChange(
    ImportConfiguration Function(ImportConfiguration) change,
  ) {
    final service = ref.read(settingsServiceProvider);
    final save = _tail.then((_) async {
      final current = await future;
      final next = change(current);
      await service.saveImportConfiguration(next);
      if (ref.read(accountServiceProvider).configured) {
        await ref
            .read(scheduleSyncCoordinatorProvider)
            .enqueueConfigurationChange(current, next);
        ref.read(accountSyncProvider.notifier).scheduleSync();
      }
      if (!_disposed) state = AsyncData(next);
    });
    _tail = save.catchError((Object _) {});
    return save;
  }
}
