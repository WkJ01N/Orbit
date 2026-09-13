import 'dart:math';

import 'package:orbit/models/course_operation.dart';
import 'package:orbit/models/course_session.dart';

enum ReminderTimeBasis { start, end, date }

enum ReminderCourseScope { all, series, sessions }

enum ReminderRepeatMode { fixed, untilAcknowledged }

enum ReminderStrength { inherit, normal, strong }

enum StrongReminderType { classLead, checkIn, summary, custom }

final _reminderRandom = Random.secure();
String newReminderId() => List.generate(
  16,
  (_) => _reminderRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class ReminderSound {
  const ReminderSound({this.kind = 'system', this.value = '', this.name = ''});
  final String kind;
  final String value;
  final String name;
  Map<String, dynamic> toJson() => {'kind': kind, 'value': value, 'name': name};
  factory ReminderSound.fromJson(Map<String, dynamic> json) => ReminderSound(
    kind: ['system', 'file'].contains(json['kind'])
        ? json['kind'] as String
        : 'system',
    value: json['value'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );
}

class StrongReminderSettings {
  const StrongReminderSettings({
    this.enabled = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.durationSeconds = 30,
    this.sound = const ReminderSound(),
    this.windowsSound = 1,
    this.types = const {
      StrongReminderType.classLead,
      StrongReminderType.checkIn,
      StrongReminderType.summary,
      StrongReminderType.custom,
    },
    this.ruleIds,
    this.courseScope = ReminderCourseScope.all,
    this.courseKeys = const [],
  });
  final bool enabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int durationSeconds;
  final ReminderSound sound;
  final int windowsSound;
  final Set<StrongReminderType> types;

  /// Null includes newly added inherited rules. Empty selects no rules.
  final Set<String>? ruleIds;
  final ReminderCourseScope courseScope;
  final List<String> courseKeys;
  StrongReminderSettings copyWith({
    bool? enabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? durationSeconds,
    ReminderSound? sound,
    int? windowsSound,
    Set<StrongReminderType>? types,
    Set<String>? ruleIds,
    bool allRules = false,
    ReminderCourseScope? courseScope,
    List<String>? courseKeys,
  }) => StrongReminderSettings(
    enabled: enabled ?? this.enabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    sound: sound ?? this.sound,
    windowsSound: windowsSound ?? this.windowsSound,
    types: types ?? this.types,
    ruleIds: allRules ? null : ruleIds ?? this.ruleIds,
    courseScope: courseScope ?? this.courseScope,
    courseKeys: courseKeys ?? this.courseKeys,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'soundEnabled': soundEnabled,
    'vibrationEnabled': vibrationEnabled,
    'durationSeconds': durationSeconds,
    'sound': sound.toJson(),
    'windowsSound': windowsSound,
    'types': types.map((e) => e.name).toList(),
    'ruleIds': ruleIds?.toList(),
    'courseScope': courseScope.name,
    'courseKeys': courseKeys,
  };
  factory StrongReminderSettings.fromJson(Map<String, dynamic> json) {
    final sound = json['sound'];
    final audio = json['soundEnabled'] != false;
    return StrongReminderSettings(
      enabled: json['enabled'] == true,
      types: json['types'] is List
          ? StrongReminderType.values
                .where((e) => (json['types'] as List).contains(e.name))
                .toSet()
          : const {
              StrongReminderType.classLead,
              StrongReminderType.checkIn,
              StrongReminderType.summary,
              StrongReminderType.custom,
            },
      ruleIds: json['ruleIds'] is List
          ? (json['ruleIds'] as List).whereType<String>().toSet()
          : null,
      courseScope: ReminderCourseScope.values.firstWhere(
        (e) => e.name == json['courseScope'],
        orElse: () => ReminderCourseScope.all,
      ),
      courseKeys: json['courseKeys'] is List
          ? (json['courseKeys'] as List).whereType<String>().toList()
          : const [],
      soundEnabled: audio,
      vibrationEnabled: !audio || json['vibrationEnabled'] != false,
      durationSeconds:
          (json['durationSeconds'] is num &&
                      (json['durationSeconds'] as num).isFinite
                  ? (json['durationSeconds'] as num).toInt()
                  : 30)
              .clamp(5, 300),
      windowsSound:
          (json['windowsSound'] is num && (json['windowsSound'] as num).isFinite
                  ? (json['windowsSound'] as num).toInt()
                  : 1)
              .clamp(1, 10),
      sound: sound is Map<String, dynamic>
          ? ReminderSound.fromJson(sound)
          : const ReminderSound(),
    );
  }
}

class CustomReminderRule {
  const CustomReminderRule({
    required this.id,
    required this.name,
    required this.activeFrom,
    this.enabled = true,
    this.basis = ReminderTimeBasis.start,
    this.offsetSeconds = -900,
    this.dayOffset = 0,
    this.secondOfDay = 72000,
    this.scope = ReminderCourseScope.all,
    this.courseKeys = const [],
    this.weekdays = const [],
    this.classTypes = const [],
    this.dateFrom,
    this.dateTo,
    this.titleTemplate = '',
    this.bodyTemplate = '',
    this.repeatMode = ReminderRepeatMode.fixed,
    this.sendCount = 1,
    this.intervalSeconds = 300,
    this.strength = ReminderStrength.inherit,
    this.strongOverride,
  });
  final String id;
  final String name;
  final DateTime activeFrom;
  final bool enabled;
  final ReminderTimeBasis basis;
  final int offsetSeconds;
  final int dayOffset;
  final int secondOfDay;
  final ReminderCourseScope scope;
  final List<String> courseKeys;
  final List<int> weekdays;
  final List<String> classTypes;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String titleTemplate;
  final String bodyTemplate;
  final ReminderRepeatMode repeatMode;
  final int sendCount;
  final int intervalSeconds;
  final ReminderStrength strength;
  final StrongReminderSettings? strongOverride;

  bool matches(CourseSession session) {
    final key = scope == ReminderCourseScope.series
        ? CourseSeriesKey.fromSession(session).value
        : session.id;
    return (scope == ReminderCourseScope.all || courseKeys.contains(key)) &&
        (weekdays.isEmpty || weekdays.contains(session.weekday)) &&
        (classTypes.isEmpty || classTypes.contains(session.classType)) &&
        (dateFrom == null || !session.date.isBefore(dateFrom!)) &&
        (dateTo == null || !session.date.isAfter(dateTo!));
  }

  DateTime firstFireAt(CourseSession session) => basis == ReminderTimeBasis.date
      ? DateTime(
          session.date.year,
          session.date.month,
          session.date.day + dayOffset,
          secondOfDay ~/ 3600,
          secondOfDay % 3600 ~/ 60,
          secondOfDay % 60,
        )
      : (basis == ReminderTimeBasis.start ? session.startAt : session.endAt)
            .add(Duration(seconds: offsetSeconds));

  StrongReminderSettings effectiveStrong(StrongReminderSettings global) =>
      (strongOverride ?? global).copyWith(
        enabled: switch (strength) {
          ReminderStrength.inherit => global.enabled,
          ReminderStrength.normal => false,
          ReminderStrength.strong => true,
        },
      );

  CustomReminderRule copyWith({
    String? id,
    String? name,
    DateTime? activeFrom,
    bool? enabled,
    ReminderTimeBasis? basis,
    int? offsetSeconds,
    int? dayOffset,
    int? secondOfDay,
    ReminderCourseScope? scope,
    List<String>? courseKeys,
    List<int>? weekdays,
    List<String>? classTypes,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDates = false,
    String? titleTemplate,
    String? bodyTemplate,
    ReminderRepeatMode? repeatMode,
    int? sendCount,
    int? intervalSeconds,
    ReminderStrength? strength,
    StrongReminderSettings? strongOverride,
    bool clearStrongOverride = false,
  }) => CustomReminderRule(
    id: id ?? this.id,
    name: name ?? this.name,
    activeFrom: activeFrom ?? this.activeFrom,
    enabled: enabled ?? this.enabled,
    basis: basis ?? this.basis,
    offsetSeconds: offsetSeconds ?? this.offsetSeconds,
    dayOffset: dayOffset ?? this.dayOffset,
    secondOfDay: secondOfDay ?? this.secondOfDay,
    scope: scope ?? this.scope,
    courseKeys: courseKeys ?? this.courseKeys,
    weekdays: weekdays ?? this.weekdays,
    classTypes: classTypes ?? this.classTypes,
    dateFrom: clearDates ? null : dateFrom ?? this.dateFrom,
    dateTo: clearDates ? null : dateTo ?? this.dateTo,
    titleTemplate: titleTemplate ?? this.titleTemplate,
    bodyTemplate: bodyTemplate ?? this.bodyTemplate,
    repeatMode: repeatMode ?? this.repeatMode,
    sendCount: sendCount ?? this.sendCount,
    intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    strength: strength ?? this.strength,
    strongOverride: clearStrongOverride
        ? null
        : strongOverride ?? this.strongOverride,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'activeFrom': activeFrom.toIso8601String(),
    'enabled': enabled,
    'basis': basis.name,
    'offsetSeconds': offsetSeconds,
    'dayOffset': dayOffset,
    'secondOfDay': secondOfDay,
    'scope': scope.name,
    'courseKeys': courseKeys,
    'weekdays': weekdays,
    'classTypes': classTypes,
    'dateFrom': dateFrom?.toIso8601String(),
    'dateTo': dateTo?.toIso8601String(),
    'titleTemplate': titleTemplate,
    'bodyTemplate': bodyTemplate,
    'repeatMode': repeatMode.name,
    'sendCount': sendCount,
    'intervalSeconds': intervalSeconds,
    'strength': strength.name,
    'strongOverride': strongOverride?.toJson(),
  };

  factory CustomReminderRule.fromJson(Map<String, dynamic> json) {
    T choice<T extends Enum>(List<T> values, String key) => values.firstWhere(
      (v) => v.name == json[key],
      orElse: () => values.first,
    );
    int number(String key, int fallback) =>
        json[key] is num && (json[key] as num).isFinite
        ? (json[key] as num).toInt()
        : fallback;
    final strong = json['strongOverride'];
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Invalid reminder identity');
    }
    return CustomReminderRule(
      id: id,
      name: json['name'] as String? ?? '',
      activeFrom:
          DateTime.tryParse(json['activeFrom'] as String? ?? '') ??
          DateTime.now(),
      enabled: json['enabled'] != false,
      basis: choice(ReminderTimeBasis.values, 'basis'),
      offsetSeconds: number('offsetSeconds', -900),
      dayOffset: number('dayOffset', 0),
      secondOfDay: number('secondOfDay', 72000).clamp(0, 86399),
      scope: choice(ReminderCourseScope.values, 'scope'),
      courseKeys: List<String>.from(json['courseKeys'] as List? ?? []),
      weekdays: List<int>.from(
        json['weekdays'] as List? ?? [],
      ).where((d) => d >= 1 && d <= 7).toList(),
      classTypes: List<String>.from(json['classTypes'] as List? ?? []),
      dateFrom: DateTime.tryParse(json['dateFrom'] as String? ?? ''),
      dateTo: DateTime.tryParse(json['dateTo'] as String? ?? ''),
      titleTemplate: json['titleTemplate'] as String? ?? '',
      bodyTemplate: json['bodyTemplate'] as String? ?? '',
      repeatMode: choice(ReminderRepeatMode.values, 'repeatMode'),
      sendCount: number('sendCount', 1).clamp(1, 100),
      intervalSeconds: number('intervalSeconds', 300).clamp(1, 2147483647),
      strength: choice(ReminderStrength.values, 'strength'),
      strongOverride: strong is Map<String, dynamic>
          ? StrongReminderSettings.fromJson(strong)
          : null,
    );
  }
}
