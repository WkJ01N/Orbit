class OrbitStatistics {
  const OrbitStatistics({required this.records});
  final List<Map<String, dynamic>> records;
  Iterable<Map<String, dynamic>> get included =>
      records.where((r) => r['excluded'] != true);
  int get activeDays => included.where((r) => r['kind'] == 'day').length;
  String? get firstUsedDate {
    final manual = included.where((r) => r['kind'] == 'profile').firstOrNull;
    if (manual?['firstUsedDate'] is String) {
      return manual!['firstUsedDate'] as String;
    }
    final dates =
        included
            .where((r) => r['kind'] == 'day')
            .map((r) => r['date'] as String)
            .toList()
          ..sort();
    return dates.firstOrNull;
  }

  Iterable<Map<String, dynamic>> get attended =>
      included.where((r) => r['kind'] == 'course' && r['counted'] == true);
  int get attendedSessions => attended.length;
  int get classMinutes => attended.fold(0, (n, r) => n + (r['minutes'] as int));
  int get completedDeadlines =>
      included.where((r) => r['kind'] == 'ddl').length;
  List<({String name, String semester})> get learnedCourses {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in included.where(
      (r) => r['kind'] == 'course' && r['withdrawn'] != true,
    )) {
      groups.putIfAbsent(r['courseKey'] as String, () => []).add(r);
    }
    return [
      for (final group in groups.values)
        if (group.isNotEmpty && group.every((r) => r['counted'] == true))
          (
            name: group.first['name'] as String,
            semester: group.first['semester'] as String,
          ),
    ]..sort(
      (a, b) => '${a.semester}|${a.name}'.compareTo('${b.semester}|${b.name}'),
    );
  }
}
