import 'package:orbit/core/app_info.dart';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orbit/models/app_update.dart';
import 'package:orbit/services/app_update_service.dart';
import 'package:orbit/services/settings_service.dart';

// CPU-heavy decompression and hashing run outside the UI isolate. Cancellation
// is checked before extraction and again before the atomic install commit.
void _extractComponent(
  ({String archive, String staging, Map<String, dynamic> files}) request,
) {
  final zip = ZipDecoder().decodeBytes(
    File(request.archive).readAsBytesSync(),
    verify: true,
  );
  final seen = <String>{};
  var size = 0;
  for (final entry in zip) {
    final expected = request.files[entry.name];
    if (!entry.isFile ||
        !seen.add(entry.name) ||
        expected == null ||
        entry.isSymbolicLink ||
        entry.size != expected['size']) {
      throw const FormatException('Invalid component entry');
    }
    size += entry.size;
    if (size > 192 * 1024 * 1024) {
      throw const FormatException('Component too large');
    }
    final bytes = entry.content as List<int>;
    if (sha256.convert(bytes).toString() != expected['sha256']) {
      throw const FormatException('Component hash mismatch');
    }
    File(
      p.join(request.staging, entry.name),
    ).writeAsBytesSync(bytes, flush: true);
  }
  if (seen.length != request.files.length) {
    throw const FormatException('Incomplete component');
  }
}

final componentServiceProvider = ChangeNotifierProvider<ComponentService>(
  (ref) => ComponentService.shared,
);

class ComponentDescriptor {
  ComponentDescriptor.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String,
      version = json['version'] as int,
      minBuild = json['minBuild'] as int? ?? 31,
      runtimeApi = json['runtimeApi'] as int? ?? 1,
      platform = json['platform'] as String,
      abi = json['abi'] as String?,
      entrypoint = json['entrypoint'] as String?,
      files = Map<String, dynamic>.from(json['files'] as Map),
      asset = UpdateAsset(
        platform: 'component',
        name: Uri.parse(json['url'] as String).pathSegments.last,
        url: json['url'] as String,
        size: json['size'] as int,
        sha256: json['sha256'] as String,
      ) {
    final uri = Uri.parse(asset.url);
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(id) ||
        version < 1 ||
        !asset.verifiable ||
        asset.size > 128 * 1024 * 1024 ||
        runtimeApi != 1 ||
        minBuild > kAppBuildNumber ||
        !const {'any', 'android', 'windows'}.contains(platform) ||
        !RegExp(r'^[A-Za-z0-9_.-]+\.orbitpack$').hasMatch(asset.name) ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith('/WkJ01N/Orbit/releases/download/') ||
        files.isEmpty ||
        files.length > 30) {
      throw const FormatException('Invalid component descriptor');
    }
    for (final entry in files.entries) {
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]*$').hasMatch(entry.key) ||
          entry.key == '..' ||
          entry.value['size'] is! int ||
          (entry.value['size'] as int) < 0 ||
          !RegExp(
            r'^[a-f0-9]{64}$',
          ).hasMatch(entry.value['sha256'] as String? ?? '')) {
        throw const FormatException('Invalid component file');
      }
    }
    if (entrypoint != null && !files.containsKey(entrypoint)) {
      throw const FormatException('Invalid entry point');
    }
  }
  final String id, name, platform;
  final int version, minBuild, runtimeApi;
  final String? abi, entrypoint;
  final Map<String, dynamic> files;
  final UpdateAsset asset;
}

class ComponentMissing implements Exception {
  const ComponentMissing(this.id);
  final String id;
  @override
  String toString() => 'Component not installed: $id';
}

class ComponentService extends ChangeNotifier {
  ComponentService({this.directory, this.catalog});
  static final shared = ComponentService();
  static const channel = MethodChannel('com.must.orbit.orbit/components');
  final Directory? directory;
  final List<ComponentDescriptor>? catalog;
  List<ComponentDescriptor>? _catalog;
  Future<void>? _initializing;
  final Set<String> _ready = {},
      _verified = {},
      _loaded = {},
      pendingRemoval = {};
  final Map<String, UpdateOperation> _operations = {};
  final Map<String, double> progress = {};
  final Map<String, String> errors = {};
  static const _fontIds = {'rounded', 'huninn', 'maiyuan'};
  final _fontFolders = <String, Directory>{};
  final _fontRecords = <String, dynamic>{};
  String _fontContent(ComponentDescriptor value) {
    final names = value.files.keys.toList()..sort();
    return sha256
        .convert(
          utf8.encode(
            jsonEncode({
              for (final name in names)
                name: [value.files[name]['size'], value.files[name]['sha256']],
            }),
          ),
        )
        .toString();
  }

  bool _ownedFontFolder(String id, String name) => RegExp(
    '^${RegExp.escape(id)}-(?:[0-9]+-[a-f0-9]{12}|font-[a-f0-9]{16})\$',
  ).hasMatch(name);
  Future<void> _fontRecordTail = Future.value();
  Future<void> _writeFontRecords() {
    final write = _fontRecordTail.catchError((Object _) {}).then((_) async {
      final directory = await root();
      await directory.create(recursive: true);
      final temporary = File(
        p.join(directory.path, '.font-installations.pending'),
      );
      await temporary.writeAsString(
        jsonEncode({'schema': 1, 'fonts': _fontRecords}),
        flush: true,
      );
      await temporary.rename(
        p.join(directory.path, '.font-installations.json'),
      );
    });
    _fontRecordTail = write;
    return write;
  }

  Future<void> _rememberFont(
    ComponentDescriptor value,
    Directory target,
  ) async {
    _fontFolders[value.id] = target;
    _fontRecords[value.id] = {
      'content': _fontContent(value),
      'directory': p.basename(target.path),
    };
    try {
      await _writeFontRecords();
    } on FileSystemException {
      // Verified files remain usable. The next launch can retry indexing them.
    }
  }

  Future<void> _deleteFontCopies(String id) async {
    final directory = await root();
    if (await directory.exists()) {
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is Directory &&
            _ownedFontFolder(id, p.basename(entry.path))) {
          await entry.delete(recursive: true);
        }
      }
    }
    _fontFolders.remove(id);
    _fontRecords.remove(id);
    await _writeFontRecords();
  }

  Future<void>? _videoInitialization;
  Future<Directory> root() async =>
      directory ??
      Directory(
        p.join((await getApplicationSupportDirectory()).path, 'components'),
      );
  Future<Directory> folder(ComponentDescriptor value) async => Directory(
    p.join(
      (await root()).path,
      _fontIds.contains(value.id)
          ? p.basename(
              _fontFolders[value.id]?.path ??
                  '${value.id}-font-${_fontContent(value).substring(0, 16)}',
            )
          : '${value.id}-${value.version}-${value.asset.sha256!.substring(0, 12)}',
    ),
  );
  Future<List<ComponentDescriptor>> descriptors() async {
    await initialize();
    return _catalog!;
  }

  bool ready(String id) => _ready.contains(id) && !pendingRemoval.contains(id);
  bool downloading(String id) => _operations.containsKey(id);
  Future<void> initialize() => _initializing ??=
      () async {
        _catalog =
            catalog ??
            [
              for (final json
                  in (jsonDecode(
                            await rootBundle.loadString(
                              'assets/components/catalog.json',
                            ),
                          )
                          as Map)['components']
                      as List)
                ComponentDescriptor.fromJson(
                  Map<String, dynamic>.from(json as Map),
                ),
            ];
        final prefs = await SharedPreferences.getInstance();
        try {
          final stored = jsonDecode(
            await File(
              p.join((await root()).path, '.font-installations.json'),
            ).readAsString(),
          );
          if (stored is Map &&
              stored['schema'] == 1 &&
              stored['fonts'] is Map) {
            _fontRecords.addAll(
              Map<String, dynamic>.from(stored['fonts'] as Map),
            );
          }
        } catch (_) {
          /* Legacy installations are recovered from verified files. */
        }
        for (final id
            in prefs.getStringList('component_pending_removal') ?? <String>[]) {
          for (final item in _catalog!.where((e) => e.id == id)) {
            if (_fontIds.contains(id)) {
              await _deleteFontCopies(id);
              continue;
            }
            final target = await folder(item);
            if (await target.exists()) await target.delete(recursive: true);
          }
        }
        await prefs.remove('component_pending_removal');
        for (final item in _catalog!) {
          if (_fontIds.contains(item.id)) {
            await _recoverFont(item);
            continue;
          }
          final target = await folder(item);
          if (await target.exists()) {
            try {
              await _verifyFiles(target, item, hash: false);
              _ready.add(item.id);
            } catch (_) {
              /* Re-download explicitly. */
            }
          }
        }
      }().catchError((Object error) {
        _initializing = null;
        throw error;
      });

  Future<void> _recoverFont(ComponentDescriptor value) async {
    final directory = await root();
    if (!await directory.exists()) return;
    final candidates = <Directory>[await folder(value)];
    final record = _fontRecords[value.id];
    if (record is Map &&
        record['content'] == _fontContent(value) &&
        record['directory'] is String &&
        _ownedFontFolder(value.id, record['directory'] as String)) {
      candidates.add(
        Directory(p.join(directory.path, record['directory'] as String)),
      );
    }
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is Directory &&
          _ownedFontFolder(value.id, p.basename(entry.path))) {
        candidates.add(entry);
      }
    }
    for (final target in candidates) {
      // Do not follow directory links or trust an archive digest as proof of
      // extracted font integrity. Recovery is entirely offline.
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        continue;
      }
      try {
        await _verifyFiles(target, value);
        await _rememberFont(value, target);
        _ready.add(value.id);
        _verified.add(value.id);
        return;
      } catch (_) {
        /* Keep unverified legacy files for explicit recovery. */
      }
    }
  }

  Future<ComponentDescriptor> descriptor(String id) async =>
      (await descriptors()).firstWhere((e) => e.id == id);
  Future<Directory> installed(String id) async {
    final value = await descriptor(id);
    if (!ready(id)) throw ComponentMissing(id);
    final target = await folder(value);
    if (!_verified.contains(id)) {
      try {
        await _verifyFiles(target, value);
        _verified.add(id);
      } catch (_) {
        _ready.remove(id);
        notifyListeners();
        throw ComponentMissing(id);
      }
    }
    return target;
  }

  Future<void> _verifyFiles(
    Directory target,
    ComponentDescriptor value, {
    bool hash = true,
  }) async {
    final contents = await target.list(followLinks: false).toList();
    if (contents.length != value.files.length ||
        contents.any(
          (entry) =>
              entry is! File ||
              !value.files.containsKey(p.basename(entry.path)),
        )) {
      throw const FormatException('Unexpected component contents');
    }
    for (final entry in value.files.entries) {
      final file = File(p.join(target.path, entry.key));
      if (await file.length() != entry.value['size'] ||
          (hash &&
              (await sha256.bind(file.openRead()).first).toString() !=
                  entry.value['sha256'])) {
        throw const FormatException('Component integrity check failed');
      }
    }
  }

  Future<void> installArchive(
    ComponentDescriptor value,
    File archive, {
    UpdateOperation? operation,
  }) async {
    await AppUpdateService.verify(archive, value.asset);
    if (value.asset.size > 128 * 1024 * 1024) {
      throw const FormatException('Component too large');
    }
    final target = await folder(value);
    final staging = Directory('${target.path}.staging');
    await staging.create(recursive: true);
    try {
      operation?.check();
      await compute(_extractComponent, (
        archive: archive.path,
        staging: staging.path,
        files: value.files,
      ));
      await _verifyFiles(staging, value);
      operation?.check();
      if (await target.exists()) {
        if (_loaded.contains(value.id)) {
          throw StateError('Restart before replacing a loaded runtime');
        }
        await target.delete(recursive: true);
      }
      await staging.rename(target.path);
      if (_fontIds.contains(value.id)) await _rememberFont(value, target);
      _ready.add(value.id);
      _verified.add(value.id);
      errors.remove(value.id);
      notifyListeners();
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<void> download(String id) async {
    if (downloading(id)) return;
    final operation = UpdateOperation();
    _operations[id] = operation;
    progress[id] = 0;
    errors.remove(id);
    notifyListeners();
    File? downloaded;
    try {
      final value = await descriptor(id);
      operation.check();
      final service = AppUpdateService(SettingsService());
      final sources = await service.sources();
      final preferences = await service.preferences();
      final chosen = sources
          .where((e) => e.prefix == preferences['source'])
          .firstOrNull;
      DownloadSource? source = chosen;
      if (source == null) {
        final results = await service.probe(value.asset, sources, operation);
        final available = results.where((e) => e.milliseconds != null).toList()
          ..sort((a, b) => a.milliseconds!.compareTo(b.milliseconds!));
        source = available.firstOrNull?.source;
      }
      if (source == null) {
        throw const HttpException('No download source available');
      }
      final file = await service.download(
        value.asset,
        source,
        operation,
        onProgress: (received, total) {
          progress[id] = received / total;
          notifyListeners();
        },
      );
      downloaded = file;
      await installArchive(value, file, operation: operation);
    } on UpdateCancelled {
      /* A cancelled download never changes the selected resource. */
    } catch (error) {
      errors[id] = '$error';
      rethrow;
    } finally {
      try {
        if (downloaded != null && await downloaded.exists()) {
          await downloaded.delete();
        }
      } catch (_) {
        /* Cache cleanup cannot change a completed installation. */
      }
      _operations.remove(id);
      progress.remove(id);
      notifyListeners();
    }
  }

  void cancel(String id) => _operations[id]?.cancel();
  Future<void> remove(String id) async {
    if (downloading(id)) throw StateError('Cancel download first');
    final value = await descriptor(id);
    if (_loaded.contains(id)) {
      pendingRemoval.add(id);
      await (await SharedPreferences.getInstance()).setStringList(
        'component_pending_removal',
        pendingRemoval.toList(),
      );
    } else {
      if (_fontIds.contains(id)) {
        await _deleteFontCopies(id);
      } else {
        final target = await folder(value);
        if (await target.exists()) await target.delete(recursive: true);
      }
      _ready.remove(id);
      _verified.remove(id);
    }
    notifyListeners();
  }

  Future<void> clearOldCaches() async {
    final values = await descriptors();
    final directory = await root();
    if (!await directory.exists()) return;
    final keep = {
      for (final value in values)
        p.normalize((await folder(value)).absolute.path),
    };
    await for (final entry in directory.list(followLinks: false)) {
      final name = p.basename(entry.path);
      final owned = values.any(
        (value) => RegExp(
          '^${RegExp.escape(value.id)}-[0-9]+-[a-f0-9]{12}'
          r'$',
        ).hasMatch(name),
      );
      final unresolvedFont = values.any(
        (value) =>
            _fontIds.contains(value.id) &&
            _ownedFontFolder(value.id, name) &&
            !ready(value.id),
      );
      if (entry is Directory &&
          owned &&
          !unresolvedFont &&
          !keep.contains(p.normalize(entry.absolute.path)) &&
          p.equals(
            p.dirname(p.normalize(entry.absolute.path)),
            p.normalize(directory.absolute.path),
          )) {
        await entry.delete(recursive: true);
      }
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> exportFontComponents(
    Set<String> selected,
  ) async {
    final result = <String, dynamic>{};
    for (final id in selected.where(
      const {'rounded', 'huninn', 'maiyuan'}.contains,
    )) {
      await initialize();
      if (!ready(id)) continue;
      final item = await descriptor(id);
      final dir = await installed(id);
      result[id] = {
        'version': item.version,
        'files': {
          for (final name in item.files.keys)
            name: base64Encode(
              await File(p.join(dir.path, name)).readAsBytes(),
            ),
        },
      };
    }
    return result;
  }

  Future<bool> restoreFontComponent(
    String id,
    Map<String, dynamic> encoded,
  ) async {
    if (!const {'rounded', 'huninn', 'maiyuan'}.contains(id)) {
      throw const FormatException('Not a font component');
    }
    final value = await descriptor(id);
    // Test/support callers may pass raw files; portable v12 records always
    // carry their component version explicitly.
    if (encoded.containsKey('version')) {
      if (encoded['version'] != value.version || encoded['files'] is! Map) {
        throw const FormatException('Unsupported font component version');
      }
      encoded = Map<String, dynamic>.from(encoded['files'] as Map);
    }
    if (encoded.length != value.files.length ||
        encoded.keys.any((e) => !value.files.containsKey(e))) {
      throw const FormatException('Font component files');
    }
    final target = await folder(value);
    if (downloading(id)) {
      throw StateError('Cancel the font download before restoring');
    }
    final staging = Directory('${target.path}.restore');
    await staging.create(recursive: true);
    try {
      for (final name in value.files.keys) {
        final text = encoded[name];
        if (text is! String || text.length > 70 * 1024 * 1024) {
          throw const FormatException('Font component size');
        }
        final bytes = base64Decode(text);
        final expected = value.files[name];
        if (bytes.length != expected['size'] ||
            sha256.convert(bytes).toString() != expected['sha256']) {
          throw const FormatException('Font component hash');
        }
        await File(p.join(staging.path, name)).writeAsBytes(bytes, flush: true);
      }
      await _verifyFiles(staging, value);
      if (ready(id)) return false;
      if (await target.exists()) await target.delete(recursive: true);
      await staging.rename(target.path);
      if (_fontIds.contains(value.id)) await _rememberFont(value, target);
      _ready.add(id);
      _verified.add(id);
      notifyListeners();
      return true;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<String> videoId() async {
    if (Platform.isWindows) return 'video-win-x64';
    if (Platform.isAndroid) {
      final abi = await channel.invokeMethod<String>('processAbi');
      return 'video-android-$abi';
    }
    throw UnsupportedError('Video runtime platform');
  }

  Future<String> ensureVideo() async {
    final id = await videoId();
    final dir = await installed(id);
    final value = await descriptor(id);
    _videoInitialization ??=
        () async {
          await channel.invokeMethod<void>('loadVideo', {
            'directory': dir.path,
          });
          _loaded.add(id);
        }().catchError((Object error) {
          _videoInitialization = null;
          throw error;
        });
    await _videoInitialization;
    return p.join(dir.path, value.entrypoint!);
  }
}
