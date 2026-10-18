import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/settings_sync_codec.dart';
import 'package:orbit/models/sync_content.dart';
import 'package:orbit/services/sync_scope_service.dart';
import 'dart:async';

import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/services/account_sync_service.dart';

class ScheduleSyncCoordinator {
  ScheduleSyncCoordinator({
    SettingsService? settings,
    SyncScopeService? scope,
    required AppDatabase database,
    required SyncBackend backend,
    required Future<ImportConfiguration> Function() loadConfiguration,
    required Future<void> Function(ImportConfiguration) saveConfiguration,
    required Future<void> Function() onCoursesChanged,
  }) : this._(
         database,
         backend,
         loadConfiguration,
         saveConfiguration,
         onCoursesChanged,
         settings,
         scope,
       );

  ScheduleSyncCoordinator._(
    this._database,
    this._backend,
    this._loadConfiguration,
    this._saveConfiguration,
    this._onCoursesChanged,
    this._settings,
    this._scope,
  );

  final AppDatabase _database;
  final SyncBackend _backend;
  final Future<ImportConfiguration> Function() _loadConfiguration;
  final Future<void> Function(ImportConfiguration) _saveConfiguration;
  final Future<void> Function() _onCoursesChanged;
  final SettingsService? _settings;
  final SyncScopeService? _scope;
  SyncSelection _selection = SyncSelection.defaults;
  bool _allows(SyncEntity e) => _scope == null || _selection.allows(e);
  Future<SyncStatus>? _running;

  Future<SyncStatus> status() async {
    final account = await _database.activeSyncAccount();
    if (account == null) {
      return const SyncStatus(phase: SyncPhase.disabled);
    }
    return SyncStatus(
      phase: SyncPhase.idle,
      account: account,
      pendingCount: await _database.pendingSyncMutationCount(),
      conflictCount: await _database.syncConflictCount(),
      lastSyncedAt: await _database.lastSyncAt(account.uid),
    );
  }

  Future<InitialSyncPreview> previewInitialMerge(SyncAccount account) async {
    if (!_backend.configured) {
      throw const AccountSyncException('cloud_not_configured');
    }
    final sameAccount = await _database.boundSyncAccountUid() == account.uid;
    if (sameAccount) await captureSettingsChanges(account.uid);
    if (_scope != null) {
      _scope.accountUid = account.uid;
      await _scope.refresh();
      _selection = await _scope.selection();
    }
    final local = (await _localEntities(
      includeLinkedChanges: sameAccount,
      statisticsOwner: account.uid,
    )).where(_allows).toList();
    final remote = (await _backend.snapshot()).where(_allows).toList();
    final localByKey = {for (final item in local) _key(item): item};
    final remoteByKey = {for (final item in remote) _key(item): item};
    final localOnly = <SyncEntity>[];
    final remoteOnly = <SyncEntity>[];
    final identical = <SyncEntity>[];
    final conflicts = <SyncConflict>[];
    for (final entry in localByKey.entries) {
      final cloud = remoteByKey[entry.key];
      if (cloud == null) {
        localOnly.add(entry.value);
      } else if (entry.value.deleted == cloud.deleted &&
          (cloud.deleted ||
              canonicalSyncPayload(entry.value.payload) ==
                  canonicalSyncPayload(cloud.payload))) {
        identical.add(cloud);
      } else {
        final mutation = SyncMutation(
          mutationId: 'initial:${entry.key}',
          entity: entry.value,
          operation: entry.value.deleted
              ? SyncOperation.delete
              : SyncOperation.upsert,
          baseRevision: cloud.revision,
        );
        conflicts.add(
          SyncConflict(
            id: mutation.mutationId,
            local: mutation,
            remote: cloud,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
    for (final entry in remoteByKey.entries) {
      if (!entry.value.deleted && !localByKey.containsKey(entry.key)) {
        remoteOnly.add(entry.value);
      }
    }
    return InitialSyncPreview(
      localOnly: localOnly,
      remoteOnly: remoteOnly,
      identical: identical,
      conflicts: conflicts,
    );
  }

  Future<void> confirmInitialMerge({
    required SyncAccount account,
    required InitialSyncPreview preview,
    required Map<String, bool> useLocalForConflict,
    bool mergeGuestStatistics = false,
    bool resetState = true,
    bool synchronizeAfter = true,
  }) async {
    if (preview.conflicts.any(
      (conflict) => !useLocalForConflict.containsKey(conflict.id),
    )) {
      throw const AccountSyncException('unresolved_conflicts');
    }
    if (resetState) {
      await _database.setActiveSyncAccount(account, resetState: true);
      if (mergeGuestStatistics) {
        await _database.mergeGuestStatistics(account.uid);
      }
    }
    var coursesChanged = false;
    for (final entity in preview.localOnly) {
      await _database.enqueueSyncEntity(
        entity,
        operation: entity.deleted ? SyncOperation.delete : SyncOperation.upsert,
      );
    }
    for (final entity in preview.remoteOnly) {
      coursesChanged |= await _applyRemote(entity);
    }
    for (final entity in preview.identical) {
      coursesChanged |= await _applyRemote(entity);
    }
    for (final conflict in preview.conflicts) {
      if (useLocalForConflict[conflict.id] == true) {
        await _database.storeSyncConflicts([conflict]);
        await _database.resolveSyncConflict(conflict, useLocal: true);
      } else {
        await _database.discardPendingSyncEntity(conflict.remote);
        coursesChanged |= await _applyRemote(conflict.remote);
      }
    }
    if (resetState && _scope != null) {
      await _scope.markApplied(await _scope.selection());
    }
    if (coursesChanged) await _onCoursesChanged();
    if (synchronizeAfter) await synchronize();
  }

  Future<SyncStatus> synchronize() {
    final existing = _running;
    if (existing != null) return existing;
    final future = _synchronize();
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<SyncStatus> _synchronize() async {
    final account = await _database.activeSyncAccount();
    if (account == null) {
      return const SyncStatus(phase: SyncPhase.disabled);
    }
    if (!_backend.configured) {
      return (await status()).copyWith(
        phase: SyncPhase.error,
        message: 'cloud_not_configured',
      );
    }
    try {
      if (_scope != null) {
        _scope.accountUid = account.uid;
        await _scope.refresh();
        _selection = await _scope.safeSelection();
      }
      await captureSettingsChanges(account.uid);
      var cursor = await _database.syncCursor(account.uid);
      final capabilityKey = 'sync_exams_v1_${account.uid}';
      final firstExamSync =
          _settings != null &&
          (await _settings.loadLocalJson(capabilityKey)).isEmpty;
      if (firstExamSync) cursor = 0;
      var coursesChanged = false;
      var receivedPull = false;
      var hasMore = true;

      Future<void> applyPull(SyncPullResult pulled) async {
        final conflicts = {
          for (final conflict in await _database.syncConflicts())
            _key(conflict.remote),
        };
        for (final entity in pulled.entities) {
          if (!_allows(entity) || conflicts.contains(_key(entity))) continue;
          coursesChanged |= await _applyRemote(entity);
        }
        cursor = pulled.cursor;
        hasMore = pulled.hasMore;
        receivedPull = true;
      }

      while (true) {
        final pending = await _database.pendingSyncMutations(
          limit: 100,
          entityTypes: _scope == null
              ? null
              : [
                  for (final t in SyncEntityType.values)
                    if (t != SyncEntityType.settingGroup &&
                        _selection.allows(
                          SyncEntity(type: t, id: '', payload: {}),
                        ))
                      t.name,
                ],
          settingGroups: _scope == null
              ? null
              : _selection.enabled
                    .where((c) => c.index >= 5)
                    .map((c) => c.name)
                    .toList(),
        );
        if (pending.isEmpty) break;
        final SyncPushResult pushed;
        final backend = _backend;
        if (backend is OptimizedSyncBackend) {
          final exchanged = await (backend as OptimizedSyncBackend).exchange(
            pending,
            cursor,
          );
          pushed = exchanged.push;
          await _database.acknowledgeSyncMutations(
            pushed.accepted,
            sent: pending,
          );
          await _database.storeSyncConflicts(pushed.conflicts);
          await applyPull(exchanged.pull);
        } else {
          pushed = await backend.push(pending, cursor);
          await _database.acknowledgeSyncMutations(
            pushed.accepted,
            sent: pending,
          );
          await _database.storeSyncConflicts(pushed.conflicts);
        }
        if (pushed.accepted.isEmpty && pushed.conflicts.isEmpty) {
          throw const AccountSyncException('invalid_cloud_response');
        }
      }
      if (!receivedPull) hasMore = true;
      while (hasMore) {
        final pulled = await _backend.pull(cursor);
        await applyPull(pulled);
      }
      await _database.setSyncCursor(account.uid, cursor);
      if (firstExamSync) {
        await _settings.saveLocalJson(capabilityKey, {'applied': true});
      }
      final now = DateTime.now();
      await _database.setLastSyncAt(account.uid, now);
      if (coursesChanged) await _onCoursesChanged();
      return SyncStatus(
        phase: SyncPhase.idle,
        account: account,
        pendingCount: await _database.pendingSyncMutationCount(),
        conflictCount: await _database.syncConflictCount(),
        lastSyncedAt: now,
      );
    } on AccountSyncException catch (error) {
      return (await status()).copyWith(
        phase: SyncPhase.error,
        message: error.code,
      );
    } catch (error) {
      return (await status()).copyWith(
        phase: SyncPhase.offline,
        message: '$error',
      );
    }
  }

  Future<void> enqueueConfigurationChange(
    ImportConfiguration before,
    ImportConfiguration after,
  ) async {
    final old = {
      for (final entity in _configurationEntities(before)) _key(entity): entity,
    };
    final next = {
      for (final entity in _configurationEntities(after)) _key(entity): entity,
    };
    for (final entry in next.entries) {
      if (canonicalSyncPayload(old[entry.key]?.payload ?? const {}) !=
          canonicalSyncPayload(entry.value.payload)) {
        await _database.enqueueSyncEntity(entry.value);
      }
    }
    for (final entry in old.entries) {
      if (!next.containsKey(entry.key)) {
        await _database.enqueueSyncEntity(
          SyncEntity(
            type: entry.value.type,
            id: entry.value.id,
            payload: entry.value.payload,
            deleted: true,
          ),
          operation: SyncOperation.delete,
        );
      }
    }
  }

  Future<void> resolveConflict(SyncConflict conflict, bool useLocal) async {
    await _database.resolveSyncConflict(conflict, useLocal: useLocal);
    if (!useLocal) {
      final coursesChanged = await _applyRemote(conflict.remote);
      if (coursesChanged) await _onCoursesChanged();
    }
  }

  Future<List<SyncEntity>> _localEntities({
    bool includeLinkedChanges = false,
    String? statisticsOwner,
  }) async {
    final values = <String, SyncEntity>{};
    for (final entity in [
      ...await _database.localCourseSyncEntities(
        includeDeleted: includeLinkedChanges,
      ),
      ...await _database.localDeadlineSyncEntities(
        includeDeleted: includeLinkedChanges,
      ),
      ...await _database.localStatisticsSyncEntities(owner: statisticsOwner),
      ..._configurationEntities(await _loadConfiguration()),
      if (_settings != null) ...[
        for (final e in SettingsSyncCodec.groups(
          await _settings.exportPortableSettings(),
        ).entries)
          SyncEntity(
            type: SyncEntityType.settingGroup,
            id: e.key,
            payload: e.value,
          ),
      ],
    ]) {
      values[_key(entity)] = entity;
    }
    if (includeLinkedChanges) {
      for (final mutation in await _database.pendingSyncMutations(
        limit: 100000,
      )) {
        values[_key(mutation.entity)] = SyncEntity(
          type: mutation.entity.type,
          id: mutation.entity.id,
          payload: mutation.entity.payload,
          schemaVersion: mutation.entity.schemaVersion,
          revision: mutation.entity.revision,
          deleted: mutation.operation == SyncOperation.delete,
        );
      }
    }
    return values.values.toList();
  }

  List<SyncEntity> _configurationEntities(ImportConfiguration configuration) =>
      [
        for (final template in configuration.templates)
          SyncEntity(
            type: SyncEntityType.importTemplate,
            id: template.id,
            payload: template.toJson(),
          ),
        for (final plan in configuration.semesters)
          SyncEntity(
            type: SyncEntityType.semesterPlan,
            id: plan.id,
            payload: plan.toJson(),
          ),
        for (final plan in configuration.periodTimes)
          SyncEntity(
            type: SyncEntityType.periodTimePlan,
            id: plan.id,
            payload: plan.toJson(),
          ),
      ];

  Future<bool> _applyRemote(SyncEntity entity) async {
    if (entity.type == SyncEntityType.settingGroup) {
      if (_settings != null && !entity.deleted) {
        var incoming = entity;
        if (entity.id == 'strong') {
          final audio = await SettingsSyncCodec.restoreAudio(entity.payload);
          if (audio.fallback) {
            await _settings.saveLocalJson('sync_sound_reselect', {
              'required': true,
            });
          }
          incoming = SyncEntity(
            type: entity.type,
            id: entity.id,
            revision: entity.revision,
            payload: audio.payload,
          );
        }
        final value = SettingsSyncCodec.merge(
          await _settings.exportPortableSettings(),
          incoming,
        );
        await _settings.importPortableSettings(value);
        final uid = (await _database.activeSyncAccount())?.uid;
        if (uid != null) {
          final hashes = await _settings.loadLocalJson('sync_settings_$uid');
          hashes[entity.id] = canonicalSyncPayload(
            SettingsSyncCodec.groups(value)[entity.id] ?? {},
          );
          await _settings.saveLocalJson('sync_settings_$uid', hashes);
        }
      }
      await _database.applyRemoteEntities([entity]);
      return true;
    }
    if (entity.type == SyncEntityType.statistic ||
        entity.type == SyncEntityType.courseSession ||
        entity.type == SyncEntityType.deadline) {
      await _database.applyRemoteEntities([entity]);
      return true;
    }
    final current = await _loadConfiguration();
    ImportConfiguration next;
    switch (entity.type) {
      case SyncEntityType.importTemplate:
        final values = [...current.templates]
          ..removeWhere((value) => value.id == entity.id);
        if (!entity.deleted) {
          values.add(ScheduleImportTemplate.fromJson(entity.payload));
        }
        next = current.copy(templates: values);
      case SyncEntityType.semesterPlan:
        final values = [...current.semesters]
          ..removeWhere((value) => value.id == entity.id);
        if (!entity.deleted) values.add(SemesterPlan.fromJson(entity.payload));
        next = current.copy(semesters: values);
      case SyncEntityType.periodTimePlan:
        final values = [...current.periodTimes]
          ..removeWhere((value) => value.id == entity.id);
        if (!entity.deleted) {
          values.add(PeriodTimePlan.fromJson(entity.payload));
        }
        next = current.copy(periodTimes: values);
      case SyncEntityType.statistic:
      case SyncEntityType.courseSession:
      case SyncEntityType.deadline:
      case SyncEntityType.settingGroup:
        throw StateError('Handled above');
    }
    await _saveConfiguration(next);
    await _database.applyRemoteEntities([entity]);
    return false;
  }

  Future<void> captureSettingsChanges(String uid) async {
    if (_settings == null) return;
    final saved = await _settings.loadLocalJson('sync_settings_$uid');
    for (final e in SettingsSyncCodec.groups(
      await _settings.exportPortableSettings(),
    ).entries) {
      final hash = canonicalSyncPayload(e.value);
      if (saved[e.key] != hash) {
        await _database.enqueueSyncEntity(
          SyncEntity(
            type: SyncEntityType.settingGroup,
            id: e.key,
            payload: e.value,
          ),
        );
        saved[e.key] = hash;
      }
    }
    await _settings.saveLocalJson('sync_settings_$uid', saved);
  }

  Future<InitialSyncPreview> previewCategories(SyncSelection target) async {
    final account = await _database.activeSyncAccount();
    if (account == null) throw const AccountSyncException('invalid_account');
    await captureSettingsChanges(account.uid);
    final backend = _backend;
    if (backend is CloudBaseSyncBackend) backend.previewAll = true;
    final previous = _selection;
    _selection = target;
    try {
      // Avoid refreshing policy while previewing a not-yet-enabled range.
      final local = await _localEntities(includeLinkedChanges: true);
      final remote = await _backend.snapshot();
      final byKey = {for (final e in local.where(target.allows)) _key(e): e};
      final clouds = {for (final e in remote.where(target.allows)) _key(e): e};
      final conflicts = <SyncConflict>[];
      final identical = <SyncEntity>[];
      final localOnly = <SyncEntity>[];
      for (final e in byKey.values) {
        final r = clouds[_key(e)];
        if (r == null) {
          localOnly.add(e);
        } else if (r.deleted == e.deleted &&
            canonicalSyncPayload(r.payload) ==
                canonicalSyncPayload(e.payload)) {
          identical.add(r);
        } else {
          conflicts.add(
            SyncConflict(
              id: 'range:${_key(e)}',
              local: SyncMutation(
                mutationId: 'range:${_key(e)}',
                entity: e,
                operation: e.deleted
                    ? SyncOperation.delete
                    : SyncOperation.upsert,
                baseRevision: r.revision,
              ),
              remote: r,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
      return InitialSyncPreview(
        localOnly: localOnly,
        remoteOnly: clouds.values
            .where((r) => !byKey.containsKey(_key(r)))
            .toList(),
        identical: identical,
        conflicts: conflicts,
      );
    } finally {
      _selection = previous;
      if (backend is CloudBaseSyncBackend) backend.previewAll = false;
    }
  }

  static String _key(SyncEntity entity) => '${entity.type.name}|${entity.id}';
}
