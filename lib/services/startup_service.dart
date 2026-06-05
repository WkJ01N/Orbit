import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:orbit/services/settings_service.dart';

class StartupService {
  StartupService(this._settings);

  final SettingsService _settings;
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured || !Platform.isWindows) {
      return;
    }
    launchAtStartup.setup(
      appName: 'Orbit',
      appPath: Platform.resolvedExecutable,
      args: ['--startup'],
    );
    _configured = true;
  }

  Future<bool> isEnabled() async {
    if (!Platform.isWindows) {
      return false;
    }
    await _ensureConfigured();
    return launchAtStartup.isEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!Platform.isWindows) {
      return;
    }
    await _ensureConfigured();
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
    await _settings.saveLaunchAtStartup(enabled);
  }

  Future<bool> loadPreference() {
    return _settings.loadLaunchAtStartup();
  }

  Future<void> syncWithPreference() async {
    if (!Platform.isWindows) {
      return;
    }
    final enabled = await loadPreference();
    await _ensureConfigured();
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}

bool isStartupLaunch(List<String> args) {
  if (args.contains('--startup')) {
    return true;
  }
  if (Platform.isWindows) {
    return Platform.executableArguments.contains('--startup');
  }
  return false;
}
