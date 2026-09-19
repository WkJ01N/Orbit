import 'dart:async';
import 'dart:convert';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountSyncException implements Exception {
  const AccountSyncException(this.code, [this.detail]);

  final String code;
  final String? detail;

  @override
  String toString() => detail == null ? code : '$code: $detail';
}

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
      await clearSession();
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
  CloudBaseAccountService(this._gateway);

  final CloudBaseGateway _gateway;

  @override
  bool get configured => _gateway.configured;

  @override
  Future<SyncAccount?> restoreSession() async {
    if (!configured) return null;
    final session = await _gateway.restoreSecureSession();
    return session == null ? null : _account(session.user);
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
    return _account(response.data?.user);
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
      final account = _account(response.data?.user);
      return VerificationChallenge(
        (_) async => account,
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
        return _account(verified.data?.user);
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
    final app = await _gateway.app();
    var avatarFileId = account.avatarFileId;
    if (avatar != null) {
      if (avatar.bytes.isEmpty || avatar.bytes.length > 2 * 1024 * 1024) {
        throw const AccountSyncException('avatar_too_large');
      }
      final extension = avatar.extension.toLowerCase();
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        throw const AccountSyncException('avatar_type_invalid');
      }
      final path =
          'orbit-user-avatars/${account.uid}/avatar-${DateTime.now().millisecondsSinceEpoch}.$extension';
      final upload = await app.storage.from().upload(
        path,
        avatar.bytes,
        options: StorageUploadOptions(
          contentType: avatar.contentType,
          cacheControl: 'max-age=86400',
        ),
      );
      if (upload.error != null || upload.data?.id == null) {
        throw AccountSyncException(
          upload.error?.code ?? 'avatar_upload_failed',
          upload.error?.message,
        );
      }
      avatarFileId = upload.data!.id;
    }
    final response = await app.auth.updateUser(
      UpdateUserReq(
        nickname: normalizedUsername,
        avatarUrl: avatar == null ? null : avatarFileId,
      ),
    );
    _throwAuth(response.error);
    final updated = _account(response.data?.user);
    if (avatar != null &&
        account.avatarFileId != null &&
        account.avatarFileId != updated.avatarFileId) {
      unawaited(app.storage.from().remove([account.avatarFileId!]));
    }
    await _gateway.scrubSdkSession();
    return updated;
  }

  @override
  Future<String?> avatarDownloadUrl(String? fileId) async {
    if (fileId == null || fileId.isEmpty) return null;
    if (fileId.startsWith('http://') || fileId.startsWith('https://')) {
      return fileId;
    }
    final app = await _gateway.app();
    final response = await app.storage.from().getDownloadUrls([fileId]);
    if (response.error != null || response.data?.isEmpty != false) return null;
    return response.data!.first.downloadUrl;
  }

  @override
  Future<void> signOut() async {
    if (!configured) return;
    final app = await _gateway.app();
    await app.auth.signOut();
    await _gateway.clearSession();
  }

  @override
  Future<void> deleteAccount(String password) async {
    final app = await _gateway.app();
    final response = await app.auth.deleteUser(
      DeleteUserReq(password: password),
    );
    _throwAuth(response.error);
    await _gateway.clearSession();
  }

  static SyncAccount _account(User? user) {
    final uid = user?.id;
    if (uid == null || uid.isEmpty) {
      throw const AccountSyncException('invalid_account');
    }
    final metadata = user?.userMetadata;
    final username = metadata?.nickName ?? metadata?.username ?? metadata?.name;
    final avatar = metadata?.avatarUrl ?? metadata?.picture;
    return SyncAccount(
      uid: uid,
      email: user?.email ?? '',
      username: username?.trim().isEmpty == true ? null : username,
      avatarFileId: avatar?.trim().isEmpty == true ? null : avatar,
    );
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
  CloudBaseSyncBackend(this._gateway);

  final CloudBaseGateway _gateway;

  @override
  bool get configured => _gateway.configured;

  @override
  Future<SyncPushResult> push(List<SyncMutation> mutations, int cursor) async {
    final result = await _call('orbit-sync-push', {
      'cursor': cursor,
      'mutations': mutations.map((mutation) => mutation.toJson()).toList(),
    });
    return _pushResult(result, mutations, cursor);
  }

  @override
  Future<SyncExchangeResult> exchange(
    List<SyncMutation> mutations,
    int cursor, {
    int limit = 200,
  }) async {
    final result = await _call('orbit-sync-push', {
      'cursor': cursor,
      'pullLimit': limit,
      'mutations': mutations.map((mutation) => mutation.toJson()).toList(),
    });
    final pull = Map<String, dynamic>.from(result['pull'] as Map? ?? const {});
    return SyncExchangeResult(
      push: _pushResult(result, mutations, cursor),
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
    final result = await _call('orbit-sync-pull', {
      'cursor': cursor,
      'limit': limit,
    });
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
    final result = await _call('orbit-sync-pull', {
      'cursor': 0,
      'snapshot': true,
      'limit': 10000,
    });
    return [
      for (final value in result['entities'] as List? ?? const [])
        SyncEntity.fromJson(Map<String, dynamic>.from(value as Map)),
    ];
  }

  @override
  Future<void> deleteAccountData() => _call('orbit-sync-delete-data', const {});

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final app = await _gateway.app();
    try {
      final response = await app.callFunction(name: name, data: data);
      if (response.code != null) {
        throw AccountSyncException(
          response.code!,
          response.message?.toString(),
        );
      }
      if (response.result is! Map) {
        throw const AccountSyncException('invalid_cloud_response');
      }
      return Map<String, dynamic>.from(response.result as Map);
    } finally {
      await _gateway.scrubSdkSession();
    }
  }
}
