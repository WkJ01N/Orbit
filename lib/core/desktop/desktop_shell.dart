import 'dart:io';

import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/services/tray_service.dart';
import 'package:window_manager/window_manager.dart';

class DesktopShell extends StatefulWidget {
  const DesktopShell({required this.child, super.key});

  final Widget child;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> with WindowListener {
  bool _trayHintShown = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initTray();
      });
    }
  }

  Future<void> _initTray() async {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      await TrayService.instance.initialize(
        onShowWindow: showMainWindow,
        onExitApp: exitDesktopApp,
        showLabel: l10n.trayShow,
        exitLabel: l10n.trayExit,
        tooltip: l10n.appTitle,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.trayInitFailed)),
        );
      }
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    hideMainWindow();
    if (!_trayHintShown && mounted) {
      _trayHintShown = true;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.trayHiddenHint)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
