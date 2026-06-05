import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  TrayService._();

  static final TrayService instance = TrayService._();

  static const _trayIconAsset = 'assets/icons/tray_icon.ico';

  bool _initialized = false;
  VoidCallback? _onShowWindow;
  VoidCallback? _onExitApp;

  Future<String> _resolveTrayIconPath() async {
    final bundled = File(
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'data',
        'flutter_assets',
        'assets',
        'icons',
        'tray_icon.ico',
      ),
    );
    if (bundled.existsSync()) {
      return bundled.path;
    }

    final bytes = await rootBundle.load(_trayIconAsset);
    final temp = File(
      p.join((await getTemporaryDirectory()).path, 'orbit_tray.ico'),
    );
    await temp.writeAsBytes(
      bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      ),
    );
    return temp.path;
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

    final iconPath = await _resolveTrayIconPath();
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip(tooltip);
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: showLabel),
          MenuItem(key: 'exit', label: exitLabel),
        ],
      ),
    );
    trayManager.addListener(this);
    _initialized = true;
  }

  Future<void> dispose() async {
    if (!Platform.isWindows || !_initialized) {
      return;
    }
    trayManager.removeListener(this);
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
}

Future<void> hideMainWindow() async {
  if (!Platform.isWindows) {
    return;
  }
  await windowManager.hide();
}

Future<void> exitDesktopApp() async {
  if (!Platform.isWindows) {
    return;
  }
  await TrayService.instance.dispose();
  await windowManager.destroy();
}
