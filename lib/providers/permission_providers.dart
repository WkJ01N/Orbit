import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/notification_permission_service.dart';

final notificationPermissionServiceProvider = Provider(
  (ref) => NotificationPermissionService(),
);
final notificationPermissionProvider = FutureProvider(
  (ref) => ref.watch(notificationPermissionServiceProvider).query(),
);
final permissionWarningIgnoredProvider =
    AsyncNotifierProvider<PermissionWarningIgnoredNotifier, bool>(
      PermissionWarningIgnoredNotifier.new,
    );

class PermissionWarningIgnoredNotifier extends AsyncNotifier<bool> {
  Future<void> _saves = Future.value();
  @override
  Future<bool> build() =>
      ref.read(settingsServiceProvider).loadPermissionWarningIgnored();
  Future<void> setIgnored(bool value) {
    final previous = state;
    state = AsyncData(value);
    final service = ref.read(settingsServiceProvider);
    return _saves = _saves.catchError((Object _) {}).then((_) async {
      try {
        await service.savePermissionWarningIgnored(value);
      } catch (_) {
        if (state.value == value) state = previous;
        rethrow;
      }
    });
  }
}
