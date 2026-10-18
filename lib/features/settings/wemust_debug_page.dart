import 'package:orbit/core/motion/page_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/navigation_assist_text.dart';
import 'package:orbit/services/wemust_launcher.dart';

class WemustDebugPage extends ConsumerStatefulWidget {
  const WemustDebugPage({super.key});
  @override
  ConsumerState<WemustDebugPage> createState() => _WemustDebugPageState();
}

class _WemustDebugPageState extends ConsumerState<WemustDebugPage> {
  bool _busy = false;
  String? _version;
  DateTime? _testedAt;
  WemustLaunchResult? _result;
  bool _timetable = true;
  @override
  void initState() {
    super.initState();
    ref.read(wemustLauncherProvider).installedVersion().then((value) {
      if (mounted) setState(() => _version = value);
    });
  }

  Future<void> _test(bool timetable) async {
    if (_busy) return;
    setState(() => _busy = true);
    final service = ref.read(wemustLauncherProvider);
    final version = await service.installedVersion();
    final result = await service.open(timetable: timetable);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _version = version;
      _testedAt = DateTime.now();
      _timetable = timetable;
      _result = result;
    });
  }

  String _status(NavigationAssistText t) => switch (_result) {
    WemustLaunchResult.linkLaunched => t.pick(
      'Link accepted by Android; page arrival is unverified.',
      '系统已接受链接；尚未验证页面落点。',
      '系統已接受連結；尚未驗證頁面落點。',
    ),
    WemustLaunchResult.appLaunched => t.pick(
      'WeMust launched. Open the timetable manually.',
      '已启动 WeMust，请手动进入课表。',
      '已啟動 WeMust，請手動進入課表。',
    ),
    WemustLaunchResult.notInstalled => t.notInstalled,
    WemustLaunchResult.failed || WemustLaunchResult.unsupported => t.failed,
    null => t.pick('Not tested', '尚未测试', '尚未測試'),
  };
  @override
  Widget build(BuildContext context) {
    final t = NavigationAssistText.of(context);
    final diagnostic =
        'WeMust: ${_version ?? "—"}\n${WemustLauncher.targetPackage}\n${WemustLauncher.timetableUri}\n${_testedAt?.toIso8601String() ?? "—"}\n${_timetable ? "timetable" : "app"}: ${_status(t)}';
    return Scaffold(
      appBar: AppBar(
        title: PageModule(
          child: Text(
            t.pick('WeMust diagnostics', 'WeMust 跳转调试', 'WeMust 跳轉偵錯'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectableText(diagnostic),
          const SizedBox(height: 16),
          PageModule(child: Text(t.manualPath)),
          PageModule(
            child: FilledButton(
              onPressed: _busy ? null : () => _test(true),
              child: Text(t.openTimetable),
            ),
          ),
          PageModule(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _test(false),
              child: Text(
                t.pick('Open WeMust only', '仅打开 WeMust', '僅開啟 WeMust'),
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          PageModule(
            child: TextButton(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: diagnostic)),
              child: Text(t.pick('Copy diagnostics', '复制诊断信息', '複製診斷資訊')),
            ),
          ),
        ],
      ),
    );
  }
}
