import 'package:orbit/models/launch_settings.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:orbit/services/launch_icon_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:orbit/services/font_service.dart';
import 'package:orbit/models/typography_settings.dart';
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
    this.fonts = const {},
    this.fontComponents = const {},
    this.localPresentation,
    this.statistics = const [],
    this.sessionAliases = const {},
    this.seriesMemberships = const {},
  });

  final List<Map<String, dynamic>> statistics;
  final Map<String, String> sessionAliases;
  final Map<String, List<String>> seriesMemberships;
  final int version;
  final DateTime exportedAt;
  final List<CourseSession> sessions;
  final List<Deadline> deadlines;
  final PortableSettings? settings;
  final Map<String, Map<String, dynamic>> audio;
  final Map<String, Map<String, dynamic>> fonts;
  final Map<String, Map<String, dynamic>> fontComponents;
  final Map<String, dynamic>? localPresentation;
}

class ScheduleBackupException implements Exception {
  ScheduleBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScheduleBackupService {
  ScheduleBackupService({FontService? fonts})
    : fontService = fonts ?? FontService.shared;
  final FontService fontService;
  static const backupVersion = 13;

  Future<String> encodeWithAudio(
    List<CourseSession> sessions,
    PortableSettings settings, {
    List<Deadline> deadlines = const [],
    List<Map<String, dynamic>> statistics = const [],
    Map<String, String> sessionAliases = const {},
    Map<String, List<String>> seriesMemberships = const {},
    bool protectLocalResources = false,
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
                statistics: statistics,
                settings: settings.withReminders(reminders),
              ),
            )
            as Map<String, dynamic>;
    json['audio'] = audio;
    if (settings.typography != null) {
      json['fonts'] = await fontService.exportFonts(
        settings.typography!,
        allLibrary: protectLocalResources,
      );
      if (protectLocalResources) {
        (json['settings'] as Map)['typography'] = settings.typography!.toJson();
      }
      json['fontComponents'] = await fontService.components
          .exportFontComponents(settings.typography!.selected);
    }
    if (protectLocalResources) {
      final presentation = await SettingsService().loadLocalJson(
        'launch_presentation_v1',
      );
      final iconPath = presentation['iconPath'] as String?;
      final local = LaunchSettings.fromJson(presentation).toJson()
        ..remove('iconPath');
      if (iconPath != null) {
        final support = await getApplicationSupportDirectory();
        final root = p.join(support.path, 'launch_icons');
        final source = File(iconPath);
        if (!p.isWithin(root, p.absolute(source.path)) ||
            !await source.exists() ||
            await source.length() > 2 * 1024 * 1024) {
          throw const FormatException('Startup icon missing');
        }
        local['iconData'] = base64Encode(await source.readAsBytes());
      }
      json['localPresentation'] = local;
    }
    json['sessionAliases'] = sessionAliases;
    json['seriesMemberships'] = seriesMemberships;
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  Future<
    ({
      PortableSettings settings,
      bool soundFallback,
      List<String> importedFiles,
      List<ImportedFont> importedFonts,
      List<String> importedComponents,
      Map<String, dynamic>? launchPresentation,
      String? createdLaunchIcon,
    })
  >
  restoreAudio(OrbitBackup backup) async {
    var fallback = false;
    final refs = <String, ReminderSound>{};
    final createdFonts = <ImportedFont>[];
    final createdComponents = <String>[];
    String? createdIcon;
    Map<String, dynamic>? launchPresentation;
    try {
      for (final entry in backup.fontComponents.entries) {
        if (await fontService.components.restoreFontComponent(
          entry.key,
          entry.value,
        )) {
          createdComponents.add(entry.key);
        }
      }
      for (final entry in backup.fonts.values) {
        final source = ImportedFont.fromJson(entry);
        final result = await fontService.importBytes(
          '${source.name}.${source.extension}',
          base64Decode(entry['data'] as String),
        );
        if (result.font.id != source.id) {
          throw const FormatException('Font hash mismatch');
        }
        if (result.created) createdFonts.add(result.font);
      }
      if (backup.localPresentation != null) {
        launchPresentation = {...backup.localPresentation!};
        launchPresentation.remove('iconData');
        if (backup.localPresentation!['iconData'] != null) {
          createdIcon = await saveLaunchIcon(
            base64Decode(backup.localPresentation!['iconData'] as String),
          );
          launchPresentation['iconPath'] = createdIcon;
        }
      }
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
    } catch (_) {
      try {
        await discardImportedAudio(refs.values.map((s) => s.value).toList());
      } finally {
        for (final font in createdFonts) {
          await fontService.deleteFile(font);
        }
      }
      await deleteLaunchIcon(createdIcon);
      for (final id in createdComponents) {
        await fontService.components.remove(id);
      }
      rethrow;
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
    return (
      settings: settings,
      soundFallback: fallback,
      importedFiles: refs.values.map((s) => s.value).toList(),
      importedFonts: createdFonts,
      importedComponents: createdComponents,
      launchPresentation: launchPresentation,
      createdLaunchIcon: createdIcon,
    );
  }

  Future<void> discardImportedAudio(List<String> paths) async {
    if (paths.isEmpty) return;
    final root = p.normalize(
      p.absolute((await ReminderAudioService.audioDirectory()).path),
    );
    for (final path in paths) {
      final target = p.normalize(p.absolute(path));
      if (p.isWithin(root, target)) {
        final file = File(target);
        if (await file.exists()) await file.delete();
      }
    }
  }

  String encodeToJson(
    List<CourseSession> sessions, {
    List<Deadline> deadlines = const [],
    List<Map<String, dynamic>> statistics = const [],
    PortableSettings? settings,
  }) {
    final payload = {
      'version': backupVersion,
      'statistics': statistics,
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

    final List<CourseSession> sessions;
    try {
      final ids = <String>{};
      sessions = sessionsRaw.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('session');
        }
        final session = _sessionFromJson(item);
        if (session.id.isEmpty ||
            !ids.add(session.id) ||
            !session.endAt.isAfter(session.startAt) ||
            session.weekday < 1 ||
            session.weekday > 7 ||
            !_validDate(item['date']) ||
            session.examLeadMinutes < 0 ||
            session.examLeadMinutes > 10080 ||
            (session.isExam && !session.id.startsWith('exam|')) ||
            (item['kind'] != null &&
                !['course', 'exam'].contains(item['kind']))) {
          throw const FormatException('session');
        }
        return session;
      }).toList();
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    final deadlinesRaw = decoded['deadlines'];
    if (deadlinesRaw != null && deadlinesRaw is! List) {
      throw ScheduleBackupException('invalid_format');
    }
    final List<Deadline> deadlines;
    try {
      final ids = <String>{};
      deadlines = [
        for (final value in deadlinesRaw as List? ?? const [])
          Deadline.fromSyncPayload(Map<String, dynamic>.from(value as Map)),
      ];
      for (final value in deadlinesRaw ?? const []) {
        if (value['countsTowardStatistics'] != null &&
            value['countsTowardStatistics'] is! bool) {
          throw const FormatException('deadline statistics choice');
        }
        if (value['strongReminderEnabled'] != null &&
            value['strongReminderEnabled'] is! bool) {
          throw const FormatException('deadline strong choice');
        }
      }
      for (final deadline in deadlines) {
        if (deadline.id.isEmpty ||
            !ids.add(deadline.id) ||
            deadline.leadMinutes.any((lead) => lead < 0) ||
            (deadline.strongLeadMinutes ?? const <int>[]).any(
              (m) => m <= 0 || !deadline.leadMinutes.contains(m),
            ) ||
            deadline.disabledReminderLeadMinutes.any(
              (m) => m <= 0 || !deadline.leadMinutes.contains(m),
            )) {
          throw const FormatException('deadline');
        }
      }
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    final settingsRaw = decoded['settings'];
    final PortableSettings? settings;
    try {
      if (settingsRaw != null && settingsRaw is! Map<String, dynamic>) {
        throw const FormatException('settings');
      }
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
          if (item['displayName'] != null && item['displayName'] is! String) {
            throw const FormatException('audio name');
          }
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
    final fonts = <String, Map<String, dynamic>>{};
    try {
      final raw = decoded['fonts'] ?? <String, dynamic>{};
      if (raw is! Map || raw.length > (version >= 12 ? 100 : 2)) {
        throw const FormatException('Font backup');
      }
      var total = 0;
      for (final entry in raw.entries) {
        final item = Map<String, dynamic>.from(entry.value as Map);
        final font = ImportedFont.fromJson(item);
        final encoded = item['data'];
        if (entry.key != font.id ||
            encoded is! String ||
            encoded.length > ((FontService.maxFileBytes + 2) ~/ 3) * 4) {
          throw const FormatException('Font backup size');
        }
        final bytes = base64Decode(encoded);
        FontService.validate(bytes);
        total += bytes.length;
        if (total > FontService.maxBackupBytes ||
            sha256.convert(bytes).toString() != font.id ||
            (ByteData.sublistView(bytes).getUint32(0) == 0x4f54544f
                    ? 'otf'
                    : 'ttf') !=
                font.extension ||
            settings?.typography?.imports[font.id]?.extension !=
                font.extension ||
            (version < 12 &&
                !(settings?.typography?.selected.contains(font.id) ?? false))) {
          throw const FormatException('Invalid backup font');
        }
        fonts[font.id] = item;
      }
      if (settings?.typography != null) {
        for (final id
            in (version >= 12
                ? settings!.typography!.imports.keys
                : settings!.typography!.selected)) {
          if (settings.typography!.imports.containsKey(id) &&
              !fonts.containsKey(id)) {
            throw const FormatException('Missing backup font');
          }
        }
      }
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    Map<String, dynamic>? localPresentation;
    try {
      final raw = decoded['localPresentation'];
      if (raw != null) {
        if (version < 12 ||
            raw is! Map ||
            raw.keys.any(
              (e) =>
                  !(version >= 13
                          ? const [
                              'cardEntrance',
                              'iconData',
                              'brandEnabled',
                              'onStartup',
                              'onResume',
                              'onPageSwitch',
                              'pageTransitionStyle',
                              'pageTransitionSpeed',
                              'pageEnabled',
                            ]
                          : const ['cardEntrance', 'iconData'])
                      .contains(e),
            ) ||
            !const ['edge', 'nearby'].contains(raw['cardEntrance'])) {
          throw const FormatException('Presentation backup');
        }
        for (final key in [
          'brandEnabled',
          'onStartup',
          'onResume',
          'onPageSwitch',
        ]) {
          if (raw[key] != null && raw[key] is! bool) {
            throw const FormatException('Animation switch');
          }
        }
        for (final key in ['pageTransitionStyle', 'pageTransitionSpeed']) {
          if (raw[key] != null && raw[key] is! String) {
            throw const FormatException('Transition preference');
          }
        }
        if (raw['pageEnabled'] != null &&
            (raw['pageEnabled'] is! List ||
                (raw['pageEnabled'] as List).length != 4 ||
                (raw['pageEnabled'] as List).any((v) => v is! bool))) {
          throw const FormatException('Animation pages');
        }
        localPresentation = Map<String, dynamic>.from(raw);
        final encoded = raw['iconData'];
        if (encoded != null) {
          if (encoded is! String || encoded.length > 3 * 1024 * 1024) {
            throw const FormatException('Icon size');
          }
          final bytes = base64Decode(encoded);
          if (bytes.length > 2 * 1024 * 1024 ||
              bytes.length < 8 ||
              bytes[0] != 137 ||
              bytes[1] != 80 ||
              bytes[2] != 78 ||
              bytes[3] != 71) {
            throw const FormatException('Icon format');
          }
        }
      }
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    final fontComponents = <String, Map<String, dynamic>>{};
    try {
      final raw = decoded['fontComponents'] ?? <String, dynamic>{};
      if (raw is! Map ||
          raw.length > (version >= 13 ? 5 : 2) ||
          (version < 12 && raw.isNotEmpty)) {
        throw const FormatException('Font components');
      }
      var total = 0;
      for (final entry in raw.entries) {
        if (!const {'rounded', 'huninn', 'maiyuan'}.contains(entry.key) ||
            !(settings?.typography?.selected.contains(entry.key) ?? false)) {
          throw const FormatException('Unreferenced font component');
        }
        final record = Map<String, dynamic>.from(entry.value as Map);
        if (record['version'] is! int ||
            record['version'] < 1 ||
            record['files'] is! Map) {
          throw const FormatException('Font component version');
        }
        final files = Map<String, dynamic>.from(record['files'] as Map);
        if (files.length > 3) throw const FormatException('Font files');
        for (final file in files.entries) {
          if (!RegExp(r'^[A-Za-z0-9_.-]+\.(ttf|txt)$').hasMatch(file.key) ||
              file.value is! String ||
              (file.value as String).length > 70 * 1024 * 1024) {
            throw const FormatException('Font component entry');
          }
          final bytes = base64Decode(file.value as String);
          total += bytes.length;
          if (total > FontService.maxBackupBytes) {
            throw const FormatException('Font backup size');
          }
          if (file.key.endsWith('.ttf')) FontService.validate(bytes);
        }
        fontComponents[entry.key as String] = record;
      }
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    final List<Map<String, dynamic>> statistics;
    final Map<String, String> aliases;
    final Map<String, List<String>> memberships;
    try {
      statistics = [
        for (final value in decoded['statistics'] as List? ?? [])
          Map<String, dynamic>.from(value as Map),
      ];
      for (final value in statistics) {
        if (value['id'] is! String ||
            (value['id'] as String).isEmpty ||
            (value['id'] as String).length > 512 ||
            ![
              'day',
              'course',
              'exam',
              'ddl',
              'profile',
            ].contains(value['kind']) ||
            DateTime.tryParse('${value['updatedAt']}') == null) {
          throw const FormatException('statistics');
        }
        if (value['kind'] == 'day' &&
            (!_validDate(value['date']) ||
                value['id'] != 'day|${value['date']}')) {
          throw const FormatException('statistics date');
        }
        if (value['kind'] == 'profile' &&
            (!_validDate(value['firstUsedDate']) || value['id'] != 'profile')) {
          throw const FormatException('first date');
        }
        if (value['kind'] == 'course' &&
            (!(value['id'] as String).startsWith('course|') ||
                value['courseKey'] is! String ||
                value['name'] is! String ||
                value['semester'] is! String ||
                value['minutes'] is! int ||
                value['minutes'] < 0 ||
                value['counted'] is! bool)) {
          throw const FormatException('course statistics');
        }
        if (value['kind'] == 'exam' &&
            (!(value['id'] as String).startsWith('exam|') ||
                value['name'] is! String ||
                value['counted'] is! bool ||
                DateTime.tryParse('${value['endAt']}') == null)) {
          throw const FormatException('Exam statistics');
        }
        if (value['kind'] == 'ddl' &&
            !(value['id'] as String).startsWith('ddl|')) {
          throw const FormatException('DDL statistics');
        }
        for (final key in ['excluded', 'withdrawn', 'firstUsedDateAutomatic']) {
          if (value[key] != null && value[key] is! bool) {
            throw const FormatException('statistics flag');
          }
        }
      }
      aliases = Map<String, String>.from(
        decoded['sessionAliases'] as Map? ?? {},
      );
      memberships = {
        for (final e in (decoded['seriesMemberships'] as Map? ?? {}).entries)
          e.key as String: List<String>.from(e.value as List),
      };
    } catch (_) {
      throw ScheduleBackupException('invalid_format');
    }
    return OrbitBackup(
      statistics: statistics,
      sessionAliases: aliases,
      seriesMemberships: memberships,
      version: version,
      exportedAt:
          DateTime.tryParse(decoded['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sessions: sessions,
      deadlines: deadlines,
      settings: settings,
      audio: audio,
      fonts: fonts,
      fontComponents: fontComponents,
      localPresentation: localPresentation,
    );
  }

  Map<String, dynamic> _sessionToJson(CourseSession session) {
    return {
      ...session.featurePayload,
      'id': session.id,
      'deletedAt': session.deletedAt?.toUtc().toIso8601String(),
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
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String).toLocal(),
      kind: json['kind'] == 'exam' ? SessionKind.exam : SessionKind.course,
      semesterId: json['semesterId'] as String?,
      examReminderEnabled: json['examReminderEnabled'] as bool? ?? true,
      examStrongReminder: json['examStrongReminder'] as bool? ?? true,
      examLeadMinutes: json['examLeadMinutes'] as int? ?? 30,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String).toLocal(),
      archiveHidden: json['archiveHidden'] == true,
      autoArchivePaused: json['autoArchivePaused'] == true,
      linkedCourseKey: json['linkedCourseKey'] as String?,
      startPeriod: json['startPeriod'] as int?,
      periodTimePlanId: json['periodTimePlanId'] as String?,
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

  static bool _validDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final date = DateTime.tryParse(value);
    return date != null && _dateKey(date) == value;
  }
}
