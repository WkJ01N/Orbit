import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';
import 'package:orbit/models/navigation_assist_text.dart';
import 'package:orbit/services/wemust_launcher.dart';

/// Retains the fallback after returning from an accepted, but unverified link.
class WemustCheckInAction extends ConsumerStatefulWidget {
  const WemustCheckInAction({super.key});
  @override
  ConsumerState<WemustCheckInAction> createState() =>
      _WemustCheckInActionState();
}

class _WemustCheckInActionState extends ConsumerState<WemustCheckInAction> {
  bool _opening = false;
  bool _attempted = false;

  Future<void> _open({required bool timetable}) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _attempted = true;
    });
    final result = await ref
        .read(wemustLauncherProvider)
        .open(timetable: timetable);
    if (!mounted) return;
    setState(() => _opening = false);
    final text = NavigationAssistText.of(context);
    final message = switch (result) {
      WemustLaunchResult.notInstalled => text.notInstalled,
      WemustLaunchResult.failed ||
      WemustLaunchResult.unsupported => text.failed,
      WemustLaunchResult.appLaunched => text.manualPath,
      WemustLaunchResult.linkLaunched => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(wemustLauncherProvider).supported) {
      return const SizedBox.shrink();
    }
    final text = NavigationAssistText.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const Key('wemust-open-timetable'),
            onPressed: _opening ? null : () => _open(timetable: true),
            icon: const Icon(Icons.open_in_new),
            label: Text(text.openTimetable),
          ),
          if (_attempted) ...[
            TextButton(
              key: const Key('wemust-open-app'),
              onPressed: _opening ? null : () => _open(timetable: false),
              child: Text(text.fallback),
            ),
            Text(text.manualPath, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
