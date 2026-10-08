import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/app_info.dart';
import 'package:orbit/features/reminder/strong_confirmation.dart';
import 'package:orbit/features/settings/update_page.dart';
import 'package:orbit/models/app_update.dart';
import 'package:orbit/models/sync_update_text.dart';
import 'package:orbit/services/strong_session_service.dart';

class UpdateHost extends ConsumerStatefulWidget {
  const UpdateHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  ConsumerState<UpdateHost> createState() => _UpdateHostState();
}

class _UpdateHostState extends ConsumerState<UpdateHost>
    with WidgetsBindingObserver {
  AppRelease? _pending;
  bool _checking = false, _shown = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final release = await ref
          .read(appUpdateServiceProvider)
          .check(automatic: true);
      if (mounted &&
          release != null &&
          release.newerThan(kAppVersion, kAppBuildNumber)) {
        _pending = release;
        _show();
      }
    } catch (_) {
      /* Automatic failures stay quiet; manual checks show errors. */
    } finally {
      _checking = false;
    }
  }

  Future<void> _show() async {
    if (!mounted ||
        _pending == null ||
        _shown ||
        StrongSessionService.active(ref.read(strongSessionProvider)) ||
        ref.read(strongConfirmationVisibleProvider)) {
      return;
    }
    final context = widget.navigatorKey.currentContext;
    if (context == null) return;
    final release = _pending!;
    _pending = null;
    _shown = true;
    final t = SyncUpdateText.of(context);
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.available),
        content: Text('${release.version} (${release.buildNumber})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.check),
          ),
        ],
      ),
    );
    if (open == true && mounted) {
      await widget.navigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => UpdatePage(release: release)),
      );
    }
    _shown = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(strongSessionProvider, (_, _) => _show());
    ref.listen(strongConfirmationVisibleProvider, (_, _) => _show());
    return widget.child;
  }
}
