import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/models/schedule_import.dart';
import 'package:orbit/models/sync_content.dart';
import 'package:orbit/services/account_sync_service.dart';
import 'package:orbit/services/orbit_api_client.dart';
import 'package:orbit/services/schedule_sync_coordinator.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/settings_sync_codec.dart';
import 'package:orbit/services/sync_scope_service.dart';

class _Api extends OrbitApiClient {
  _Api() : super(environment: 'test');
  SyncScopePolicy policy = const SyncScopePolicy();
  bool fail = false;
  @override
  Future<Map<String, dynamic>> syncPolicy({Map<String, dynamic>? body}) async {
    if (fail) throw const SocketException('offline');
    if (body != null) {
      final requested = SyncScopePolicy.fromJson(body);
      if (requested.revision != policy.revision) {
        throw StateError('policy conflict');
      }
      policy = SyncScopePolicy(
        mode: requested.mode,
        selection: requested.selection,
        revision: policy.revision + 1,
      );
    }
    return policy.toJson();
  }
}

class _Backend implements SyncBackend {
  List<SyncEntity> remote = [];
  final sent = <SyncMutation>[];
  @override
  bool get configured => true;
  @override
  Future<void> deleteAccountData() async {}
  @override
  Future<List<SyncEntity>> snapshot() async => remote;
  @override
  Future<SyncPushResult> push(List<SyncMutation> mutations, int cursor) async {
    sent.addAll(mutations);
    return SyncPushResult(
      accepted: {for (final m in mutations) m.mutationId: 1},
      cursor: 1,
    );
  }

  @override
  Future<SyncPullResult> pull(int cursor, {int limit = 200}) async =>
      SyncPullResult(entities: remote, cursor: 10);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'default categories keep strong reminders local and mode changes require an online save',
    () async {
      final api = _Api();
      final settings = SettingsService();
      final scope = SyncScopeService(settings, api)..accountUid = 'u';
      expect((await scope.selection()).enabled, SyncSelection.defaults.enabled);
      final original = SyncSelection.defaults.toggle(
        SyncCategory.appearance,
        true,
      );
      await scope.saveSelection(original);
      await scope.setMode(SyncScopeMode.shared);
      await scope.saveSelection(original.toggle(SyncCategory.strong, true));
      await scope.setMode(SyncScopeMode.perDevice);
      expect((await scope.selection()).enabled, original.enabled);
      api.fail = true;
      await expectLater(
        scope.setMode(SyncScopeMode.shared),
        throwsA(isA<SocketException>()),
      );
      expect((await scope.cachedPolicy()).mode, SyncScopeMode.perDevice);
    },
  );
  test(
    'normal rules cannot overwrite local strong flags, overrides, timings or audio paths',
    () async {
      final settings = SettingsService();
      final base = await settings.exportPortableSettings();
      final local = base.withReminders(
        base.reminders.copyWith(
          strong: const StrongReminderSettings(
            enabled: true,
            prepareSeconds: 17,
            answerSeconds: 40,
            sound: ReminderSound(kind: 'file', value: 'C:/secret.mp3'),
          ),
          customRules: [
            CustomReminderRule(
              id: 'r',
              name: 'local',
              activeFrom: DateTime(2026),
              strength: ReminderStrength.strong,
              strongOverride: const StrongReminderSettings(enabled: true),
            ),
          ],
        ),
      );
      final cloud = base.withReminders(
        base.reminders.copyWith(
          customRules: [
            CustomReminderRule(
              id: 'r',
              name: 'remote',
              activeFrom: DateTime(2026),
              strength: ReminderStrength.normal,
            ),
          ],
        ),
      );
      final groups = SettingsSyncCodec.groups(local);
      expect(jsonEncode(groups), isNot(contains('C:/secret.mp3')));
      final merged = SettingsSyncCodec.merge(
        local,
        SyncEntity(
          type: SyncEntityType.settingGroup,
          id: 'reminders',
          payload: SettingsSyncCodec.groups(cloud)['reminders']!,
        ),
      );
      expect(merged.reminders.customRules.single.name, 'remote');
      expect(
        merged.reminders.customRules.single.strength,
        ReminderStrength.strong,
      );
      expect(merged.reminders.strong.toJson(), local.reminders.strong.toJson());
      expect(merged.reminders.customRules.single.strongOverride, isNotNull);
      expect(jsonEncode(groups), isNot(contains('autoSyncSettings')));
    },
  );
  test(
    'disabled queued changes do not block others and cloud merge choice discards stale pending values',
    () async {
      final dir = await Directory.systemTemp.createTemp('orbit_scope_');
      final db = await AppDatabase.open(dir.path);
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      const account = SyncAccount(uid: 'u', email: 'u@test');
      await db.setActiveSyncAccount(account);
      final settings = SettingsService();
      final api = _Api();
      final scope = SyncScopeService(settings, api)..accountUid = 'u';
      final backend = _Backend();
      final coordinator = ScheduleSyncCoordinator(
        database: db,
        backend: backend,
        settings: settings,
        scope: scope,
        loadConfiguration: () async => const ImportConfiguration(),
        saveConfiguration: (_) async {},
        onCoursesChanged: () async {},
      );
      for (var i = 0; i < 110; i++) {
        await db.enqueueSyncEntity(
          SyncEntity(
            type: SyncEntityType.settingGroup,
            id: 'held$i',
            payload: {},
          ),
        );
      }
      await db.enqueueSyncEntity(
        const SyncEntity(
          type: SyncEntityType.importTemplate,
          id: 't',
          payload: {},
        ),
      );
      await coordinator.synchronize();
      expect(backend.sent.any((m) => m.entity.id == 't'), isTrue);
      expect(
        (await db.pendingSyncMutations(
          limit: 1000,
        )).any((m) => m.entity.id == 'held0'),
        isTrue,
      );
      backend.remote = [
        const SyncEntity(
          type: SyncEntityType.settingGroup,
          id: 'appearance',
          revision: 9,
          payload: {'locale': 'en'},
        ),
      ];
      final preview = await coordinator.previewCategories(
        const SyncSelection({SyncCategory.appearance}),
      );
      expect(preview.conflicts, hasLength(1));
      await coordinator.confirmInitialMerge(
        account: account,
        preview: preview,
        useLocalForConflict: {preview.conflicts.single.id: false},
        resetState: false,
        synchronizeAfter: false,
      );
      expect(
        (await db.pendingSyncMutations(
          limit: 1000,
        )).where((m) => m.entity.id == 'appearance'),
        isEmpty,
      );
      expect((await settings.exportPortableSettings()).locale, 'en');
    },
  );
}
