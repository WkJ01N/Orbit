import 'dart:async';

import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/services/account_sync_service.dart';

class ScheduleSyncCoordinator {
  ScheduleSyncCoordinator({
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
       );

  ScheduleSyncCoordinator._(
    this._database,
    this._backend,
    this._loadConfiguration,
    this._saveConfiguration,
    this._onCoursesChanged,
  );

  final AppDatabase _database;
  final SyncBackend _backend;
  final Future<ImportConfiguration> Function() _loadConfiguration;
  final Future<void> Function(ImportConfiguration) _saveConfiguration;
  final Future<void> Function() _onCoursesChanged;
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
    final local = await _localEntities(includeLinkedChanges: sameAccount);
    final remote = await _backend.snapshot();
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
  }) async {
    if (preview.conflicts.any(
      (conflict) => !useLocalForConflict.containsKey(conflict.id),
    )) {
      throw const AccountSyncException('unresolved_conflicts');
    }
    await _database.setActiveSyncAccount(account, resetState: true);
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
        coursesChanged |= await _applyRemote(conflict.remote);
      }
    }
    if (coursesChanged) await _onCoursesChanged();
    await synchronize();
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
      var cursor = await _database.syncCursor(account.uid);
      var coursesChanged = false;
      var receivedPull = false;
      var hasMore = true;

      Future<void> applyPull(SyncPullResult pulled) async {
        final conflicts = {
          for (final conflict in await _database.syncConflicts())
            _key(conflict.remote),
        };
        for (final entity in pulled.entities) {
          if (conflicts.contains(_key(entity))) continue;
          coursesChanged |= await _applyRemote(entity);
        }
        cursor = pulled.cursor;
        hasMore = pulled.hasMore;
        receivedPull = true;
      }

      while (true) {
        final pending = await _database.pendingSyncMutations();
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
  }) async {
    final values = <String, SyncEntity>{};
    for (final entity in [
      ...await _database.localCourseSyncEntities(
        includeDeleted: includeLinkedChanges,
      ),
      ...await _database.localDeadlineSyncEntities(
        includeDeleted: includeLinkedChanges,
      ),
      ..._configurationEntities(await _loadConfiguration()),
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
    if (entity.type == SyncEntityType.courseSession ||
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
      case SyncEntityType.courseSession:
      case SyncEntityType.deadline:
        throw StateError('Handled above');
    }
    await _saveConfiguration(next);
    await _database.applyRemoteEntities([entity]);
    return false;
  }

  static String _key(SyncEntity entity) => '${entity.type.name}|${entity.id}';
}
