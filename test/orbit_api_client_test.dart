import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/services/account_errors.dart';
import 'package:orbit/services/orbit_api_client.dart';

void main() {
  test(
    'session store survives recreation and keeps a stable device id',
    () async {
      final secure = _MemorySecureStore();
      final first = OrbitSessionStore(environment: 'test', storage: secure);
      final deviceId = await first.deviceId();
      await first.saveSession(_session());

      final restarted = OrbitSessionStore(environment: 'test', storage: secure);
      expect(await restarted.deviceId(), deviceId);
      expect((await restarted.readSession())?.account.uid, 'user-1');
    },
  );

  test('concurrent requests share one refresh operation', () async {
    var refreshCount = 0;
    var profileCount = 0;
    final server = await _server((request) async {
      if (request.uri.path == '/orbit/v1/session/refresh') {
        refreshCount++;
        await _json(request.response, {
          'session': _sessionJson(accessToken: 'new-access'),
        });
        return;
      }
      if (request.uri.path == '/orbit/v1/profile') {
        profileCount++;
        expect(request.headers.value('authorization'), 'Bearer new-access');
        await _json(request.response, {'account': _accountJson()});
        return;
      }
      request.response.statusCode = 404;
      await request.response.close();
    });
    addTearDown(server.close);

    final store = OrbitSessionStore(
      environment: 'test',
      storage: _MemorySecureStore(),
    );
    await store.saveSession(
      _session(
        accessExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
    final client = OrbitApiClient(
      environment: 'test',
      baseUrl: 'http://${server.address.host}:${server.port}/orbit',
      sessionStore: store,
    );

    await Future.wait([client.getProfile(), client.getProfile()]);
    expect(refreshCount, 1);
    expect(profileCount, 2);
    expect((await store.readSession())?.accessToken, 'new-access');
  });

  test('a 401 refreshes once and retries the request', () async {
    var refreshCount = 0;
    var profileCount = 0;
    final server = await _server((request) async {
      if (request.uri.path == '/orbit/v1/profile') {
        profileCount++;
        if (profileCount == 1) {
          request.response.statusCode = 401;
          await _json(request.response, {
            'code': 'ACCESS_EXPIRED',
            'message': 'expired',
          });
        } else {
          await _json(request.response, {'account': _accountJson()});
        }
        return;
      }
      if (request.uri.path == '/orbit/v1/session/refresh') {
        refreshCount++;
        await _json(request.response, {
          'session': _sessionJson(accessToken: 'retried-access'),
        });
        return;
      }
    });
    addTearDown(server.close);
    final store = OrbitSessionStore(
      environment: 'test',
      storage: _MemorySecureStore(),
    );
    await store.saveSession(_session());
    final client = OrbitApiClient(
      environment: 'test',
      baseUrl: 'http://${server.address.host}:${server.port}/orbit',
      sessionStore: store,
    );

    expect((await client.getProfile()).uid, 'user-1');
    expect(refreshCount, 1);
    expect(profileCount, 2);
  });

  test('network failure preserves the active session', () async {
    final port = await _unusedPort();
    final store = OrbitSessionStore(
      environment: 'test',
      storage: _MemorySecureStore(),
    );
    await store.saveSession(_session());
    final client = OrbitApiClient(
      environment: 'test',
      baseUrl: 'http://127.0.0.1:$port/orbit',
      sessionStore: store,
    );

    await expectLater(
      client.getProfile(),
      throwsA(
        isA<AccountSyncException>().having(
          (error) => error.code,
          'code',
          'network_error',
        ),
      ),
    );
    expect(await store.readSession(), isNotNull);
  });

  test('invalid refresh clears the local session', () async {
    final server = await _server((request) async {
      request.response.statusCode = 401;
      await _json(request.response, {
        'code': 'SESSION_INVALID',
        'message': 'revoked',
      });
    });
    addTearDown(server.close);
    final store = OrbitSessionStore(
      environment: 'test',
      storage: _MemorySecureStore(),
    );
    await store.saveSession(
      _session(
        accessExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
    final client = OrbitApiClient(
      environment: 'test',
      baseUrl: 'http://${server.address.host}:${server.port}/orbit',
      sessionStore: store,
    );

    await expectLater(
      client.getProfile(),
      throwsA(
        isA<AccountSyncException>().having(
          (error) => error.code,
          'code',
          'session_invalid',
        ),
      ),
    );
    expect(await store.readSession(), isNull);
  });

  test(
    'offline sign out is queued and clears only local login state',
    () async {
      final port = await _unusedPort();
      final store = OrbitSessionStore(
        environment: 'test',
        storage: _MemorySecureStore(),
      );
      await store.saveSession(_session());
      final client = OrbitApiClient(
        environment: 'test',
        baseUrl: 'http://127.0.0.1:$port/orbit',
        sessionStore: store,
      );

      await client.signOut();
      expect(await store.readSession(), isNull);
      expect(await store.pendingRevocations(), ['refresh-token']);
    },
  );

  test(
    'transient refresh failures (5xx, 429, HTML) preserve the local session',
    () async {
      for (final scenario in [
        (status: 500, body: jsonEncode({'code': 'INTERNAL', 'message': 'err'})),
        (
          status: 502,
          body: jsonEncode({'code': 'BAD_GATEWAY', 'message': 'down'}),
        ),
        (
          status: 429,
          body: jsonEncode({'code': 'RATE_LIMITED', 'message': 'slow down'}),
        ),
        (status: 200, body: '<html>captive portal</html>'),
      ]) {
        final server = await _server((request) async {
          request.response.statusCode = scenario.status;
          request.response.write(scenario.body);
          await request.response.close();
        });
        addTearDown(server.close);
        final store = OrbitSessionStore(
          environment: 'test',
          storage: _MemorySecureStore(),
        );
        await store.saveSession(
          _session(
            accessExpiresAt: DateTime.now().subtract(
              const Duration(minutes: 1),
            ),
          ),
        );
        final client = OrbitApiClient(
          environment: 'test',
          baseUrl: 'http://${server.address.host}:${server.port}/orbit',
          sessionStore: store,
        );

        await expectLater(
          client.getProfile(),
          throwsA(
            isA<AccountSyncException>().having(
              (error) => error.code,
              'code',
              isNot('session_invalid'),
            ),
          ),
        );
        final kept = await store.readSession();
        expect(kept, isNotNull);
        expect(kept!.refreshToken, 'refresh-token');
      }
    },
  );

  test(
    'concurrent profile update does not overwrite rotated tokens from refresh',
    () async {
      final server = await _server((request) async {
        if (request.uri.path == '/orbit/v1/session/refresh') {
          await _json(request.response, {
            'session': _sessionJson(accessToken: 'rotated-access'),
          });
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      });
      addTearDown(server.close);
      final store = OrbitSessionStore(
        environment: 'test',
        storage: _MemorySecureStore(),
      );
      await store.saveSession(
        _session(
          accessExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      final client = OrbitApiClient(
        environment: 'test',
        baseUrl: 'http://${server.address.host}:${server.port}/orbit',
        sessionStore: store,
      );

      // Simulate a refresh running while an older profile response updates display name.
      await Future.wait([
        client.syncPolicy().catchError((_) => <String, dynamic>{}),
        store.updateAccount(
          const SyncAccount(
            uid: 'user-1',
            email: 'orbit@example.com',
            username: 'Updated',
          ),
        ),
      ]);

      final finalSession = await store.readSession();
      expect(finalSession, isNotNull);
      expect(finalSession!.accessToken, 'rotated-access');
      expect(finalSession.refreshToken, 'rotated-refresh-token');
      expect(finalSession.account.username, 'Updated');
    },
  );

  test(
    'concurrent 401 reuses already-rotated access token without clearing session',
    () async {
      var profileCalls = 0;
      var refreshCalls = 0;
      final store = OrbitSessionStore(
        environment: 'test',
        storage: _MemorySecureStore(),
      );
      await store.saveSession(_session());
      final server = await _server((request) async {
        if (request.uri.path == '/orbit/v1/profile') {
          profileCalls++;
          if (profileCalls == 1) {
            // Simulate another caller finishing refresh while this request was in flight.
            await store.saveSession(
              OrbitSession(
                accessToken: 'already-rotated-access',
                accessExpiresAt: DateTime.now().add(const Duration(hours: 1)),
                refreshToken: 'already-rotated-refresh',
                refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
                account: _session().account,
              ),
            );
            request.response.statusCode = 401;
            await _json(request.response, {
              'code': 'SESSION_INVALID',
              'message': 'superseded',
            });
            return;
          }
          expect(
            request.headers.value('authorization'),
            'Bearer already-rotated-access',
          );
          await _json(request.response, {'account': _accountJson()});
          return;
        }
        if (request.uri.path == '/orbit/v1/session/refresh') {
          refreshCalls++;
          request.response.statusCode = 500;
          await request.response.close();
        }
      });
      addTearDown(server.close);
      final client = OrbitApiClient(
        environment: 'test',
        baseUrl: 'http://${server.address.host}:${server.port}/orbit',
        sessionStore: store,
      );

      final account = await client.getProfile();
      expect(account.uid, 'user-1');
      expect(refreshCalls, 0);
      expect(
        (await store.readSession())?.accessToken,
        'already-rotated-access',
      );
    },
  );

  test(
    'local clock past refreshExpiresAt delegates to server instead of clearing locally',
    () async {
      var refreshCalls = 0;
      final server = await _server((request) async {
        if (request.uri.path == '/orbit/v1/session/refresh') {
          refreshCalls++;
          await _json(request.response, {
            'session': _sessionJson(accessToken: 'server-validated-access'),
          });
          return;
        }
        if (request.uri.path == '/orbit/v1/profile') {
          await _json(request.response, {'account': _accountJson()});
          return;
        }
      });
      addTearDown(server.close);
      final store = OrbitSessionStore(
        environment: 'test',
        storage: _MemorySecureStore(),
      );
      await store.saveSession(
        OrbitSession(
          accessToken: 'old-access',
          accessExpiresAt: DateTime.now().subtract(const Duration(days: 2)),
          refreshToken: 'valid-server-refresh',
          refreshExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
          account: _session().account,
        ),
      );
      final client = OrbitApiClient(
        environment: 'test',
        baseUrl: 'http://${server.address.host}:${server.port}/orbit',
        sessionStore: store,
      );

      final account = await client.getProfile();
      expect(account.uid, 'user-1');
      expect(refreshCalls, 1);
      expect(
        (await store.readSession())?.accessToken,
        'server-validated-access',
      );
    },
  );
}

OrbitSession _session({DateTime? accessExpiresAt}) => OrbitSession(
  accessToken: 'access-token',
  accessExpiresAt:
      accessExpiresAt ?? DateTime.now().add(const Duration(minutes: 30)),
  refreshToken: 'refresh-token',
  refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
  account: const SyncAccount(
    uid: 'user-1',
    email: 'orbit@example.com',
    username: 'Orbit',
  ),
);

Map<String, dynamic> _sessionJson({required String accessToken}) => {
  'accessToken': accessToken,
  'accessExpiresAt': DateTime.now()
      .add(const Duration(hours: 1))
      .millisecondsSinceEpoch,
  'refreshToken': 'rotated-refresh-token',
  'refreshExpiresAt': DateTime.now()
      .add(const Duration(days: 30))
      .millisecondsSinceEpoch,
};

Map<String, dynamic> _accountJson() => {
  'uid': 'user-1',
  'email': 'orbit@example.com',
  'username': 'Orbit',
  'avatarFileId': null,
};

Future<HttpServer> _server(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

Future<int> _unusedPort() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close(force: true);
  return port;
}

Future<void> _json(HttpResponse response, Map<String, dynamic> value) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(value));
  await response.close();
}

class _MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
