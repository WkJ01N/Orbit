import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/services/account_sync_service.dart';
import 'package:orbit/services/orbit_api_client.dart';

class _Api extends OrbitApiClient {
  _Api(this.supportsExams)
    : super(environment: 'test', baseUrl: 'https://example.invalid');
  final bool supportsExams;
  int pushes = 0, probes = 0;
  @override
  Future<Map<String, dynamic>> syncPolicy({Map<String, dynamic>? body}) async {
    probes++;
    return {'supportsExams': supportsExams};
  }

  @override
  Future<Map<String, dynamic>> syncRequest(
    String operation,
    Map<String, dynamic> body,
  ) async {
    pushes++;
    return {'cursor': 0, 'accepted': [], 'conflicts': []};
  }
}

void main() {
  SyncMutation mutation(String id, String kind) => SyncMutation(
    mutationId: id,
    entity: SyncEntity(
      type: SyncEntityType.courseSession,
      id: id,
      payload: {'kind': kind},
    ),
    operation: SyncOperation.upsert,
    baseRevision: 0,
  );
  test(
    'old server receives no exam write before it advertises support',
    () async {
      final api = _Api(false);
      await expectLater(
        CloudBaseSyncBackend(api).push([mutation('exam|one', 'exam')], 0),
        throwsA(
          isA<AccountSyncException>().having(
            (e) => e.code,
            'code',
            'sync_server_upgrade_required',
          ),
        ),
      );
      expect(api.probes, 1);
      expect(api.pushes, 0);
    },
  );
  test(
    'new server is probed once, ordinary course syncing needs no probe',
    () async {
      final api = _Api(true);
      final checked = CloudBaseSyncBackend(api);
      await checked.push([mutation('course', 'course')], 0);
      expect(api.probes, 0);
      await checked.push([mutation('exam|one', 'exam')], 0);
      await checked.push([mutation('exam|two', 'exam')], 0);
      expect(api.probes, 1);
      expect(api.pushes, 3);
    },
  );
}
