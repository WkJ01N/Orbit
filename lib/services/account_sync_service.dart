import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/services/account_errors.dart';
import 'package:orbit/services/orbit_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:orbit/services/account_errors.dart';

class VerificationChallenge {
  const VerificationChallenge(
    this.verify, {
    required this.resend,
    this.requiresCode = true,
  });

  final Future<SyncAccount> Function(String code) verify;
  final Future<void> Function() resend;
  final bool requiresCode;
}

class PasswordResetChallenge {
  const PasswordResetChallenge(this.complete, {required this.resend});

  final Future<void> Function(String code, String newPassword) complete;
  final Future<void> Function() resend;
}

class AccountAvatarUpload {
  const AccountAvatarUpload({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final List<int> bytes;
  final String extension;
  final String contentType;
}

bool isValidOrbitPassword(String password) =>
    password.length >= 8 &&
    password.length <= 20 &&
    RegExp('[A-Za-z]').hasMatch(password) &&
    RegExp('[0-9]').hasMatch(password);

bool isValidOrbitUsername(String username) {
  final value = username.trim();
  return value.isEmpty ||
      (value.runes.isNotEmpty &&
          value.runes.length <= 24 &&
          !RegExp(r'[\r\n\t]').hasMatch(value));
}

abstract interface class AccountService {
  bool get configured;
  Future<SyncAccount?> restoreSession();
  Future<SyncAccount> refreshAccount();
  Future<SyncAccount> signIn(String email, String password);
  Future<VerificationChallenge> signUp(
    String email,
    String password, {
    String? username,
  });
  Future<PasswordResetChallenge> beginPasswordReset(String email);
  Future<SyncAccount> updateProfile(
    SyncAccount account, {
    required String username,
    AccountAvatarUpload? avatar,
  });
  Future<String?> avatarDownloadUrl(String? fileId);
  Future<void> signOut();
  Future<void> deleteAccount(String password);
}

bool isAccountSessionInvalid(Object error) =>
    error is AccountSyncException && error.code == 'session_invalid';

bool isAccountNetworkError(Object error) {
  final value = error.toString().toLowerCase();
  return value.contains('network') ||
      value.contains('timeout') ||
      value.contains('socket') ||
      value.contains('unreachable') ||
      value.contains('connection') ||
      value.contains('网络') ||
      value.contains('網路') ||
      value.contains('連線');
}

bool _isInvalidSessionResponse(Object error) {
  final value = error.toString().toLowerCase();
  return value.contains('invalid_refresh_token') ||
      value.contains('refresh_token_expired') ||
      value.contains('refresh_token_exhausted') ||
      value.contains('refresh_token_disabled') ||
      value.contains('user_not_found');
}

abstract interface class SyncBackend {
  bool get configured;
  Future<SyncPushResult> push(List<SyncMutation> mutations, int cursor);
  Future<SyncPullResult> pull(int cursor, {int limit = 200});
  Future<List<SyncEntity>> snapshot();
  Future<void> deleteAccountData();
}

abstract interface class OptimizedSyncBackend {
  Future<SyncExchangeResult> exchange(
    List<SyncMutation> mutations,
    int cursor, {
    int limit = 200,
  });
}

class CloudBaseGateway {
  CloudBaseGateway({
    String? environment,
    String? region,
    FlutterSecureStorage? secureStorage,
  }) : environment =
           environment ?? const String.fromEnvironment('ORBIT_CLOUDBASE_ENV'),
       region =
           region ??
           const String.fromEnvironment(
             'ORBIT_CLOUDBASE_REGION',
             defaultValue: 'ap-shanghai',
           ),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final String environment;
  final String region;
  final FlutterSecureStorage _secureStorage;
  CloudBase? _app;
  Future<CloudBase>? _initializing;

  bool get configured => environment.trim().isNotEmpty;

  Future<CloudBase> app() {
    if (!configured) {
      throw const AccountSyncException('cloud_not_configured');
    }
    return _initializing ??= _initialize();
  }

  Future<CloudBase> _initialize() async {
    final value = await CloudBase.init(env: environment, region: region);
    _app = value;
    await _migrateSdkSession(value);
    return value;
  }

  Future<void> _migrateSdkSession(CloudBase app) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'credentials_$environment';
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final session = Session.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        await persistAndScrub(session);
      } catch (_) {
        await prefs.remove(key);
      }
    }
  }

  Future<Session?> restoreSecureSession() async {
    final app = await this.app();
    final refresh = await _secureStorage.read(
      key: 'orbit.cloudbase.$environment.refresh',
    );
    if (refresh == null || refresh.isEmpty) return null;
    final response = await app.auth.setSession(
      SetSessionReq(refreshToken: refresh),
    );
    if (response.error != null) {
      final detail = '${response.error!.code} ${response.error!.message}';
      if (isAccountNetworkError(detail)) {
        throw AccountSyncException(
          response.error!.code ?? 'network_error',
          response.error!.message,
        );
      }
      if (_isInvalidSessionResponse(detail)) {
        await clearSession();
        throw AccountSyncException('session_invalid', response.error!.message);
      }
      throw AccountSyncException(
        response.error!.code ?? 'session_restore_failed',
        response.error!.message,
      );
    }
    await persistAndScrub(response.data?.session);
    return response.data?.session;
  }

  Future<void> persistAndScrub(Session? session) async {
    final key = 'orbit.cloudbase.$environment.refresh';
    if (session?.refreshToken case final String refresh) {
      await _secureStorage.write(key: key, value: refresh);
    } else {
      await _secureStorage.delete(key: key);
    }
    await (await SharedPreferences.getInstance()).remove(
      'credentials_$environment',
    );
  }

  Future<void> scrubSdkSession() async {
    final app = _app;
    if (app != null) {
      final response = await app.auth.getSession();
      if (response.error == null) {
        await persistAndScrub(response.data?.session);
        return;
      }
    }
    await (await SharedPreferences.getInstance()).remove(
      'credentials_$environment',
    );
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: 'orbit.cloudbase.$environment.refresh');
    await (await SharedPreferences.getInstance()).remove(
      'credentials_$environment',
    );
  }
}

class CloudBaseAccountService implements AccountService {
  CloudBaseAccountService(this._gateway, this._api);

  final CloudBaseGateway _gateway;
  final OrbitApiClient _api;

  @override
  bool get configured => _gateway.configured && _api.configured;

  @override
  Future<SyncAccount?> restoreSession() async {
    if (!configured) return null;
    final orbit = await _api.sessions.readSession();
    if (orbit != null) return _api.restoreAccount();

    // One-time upgrade path for installations that only have the old
    // CloudBase refresh token. The CloudBase session is discarded as soon as
    // it has been exchanged for an Orbit device session.
    final legacy = await _gateway.restoreSecureSession();
    if (legacy == null) return null;
    return _bootstrapSession();
  }

  @override
  Future<SyncAccount> refreshAccount() async {
    return _api.getProfile();
  }

  @override
  Future<SyncAccount> signIn(String email, String password) async {
    if (!isValidOrbitPassword(password)) {
      throw const AccountSyncException('invalid_password_format');
    }
    final app = await _gateway.app();
    final response = await app.auth.signInWithPassword(
      SignInWithPasswordReq(email: email.trim(), password: password),
    );
    _throwAuth(response.error);
    await _gateway.persistAndScrub(response.data?.session);
    return _bootstrapSession();
  }

  @override
  Future<VerificationChallenge> signUp(
    String email,
    String password, {
    String? username,
  }) async {
    if (!isValidOrbitPassword(password)) {
      throw const AccountSyncException('invalid_password_format');
    }
    final normalizedUsername = username?.trim() ?? '';
    if (!isValidOrbitUsername(normalizedUsername)) {
      throw const AccountSyncException('invalid_username');
    }
    final app = await _gateway.app();
    final normalizedEmail = email.trim();
    final response = await app.auth.signUp(
      SignUpReq(
        email: normalizedEmail,
        password: password,
        nickname: normalizedUsername.isEmpty ? null : normalizedUsername,
      ),
    );
    _throwAuth(response.error);
    final verify = response.data?.verifyOtp;
    if (verify == null) {
      await _gateway.persistAndScrub(response.data?.session);
      return VerificationChallenge(
        (_) => _bootstrapSession(),
        resend: () async {},
        requiresCode: false,
      );
    }
    String? messageId;
    return VerificationChallenge(
      (code) async {
        final verified = await verify(
          VerifyOtpParams(token: code.trim(), messageId: messageId),
        );
        _throwAuth(verified.error);
        await _gateway.persistAndScrub(verified.data?.session);
        return _bootstrapSession();
      },
      resend: () async {
        final resent = await app.auth.resend(
          ResendReq(email: normalizedEmail, type: ResendType.signup),
        );
        _throwAuth(resent.error);
        messageId = resent.data?.messageId;
      },
    );
  }

  @override
  Future<PasswordResetChallenge> beginPasswordReset(String email) async {
    final app = await _gateway.app();
    final normalizedEmail = email.trim();
    Future<void> Function(String, String)? currentComplete;

    Future<void> requestCode() async {
      final response = await app.auth.resetPasswordForEmail(normalizedEmail);
      _throwAuth(response.error);
      final update = response.data?.updateUser;
      if (update == null) {
        throw const AccountSyncException('password_reset_unavailable');
      }
      currentComplete = (code, password) async {
        if (!isValidOrbitPassword(password)) {
          throw const AccountSyncException('invalid_password_format');
        }
        final result = await update(
          UpdateUserAttributes(nonce: code.trim(), password: password),
        );
        _throwAuth(result.error);
        await _gateway.persistAndScrub(result.data?.session);
        final revoked = await app.callFunction(
          name: 'orbit-api',
          data: const {'action': 'revokeAllSessions'},
        );
        if (revoked.code != null) {
          throw AccountSyncException(
            revoked.code!,
            revoked.message?.toString(),
          );
        }
        await _api.sessions.clearSession();
        await app.auth.signOut();
        await _gateway.clearSession();
      };
    }

    await requestCode();
    return PasswordResetChallenge(
      (code, password) => currentComplete!(code, password),
      resend: requestCode,
    );
  }

  @override
  Future<SyncAccount> updateProfile(
    SyncAccount account, {
    required String username,
    AccountAvatarUpload? avatar,
  }) async {
    final normalizedUsername = username.trim();
    if (!isValidOrbitUsername(normalizedUsername)) {
      throw const AccountSyncException('invalid_username');
    }
    if (avatar != null) {
      if (avatar.bytes.isEmpty || avatar.bytes.length > 2 * 1024 * 1024) {
        throw const AccountSyncException('avatar_too_large');
      }
      final extension = avatar.extension.toLowerCase();
      if (extension != 'png' || avatar.contentType != 'image/png') {
        throw const AccountSyncException('avatar_type_invalid');
      }
      return _api.uploadAvatar(
        Uint8List.fromList(avatar.bytes),
        username: normalizedUsername,
      );
    }
    return _api.updateProfile(normalizedUsername);
  }

  @override
  Future<String?> avatarDownloadUrl(String? fileId) async {
    return _api.avatarDownloadUrl(fileId);
  }

  @override
  Future<void> signOut() async {
    if (!configured) return;
    await _api.signOut();
  }

  @override
  Future<void> deleteAccount(String password) async {
    final session = await _api.sessions.readSession();
    if (session == null) {
      throw const AccountSyncException('session_invalid');
    }
    final app = await _gateway.app();
    final signedIn = await app.auth.signInWithPassword(
      SignInWithPasswordReq(email: session.account.email, password: password),
    );
    _throwAuth(signedIn.error);
    await _gateway.persistAndScrub(signedIn.data?.session);
    await _api.deleteAccountData();
    final response = await app.auth.deleteUser(
      DeleteUserReq(password: password),
    );
    _throwAuth(response.error);
    await _gateway.clearSession();
  }

  Future<SyncAccount> _bootstrapSession() async {
    final app = await _gateway.app();
    try {
      final response = await app.callFunction(
        name: 'orbit-api',
        data: {
          'action': 'bootstrapSession',
          'deviceId': await _api.sessions.deviceId(),
          'platform': Platform.operatingSystem,
          'appVersion': '1.5.1+21',
        },
      );
      if (response.code != null) {
        throw AccountSyncException(
          response.code!,
          response.message?.toString(),
        );
      }
      if (response.result is! Map) {
        throw const AccountSyncException('invalid_cloud_response');
      }
      var value = Map<String, dynamic>.from(response.result as Map);
      if (value['result'] is Map) {
        value = Map<String, dynamic>.from(value['result'] as Map);
      }
      final orbit = await _api.acceptBootstrap(value);
      await app.auth.signOut();
      await _gateway.clearSession();
      return orbit.account;
    } catch (error) {
      if (!isAccountNetworkError(error)) {
        await app.auth.signOut();
        await _gateway.clearSession();
      }
      rethrow;
    }
  }

  static void _throwAuth(AuthError? error) {
    if (error != null) {
      throw AccountSyncException(
        error.code ?? error.error ?? 'authentication_failed',
        error.message,
      );
    }
  }
}

class CloudBaseSyncBackend implements SyncBackend, OptimizedSyncBackend {
  CloudBaseSyncBackend(this._api);

  final OrbitApiClient _api;

  @override
  bool get configured => _api.configured;

  @override
  Future<SyncPushResult> push(List<SyncMutation> mutations, int cursor) async {
    final batch = _limitedBatch(mutations);
    final result = await _call('push', {
      'cursor': cursor,
      'mutations': batch.map((mutation) => mutation.toJson()).toList(),
    });
    return _pushResult(result, batch, cursor);
  }

  @override
  Future<SyncExchangeResult> exchange(
    List<SyncMutation> mutations,
    int cursor, {
    int limit = 200,
  }) async {
    final batch = _limitedBatch(mutations);
    final result = await _call('exchange', {
      'cursor': cursor,
      'pullLimit': limit,
      'mutations': batch.map((mutation) => mutation.toJson()).toList(),
    });
    final pull = Map<String, dynamic>.from(result['pull'] as Map? ?? const {});
    return SyncExchangeResult(
      push: _pushResult(result, batch, cursor),
      pull: _pullResult(pull, cursor),
    );
  }

  SyncPushResult _pushResult(
    Map<String, dynamic> result,
    List<SyncMutation> mutations,
    int cursor,
  ) {
    final accepted = <String, int>{};
    for (final item in result['accepted'] as List? ?? const []) {
      final row = Map<String, dynamic>.from(item as Map);
      accepted[row['mutationId'] as String] = row['revision'] as int;
    }
    final byMutation = {
      for (final mutation in mutations) mutation.mutationId: mutation,
    };
    final conflicts = <SyncConflict>[];
    for (final item in result['conflicts'] as List? ?? const []) {
      final row = Map<String, dynamic>.from(item as Map);
      final local = byMutation[row['mutationId']];
      if (local == null) continue;
      conflicts.add(
        SyncConflict(
          id: row['conflictId'] as String? ?? local.mutationId,
          local: local,
          remote: SyncEntity.fromJson(
            Map<String, dynamic>.from(row['remote'] as Map),
          ),
          createdAt: DateTime.now(),
        ),
      );
    }
    return SyncPushResult(
      accepted: accepted,
      conflicts: conflicts,
      cursor: result['cursor'] as int? ?? cursor,
    );
  }

  @override
  Future<SyncPullResult> pull(int cursor, {int limit = 200}) async {
    final result = await _call('pull', {'cursor': cursor, 'limit': limit});
    return _pullResult(result, cursor);
  }

  SyncPullResult _pullResult(Map<String, dynamic> result, int cursor) {
    return SyncPullResult(
      entities: [
        for (final value in result['entities'] as List? ?? const [])
          SyncEntity.fromJson(Map<String, dynamic>.from(value as Map)),
      ],
      cursor: result['cursor'] as int? ?? cursor,
      hasMore: result['hasMore'] as bool? ?? false,
    );
  }

  @override
  Future<List<SyncEntity>> snapshot() async {
    final entities = <SyncEntity>[];
    var offset = 0;
    while (true) {
      final result = await _call('snapshot', {'offset': offset, 'limit': 500});
      final page = [
        for (final value in result['entities'] as List? ?? const [])
          SyncEntity.fromJson(Map<String, dynamic>.from(value as Map)),
      ];
      entities.addAll(page);
      if (result['hasMore'] != true) break;
      final next = result['nextOffset'] as int?;
      offset = next ?? (offset + page.length);
      if (page.isEmpty && next == null) break;
    }
    return entities;
  }

  @override
  Future<void> deleteAccountData() => _api.deleteAccountData();

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    return _api.syncRequest(name, {...data, 'supportsDeadline': true});
  }

  List<SyncMutation> _limitedBatch(List<SyncMutation> mutations) {
    final batch = <SyncMutation>[];
    var encodedBytes = 0;
    for (final mutation in mutations.take(100)) {
      final size = utf8.encode(jsonEncode(mutation.toJson())).length;
      if (batch.isNotEmpty && encodedBytes + size > 4 * 1024 * 1024) break;
      if (size > 4 * 1024 * 1024) {
        throw const AccountSyncException('sync_item_too_large');
      }
      batch.add(mutation);
      encodedBytes += size;
    }
    return batch;
  }
}
