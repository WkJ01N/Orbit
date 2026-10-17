import 'package:url_launcher/url_launcher.dart';
import 'package:orbit/features/settings/downgrade_page.dart';
import 'package:orbit/models/navigation_assist_text.dart';
import 'package:orbit/core/background/background_scope.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/app_info.dart';
import 'package:orbit/models/app_update.dart';
import 'package:orbit/models/sync_update_text.dart';
import 'package:orbit/providers/reminder_providers.dart';
import 'package:orbit/services/app_update_service.dart';

final appUpdateServiceProvider = Provider(
  (ref) => AppUpdateService(ref.watch(settingsServiceProvider)),
);

class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key, this.release});
  final AppRelease? release;
  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  AppRelease? _release;
  List<DownloadSource> _sources = DownloadSource.builtIn;
  Map<String, SourceLatency> _latencies = {};
  Map<String, dynamic> _prefs = {};
  String? _source;
  UpdateOperation? _operation;
  File? _file;
  String? _error;
  bool _checked = false, _busy = false;
  bool _assetsReady = false;
  String? _assetName;
  double? _progress;
  List<String> _supportedAbis = const [];
  bool get _older =>
      _release != null &&
      (AppRelease.compareVersions(_release!.version, kAppVersion) < 0 ||
          (_release!.version == kAppVersion &&
              _release!.buildNumber > 0 &&
              _release!.buildNumber < kAppBuildNumber));
  UpdateAsset? get _asset => _assetName == null
      ? _recommendedAsset
      : _release?.assets.where((e) => e.name == _assetName).firstOrNull;
  UpdateAsset? get _recommendedAsset => !_assetsReady
      ? null
      : _release?.assetFor(
          Platform.operatingSystem,
          supportedAbis: _supportedAbis,
        );
  @override
  void initState() {
    super.initState();
    _release = widget.release;
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(appUpdateServiceProvider);
    final abis = await service.supportedAbis();
    final prefs = await service.preferences();
    final sources = await service.sources();
    if (mounted) {
      setState(() {
        _supportedAbis = abis;
        _assetsReady = true;
        _prefs = prefs;
        _sources = sources;
        _source = prefs['source'] as String?;
      });
    }
  }

  @override
  void dispose() {
    _operation?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } on UpdateCancelled {
      /* Cancellation is a user action. */
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == 'install_permission'
              ? SyncUpdateText.of(context).installPermission
              : (e.message ?? e.code),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _operation = null;
        });
      }
    }
  }

  Future<void> _check() => _run(() async {
    final release = await ref.read(appUpdateServiceProvider).check();
    if (mounted) {
      setState(() {
        _release = release;
        _assetName = null;
        _checked = true;
        _file = null;
        _latencies = {};
        _progress = null;
      });
    }
  });
  Future<void> _chooseRelease() async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _ReleaseHistoryPage()),
    );
    if (selected == null || !mounted) return;
    await _run(() async {
      final release = await ref
          .read(appUpdateServiceProvider)
          .release(selected);
      if (!mounted) return;
      setState(() {
        _release = release;
        _assetName = null;
        _file = null;
        _progress = null;
        _latencies = {};
      });
    });
  }

  Future<List<SourceLatency>> _test() async {
    final operation = _operation ??= UpdateOperation();
    setState(() => _latencies = {});
    return ref
        .read(appUpdateServiceProvider)
        .probe(
          _asset!,
          _sources,
          operation,
          onResult: (result) {
            if (mounted) {
              setState(() => _latencies[result.source.prefix] = result);
            }
          },
        );
  }

  Future<void> _download() => _run(() async {
    _operation = UpdateOperation();
    _file = null;
    _progress = null;
    DownloadSource? source;
    if (_source == null) {
      final results =
          (await _test()).where((r) => r.milliseconds != null).toList()
            ..sort((a, b) => a.milliseconds!.compareTo(b.milliseconds!));
      if (results.isEmpty) {
        throw const HttpException('No available download source');
      }
      source = results.first.source;
    } else {
      source = _sources.where((s) => s.prefix == _source).firstOrNull;
    }
    if (source == null) throw const FormatException('Choose a download source');
    final file = await ref
        .read(appUpdateServiceProvider)
        .download(
          _asset!,
          source,
          _operation!,
          onProgress: (received, total) {
            if (mounted) setState(() => _progress = received / total);
          },
        );
    if (mounted) setState(() => _file = file);
  });
  Future<void> _install() => _run(() async {
    final service = ref.read(appUpdateServiceProvider);
    final info = Platform.isAndroid
        ? await service.inspect(_file!, _asset!, release: _release)
        : <String, dynamic>{};
    if (!mounted) return;
    final actualCode = info['versionCode'] as int?;
    final installedCode = info['installedVersionCode'] as int?;
    if (_older ||
        (actualCode != null &&
            installedCode != null &&
            actualCode < installedCode)) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DowngradePage(release: _release!, asset: _asset!, file: _file!),
        ),
      );
    } else {
      await service.install(_file!, _asset!, release: _release);
    }
  });

  Future<void> _addSource() async {
    final t = SyncUpdateText.of(context);
    final controller = TextEditingController();
    final prefix = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: Text(t.custom),
          content: TextField(
            controller: controller,
            onChanged: (_) => setDialog(() {}),
            decoration: const InputDecoration(
              hintText: 'https://mirror.example/',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: DownloadSource.validPrefix(controller.text.trim())
                  ? () => Navigator.pop(c, controller.text.trim())
                  : null,
              child: Text(t.confirm),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (prefix == null || !mounted) return;
    final values = {
      ...(_prefs['custom'] as List? ?? []).cast<String>(),
      prefix,
    }.toList();
    await ref.read(appUpdateServiceProvider).savePreferences({
      ..._prefs,
      'custom': values,
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = SyncUpdateText.of(context);
    final extra = NavigationAssistText.of(context);
    final newer = _release?.newerThan(kAppVersion, kAppBuildNumber) ?? false;
    return BackgroundScaffold(
      appBar: AppBar(title: Text(t.check)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${t.current}: $kAppVersion ($kAppBuildNumber)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.autoCheck),
            value: _prefs['automatic'] != false,
            onChanged: (value) async {
              await ref.read(appUpdateServiceProvider).savePreferences({
                ..._prefs,
                'automatic': value,
              });
              await _load();
            },
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _check,
            icon: const Icon(Icons.system_update),
            label: Text(t.check),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final current = await ref
                            .read(appUpdateServiceProvider)
                            .release(kAppVersion);
                        if (mounted) {
                          setState(() {
                            _release = current;
                            _assetName = null;
                            _file = null;
                            _latencies = {};
                            _progress = null;
                          });
                        }
                      }),
                child: Text(
                  extra.pick('Reinstall this version', '重新安装此版本', '重新安裝此版本'),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _chooseRelease,
                child: Text(extra.pick('Version history', '历史版本', '歷史版本')),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          if (_error != null) SelectableText('${t.failed}\n$_error'),
          if (_release != null) ...[
            const SizedBox(height: 16),
            Text(
              newer
                  ? '${t.available}: ${_release!.version} (${_release!.buildNumber})'
                  : _older
                  ? '${extra.pick('Older version', '旧版本', '舊版本')}: ${_release!.version}'
                  : t.latest,
            ),
            SelectableText(_release!.notes),
          ] else if (_checked)
            Text(t.latest),
          if (_asset != null) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('asset-${_release!.version}-${_asset!.name}'),
              initialValue: _asset!.name,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: extra.pick('Package type', '安装包类型', '安裝包類型'),
              ),
              items: [
                for (final item in _release!.assets.where(
                  (e) => e.platform == Platform.operatingSystem,
                ))
                  DropdownMenuItem(
                    value: item.name,
                    enabled:
                        item.abi == null || _supportedAbis.contains(item.abi),
                    child: Text(
                      '${item.abi ?? (item.platform == 'android' ? 'Universal APK' : 'Windows x64')}${item.abi != null && !_supportedAbis.contains(item.abi) ? ' · ${extra.pick('Incompatible', '不兼容', '不相容')}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _assetName = value;
                      _file = null;
                      _progress = null;
                      _latencies = {};
                    }),
            ),
            if (_older)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  extra.pick(
                    'Downgrading needs an external backup. Android normally requires uninstalling first; unsupported data cannot be restored.',
                    '降级前必须导出外部备份。Android 通常需要先卸载再安装；旧版不支持的数据无法恢复。',
                    '降級前必須匯出外部備份。Android 通常需要先解除安裝再安裝；舊版不支援的資料無法恢復。',
                  ),
                ),
              ),
            Text(
              '${_asset!.name}${_asset!.platform == 'android' && _asset!.abi == null ? ' (Universal APK)' : ''} · ${(_asset!.size / 1024 / 1024).toStringAsFixed(1)} MB',
            ),
            if (!_asset!.verifiable) ...[
              Text(t.unverified),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(_release!.releaseUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  extra.pick('View official release', '查看官方发布页', '查看官方發佈頁'),
                ),
              ),
            ],
            DropdownButtonFormField<String>(
              initialValue: _source ?? 'automatic',
              isExpanded: true,
              decoration: InputDecoration(labelText: t.source),
              items: [
                DropdownMenuItem(
                  value: 'automatic',
                  child: Text(t.automatic, overflow: TextOverflow.ellipsis),
                ),
                for (final source in _sources)
                  DropdownMenuItem(
                    value: source.prefix,
                    child: Text(source.name),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) async {
                      setState(
                        () => _source = value == 'automatic' ? null : value,
                      );
                      await ref.read(appUpdateServiceProvider).savePreferences({
                        ..._prefs,
                        'source': _source,
                      });
                      await _load();
                    },
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await _test();
                        }),
                  child: Text(t.probe),
                ),
                TextButton(
                  onPressed: _busy ? null : _addSource,
                  child: Text(t.custom),
                ),
              ],
            ),
            for (final r in _latencies.values)
              ListTile(
                dense: true,
                title: Text(r.source.name),
                subtitle: Text(
                  '${r.testedAt.toLocal()}${r.error == null ? '' : '\n${r.error}'}',
                ),
                trailing: Text(
                  r.milliseconds == null ? t.failed : '${r.milliseconds} ms',
                ),
              ),
            if (_progress != null) ...[
              LinearProgressIndicator(value: _progress),
              Text('${(_progress! * 100).toStringAsFixed(1)}%'),
            ],
            if (_file != null) ...[
              Text(t.verified),
              if (Platform.isWindows) Text(t.zipHelp),
              FilledButton(
                onPressed: _busy ? null : _install,
                child: Text(t.install),
              ),
            ],
            FilledButton(
              onPressed: _busy || !_asset!.verifiable ? null : _download,
              child: Text(t.download),
            ),
            if (_operation != null)
              TextButton(
                onPressed: () => _operation?.cancel(),
                child: Text(t.cancel),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReleaseHistoryPage extends ConsumerStatefulWidget {
  const _ReleaseHistoryPage();
  @override
  ConsumerState<_ReleaseHistoryPage> createState() =>
      _ReleaseHistoryPageState();
}

class _ReleaseHistoryPageState extends ConsumerState<_ReleaseHistoryPage> {
  final List<AppRelease> _items = [];
  int _page = 1;
  bool _busy = false, _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(appUpdateServiceProvider)
          .history(page: _page);
      if (mounted) {
        setState(() {
          _items.addAll(
            page.items.where(
              (e) => !_items.any((old) => old.version == e.version),
            ),
          );
          _page++;
          _more = page.hasMore;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NavigationAssistText.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.pick('Version history', '历史版本', '歷史版本'))),
      body: ListView(
        children: [
          for (final item in _items)
            ListTile(
              title: Text('v${item.version}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, item.version),
            ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          if (_busy)
            const LinearProgressIndicator()
          else if (_more)
            TextButton(
              onPressed: _load,
              child: Text(t.pick('Load more', '加载更多', '載入更多')),
            ),
        ],
      ),
    );
  }
}
