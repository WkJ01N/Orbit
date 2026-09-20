import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/auto_sync_settings.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/providers/schedule_providers.dart';
import 'package:orbit/services/account_sync_service.dart';
import 'package:orbit/services/account_avatar_cache.dart';
import 'package:orbit/services/schedule_sync_coordinator.dart';

final cloudBaseGatewayProvider = Provider((ref) => CloudBaseGateway());

final accountServiceProvider = Provider<AccountService>(
  (ref) => CloudBaseAccountService(ref.watch(cloudBaseGatewayProvider)),
);

final accountAvatarCacheProvider = Provider<AccountAvatarCache>(
  (ref) => AccountAvatarCache(),
);

final syncBackendProvider = Provider<SyncBackend>(
  (ref) => CloudBaseSyncBackend(ref.watch(cloudBaseGatewayProvider)),
);

final importConfigurationRefreshProvider = StateProvider<int>((ref) => 0);

final autoSyncSettingsProvider =
    AsyncNotifierProvider<AutoSyncSettingsNotifier, AutoSyncSettings>(
      AutoSyncSettingsNotifier.new,
    );

class AutoSyncSettingsNotifier extends AsyncNotifier<AutoSyncSettings> {
  @override
  Future<AutoSyncSettings> build() =>
      ref.read(settingsServiceProvider).loadAutoSyncSettings();

  Future<void> save(AutoSyncSettings value) async {
    final previous = state;
    state = AsyncData(value);
    try {
      await ref.read(settingsServiceProvider).saveAutoSyncSettings(value);
    } catch (error, stack) {
      state = previous;
      Error.throwWithStackTrace(error, stack);
    }
  }
}

final scheduleSyncCoordinatorProvider = Provider<ScheduleSyncCoordinator>((
  ref,
) {
  final settings = ref.watch(settingsServiceProvider);
  return ScheduleSyncCoordinator(
    database: ref.watch(appDatabaseProvider),
    backend: ref.watch(syncBackendProvider),
    loadConfiguration: settings.loadImportConfiguration,
    saveConfiguration: settings.saveImportConfiguration,
    onCoursesChanged: () async {
      ref.read(scheduleRefreshProvider.notifier).state++;
      await ref.read(reminderSettingsProvider.notifier).resyncReminders();
    },
  );
});

final accountSyncProvider =
    AsyncNotifierProvider<AccountSyncNotifier, SyncStatus>(
      AccountSyncNotifier.new,
    );

class AccountSyncNotifier extends AsyncNotifier<SyncStatus> {
  Timer? _debounce;
  StreamSubscription<void>? _changes;
  Future<void>? _syncRun;
  bool _syncQueued = false;
  bool _suppressLocalTrigger = false;
  Future<void>? _profileRefresh;

  @override
  Future<SyncStatus> build() async {
    ref.onDispose(() {
      _debounce?.cancel();
      unawaited(_changes?.cancel());
    });
    final auth = ref.read(accountServiceProvider);
    if (!auth.configured) {
      return const SyncStatus(
        phase: SyncPhase.disabled,
        message: 'cloud_not_configured',
      );
    }
    _changes = ref.read(appDatabaseProvider).syncChanges.listen((_) {
      if (!_suppressLocalTrigger) scheduleSync();
    });
    try {
      final stored = await ref.read(appDatabaseProvider).activeSyncAccount();
      final account = await auth.restoreSession();
      if (account == null) {
        if (stored != null) {
          await ref.read(appDatabaseProvider).setActiveSyncAccount(null);
        }
        return const SyncStatus();
      }
      if (stored?.uid != account.uid) {
        return SyncStatus(phase: SyncPhase.needsInitialMerge, account: account);
      }
      final settings = await ref
          .read(settingsServiceProvider)
          .loadAutoSyncSettings();
      if (!settings.allows(SyncTrigger.startup)) {
        return ref.read(scheduleSyncCoordinatorProvider).status();
      }
      _suppressLocalTrigger = true;
      try {
        return await ref.read(scheduleSyncCoordinatorProvider).synchronize();
      } finally {
        _suppressLocalTrigger = false;
      }
    } catch (error) {
      final stored = await ref.read(appDatabaseProvider).activeSyncAccount();
      if (isAccountSessionInvalid(error)) {
        await ref.read(appDatabaseProvider).setActiveSyncAccount(null);
        return const SyncStatus();
      }
      if (stored != null && isAccountNetworkError(error)) {
        return SyncStatus(
          phase: SyncPhase.offline,
          account: stored,
          message: '$error',
        );
      }
      return SyncStatus(phase: SyncPhase.error, message: '$error');
    }
  }

  bool get configured => ref.read(accountServiceProvider).configured;

  Future<InitialSyncPreview> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      final account = await ref
          .read(accountServiceProvider)
          .signIn(email, password);
      final preview = await ref
          .read(scheduleSyncCoordinatorProvider)
          .previewInitialMerge(account);
      state = AsyncData(
        SyncStatus(phase: SyncPhase.needsInitialMerge, account: account),
      );
      return preview;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<VerificationChallenge> signUp(
    String email,
    String password, {
    String? username,
  }) => ref
      .read(accountServiceProvider)
      .signUp(email, password, username: username);

  Future<InitialSyncPreview> finishVerification(
    VerificationChallenge challenge,
    String code,
  ) async {
    state = const AsyncLoading();
    try {
      final account = await challenge.verify(code);
      final preview = await ref
          .read(scheduleSyncCoordinatorProvider)
          .previewInitialMerge(account);
      state = AsyncData(
        SyncStatus(phase: SyncPhase.needsInitialMerge, account: account),
      );
      return preview;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<PasswordResetChallenge> beginPasswordReset(String email) =>
      ref.read(accountServiceProvider).beginPasswordReset(email);

  Future<void> confirmInitialMerge(
    InitialSyncPreview preview,
    Map<String, bool> conflictChoices,
  ) async {
    final account = state.value?.account;
    if (account == null) {
      throw const AccountSyncException('invalid_account');
    }
    state = AsyncData(state.value!.copyWith(phase: SyncPhase.syncing));
    _suppressLocalTrigger = true;
    try {
      await ref
          .read(scheduleSyncCoordinatorProvider)
          .confirmInitialMerge(
            account: account,
            preview: preview,
            useLocalForConflict: conflictChoices,
          );
      ref.read(importConfigurationRefreshProvider.notifier).state++;
      state = AsyncData(
        await ref.read(scheduleSyncCoordinatorProvider).status(),
      );
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    } finally {
      _suppressLocalTrigger = false;
    }
  }

  Future<InitialSyncPreview> previewInitialMerge() async {
    final account = state.value?.account;
    if (account == null) {
      throw const AccountSyncException('invalid_account');
    }
    return ref
        .read(scheduleSyncCoordinatorProvider)
        .previewInitialMerge(account);
  }

  Future<void> syncNow() async {
    return triggerSync(SyncTrigger.manual);
  }

  Future<void> triggerSync(SyncTrigger trigger) async {
    final settings = await ref
        .read(settingsServiceProvider)
        .loadAutoSyncSettings();
    if (!settings.allows(trigger)) return;
    if (trigger == SyncTrigger.localChange) {
      scheduleSync();
      return;
    }
    return _enqueueSync();
  }

  Future<void> _enqueueSync() {
    final running = _syncRun;
    if (running != null) {
      _syncQueued = true;
      return running;
    }
    final run = _drainSyncQueue();
    _syncRun = run;
    return run.whenComplete(() {
      if (identical(_syncRun, run)) _syncRun = null;
    });
  }

  Future<void> _drainSyncQueue() async {
    do {
      _syncQueued = false;
      await _performSync();
    } while (_syncQueued);
  }

  Future<void> _performSync() async {
    final current = state.value;
    if (current == null ||
        !current.signedIn ||
        current.phase == SyncPhase.needsInitialMerge) {
      return;
    }
    state = AsyncData(current.copyWith(phase: SyncPhase.syncing));
    _suppressLocalTrigger = true;
    try {
      state = AsyncData(
        await ref.read(scheduleSyncCoordinatorProvider).synchronize(),
      );
      ref.read(importConfigurationRefreshProvider.notifier).state++;
    } catch (error) {
      final message = '$error';
      final offline =
          message.contains('network') ||
          message.contains('unreachable') ||
          message.contains('SocketException');
      state = AsyncData(
        current.copyWith(
          phase: offline ? SyncPhase.offline : SyncPhase.error,
          message: message,
        ),
      );
    } finally {
      _suppressLocalTrigger = false;
    }
  }

  Future<void> updateProfile({
    required String username,
    AccountAvatarUpload? avatar,
  }) async {
    final current = state.value;
    final account = current?.account;
    if (current == null || account == null) {
      throw const AccountSyncException('invalid_account');
    }
    final updated = await ref
        .read(accountServiceProvider)
        .updateProfile(account, username: username, avatar: avatar);
    await ref.read(appDatabaseProvider).setActiveSyncAccount(updated);
    if (avatar != null) {
      final fileId = updated.avatarFileId;
      if (fileId != null) {
        try {
          await ref
              .read(accountAvatarCacheProvider)
              .store(
                uid: updated.uid,
                fileId: fileId,
                bytes: Uint8List.fromList(avatar.bytes),
              );
        } catch (_) {
          // The cloud profile update succeeded; caching is best-effort.
        }
      }
    }
    state = AsyncData(current.copyWith(account: updated));
  }

  Future<void> refreshProfile() {
    final active = _profileRefresh;
    if (active != null) return active;
    late final Future<void> run;
    run = _refreshProfile().whenComplete(() {
      if (identical(_profileRefresh, run)) _profileRefresh = null;
    });
    _profileRefresh = run;
    return run;
  }

  Future<void> _refreshProfile() async {
    final current = state.value;
    final account = current?.account;
    if (current == null || account == null) return;
    try {
      final updated = await ref.read(accountServiceProvider).refreshAccount();
      if (updated.uid != account.uid) {
        throw const AccountSyncException('session_invalid');
      }
      await ref.read(appDatabaseProvider).setActiveSyncAccount(updated);
      state = AsyncData(current.copyWith(account: updated));
    } catch (error) {
      if (!isAccountSessionInvalid(error)) return;
      await ref.read(appDatabaseProvider).setActiveSyncAccount(null);
      state = const AsyncData(SyncStatus());
    }
  }

  void scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(seconds: 2),
      () => unawaited(_scheduleLocalSync()),
    );
  }

  Future<void> _scheduleLocalSync() async {
    final settings = await ref
        .read(settingsServiceProvider)
        .loadAutoSyncSettings();
    if (settings.allows(SyncTrigger.localChange)) await _enqueueSync();
  }

  Future<void> signOut() async {
    _debounce?.cancel();
    _syncQueued = false;
    await ref.read(accountServiceProvider).signOut();
    await ref.read(appDatabaseProvider).setActiveSyncAccount(null);
    state = const AsyncData(SyncStatus());
  }

  Future<void> deleteAccount(String password) async {
    final account = state.value?.account;
    if (account == null) {
      throw const AccountSyncException('invalid_account');
    }
    await ref.read(accountServiceProvider).signIn(account.email, password);
    await ref.read(syncBackendProvider).deleteAccountData();
    await ref.read(accountServiceProvider).deleteAccount(password);
    await ref
        .read(appDatabaseProvider)
        .setActiveSyncAccount(null, clearBinding: true);
    try {
      await ref.read(accountAvatarCacheProvider).clearUser(account.uid);
    } catch (_) {
      // Account deletion must not be reported as failed because of local cache.
    }
    state = const AsyncData(SyncStatus());
  }

  Future<List<SyncConflict>> conflicts() =>
      ref.read(appDatabaseProvider).syncConflicts();

  Future<void> resolveConflict(SyncConflict conflict, bool useLocal) async {
    _suppressLocalTrigger = true;
    try {
      await ref
          .read(scheduleSyncCoordinatorProvider)
          .resolveConflict(conflict, useLocal);
    } finally {
      _suppressLocalTrigger = false;
    }
    ref.read(importConfigurationRefreshProvider.notifier).state++;
    await syncNow();
  }
}
