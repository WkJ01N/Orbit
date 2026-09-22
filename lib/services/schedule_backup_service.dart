import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:orbit/services/reminder_audio_service.dart';
import 'package:orbit/services/strong_reminder_resolver.dart';

import 'package:orbit/models/course_session.dart';
import 'package:orbit/models/deadline.dart';
import 'package:orbit/models/portable_settings.dart';

class OrbitBackup {
  const OrbitBackup({
    required this.version,
    required this.exportedAt,
    required this.sessions,
    this.deadlines = const [],
    this.settings,
    this.audio = const {},
  });

  final int version;
  final DateTime exportedAt;
  final List<CourseSession> sessions;
  final List<Deadline> deadlines;
  final PortableSettings? settings;
  final Map<String, Map<String, dynamic>> audio;
}

class ScheduleBackupException implements Exception {
  ScheduleBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScheduleBackupService {
  static const backupVersion = 6;

  Future<String> encodeWithAudio(
    List<CourseSession> sessions,
    PortableSettings settings, {
    List<Deadline> deadlines = const [],
    Map<String, String> sessionAliases = const {},
    Map<String, List<String>> seriesMemberships = const {},
  }) async {
    final sounds = [
      settings.reminders.strong.sound,
      ...settings.reminders.customRules
          .map((r) => r.strongOverride?.sound)
          .whereType<ReminderSound>(),
    ];
    final audio = <String, Map<String, dynamic>>{};
    final refs = <String, String>{};
    var total = 0;
    for (final sound in sounds.where((s) => s.kind == 'file')) {
      if (refs.containsKey(sound.value)) continue;
      final file = File(sound.value);
      if (!await file.exists()) continue;
      if (await file.length() > ReminderAudioService.maxFileBytes) {
        throw ScheduleBackupException('audio_size');
      }
      final bytes = await file.readAsBytes();
      ReminderAudioService.validate(p.extension(file.path), bytes);
      // Content-based deduplication without an additional hashing dependency.
      final data = base64Encode(bytes);
      final same = audio.entries
          .where((e) => e.value['data'] == data)
          .firstOrNull;
      final id = same?.key ?? 'audio_${audio.length}';
      refs[sound.value] = id;
      if (same == null) {
        total += bytes.length;
        if (total > ReminderAudioService.maxBackupBytes) {
          throw ScheduleBackupException('audio_size');
        }
        audio[id] = {
          'name': p.basename(file.path),
          'displayName': sound.name,
          'data': data,
        };
      }
    }
    ReminderSound remap(ReminderSound sound) => sound.kind == 'file'
        ? ReminderSound(
            kind: 'file',
            value: refs[sound.value] ?? '',
            name: sound.name,
          )
        : sound;
    final normalized = [
      for (final r in settings.reminders.customRules)
        r.copyWith(
          courseKeys: normalizeReminderCourseKeys(
            scope: r.scope,
            keys: r.courseKeys,
            sessions: sessions,
            aliases: sessionAliases,
            memberships: seriesMemberships,
          ),
        ),
    ];
    final reminders = settings.reminders.copyWith(
      strong: settings.reminders.strong.copyWith(
        sound: remap(settings.reminders.strong.sound),
        courseKeys: normalizeReminderCourseKeys(
          scope: settings.reminders.strong.courseScope,
          keys: settings.reminders.strong.courseKeys,
          sessions: sessions,
          aliases: sessionAliases,
          memberships: seriesMemberships,
        ),
      ),
      customRules: [
        for (final r in normalized)
          r.strongOverride == null
              ? r
              : r.copyWith(
                  strongOverride: r.strongOverride!.copyWith(
                    sound: remap(r.strongOverride!.sound),
                  ),
                ),
      ],
    );
    final json =
        jsonDecode(
              encodeToJson(
                sessions,
                deadlines: deadlines,
                settings: settings.withReminders(reminders),
              ),
            )
            as Map<String, dynamic>;
    json['audio'] = audio;
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  Future<({PortableSettings settings, bool soundFallback})> restoreAudio(
    OrbitBackup backup,
  ) async {
    var fallback = false;
    final refs = <String, ReminderSound>{};
    for (final entry in backup.audio.entries) {
      final info = entry.value;
      final imported = await ReminderAudioService.importBytes(
        info['name'] as String,
        base64Decode(info['data'] as String),
      );
      refs[entry.key] = ReminderSound(
        kind: imported.kind,
        value: imported.value,
        name: info['displayName'] as String? ?? imported.name,
      );
    }
    ReminderSound restore(ReminderSound sound) {
      if (sound.kind == 'file') {
        final found = refs[sound.value];
        if (found != null) {
          if (Platform.isWindows) fallback = true;
          return found;
        }
        fallback = true;
        return const ReminderSound();
      }
      if (sound.value.isNotEmpty) {
        fallback = true;
        return const ReminderSound();
      }
      return sound;
    }

    final source = backup.settings!;
    final now = DateTime.now();
    final settings = source.withReminders(
      source.reminders.copyWith(
        strong: source.reminders.strong.copyWith(
          sound: restore(source.reminders.strong.sound),
        ),
        customRules: [
          for (final rule in source.reminders.customRules)
            rule.copyWith(
              activeFrom: now,
              strongOverride: rule.strongOverride?.copyWith(
                sound: restore(rule.strongOverride!.sound),
              ),
            ),
        ],
      ),
    );
    return (settings: settings, soundFallback: fallback);
  }

  String encodeToJson(
    List<CourseSession> sessions, {
    List<Deadline> deadlines = const [],
    PortableSettings? settings,
  }) {
    final payload = {
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'sessions': sessions.map(_sessionToJson).toList(),
      'deadlines': deadlines.map((value) => value.toSyncPayload()).toList(),
      if (settings != null) 'settings': settings.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  List<CourseSession> decodeFromJson(String raw) {
    return decodeBackup(raw).sessions;
  }

  OrbitBackup decodeBackup(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ScheduleBackupException('invalid_format');
    }

    final version = decoded['version'];
    if (version is! int || version < 1 || version > backupVersion) {
      throw ScheduleBackupException('unsupported_version');
    }

    final sessionsRaw = decoded['sessions'];
    if (sessionsRaw is! List<dynamic>) {
      throw ScheduleBackupException('invalid_format');
    }

    final sessions = sessionsRaw.map((item) {
      if (item is! Map<String, dynamic>) {
        throw ScheduleBackupException('invalid_format');
      }
      return _sessionFromJson(item);
    }).toList();
    final deadlinesRaw = decoded['deadlines'];
    if (deadlinesRaw != null && deadlinesRaw is! List) {
      throw ScheduleBackupException('invalid_format');
    }
    final List<Deadline> deadlines;
    try {
      deadlines = [
        for (final value in deadlinesRaw as List? ?? const [])
          Deadline.fromSyncPayload(Map<String, dynamic>.from(value as Map)),
      ];
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    final settingsRaw = decoded['settings'];
    final PortableSettings? settings;
    try {
      settings = settingsRaw is Map<String, dynamic>
          ? PortableSettings.fromJson(settingsRaw)
          : null;
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    final audio = <String, Map<String, dynamic>>{};
    var total = 0;
    try {
      final rawAudio = decoded['audio'];
      if (rawAudio != null && rawAudio is! Map) {
        throw const FormatException('audio_format');
      }
      if (rawAudio is Map) {
        for (final entry in rawAudio.entries) {
          final item = Map<String, dynamic>.from(entry.value as Map);
          final name = item['name'] as String;
          final data = item['data'] as String;
          if (data.length > 7 * 1024 * 1024) {
            throw const FormatException('audio_size');
          }
          final bytes = base64Decode(data);
          ReminderAudioService.validate(p.extension(name), bytes);
          total += bytes.length;
          if (total > ReminderAudioService.maxBackupBytes) {
            throw const FormatException('audio_size');
          }
          audio[entry.key as String] = item;
        }
      }
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    return OrbitBackup(
      version: version,
      exportedAt:
          DateTime.tryParse(decoded['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sessions: sessions,
      deadlines: deadlines,
      settings: settings,
      audio: audio,
    );
  }

  Map<String, dynamic> _sessionToJson(CourseSession session) {
    return {
      'id': session.id,
      'classType': session.classType,
      'room': session.room,
      'date': _dateKey(session.date),
      'weekday': session.weekday,
      'courseName': session.courseName,
      'courseCode': session.courseCode,
      'section': session.section,
      'startAt': session.startAt.toIso8601String(),
      'endAt': session.endAt.toIso8601String(),
      'teachers': session.teachers,
      'faculty': session.faculty,
      'semester': session.semester,
      'sourceFile': session.sourceFile,
      'note': session.note,
      'recurrenceSeriesId': session.recurrenceSeriesId,
      'recurrenceMeetingId': session.recurrenceMeetingId,
    };
  }

  CourseSession _sessionFromJson(Map<String, dynamic> json) {
    final teachersRaw = json['teachers'];
    final teachers = teachersRaw is List
        ? teachersRaw.map((value) => value.toString()).toList()
        : <String>[];

    return CourseSession(
      id: json['id'] as String,
      classType: json['classType'] as String? ?? '',
      room: json['room'] as String,
      date: DateTime.parse(json['date'] as String),
      weekday: json['weekday'] as int,
      courseName: json['courseName'] as String,
      courseCode: json['courseCode'] as String? ?? '',
      section: json['section'] as String? ?? '',
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
      teachers: teachers,
      faculty: json['faculty'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      sourceFile: json['sourceFile'] as String?,
      note: json['note'] as String?,
      recurrenceSeriesId: json['recurrenceSeriesId'] as String?,
      recurrenceMeetingId: json['recurrenceMeetingId'] as String?,
    );
  }

  static String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
