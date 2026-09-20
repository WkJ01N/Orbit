import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef AvatarDirectoryProvider = Future<Directory> Function();
typedef AvatarDownloader = Future<Uint8List> Function(Uri uri);

class AccountAvatarCache {
  AccountAvatarCache({
    AvatarDirectoryProvider? directoryProvider,
    AvatarDownloader? downloader,
  }) : _directoryProvider =
           directoryProvider ??
           (() async => Directory(
             path.join(
               (await getApplicationSupportDirectory()).path,
               'avatar_cache',
             ),
           )),
       _downloader = downloader ?? _download;

  final AvatarDirectoryProvider _directoryProvider;
  final AvatarDownloader _downloader;
  final Map<String, Uint8List> _memory = {};
  final Map<String, Future<Uint8List?>> _loads = {};

  Future<Uint8List?> load({
    required String uid,
    required String? fileId,
    required Future<String?> Function(String? fileId) resolveUrl,
  }) async {
    if (fileId == null || fileId.isEmpty) {
      await clearUser(uid);
      return null;
    }
    final key = _cacheKey(uid, fileId);
    final memory = _memory[key];
    if (memory != null) return memory;
    final active = _loads[key];
    if (active != null) return active;
    final operation = _load(
      uid: uid,
      fileId: fileId,
      key: key,
      resolveUrl: resolveUrl,
    );
    _loads[key] = operation;
    try {
      return await operation;
    } finally {
      if (identical(_loads[key], operation)) _loads.remove(key);
    }
  }

  Future<void> store({
    required String uid,
    required String fileId,
    required Uint8List bytes,
  }) async {
    if (!_isImage(bytes)) throw const FormatException('avatar_decode_failed');
    final key = _cacheKey(uid, fileId);
    final fileKey = _fileKey(fileId);
    final directory = await _userDirectory(uid);
    await directory.create(recursive: true);
    await _writeAtomically(
      File(path.join(directory.path, '$fileKey.avatar')),
      bytes,
    );
    _memory[key] = bytes;
    await _removeStale(directory, fileKey);
    _memory.removeWhere(
      (candidate, _) =>
          candidate != key && candidate.startsWith(_uidPrefix(uid)),
    );
  }

  Future<void> clearUser(String uid) async {
    _memory.removeWhere((key, _) => key.startsWith(_uidPrefix(uid)));
    final directory = await _userDirectory(uid);
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      if (await directory.exists()) rethrow;
    }
  }

  Future<Uint8List?> _load({
    required String uid,
    required String fileId,
    required String key,
    required Future<String?> Function(String? fileId) resolveUrl,
  }) async {
    final directory = await _userDirectory(uid);
    final target = File(
      path.join(directory.path, '${_fileKey(fileId)}.avatar'),
    );
    if (await target.exists()) {
      final bytes = await target.readAsBytes();
      if (_isImage(bytes)) {
        _memory[key] = bytes;
        return bytes;
      }
      await target.delete();
    }

    final fallback = await _readFallback(directory);
    try {
      final value = await resolveUrl(fileId);
      final uri = value == null ? null : Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) return fallback;
      final bytes = await _downloader(uri);
      if (!_isImage(bytes)) return fallback;
      await store(uid: uid, fileId: fileId, bytes: bytes);
      return bytes;
    } catch (_) {
      return fallback;
    }
  }

  Future<Uint8List?> _readFallback(Directory directory) async {
    if (!await directory.exists()) return null;
    final files = await directory
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.avatar'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (_isImage(bytes)) return bytes;
    }
    return null;
  }

  Future<Directory> _userDirectory(String uid) async {
    final root = await _directoryProvider();
    return Directory(path.join(root.path, _shortHash(uid)));
  }

  Future<void> _removeStale(Directory directory, String currentKey) async {
    await for (final entity in directory.list()) {
      if (entity is File &&
          entity.path.endsWith('.avatar') &&
          path.basename(entity.path) != '$currentKey.avatar') {
        await entity.delete();
      }
    }
  }

  Future<void> _writeAtomically(File target, Uint8List bytes) async {
    final temporary = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  String _cacheKey(String uid, String fileId) =>
      '${_uidPrefix(uid)}${sha256.convert(fileId.codeUnits)}';

  String _uidPrefix(String uid) => '${sha256.convert(uid.codeUnits)}-';

  String _fileKey(String fileId) => _shortHash(fileId);

  String _shortHash(String value) =>
      sha256.convert(value.codeUnits).toString().substring(0, 32);

  static bool _isImage(List<int> bytes) =>
      bytes.isNotEmpty &&
      image.decodeImage(
            bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          ) !=
          null;

  static Future<Uint8List> _download(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Avatar download failed: ${response.statusCode}',
          uri: uri,
        );
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }
}
