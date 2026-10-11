import 'package:flutter/services.dart';
import 'dart:io';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/portable_settings.dart';

/// Whitelisted groups never carry policy, credentials, device paths or runtime state.
class SettingsSyncCodec {
  static const fields = {
    'appearance': [
      'locale',
      'themeColor',
      'themeMode',
      'themeStyle',
      'colorScheme',
      'multicolor',
    ],
    'colors': ['automaticCourseColorIds', 'courseColorOverrides'],
    'display': [
      'gridDefaultWeekMode',
      'weekStartDay',
      'gridDensity',
      'scheduleDisplay',
    ],
    'archive': ['archive'],
  };
  static Map<String, Map<String, dynamic>> groups(PortableSettings settings) {
    final json = settings.toJson();
    final reminders = Map<String, dynamic>.from(json['reminders']);
    final rules = (reminders.remove('customRules') as List)
        .cast<Map<String, dynamic>>();
    final strong = Map<String, dynamic>.from(reminders.remove('strong'));
    final result = {
      for (final entry in fields.entries)
        entry.key: {
          for (final field in entry.value)
            if (json.containsKey(field)) field: json[field],
        },
    };
    result['reminders'] = {
      ...reminders,
      'customRules': [
        for (final rule in rules)
          Map<String, dynamic>.from(rule)
            ..remove('strength')
            ..remove('strongOverride'),
      ],
    };
    result['strong'] = {
      'strong': portableStrong(strong),
      'ruleOverrides': {
        for (final rule in rules)
          rule['id'] as String: {
            'strength': rule['strength'],
            if (rule['strongOverride'] is Map)
              'strongOverride': portableStrong(
                Map<String, dynamic>.from(rule['strongOverride']),
              ),
          },
      },
    };
    return result;
  }

  static Map<String, dynamic> portableStrong(Map<String, dynamic> input) {
    final value = Map<String, dynamic>.from(input);
    final sound = Map<String, dynamic>.from(value['sound'] as Map? ?? {});
    // System URIs and file paths only work on the originating device.
    if (sound.isNotEmpty) {
      value['sound'] = {
        'kind': 'descriptor',
        'sourceKind': sound['sourceKind'] ?? sound['kind'],
        'name': sound['name'],
        'portable': true,
        'requiresSelection':
            sound['kind'] == 'file' ||
            (sound['value'] as String? ?? '').isNotEmpty,
      };
    }
    value['sourcePlatform'] = Platform.operatingSystem;
    return value;
  }

  static Future<({Map<String, dynamic> payload, bool fallback})> restoreAudio(
    Map<String, dynamic> payload,
  ) async {
    var fallback = false;
    Future<Map<String, dynamic>> restore(Map raw) async {
      final value = Map<String, dynamic>.from(raw);
      final descriptor = Map<String, dynamic>.from(
        value['sound'] as Map? ?? {},
      );
      var needsChoice = descriptor['requiresSelection'] == true;
      if (value['sourcePlatform'] == 'windows' &&
          !Platform.isWindows &&
          (value['windowsSound'] as num? ?? 1) != 1) {
        needsChoice = true;
      }
      Map<String, dynamic>? resolved;
      if (Platform.isAndroid &&
          descriptor['sourceKind'] == 'system' &&
          needsChoice &&
          value['sourcePlatform'] == 'android') {
        try {
          final candidate =
              await const MethodChannel(
                'com.must.orbit.orbit/reminders',
              ).invokeMapMethod<String, dynamic>('resolveReminderSound', {
                'name': descriptor['name'],
              });
          if (candidate != null) resolved = candidate;
        } on MissingPluginException {
          /* An unavailable sound uses the local default. */
        } on PlatformException {
          /* An unavailable sound uses the local default. */
        }
      }
      if (needsChoice && resolved == null) fallback = true;
      value['sound'] = resolved ?? {'kind': 'system', 'value': '', 'name': ''};
      return value;
    }

    final result = <String, dynamic>{};
    if (payload['strong'] is Map) {
      result['strong'] = await restore(payload['strong'] as Map);
    }
    final overrides = <String, dynamic>{};
    for (final e in (payload['ruleOverrides'] as Map? ?? {}).entries) {
      final rule = Map<String, dynamic>.from(e.value as Map);
      overrides[e.key as String] = {
        if (rule.containsKey('strength')) 'strength': rule['strength'],
        if (rule['strongOverride'] is Map)
          'strongOverride': await restore(rule['strongOverride'] as Map),
      };
    }
    result['ruleOverrides'] = overrides;
    return (payload: result, fallback: fallback);
  }

  static PortableSettings merge(PortableSettings local, SyncEntity entity) {
    final json = local.toJson()
      ..remove('importConfiguration')
      ..remove('autoSyncSettings');
    final incoming = entity.payload;
    if (fields.containsKey(entity.id)) {
      for (final key in fields[entity.id]!) {
        if (incoming.containsKey(key)) json[key] = incoming[key];
      }
    } else if (entity.id == 'reminders') {
      final current = Map<String, dynamic>.from(json['reminders']);
      final oldRules = {
        for (final r
            in (current['customRules'] as List).cast<Map<String, dynamic>>())
          r['id']: r,
      };
      for (final e in incoming.entries) {
        if (e.key == 'strong') continue;
        if (e.key == 'customRules') {
          current[e.key] = [
            for (final raw in e.value as List)
              {
                ...Map<String, dynamic>.from(raw as Map)
                  ..remove('strength')
                  ..remove('strongOverride'),
                if (oldRules[(raw)['id']]?['strength'] != null)
                  'strength': oldRules[raw['id']]!['strength'],
                if (oldRules[raw['id']]?['strongOverride'] != null)
                  'strongOverride': oldRules[raw['id']]!['strongOverride'],
              },
          ];
        } else if ((json['reminders'] as Map).containsKey(e.key)) {
          current[e.key] = e.value;
        }
      }
      json['reminders'] = current;
    } else if (entity.id == 'strong') {
      final current = Map<String, dynamic>.from(json['reminders']);
      if (incoming['strong'] is Map) {
        current['strong'] = {
          ...current['strong'] as Map,
          ...incoming['strong'] as Map,
        };
      }
      final overrides = incoming['ruleOverrides'] as Map? ?? {};
      current['customRules'] = [
        for (final raw in current['customRules'] as List)
          {
            ...Map<String, dynamic>.from(raw as Map),
            if (overrides[raw['id']] is Map) ...{
              for (final e in Map<String, dynamic>.from(
                overrides[raw['id']],
              ).entries)
                if (['strength', 'strongOverride'].contains(e.key))
                  e.key: e.key == 'strongOverride' && e.value is Map
                      ? {
                          ...raw['strongOverride'] as Map? ?? {},
                          ...e.value as Map,
                        }
                      : e.value,
            },
          },
      ];
      json['reminders'] = current;
    }
    return PortableSettings.fromJson(json);
  }
}
