import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/models/navigation_assist_text.dart';
import 'package:orbit/providers/app_providers.dart';
import 'package:orbit/services/wemust_launcher.dart';

class WemustCheckInAction extends ConsumerStatefulWidget {
  const WemustCheckInAction({
    super.key,
    required this.startAt,
    this.openOnShow = false,
  });

  final DateTime startAt;
  final bool openOnShow;

  @override
  ConsumerState<WemustCheckInAction> createState() =>
      _WemustCheckInActionState();
}

class _WemustCheckInActionState extends ConsumerState<WemustCheckInAction>
    with WidgetsBindingObserver {
  bool _opening = false;
  bool _openOnNextFrame = false;
  WemustLaunchResult? _result;

  @override
  void initState() {
    super.initState();
    _openOnNextFrame =
        widget.openOnShow && ref.read(wemustLauncherProvider).supported;
    if (_openOnNextFrame) {
      WidgetsBinding.instance.addObserver(this);
      _scheduleNotificationOpen();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_openOnNextFrame && state == AppLifecycleState.resumed) {
      _scheduleNotificationOpen();
    }
  }

  void _scheduleNotificationOpen() {
    // Install and paint the return route before handing control to WeMust.
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (!mounted ||
          !_openOnNextFrame ||
          binding.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      _openOnNextFrame = false;
      if (ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_open(timetable: true));
      }
    });
    binding.ensureVisualUpdate();
  }

  Future<void> _open({required bool timetable}) async {
    if (_opening) return;
    _openOnNextFrame = false;
    setState(() => _opening = true);
    final result = await ref
        .read(wemustLauncherProvider)
        .open(timetable: timetable);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(wemustLauncherProvider).supported) {
      return const SizedBox.shrink();
    }
    const margin = Duration(minutes: 30);
    final opensAt = widget.startAt.subtract(margin);
    final closesAt = widget.startAt.add(margin);
    final checkInOpen = ref.watch(
      currentTimeProvider.select(
        (now) => !now.isBefore(opensAt) && now.isBefore(closesAt),
      ),
    );
    final text = NavigationAssistText.of(context);
    final message = switch (_result) {
      WemustLaunchResult.timetableUnavailable => text.timetableUnavailable,
      WemustLaunchResult.notInstalled => text.notInstalled,
      WemustLaunchResult.failed ||
      WemustLaunchResult.unsupported => text.failed,
      _ => null,
    };
    if (!checkInOpen && (!widget.openOnShow || message == null)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (checkInOpen)
            FilledButton.icon(
              key: const Key('wemust-open-timetable'),
              onPressed: _opening ? null : () => _open(timetable: true),
              icon: const Icon(Icons.open_in_new),
              label: Text(text.openTimetable),
            ),
          if (message != null)
            Semantics(liveRegion: true, child: Text(message)),
          if (_result == WemustLaunchResult.timetableUnavailable)
            TextButton(
              key: const Key('wemust-open-app'),
              onPressed: _opening ? null : () => _open(timetable: false),
              child: Text(text.openApp),
            )
          else if (!checkInOpen)
            TextButton(
              onPressed: _opening ? null : () => _open(timetable: true),
              child: Text(AppLocalizations.of(context)!.actionRetry),
            ),
        ],
      ),
    );
  }
}
