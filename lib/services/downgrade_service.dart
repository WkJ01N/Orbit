import 'dart:convert';
import 'package:orbit/models/app_update.dart';

class DowngradeConversion {
  const DowngradeConversion(
    this.json,
    this.losses,
    this.backupVersion, {
    this.lossCounts = const {},
  });
  final String json;
  final List<String> losses;
  final int backupVersion;
  final Map<String, int> lossCounts;
}

class DowngradeService {
  static int? backupVersionFor(String version) {
    if (version == '1.5.5') return 9;
    if (const ['1.5.6', '1.5.7'].contains(version)) return 10;
    if (version == '1.6.0') return 11;
    if (version == '1.6.1') return 12;
    if (version == '1.6.2') return 13;
    return null;
  }

  static DowngradeConversion? convert(String original, String target) {
    final version = backupVersionFor(target);
    if (version == null) return null;
    final raw = Map<String, dynamic>.from(jsonDecode(original) as Map);
    final losses = <String>[];
    final counts = <String, int>{};
    if ((raw['version'] as int) < version) {
      throw const FormatException('Conversion is for older formats only');
    }
    final settings = raw['settings'] as Map?;
    if (version < 13) {
      final sessions = raw['sessions'] as List? ?? [];
      final examIds = sessions
          .where((s) => s['kind'] == 'exam')
          .map((s) => s['id'])
          .toSet();
      if (examIds.isNotEmpty) {
        losses.add('exams');
        counts['exams'] = examIds.length;
      }
      sessions.removeWhere((s) => s['kind'] == 'exam');
      (raw['statistics'] as List?)?.removeWhere((s) => s['kind'] == 'exam');
      for (final key in ['sessionAliases', 'seriesMemberships']) {
        (raw[key] as Map?)?.removeWhere((id, _) => examIds.contains(id));
      }
      final typography = settings?['typography'] as Map?;
      final fallback = typography?.remove('fallbackFontIds') as List? ?? [];
      if (fallback.isNotEmpty) {
        losses.add('fallbacks');
        counts['fallbacks'] = fallback.length;
      }
      final primary = {typography?['appFontId'], typography?['launchFontId']};
      if (typography != null) {
        final imports = typography['imports'] as List? ?? [];
        final removed = imports.where((f) => !primary.contains(f['id'])).length;
        if (removed > 0) {
          losses.add('fontLibrary');
          counts['fontLibrary'] = removed;
        }
        typography['imports'] = imports
            .where((f) => primary.contains(f['id']))
            .toList();
      }
      (raw['fontComponents'] as Map?)?.removeWhere(
        (id, _) => !primary.contains(id),
      );
      // Older readers permit at most two selected fonts / 100 MiB.
      (raw['fonts'] as Map?)?.removeWhere((id, _) => !primary.contains(id));
      final presentation = raw['localPresentation'] as Map?;
      if (presentation != null) {
        for (final key in [
          'brandEnabled',
          'onStartup',
          'onResume',
          'onPageSwitch',
          'pageTransitionStyle',
          'pageTransitionSpeed',
          'pageEnabled',
        ]) {
          presentation.remove(key);
        }
      }
    }
    if (version < 12) {
      raw.remove('fontComponents');
      final presentation = raw.remove('localPresentation') as Map?;
      if (presentation != null &&
          (presentation['iconData'] != null ||
              presentation['cardEntrance'] != 'edge')) {
        losses.add('launch');
        counts['launch'] = 1;
      }
      final typography = settings?['typography'] as Map?;
      if (typography != null) {
        final selected = {typography['appFontId'], typography['launchFontId']};
        final imports = typography['imports'] as List? ?? [];
        if (imports.any((e) => !selected.contains(e['id']))) {
          losses.add('fontLibrary');
          counts['fontLibrary'] = imports
              .where((e) => !selected.contains(e['id']))
              .length;
        }
        typography['imports'] = imports
            .where((e) => selected.contains(e['id']))
            .toList();
        (raw['fonts'] as Map?)?.removeWhere((id, _) => !selected.contains(id));
      }
    }
    if (version < 11) {
      if (settings?.remove('typography') != null) {
        losses.add('typography');
        counts['typography'] = 2;
      }
      raw.remove('fonts');
      if ((settings?['scheduleDisplay'] as Map?)?.remove('backToTopPosition') !=
          null) {
        losses.add('position');
        counts['position'] = 1;
      }
    }
    if (version < 10) {
      final backgrounds = settings?.remove('backgrounds') as Map?;
      if (backgrounds != null) {
        losses.add('backgrounds');
        counts['backgrounds'] = (backgrounds['assets'] as Map? ?? {}).length;
      }
    }
    raw['version'] = version;
    return DowngradeConversion(
      const JsonEncoder.withIndent('  ').convert(raw),
      losses,
      version,
      lossCounts: counts,
    );
  }

  static bool isOlder(AppRelease release, String version, int build) =>
      AppRelease.compareVersions(release.version, version) < 0 ||
      (release.version == version &&
          release.buildNumber > 0 &&
          release.buildNumber < build);
}
