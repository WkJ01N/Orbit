import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/navigation_assist_text.dart';
import 'package:orbit/models/typography_text.dart';
import 'package:orbit/providers/typography_providers.dart';
import 'package:orbit/services/component_service.dart';

class ComponentsPage extends ConsumerStatefulWidget {
  const ComponentsPage({super.key, this.focusId});
  final String? focusId;
  @override
  ConsumerState<ComponentsPage> createState() => _ComponentsPageState();
}

class _ComponentsPageState extends ConsumerState<ComponentsPage> {
  late final Future<List<ComponentDescriptor>> _items = _load();
  String? _video;
  Future<List<ComponentDescriptor>> _load() async {
    final service = ref.read(componentServiceProvider);
    final items = await service.descriptors();
    String? video;
    try {
      video = await service.videoId();
      _video = video;
    } catch (_) {
      /* Unsupported platform. */
    }
    return items
        .where(
          (e) =>
              e.platform == 'any' ||
              e.id == video ||
              service.ready(e.id) ||
              service.pendingRemoval.contains(e.id),
        )
        .toList();
  }

  Future<void> _download(String id) async {
    try {
      await ref.read(componentServiceProvider).download(id);
      final fonts = ref.read(fontServiceProvider);
      ref
          .read(typographySettingsProvider.notifier)
          .restoreLoaded(await fonts.initialize());
    } catch (_) {
      /* The persistent component card displays the error and retry action. */
    }
  }

  Future<void> _remove(String id) async {
    final t = NavigationAssistText.of(context);
    if (await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(t.pick('Remove component?', '删除组件？', '刪除元件？')),
            content: Text(
              t.pick(
                'A selected font returns to its default. A loaded video runtime is removed after restarting. Your media files are kept.',
                '使用中的字体将恢复默认。已加载的视频组件将在重启后删除，媒体文件会保留。',
                '使用中的字體將恢復預設。已載入的影片元件會在重啟後刪除，媒體檔案會保留。',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(t.pick('Cancel', '取消', '取消')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(t.pick('Remove', '删除', '刪除')),
              ),
            ],
          ),
        ) !=
        true) {
      return;
    }
    if (!mounted) return;
    final fonts = ref.read(typographySettingsProvider.notifier);
    try {
      await fonts.update(
        (value) => value.copyWith(
          appFontId: value.appFontId == id ? 'system' : null,
          launchFontId: value.launchFontId == id ? 'nunito' : null,
        ),
      );
      await ref.read(componentServiceProvider).remove(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(componentServiceProvider);
    final t = NavigationAssistText.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pick('Resources & components', '资源与组件', '資源與元件')),
      ),
      body: FutureBuilder<List<ComponentDescriptor>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                t.pick(
                  'Download once, then use offline. System fonts and image/GIF backgrounds work without downloads.',
                  '下载后可离线使用。系统字体、图片及 GIF 背景无需下载组件。',
                  '下載後可離線使用。系統字體、圖片及 GIF 背景無需下載元件。',
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await service.clearOldCaches();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t.pick(
                              'Old component cache cleared',
                              '旧组件缓存已清理',
                              '舊元件快取已清理',
                            ),
                          ),
                        ),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t.pick(
                              'Could not remove the cache. Restart and retry.',
                              '缓存清理失败，请重启后重试。',
                              '快取清理失敗，請重啟後重試。',
                            ),
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.cleaning_services_outlined),
                label: Text(
                  t.pick('Clear old component cache', '清理旧组件缓存', '清理舊元件快取'),
                ),
              ),
              for (final item in snapshot.data!)
                Card(
                  color: item.id == widget.focusId
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.platform == 'any'
                              ? TypographyText(context).name(item.id, null)
                              : t.pick('Video backgrounds', '视频背景组件', '影片背景元件'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (item.platform != 'any')
                          Text(
                            '${item.abi ?? ''}${item.id != _video ? ' · ${t.pick('Not the current architecture', '非当前架构', '非目前架構')}' : ''}',
                          ),
                        Text(
                          '${(item.asset.size / 1048576).toStringAsFixed(1)} MiB · ${(item.files.values.fold<int>(0, (sum, file) => sum + (file['size'] as int)) / 1048576).toStringAsFixed(1)} MiB ${t.pick('installed', '安装后', '安裝後')}',
                        ),
                        if (service.errors[item.id] != null)
                          Text(
                            t.pick(
                              'Download or verification failed. Check the network and retry; a loaded runtime may require restarting.',
                              '下载或校验失败，请检查网络后重试；已加载的组件可能需要重启后再操作。',
                              '下載或校驗失敗，請檢查網路後重試；已載入的元件可能需要重啟後再操作。',
                            ),
                          ),
                        if (service.pendingRemoval.contains(item.id))
                          Text(
                            t.pick('Removal pending restart', '重启后删除', '重啟後刪除'),
                          )
                        else if (service.downloading(item.id)) ...[
                          LinearProgressIndicator(
                            value: service.progress[item.id] == 0
                                ? null
                                : service.progress[item.id],
                          ),
                          TextButton(
                            onPressed: () => service.cancel(item.id),
                            child: Text(t.pick('Cancel', '取消', '取消')),
                          ),
                        ] else if (service.ready(item.id)) ...[
                          Text(t.pick('Installed', '已下载', '已下載')),
                          TextButton(
                            onPressed: () => _remove(item.id),
                            child: Text(t.pick('Remove', '删除', '刪除')),
                          ),
                        ] else
                          FilledButton.icon(
                            onPressed: () => _download(item.id),
                            icon: const Icon(Icons.download),
                            label: Text(t.pick('Download', '下载', '下載')),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
