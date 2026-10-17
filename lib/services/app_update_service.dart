import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:orbit/models/app_update.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/core/app_info.dart';

class UpdateOperation {
  bool cancelled = false;
  final _clients = <HttpClient>{};
  void cancel() {
    cancelled = true;
    for (final c in _clients) {
      c.close(force: true);
    }
  }

  void check() {
    if (cancelled) throw const UpdateCancelled();
  }

  HttpClient client() {
    check();
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    _clients.add(c);
    return c;
  }

  void done(HttpClient c) {
    _clients.remove(c);
    c.close(force: true);
  }
}

class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

class AppUpdateService {
  AppUpdateService(
    this.settings, {
    this.apiBase = const String.fromEnvironment('ORBIT_API_BASE_URL'),
    this.directory,
  });
  final SettingsService settings;
  final String apiBase;
  final Future<Directory> Function()? directory;
  static const _official =
      'https://api.github.com/repos/WkJ01N/Orbit/releases/latest';
  static const _native = MethodChannel('com.must.orbit.orbit/reminders');
  Future<List<String>> supportedAbis() async {
    if (!Platform.isAndroid) return const [];
    try {
      return await _native.invokeListMethod<String>('supportedAbis') ??
          const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<Map<String, dynamic>> preferences() =>
      settings.loadLocalJson('update_preferences');
  Future<void> savePreferences(Map<String, dynamic> value) =>
      settings.saveLocalJson('update_preferences', value);
  Future<AppRelease?> check({bool automatic = false}) async {
    final prefs = await preferences();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (automatic &&
        (prefs['automatic'] == false ||
            now - (prefs['lastCheck'] as num? ?? 0) < 86400000)) {
      return null;
    }
    await savePreferences({...prefs, 'lastCheck': now});
    final operation = UpdateOperation();
    try {
      Map<String, dynamic>? json;
      if (apiBase.isNotEmpty && Uri.parse(apiBase).scheme == 'https') {
        try {
          json = await _json(
            Uri.parse(
              '${apiBase.replaceAll(RegExp(r'/$'), '')}/v1/updates/latest',
            ),
            operation,
          );
          AppRelease.fromGitHub(json);
        } catch (_) {
          json = null;
        }
      }
      json ??= await _json(Uri.parse(_official), operation);
      if (json['orbitManifest'] == null) {
        final raw = (json['assets'] as List? ?? [])
            .where((a) => a['name'] == 'update-manifest.json')
            .firstOrNull;
        if (raw != null) {
          final uri = Uri.parse(raw['browser_download_url']);
          if (uri.scheme == 'https' &&
              uri.host == 'github.com' &&
              uri.path.startsWith('/WkJ01N/Orbit/releases/download/')) {
            try {
              json['orbitManifest'] = await _json(uri, operation);
            } catch (_) {
              /* Missing digest blocks installation. */
            }
          }
        }
      }
      return AppRelease.fromGitHub(json);
    } finally {
      operation.cancel();
    }
  }

  Future<ReleaseHistoryPage> history({int page = 1}) async {
    if (page < 1 || page > 1000) throw ArgumentError.value(page);
    final operation = UpdateOperation();
    try {
      dynamic payload;
      if (apiBase.isNotEmpty) {
        try {
          payload = await _json(
            Uri.parse('$apiBase/v1/updates/releases?page=$page'),
            operation,
          );
        } catch (_) {
          /* Official fallback below. */
        }
      }
      payload ??= await _value(
        Uri.parse(
          'https://api.github.com/repos/WkJ01N/Orbit/releases?per_page=20&page=$page',
        ),
        operation,
      );
      final values = payload is Map
          ? payload['releases'] as List
          : payload as List;
      return ReleaseHistoryPage(
        [
          for (final item in values)
            if (item['draft'] != true &&
                item['prerelease'] != true &&
                RegExp(
                  r'^v?\d+\.\d+\.\d+(\+\d+)?$',
                ).hasMatch(item['tag_name'] as String? ?? ''))
              AppRelease.fromGitHub(Map<String, dynamic>.from(item as Map)),
        ],
        hasMore: payload is Map
            ? payload['hasMore'] == true
            : values.length >= 20,
      );
    } finally {
      operation.cancel();
    }
  }

  Future<AppRelease> release(String version) async {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const FormatException('Invalid version');
    }
    final operation = UpdateOperation();
    try {
      Map<String, dynamic>? payload;
      if (apiBase.isNotEmpty) {
        try {
          payload = await _json(
            Uri.parse('$apiBase/v1/updates/releases/v$version'),
            operation,
          );
          AppRelease.fromGitHub(payload);
        } catch (_) {
          payload = null;
        }
      }
      payload ??= await _json(
        Uri.parse(
          'https://api.github.com/repos/WkJ01N/Orbit/releases/tags/v$version',
        ),
        operation,
      );
      if (payload['orbitManifest'] == null) {
        final metadata = (payload['assets'] as List? ?? [])
            .where((e) => e['name'] == 'update-manifest.json')
            .firstOrNull;
        if (metadata != null) {
          final uri = Uri.parse(metadata['browser_download_url'] as String);
          if (uri.scheme == 'https' &&
              uri.host == 'github.com' &&
              uri.path.startsWith('/WkJ01N/Orbit/releases/download/')) {
            try {
              payload['orbitManifest'] = await _json(uri, operation);
            } catch (_) {
              /* Missing verification blocks download. */
            }
          }
        }
      }
      final result = AppRelease.fromGitHub(payload);
      if (result.version != version) {
        throw const FormatException('Release version mismatch');
      }
      return result;
    } finally {
      operation.cancel();
    }
  }

  Future<Map<String, dynamic>> _json(
    Uri uri,
    UpdateOperation operation,
  ) async => Map<String, dynamic>.from(await _value(uri, operation) as Map);

  Future<dynamic> _value(Uri uri, UpdateOperation operation) async {
    final client = operation.client();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set('User-Agent', 'Orbit/$kAppVersion');
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        operation.check();
        bytes.addAll(chunk);
        if (bytes.length > 3 * 1024 * 1024) {
          throw const FormatException('Metadata too large');
        }
      }
      return jsonDecode(utf8.decode(bytes));
    } finally {
      operation.done(client);
    }
  }

  Future<List<DownloadSource>> sources() async {
    final prefs = await preferences();
    return [
      ...DownloadSource.builtIn,
      for (final p in (prefs['custom'] as List? ?? []).whereType<String>())
        if (DownloadSource.validPrefix(p)) DownloadSource(Uri.parse(p).host, p),
    ];
  }

  Future<List<SourceLatency>> probe(
    UpdateAsset asset,
    List<DownloadSource> sources,
    UpdateOperation operation, {
    void Function(SourceLatency)? onResult,
  }) async {
    var index = 0;
    final results = <SourceLatency>[];
    Future<void> worker() async {
      while (index < sources.length && !operation.cancelled) {
        final source = sources[index++];
        final samples = <int>[];
        String? error;
        for (var sample = 0; sample < 3; sample++) {
          operation.check();
          final client = operation.client();
          try {
            final stopwatch = Stopwatch()..start();
            final response = await (() async {
              final req = await client.getUrl(source.assetUri(asset));
              req.headers.set('Range', 'bytes=0-65535');
              req.headers.set('User-Agent', 'Orbit/$kAppVersion');
              final res = await req.close();
              if (![200, 206].contains(res.statusCode) ||
                  res.headers.contentType?.mimeType.startsWith('text/') ==
                      true) {
                throw const FormatException('Invalid package response');
              }
              final iterator = StreamIterator<List<int>>(res);
              try {
                if (!await iterator.moveNext() || iterator.current.isEmpty) {
                  throw const FormatException('Empty package');
                }
                final latency = stopwatch.elapsedMilliseconds;
                // Read at most one range, then close even when a mirror ignores Range.
                var received = iterator.current.length;
                while (received < 65536 && await iterator.moveNext()) {
                  received += iterator.current.length;
                }
                return latency;
              } finally {
                await iterator.cancel();
              }
            })().timeout(const Duration(seconds: 6));
            samples.add(response);
          } catch (e) {
            operation.check();
            error = '$e';
          } finally {
            operation.done(client);
          }
        }
        samples.sort();
        // All three attempts must return package bytes; intermittent mirrors are not selected.
        final result = SourceLatency(
          source: source,
          testedAt: DateTime.now(),
          milliseconds: samples.length == 3 ? samples[1] : null,
          error: samples.length == 3 ? null : error,
        );
        results.add(result);
        onResult?.call(result);
      }
    }

    await Future.wait([worker(), worker()]);
    operation.check();
    return results;
  }

  Future<File> download(
    UpdateAsset asset,
    DownloadSource source,
    UpdateOperation operation, {
    required void Function(int received, int total) onProgress,
  }) async {
    if (!asset.verifiable) {
      throw const FormatException('Official SHA-256 or size missing');
    }
    final dir = await _directory();
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}${asset.name}');
    final partial = File('${file.path}.part');
    final client = operation.client();
    IOSink? sink;
    try {
      final request = await client
          .getUrl(source.assetUri(asset))
          .timeout(const Duration(seconds: 15));
      request.headers.set('User-Agent', 'Orbit/$kAppVersion');
      request.headers.set('Accept-Encoding', 'identity');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      if (response.contentLength >= 0 && response.contentLength != asset.size) {
        throw const FormatException('Package size mismatch');
      }
      sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        operation.check();
        received += chunk.length;
        if (received > asset.size) {
          throw const FormatException('Package size mismatch');
        }
        sink.add(chunk);
        onProgress(received, asset.size);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      operation.check();
      await verify(partial, asset);
      operation.check();
      return await partial.rename(file.path);
    } catch (_) {
      await sink?.close();
      if (await partial.exists()) await partial.delete();
      operation.check();
      rethrow;
    } finally {
      operation.done(client);
    }
  }

  static Future<void> verify(File file, UpdateAsset asset) async {
    if (!asset.verifiable || await file.length() != asset.size) {
      throw const FormatException('Package size mismatch');
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != asset.sha256) {
      throw const FormatException('SHA-256 mismatch');
    }
  }

  Future<Directory> _directory() async {
    if (directory != null) return directory!();
    if (Platform.isAndroid) {
      return Directory(
        (await _native.invokeMethod<String>('updateDirectory'))!,
      );
    }
    final base =
        Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return Directory(
      '$base${Platform.pathSeparator}Orbit${Platform.pathSeparator}updates',
    );
  }

  Future<Map<String, dynamic>> inspect(
    File file,
    UpdateAsset asset, {
    AppRelease? release,
  }) async {
    await verify(file, asset);
    if (!Platform.isAndroid) return {};
    final info = Map<String, dynamic>.from(
      await _native.invokeMapMethod<String, dynamic>('inspectUpdate', {
            'path': file.path,
          }) ??
          {},
    );
    if (release != null &&
        (info['versionName'] != release.version ||
            (release.buildNumber > 0 &&
                info['versionCode'] != release.buildNumber))) {
      throw const FormatException('APK version differs from release metadata');
    }
    return info;
  }

  Future<void> install(
    File file,
    UpdateAsset asset, {
    AppRelease? release,
  }) async {
    if (Platform.isAndroid) {
      await inspect(file, asset, release: release);
      await _native.invokeMethod('installUpdate', {'path': file.path});
    } else if (Platform.isWindows) {
      await verify(file, asset);
      await Process.start('explorer.exe', [file.path]);
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
