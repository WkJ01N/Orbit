class OrbitStatistics {
  OrbitStatistics({required this.records});
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
  int get completedExams =>
      included.where((r) => r['kind'] == 'exam' && r['counted'] == true).length;
  late final List<({String name, String semester})> learnedCourses =
      _learnedCourses();
  List<({String name, String semester})> _learnedCourses() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in included.where(
      (r) => r['kind'] == 'course' && r['withdrawn'] != true,
    )) {
      groups.putIfAbsent(r['courseKey'] as String, () => []).add(r);
    }
    final completed = groups.values
        .where((g) => g.isNotEmpty && g.every((r) => r['counted'] == true))
        .toList();
    String lastEnd(List<Map<String, dynamic>> group) => group
        .map((r) => r['endAt'] as String? ?? '')
        .fold('', (a, b) => a.compareTo(b) > 0 ? a : b);
    completed.sort((a, b) {
      final time = lastEnd(b).compareTo(lastEnd(a));
      return time != 0
          ? time
          : '${a.first['semester']}|${a.first['name']}'.compareTo(
              '${b.first['semester']}|${b.first['name']}',
            );
    });
    return [
      for (final g in completed)
        (
          name: g.first['name'] as String,
          semester: g.first['semester'] as String,
        ),
    ];
  }
}
