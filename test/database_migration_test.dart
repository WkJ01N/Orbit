import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/data/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('database v2 migrates to v5 without losing active classes', () async {
    final tempDir = await Directory.systemTemp.createTemp('orbit_migration_');
    addTearDown(() => tempDir.delete(recursive: true));
    final path = p.join(tempDir.path, 'orbit.db');
    final old = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE course_sessions (
            id TEXT PRIMARY KEY, class_type TEXT NOT NULL,
            room TEXT NOT NULL, date TEXT NOT NULL, weekday INTEGER NOT NULL,
            course_name TEXT NOT NULL, course_code TEXT NOT NULL,
            section TEXT NOT NULL, start_at TEXT NOT NULL,
            end_at TEXT NOT NULL, teachers TEXT NOT NULL,
            faculty TEXT NOT NULL, semester TEXT NOT NULL,
            source_file TEXT, note TEXT
          )
        ''');
      },
    );
    await old.insert('course_sessions', {
      'id': 'legacy',
      'class_type': 'Lecture',
      'room': 'R1',
      'date': '2026-08-30',
      'weekday': 7,
      'course_name': 'Algorithms',
      'course_code': 'CS101',
      'section': 'A',
      'start_at': '2026-08-30T09:00:00.000',
      'end_at': '2026-08-30T10:00:00.000',
      'teachers': jsonEncode(['Teacher']),
      'faculty': 'FIE',
      'semester': '2608',
    });
    await old.close();

    final migrated = await AppDatabase.open(tempDir.path);
    addTearDown(migrated.close);

    final sessions = await migrated.getAllSessions();
    expect(sessions.single.id, 'legacy');
    expect(sessions.single.deletedAt, isNull);
    expect(sessions.single.recurrenceSeriesId, isNull);
    expect(sessions.single.recurrenceMeetingId, isNull);
    await migrated.acknowledgeReminder('r', 'legacy');
    expect((await migrated.reminderDeliveryStates()).single['acknowledged'], 1);
  });
  test('v4 upgrade and reopening v5 retain reminder state', () async {
    final dir = await Directory.systemTemp.createTemp('orbit_v4_migration_');
    final current = await AppDatabase.open(dir.path);
    await current.close();
    final old = await openDatabase(p.join(dir.path, 'orbit.db'));
    for (final table in [
      'reminder_series_membership',
      'reminder_session_alias',
      'reminder_delivery',
      'reminder_schedule',
    ]) {
      await old.execute('DROP TABLE $table');
    }
    await old.setVersion(4);
    await old.close();
    final upgraded = await AppDatabase.open(dir.path);
    await upgraded.acknowledgeReminder('r', 's');
    await upgraded.close();
    final reopened = await AppDatabase.open(dir.path);
    try {
      expect(
        (await reopened.reminderDeliveryStates()).single['acknowledged'],
        1,
      );
      expect(await reopened.reminderSeriesMemberships(), isEmpty);
    } finally {
      await reopened.close();
      await dir.delete(recursive: true);
    }
  });
}
