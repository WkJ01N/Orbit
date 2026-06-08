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

class _DesktopShellState extends State<DesktopShell>
    with WindowListener, WidgetsBindingObserver {
  bool _trayHintShown = false;
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      WidgetsBinding.instance.addObserver(this);
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
      WidgetsBinding.instance.removeObserver(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Platform.isWindows) {
      return;
    }
    final locale = Localizations.localeOf(context);
    if (_lastLocale != null && _lastLocale != locale) {
      final l10n = AppLocalizations.of(context)!;
      TrayService.instance.updateLabels(
        showLabel: l10n.trayShow,
        exitLabel: l10n.trayExit,
        tooltip: l10n.appTitle,
      );
    }
    _lastLocale = locale;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TrayService.instance.repairIfNeeded();
    }
  }

  @override
  void onWindowFocus() {
    TrayService.instance.repairIfNeeded();
  }

  @override
  void onWindowClose() {
    // On the first close, show the hint while the window is still visible, then
    // hide shortly after so the user actually sees where the app went.
    if (!_trayHintShown && mounted) {
      _trayHintShown = true;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.trayHiddenHint),
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(milliseconds: 1500), hideMainWindow);
    } else {
      hideMainWindow();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
