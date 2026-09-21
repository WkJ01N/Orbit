import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/services/account_errors.dart';
import 'package:uuid/uuid.dart';

const _sessionKeyPrefix = 'orbit.api.session.';
const _deviceKeyPrefix = 'orbit.api.device.';
const _pendingRevokeKeyPrefix = 'orbit.api.pending-revokes.';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class OrbitSession {
  const OrbitSession({
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.account,
  });

  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final SyncAccount account;

  OrbitSession copyWith({SyncAccount? account}) => OrbitSession(
    accessToken: accessToken,
    accessExpiresAt: accessExpiresAt,
    refreshToken: refreshToken,
    refreshExpiresAt: refreshExpiresAt,
    account: account ?? this.account,
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'accessExpiresAt': accessExpiresAt.millisecondsSinceEpoch,
    'refreshToken': refreshToken,
    'refreshExpiresAt': refreshExpiresAt.millisecondsSinceEpoch,
    'account': _accountToJson(account),
  };

  factory OrbitSession.fromJson(Map<String, dynamic> json) => OrbitSession(
    accessToken: json['accessToken'] as String,
    accessExpiresAt: DateTime.fromMillisecondsSinceEpoch(
      (json['accessExpiresAt'] as num).toInt(),
    ),
    refreshToken: json['refreshToken'] as String,
    refreshExpiresAt: DateTime.fromMillisecondsSinceEpoch(
      (json['refreshExpiresAt'] as num).toInt(),
    ),
    account: _accountFromJson(
      Map<String, dynamic>.from(json['account'] as Map),
    ),
  );
}

class OrbitSessionStore {
  OrbitSessionStore({required String environment, SecureKeyValueStore? storage})
    : _storage = storage ?? FlutterSecureKeyValueStore(),
      _sessionKey = '$_sessionKeyPrefix$environment',
      _deviceKey = '$_deviceKeyPrefix$environment',
      _pendingKey = '$_pendingRevokeKeyPrefix$environment';

  final SecureKeyValueStore _storage;
  final String _sessionKey;
  final String _deviceKey;
  final String _pendingKey;

  Future<OrbitSession?> readSession() async {
    final raw = await _storage.read(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return OrbitSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> saveSession(OrbitSession session) =>
      _storage.write(_sessionKey, jsonEncode(session.toJson()));

  Future<void> clearSession() => _storage.delete(_sessionKey);

  Future<String> deviceId() async {
    final existing = await _storage.read(_deviceKey);
    if (existing != null && existing.length >= 16) return existing;
    final value = const Uuid().v4();
    await _storage.write(_deviceKey, value);
    return value;
  }

  Future<List<String>> pendingRevocations() async {
    final raw = await _storage.read(_pendingKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      await _storage.delete(_pendingKey);
      return const [];
    }
  }

  Future<void> addPendingRevocation(String refreshToken) async {
    final values = [...await pendingRevocations()];
    if (!values.contains(refreshToken)) values.add(refreshToken);
    await _storage.write(_pendingKey, jsonEncode(values));
  }

  Future<void> savePendingRevocations(List<String> values) async {
    if (values.isEmpty) {
      await _storage.delete(_pendingKey);
    } else {
      await _storage.write(_pendingKey, jsonEncode(values));
    }
  }
}

class OrbitApiClient {
  OrbitApiClient({
    required String environment,
    String? baseUrl,
    OrbitSessionStore? sessionStore,
    HttpClient? httpClient,
  }) : baseUrl = _normalizeBaseUrl(baseUrl ?? _configuredBaseUrl),
       sessions = sessionStore ?? OrbitSessionStore(environment: environment),
       _http = httpClient ?? HttpClient() {
    _http.autoUncompress = false;
    _http.connectionTimeout = const Duration(seconds: 20);
  }

  final String baseUrl;
  final OrbitSessionStore sessions;
  final HttpClient _http;
  Future<OrbitSession>? _refreshing;

  bool get configured => baseUrl.isNotEmpty;

  Future<SyncAccount?> restoreAccount() async {
    final session = await sessions.readSession();
    if (session == null) return null;
    await flushPendingRevocations();
    return getProfile();
  }

  Future<OrbitSession> acceptBootstrap(Map<String, dynamic> value) async {
    final account = _accountFromJson(
      Map<String, dynamic>.from(value['account'] as Map),
    );
    final session = _sessionFromJson(
      Map<String, dynamic>.from(value['session'] as Map),
      account,
    );
    await sessions.saveSession(session);
    await flushPendingRevocations();
    return session;
  }

  Future<SyncAccount> getProfile() async {
    final result = await _authorizedJson('GET', '/v1/profile');
    final account = _accountFromJson(
      Map<String, dynamic>.from(result['account'] as Map),
    );
    await _saveAccount(account);
    return account;
  }

  Future<SyncAccount> updateProfile(String username) async {
    final result = await _authorizedJson(
      'PATCH',
      '/v1/profile',
      body: {'username': username},
    );
    final account = _accountFromJson(
      Map<String, dynamic>.from(result['account'] as Map),
    );
    await _saveAccount(account);
    return account;
  }

  Future<SyncAccount> uploadAvatar(
    Uint8List bytes, {
    required String username,
  }) async {
    final query = Uri(queryParameters: {'username': username}).query;
    final response = await _authorizedRaw(
      'PUT',
      '/v1/profile/avatar?$query',
      body: bytes,
      headers: {'Content-Type': 'image/png'},
    );
    final result = _decodeJson(response);
    final account = _accountFromJson(
      Map<String, dynamic>.from(result['account'] as Map),
    );
    await _saveAccount(account);
    return account;
  }

  Future<String?> avatarDownloadUrl(String? fileId) async {
    if (fileId == null || fileId.isEmpty) return null;
    final query = Uri(queryParameters: {'fileId': fileId}).query;
    final result = await _authorizedJson(
      'GET',
      '/v1/profile/avatar-url?$query',
    );
    return result['url'] as String?;
  }

  Future<Map<String, dynamic>> syncRequest(
    String operation,
    Map<String, dynamic> body,
  ) => _authorizedJson(
    'POST',
    '/v1/sync/$operation',
    body: body,
    gzipBody: true,
  );

  Future<void> deleteAccountData() async {
    await _authorizedJson('DELETE', '/v1/account');
    await sessions.clearSession();
  }

  Future<void> signOut() async {
    final session = await sessions.readSession();
    if (session == null) return;
    try {
      await _json(
        'DELETE',
        '/v1/session',
        body: {'refreshToken': session.refreshToken},
      );
    } on AccountSyncException catch (error) {
      if (error.code == 'network_error') {
        await sessions.addPendingRevocation(session.refreshToken);
      }
    } finally {
      await sessions.clearSession();
    }
  }

  Future<void> flushPendingRevocations() async {
    final pending = await sessions.pendingRevocations();
    if (pending.isEmpty) return;
    final remaining = <String>[];
    for (final token in pending) {
      try {
        await _json('DELETE', '/v1/session', body: {'refreshToken': token});
      } on AccountSyncException catch (error) {
        if (error.code == 'network_error') remaining.add(token);
      }
    }
    await sessions.savePendingRevocations(remaining);
  }

  Future<Map<String, dynamic>> _authorizedJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool gzipBody = false,
  }) async => _decodeJson(
    await _authorizedRaw(
      method,
      path,
      body: body == null
          ? null
          : Uint8List.fromList(
              gzipBody
                  ? gzip.encode(utf8.encode(jsonEncode(body)))
                  : utf8.encode(jsonEncode(body)),
            ),
      headers: body == null
          ? const {}
          : {
              'Content-Type': gzipBody
                  ? 'application/octet-stream'
                  : 'application/json; charset=utf-8',
              if (gzipBody) 'Content-Encoding': 'gzip',
            },
    ),
  );

  Future<_ApiResponse> _authorizedRaw(
    String method,
    String path, {
    Uint8List? body,
    Map<String, String> headers = const {},
  }) async {
    var session = await _validSession();
    try {
      return await _raw(
        method,
        path,
        body: body,
        headers: {...headers, 'Authorization': 'Bearer ${session.accessToken}'},
      );
    } on AccountSyncException catch (error) {
      if (error.code != 'session_invalid' &&
          error.code != 'access_expired' &&
          error.code != 'unauthenticated') {
        rethrow;
      }
      session = await _refresh();
      try {
        return await _raw(
          method,
          path,
          body: body,
          headers: {
            ...headers,
            'Authorization': 'Bearer ${session.accessToken}',
          },
        );
      } on AccountSyncException catch (retryError) {
        if (retryError.code == 'session_invalid' ||
            retryError.code == 'access_expired' ||
            retryError.code == 'unauthenticated') {
          await sessions.clearSession();
          throw AccountSyncException('session_invalid', retryError.detail);
        }
        rethrow;
      }
    }
  }

  Future<OrbitSession> _validSession() async {
    final session = await sessions.readSession();
    if (session == null) {
      throw const AccountSyncException('session_invalid');
    }
    if (session.refreshExpiresAt.isBefore(DateTime.now())) {
      await sessions.clearSession();
      throw const AccountSyncException('session_invalid');
    }
    if (session.accessExpiresAt.isBefore(
      DateTime.now().add(const Duration(minutes: 5)),
    )) {
      return _refresh();
    }
    return session;
  }

  Future<OrbitSession> _refresh() {
    final active = _refreshing;
    if (active != null) return active;
    late final Future<OrbitSession> run;
    run = _performRefresh().whenComplete(() {
      if (identical(_refreshing, run)) _refreshing = null;
    });
    _refreshing = run;
    return run;
  }

  Future<OrbitSession> _performRefresh() async {
    final current = await sessions.readSession();
    if (current == null) {
      throw const AccountSyncException('session_invalid');
    }
    try {
      final value = await _json(
        'POST',
        '/v1/session/refresh',
        body: {'refreshToken': current.refreshToken},
      );
      final refreshed = _sessionFromJson(
        Map<String, dynamic>.from(value['session'] as Map),
        current.account,
      );
      await sessions.saveSession(refreshed);
      return refreshed;
    } on AccountSyncException catch (error) {
      if (error.code != 'network_error') {
        await sessions.clearSession();
        throw AccountSyncException('session_invalid', error.detail);
      }
      rethrow;
    }
  }

  Future<void> _saveAccount(SyncAccount account) async {
    final current = await sessions.readSession();
    if (current != null) {
      await sessions.saveSession(current.copyWith(account: account));
    }
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async => _decodeJson(
    await _raw(
      method,
      path,
      body: body == null
          ? null
          : Uint8List.fromList(utf8.encode(jsonEncode(body))),
      headers: body == null
          ? const {}
          : const {'Content-Type': 'application/json; charset=utf-8'},
    ),
  );

  Future<_ApiResponse> _raw(
    String method,
    String path, {
    Uint8List? body,
    Map<String, String> headers = const {},
  }) async {
    try {
      final request = await _http.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.set('Accept', 'application/json');
      headers.forEach(request.headers.set);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      var bytes = Uint8List.fromList(
        await response.fold<List<int>>(
          <int>[],
          (all, part) => all..addAll(part),
        ),
      );
      if (response.headers.value('content-encoding')?.toLowerCase() == 'gzip') {
        bytes = Uint8List.fromList(gzip.decode(bytes));
      }
      final result = _ApiResponse(response.statusCode, bytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final value = _tryDecodeJson(result.bytes);
        final serverCode = value?['code']?.toString().toLowerCase();
        throw AccountSyncException(
          _normalizeErrorCode(serverCode, response.statusCode),
          value?['message']?.toString(),
        );
      }
      return result;
    } on AccountSyncException {
      rethrow;
    } on SocketException catch (error) {
      throw AccountSyncException('network_error', '$error');
    } on HttpException catch (error) {
      throw AccountSyncException('network_error', '$error');
    } on TimeoutException catch (error) {
      throw AccountSyncException('network_error', '$error');
    }
  }

  Map<String, dynamic> _decodeJson(_ApiResponse response) {
    final value = _tryDecodeJson(response.bytes);
    if (value == null) {
      throw const AccountSyncException('invalid_cloud_response');
    }
    return value;
  }

  static Map<String, dynamic>? _tryDecodeJson(Uint8List bytes) {
    try {
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
    } catch (_) {
      return null;
    }
  }

  static String _normalizeErrorCode(String? code, int status) {
    if (code == 'session_invalid') return 'session_invalid';
    if (code == 'access_expired') return 'access_expired';
    if (code == 'unauthenticated') return 'unauthenticated';
    if (status == 401) return 'session_invalid';
    return code ?? 'http_$status';
  }

  static String _normalizeBaseUrl(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');
}

const _configuredBaseUrl = String.fromEnvironment('ORBIT_API_BASE_URL');

class _ApiResponse {
  const _ApiResponse(this.statusCode, this.bytes);

  final int statusCode;
  final Uint8List bytes;
}

OrbitSession _sessionFromJson(Map<String, dynamic> json, SyncAccount account) =>
    OrbitSession(
      accessToken: json['accessToken'] as String,
      accessExpiresAt: DateTime.fromMillisecondsSinceEpoch(
        (json['accessExpiresAt'] as num).toInt(),
      ),
      refreshToken: json['refreshToken'] as String,
      refreshExpiresAt: DateTime.fromMillisecondsSinceEpoch(
        (json['refreshExpiresAt'] as num).toInt(),
      ),
      account: account,
    );

Map<String, dynamic> _accountToJson(SyncAccount account) => {
  'uid': account.uid,
  'email': account.email,
  'username': account.username,
  'avatarFileId': account.avatarFileId,
};

SyncAccount _accountFromJson(Map<String, dynamic> json) => SyncAccount(
  uid: json['uid'] as String,
  email: json['email'] as String? ?? '',
  username: (json['username'] as String?)?.trim().isEmpty == true
      ? null
      : json['username'] as String?,
  avatarFileId: (json['avatarFileId'] as String?)?.trim().isEmpty == true
      ? null
      : json['avatarFileId'] as String?,
);
