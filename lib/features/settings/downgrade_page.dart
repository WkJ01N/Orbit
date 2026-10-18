import 'package:orbit/core/motion/page_module.dart';
import 'package:orbit/data/database/app_database.dart';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:orbit/models/app_update.dart';
import 'package:orbit/models/navigation_assist_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/providers/background_providers.dart';
import 'package:orbit/services/app_update_service.dart';
import 'package:orbit/services/background_package_service.dart';
import 'package:orbit/services/backup_file_export.dart';
import 'package:orbit/services/downgrade_service.dart';
import 'package:orbit/services/schedule_backup_service.dart';

class DowngradePage extends ConsumerStatefulWidget {
  const DowngradePage({
    super.key,
    required this.release,
    required this.asset,
    required this.file,
  });
  final AppRelease release;
  final UpdateAsset asset;
  final File file;
  @override
  ConsumerState<DowngradePage> createState() => _DowngradePageState();
}

class _DowngradePageState extends ConsumerState<DowngradePage> {
  bool _busy = false, _exported = false, _acknowledged = false;
  String? _error;
  List<String> _losses = [];
  Map<String, int> _lossCounts = {};
  String _loss(NavigationAssistText t, String id) => switch (id) {
    'exams' => t.pick(
      'Exams and their statistics remain in the protection backup only.',
      '考试及考试统计仅保存在保护备份中。',
      '考試及考試統計僅保存在保護備份中。',
    ),
    'fallbacks' => t.pick(
      'Fallback font order returns to the old defaults.',
      '替补字体顺序恢复旧版默认。',
      '替補字型順序恢復舊版預設。',
    ),
    'typography' => t.pick(
      'Interface and startup fonts return to the old defaults.',
      '界面及开屏字体恢复旧版默认。',
      '介面及開屏字體恢復舊版預設。',
    ),
    'fontLibrary' => t.pick(
      'Unused imported fonts remain in the protection backup only.',
      '未使用的导入字体仅保存在保护备份中。',
      '未使用的匯入字體僅保存在保護備份中。',
    ),
    'backgrounds' => t.pick(
      'This version does not support page backgrounds.',
      '目标版本不支持页面背景。',
      '目標版本不支援頁面背景。',
    ),
    'position' => t.pick(
      'Back-to-top positioning uses the old behavior.',
      '回到顶部位置恢复旧版行为。',
      '回到頂部位置恢復舊版行為。',
    ),
    _ => t.pick(
      'Custom startup artwork is retained in the protection backup only.',
      '自定义启动图标仅保存在保护备份中。',
      '自訂啟動圖示僅保存在保護備份中。',
    ),
  };
  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    Directory? staging;
    try {
      await AppUpdateService.verify(widget.file, widget.asset);
      staging = await (await getTemporaryDirectory()).createTemp(
        'orbit-downgrade-',
      );
      final db = ref.read(appDatabaseProvider);
      await db.refreshStatistics();
      final settings = await ref
          .read(settingsServiceProvider)
          .exportPortableSettings(
            accountUid: (await db.activeSyncAccount())?.uid,
          );
      final json = await ScheduleBackupService().encodeWithAudio(
        await db.getAllSessions(includeDeleted: true),
        settings,
        deadlines: await db.getDeadlines(includeDeleted: true),
        statistics: await db.statisticsRecords(),
        sessionAliases: await db.reminderSessionAliases(),
        seriesMemberships: await db.reminderSeriesMemberships(),
        protectLocalResources: true,
      );
      final conversion = DowngradeService.convert(json, widget.release.version);
      final media = BackgroundPackageService(
        ref.read(backgroundAssetServiceProvider),
      );
      final currentDir = Directory(p.join(staging.path, 'current'));
      await currentDir.create();
      final current = await media.create(json, currentDir);
      final compatibleDir = Directory(p.join(staging.path, 'compatible'));
      await compatibleDir.create();
      File? compatible;
      if (conversion != null) {
        compatible = conversion.backupVersion >= 10
            ? await media.create(conversion.json, compatibleDir)
            : await File(
                p.join(compatibleDir.path, 'compatible.json'),
              ).writeAsString(conversion.json);
      }
      if (!mounted) return;
      setState(() {
        _losses = conversion?.losses ?? [];
        _lossCounts = conversion?.lossCounts ?? {};
      });
      final t = NavigationAssistText.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: PageModule(
            child: Text(t.pick('Confirm downgrade backup', '确认降级备份', '確認降級備份')),
          ),
          content: SingleChildScrollView(
            child: PageModule(
              child: Text(
                [
                  t.pick(
                    'Your current data is preserved in the protection backup. Import the compatible file in the old app.',
                    '当前数据保存在保护备份中。旧版应用应导入兼容备份。',
                    '目前資料保存在保護備份中。舊版應匯入相容備份。',
                  ),
                  if (conversion == null)
                    t.pick(
                      'Data compatibility is unverified for this version. No compatible backup will be generated.',
                      '该版本未做数据适配，不会生成兼容备份。',
                      '此版本未做資料適配，不會產生相容備份。',
                    ),
                  ..._losses.map(
                    (id) => '${_loss(t, id)} (${_lossCounts[id] ?? 0})',
                  ),
                ].join('\n\n'),
              ),
            ),
          ),
          actions: [
            PageModule(
              child: TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(t.pick('Cancel', '取消', '取消')),
              ),
            ),
            PageModule(
              child: FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(t.pick('Save protection bundle', '保存保护包', '儲存保護包')),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final bundle = File(
        p.join(staging.path, 'orbit-downgrade-${widget.release.version}.zip'),
      );
      final encoder = ZipFileEncoder()..create(bundle.path);
      try {
        await encoder.addFile(current, 'current-protection.orbit', 0);
        if (compatible != null) {
          await encoder.addFile(
            compatible,
            compatible.path.endsWith('.json')
                ? 'compatible.json'
                : 'compatible.orbit',
            0,
          );
        }
        await encoder.addFile(widget.file, widget.asset.name, 0);
        final readme = await File(p.join(staging.path, 'README.txt')).writeAsString(
          [
            'Orbit downgrade to ${widget.release.version}',
            t.pick(
              'Keep current-protection.orbit for returning to v1.6.1 or later.',
              'current-protection.orbit 用于恢复到 v1.6.1 或后续兼容版本。',
              'current-protection.orbit 用於恢復至 v1.6.1 或後續相容版本。',
            ),
            t.pick(
              'Extract this ZIP before uninstalling. Android: uninstall, install the included APK, then import compatible.json/orbit. Windows: quit Orbit and extract the old ZIP into a separate folder.',
              '卸载前先解压此 ZIP。Android：卸载、安装包内 APK，再导入兼容备份。Windows：退出 Orbit，将旧版 ZIP 解压到独立目录后运行。',
              '解除安裝前先解壓此 ZIP。Android：解除安裝、安裝包內 APK，再匯入相容備份。Windows：退出 Orbit，將舊版 ZIP 解壓至獨立目錄執行。',
            ),
            if (conversion == null)
              t.pick(
                'This version has no verified data conversion.',
                '该版本未验证数据恢复。',
                '此版本未驗證資料恢復。',
              ),
            ..._losses.map((id) => '${_loss(t, id)} (${_lossCounts[id] ?? 0})'),
          ].join('\n\n'),
        );
        await encoder.addFile(readme, 'README.txt');
      } finally {
        await encoder.close();
      }
      final saved = await exportPersistentFile(bundle);
      if (mounted && saved) setState(() => _exported = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NavigationAssistText.of(context);
    return Scaffold(
      appBar: AppBar(
        title: PageModule(
          child: Text(t.pick('Downgrade protection', '降级保护', '降級保護')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageModule(child: Text('v${widget.release.version}')),
          PageModule(
            child: Text(
              t.pick(
                'A lower Android version normally requires uninstalling Orbit, which removes local data. Save the backup and installer outside the app first.',
                'Android 安装较低版本通常需要先卸载 Orbit，本地数据会被删除。请先把备份和安装包保存到应用外。',
                'Android 安裝較低版本通常需要先解除安裝 Orbit，本機資料會被刪除。請先把備份和安裝包儲存至應用外。',
              ),
            ),
          ),
          if (DowngradeService.backupVersionFor(widget.release.version) == null)
            PageModule(
              child: Text(
                t.pick(
                  'No verified data conversion for this release.',
                  '该版本未做数据适配。',
                  '此版本未做資料適配。',
                ),
              ),
            ),
          if (_error != null) SelectableText(_error!),
          if (_busy) const LinearProgressIndicator(),
          PageModule(
            child: FilledButton(
              onPressed: _busy ? null : _export,
              child: Text(
                t.pick(
                  'Export verified protection bundle',
                  '导出并校验保护包',
                  '匯出並校驗保護包',
                ),
              ),
            ),
          ),
          if (_exported) ...[
            PageModule(
              child: Text(
                t.pick(
                  'Protection bundle saved and verified. Extract it before proceeding.',
                  '保护包已保存并校验。请先解压，再继续操作。',
                  '保護包已儲存並校驗。請先解壓，再繼續操作。',
                ),
              ),
            ),
            PageModule(
              child: CheckboxListTile(
                value: _acknowledged,
                onChanged: (value) =>
                    setState(() => _acknowledged = value ?? false),
                title: Text(
                  t.pick(
                    'I have the backup and installer, and understand the listed losses.',
                    '我已取得备份与安装包，并理解列出的数据损失。',
                    '我已取得備份與安裝包，並理解列出的資料損失。',
                  ),
                ),
              ),
            ),
            if (_acknowledged)
              PageModule(
                child: Text(
                  t.pick(
                    'Close Orbit. Follow README.txt in the exported bundle to uninstall/reinstall and restore the compatible file.',
                    '请退出 Orbit，按保护包 README.txt 指引手动卸载重装并恢复兼容备份。',
                    '請退出 Orbit，按保護包 README.txt 指引手動解除安裝、重裝並恢復相容備份。',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
