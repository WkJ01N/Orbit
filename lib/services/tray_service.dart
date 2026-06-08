import 'dart:io';

import 'package:flutter/material.dart';
import 'package:orbit/providers/database_providers.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  TrayService._();

  static final TrayService instance = TrayService._();

  static const _trayIconAsset = 'assets/icons/tray_icon.ico';

  bool _initialized = false;
  bool _repairing = false;
  bool _listenerAttached = false;
  VoidCallback? _onShowWindow;
  VoidCallback? _onExitApp;
  String? _showLabel;
  String? _exitLabel;
  String? _tooltip;

  Future<void> _applyTrayState() async {
    await trayManager.setIcon(_trayIconAsset);
    await trayManager.setToolTip(_tooltip!);
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: _showLabel!),
          MenuItem(key: 'exit', label: _exitLabel!),
        ],
      ),
    );
    _ensureListener();
  }

  void _ensureListener() {
    if (_listenerAttached) {
      return;
    }
    trayManager.addListener(this);
    _listenerAttached = true;
  }

  Future<void> initialize({
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
    required String showLabel,
    required String exitLabel,
    required String tooltip,
  }) async {
    if (!Platform.isWindows || _initialized) {
      return;
    }

    _onShowWindow = onShowWindow;
    _onExitApp = onExitApp;
    _showLabel = showLabel;
    _exitLabel = exitLabel;
    _tooltip = tooltip;

    await _applyTrayState();
    _initialized = true;
  }

  /// Re-applies the tray labels and tooltip after a language change so the
  /// context menu does not keep showing the previous locale's text.
  Future<void> updateLabels({
    required String showLabel,
    required String exitLabel,
    required String tooltip,
  }) async {
    if (!Platform.isWindows || !_initialized) {
      return;
    }
    _showLabel = showLabel;
    _exitLabel = exitLabel;
    _tooltip = tooltip;
    try {
      await _applyTrayState();
    } catch (_) {
      // 托盘文案更新失败不应阻塞语言切换。
    }
  }

  Future<void> repairIfNeeded() async {
    if (!Platform.isWindows || !_initialized || _repairing) {
      return;
    }
    if (_showLabel == null || _exitLabel == null || _tooltip == null) {
      return;
    }

    _repairing = true;
    try {
      final bounds = await trayManager.getBounds();
      if (bounds != null) {
        return;
      }
      await trayManager.destroy();
      await _applyTrayState();
    } catch (_) {
      try {
        await trayManager.destroy();
        await _applyTrayState();
      } catch (_) {
        // 托盘恢复失败时不阻塞窗口操作。
      }
    } finally {
      _repairing = false;
    }
  }

  Future<void> dispose() async {
    if (!Platform.isWindows || !_initialized) {
      return;
    }
    trayManager.removeListener(this);
    _listenerAttached = false;
    await trayManager.destroy();
    _initialized = false;
  }

  @override
  void onTrayIconMouseDown() {
    _onShowWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _onShowWindow?.call();
      case 'exit':
        _onExitApp?.call();
    }
  }
}

Future<void> initializeDesktopWindow({bool startHidden = false}) async {
  if (!Platform.isWindows) {
    return;
  }

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(960, 720),
    center: true,
    title: 'Orbit',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (startHidden) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  });
  await windowManager.setPreventClose(true);
}

Future<void> showMainWindow() async {
  if (!Platform.isWindows) {
    return;
  }
  await windowManager.show();
  await windowManager.focus();
  await TrayService.instance.repairIfNeeded();
}

Future<void> hideMainWindow() async {
  if (!Platform.isWindows) {
    return;
  }
  await windowManager.hide();
  await TrayService.instance.repairIfNeeded();
}

Future<void> exitDesktopApp() async {
  if (!Platform.isWindows) {
    return;
  }
  try {
    await TrayService.instance.dispose();
    await closeAppDatabase();
  } catch (_) {
    // 退出路径不因清理失败而阻塞。
  }
  exit(0);
}
