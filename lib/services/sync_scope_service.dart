import 'package:orbit/services/account_errors.dart';
import 'package:orbit/models/sync_content.dart';
import 'package:orbit/services/orbit_api_client.dart';
import 'package:orbit/services/settings_service.dart';

class SyncScopeService {
  SyncScopeService(this.settings, this.api);
  final SettingsService settings;
  final OrbitApiClient api;
  String? accountUid;
  bool supportsSettings = true;
  String get key => 'sync_scope_${accountUid ?? "local"}';
  Future<SyncSelection> localSelection() async {
    final saved = await settings.loadLocalJson('${key}_device');
    return saved.isEmpty
        ? ((await cachedPolicy()).revision > 0
              ? (await cachedPolicy()).selection
              : SyncSelection.defaults)
        : SyncSelection.fromJson(saved);
  }

  Future<SyncScopePolicy> cachedPolicy() async =>
      SyncScopePolicy.fromJson(await settings.loadLocalJson(key));
  Future<SyncSelection> selection() async {
    final policy = await cachedPolicy();
    return policy.mode == SyncScopeMode.shared
        ? policy.selection
        : localSelection();
  }

  Future<SyncScopePolicy> refresh() async {
    final previous = await cachedPolicy();
    SyncScopePolicy remote;
    try {
      remote = SyncScopePolicy.fromJson(await api.syncPolicy());
      supportsSettings = true;
    } on AccountSyncException catch (e) {
      if (!['NOT_FOUND', 'not_found', 'http_404'].contains(e.code)) rethrow;
      supportsSettings = false;
      return previous;
    }
    if (previous.mode == SyncScopeMode.perDevice &&
        remote.mode == SyncScopeMode.shared &&
        (await settings.loadLocalJson(key)).isNotEmpty &&
        (await settings.loadLocalJson('${key}_device')).isEmpty) {
      await settings.saveLocalJson(
        '${key}_device',
        (await localSelection()).toJson(),
      );
    }
    if (previous.mode == SyncScopeMode.shared &&
        remote.mode == SyncScopeMode.perDevice &&
        (await settings.loadLocalJson('${key}_device')).isEmpty) {
      await settings.saveLocalJson(
        '${key}_device',
        previous.selection.toJson(),
      );
    }
    await settings.saveLocalJson(key, remote.toJson());
    return remote;
  }

  Future<SyncSelection> appliedSelection() async {
    final saved = await settings.loadLocalJson('${key}_applied');
    return saved.isEmpty
        ? SyncSelection.defaults
        : SyncSelection.fromJson(saved);
  }

  Future<Set<SyncCategory>> pendingCategories() async => (await selection())
      .enabled
      .difference((await appliedSelection()).enabled);
  Future<SyncSelection> safeSelection() async {
    final desired = await selection();
    final applied = await appliedSelection();
    return SyncSelection(
      desired.enabled
          .intersection(applied.enabled)
          .where((c) => supportsSettings || c.index < 5)
          .toSet(),
    );
  }

  Future<void> markApplied(SyncSelection value) =>
      settings.saveLocalJson('${key}_applied', value.toJson());
  Future<void> saveSelection(SyncSelection value) async {
    final policy = await cachedPolicy();
    if (!supportsSettings && value.enabled.any((c) => c.index >= 5)) {
      throw const AccountSyncException('sync_server_upgrade_required');
    }
    if (policy.mode == SyncScopeMode.shared) {
      final saved = SyncScopePolicy.fromJson(
        await api.syncPolicy(
          body: SyncScopePolicy(
            mode: policy.mode,
            selection: value,
            revision: policy.revision,
          ).toJson(),
        ),
      );
      await settings.saveLocalJson(key, saved.toJson());
    } else {
      await settings.saveLocalJson('${key}_device', value.toJson());
    }
  }

  Future<void> setMode(SyncScopeMode mode) async {
    final old = await cachedPolicy();
    final current = await selection();
    final saved = SyncScopePolicy.fromJson(
      await api.syncPolicy(
        body: SyncScopePolicy(
          mode: mode,
          selection: current,
          revision: old.revision,
        ).toJson(),
      ),
    );
    if (mode == SyncScopeMode.shared && old.mode != mode) {
      await settings.saveLocalJson('${key}_device', current.toJson());
    } else if (mode == SyncScopeMode.perDevice &&
        (await settings.loadLocalJson('${key}_device')).isEmpty) {
      await settings.saveLocalJson('${key}_device', current.toJson());
    }
    await settings.saveLocalJson(key, saved.toJson());
  }
}
