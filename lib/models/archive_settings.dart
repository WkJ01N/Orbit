enum ArchiveMutation { archive, hide, show, restore }

enum ArchiveSort { archivedAt, eventTime, name, manual }

class ArchiveSettings {
  const ArchiveSettings({
    this.groupCourses = true,
    this.courseSort = ArchiveSort.archivedAt,
    this.deadlineSort = ArchiveSort.archivedAt,
    this.courseDescending = true,
    this.deadlineDescending = true,
    this.orders = const {},
    this.autoCourses = false,
    this.autoDeadlines = false,
    this.courseDelayDays = 1,
    this.deadlineDelayDays = 1,
    this.hideCourses = true,
    this.hideDeadlines = true,
  });
  final bool groupCourses, courseDescending, deadlineDescending;
  final ArchiveSort courseSort, deadlineSort;
  final Map<String, List<String>> orders;
  final bool autoCourses, autoDeadlines, hideCourses, hideDeadlines;
  final int courseDelayDays, deadlineDelayDays;

  Map<String, dynamic> toJson() => {
    'groupCourses': groupCourses,
    'courseSort': courseSort.name,
    'deadlineSort': deadlineSort.name,
    'courseDescending': courseDescending,
    'deadlineDescending': deadlineDescending,
    'orders': orders,
    'autoCourses': autoCourses,
    'autoDeadlines': autoDeadlines,
    'courseDelayDays': courseDelayDays,
    'deadlineDelayDays': deadlineDelayDays,
    'hideCourses': hideCourses,
    'hideDeadlines': hideDeadlines,
  };

  factory ArchiveSettings.fromJson(Map<String, dynamic> json) {
    ArchiveSort sort(String key) => ArchiveSort.values.firstWhere(
      (s) => s.name == json[key],
      orElse: () => ArchiveSort.archivedAt,
    );
    int days(String key) => ((json[key] as num?)?.toInt() ?? 1).clamp(0, 36500);
    return ArchiveSettings(
      groupCourses: json['groupCourses'] != false,
      courseSort: sort('courseSort'),
      deadlineSort: sort('deadlineSort'),
      courseDescending: json['courseDescending'] != false,
      deadlineDescending: json['deadlineDescending'] != false,
      autoCourses: json['autoCourses'] == true,
      autoDeadlines: json['autoDeadlines'] == true,
      courseDelayDays: days('courseDelayDays'),
      deadlineDelayDays: days('deadlineDelayDays'),
      hideCourses: json['hideCourses'] != false,
      hideDeadlines: json['hideDeadlines'] != false,
      orders: {
        for (final e in (json['orders'] as Map? ?? {}).entries)
          if (e.key is String && e.value is List)
            e.key as String: (e.value as List).whereType<String>().toList(),
      },
    );
  }

  ArchiveSettings change(Map<String, dynamic> changes) =>
      ArchiveSettings.fromJson({...toJson(), ...changes});
}
