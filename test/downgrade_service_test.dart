import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/downgrade_service.dart';
import 'package:orbit/services/schedule_backup_service.dart';
import 'package:orbit/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures/legacy/backup_v9.dart' as legacy9;
import 'fixtures/legacy/backup_v10.dart' as legacy10;
import 'fixtures/legacy/backup_v11.dart' as legacy11;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'converted payloads are accepted by the actual v9, v10 and v11 readers',
    () async {
      final portable = await SettingsService().exportPortableSettings();
      final raw =
          jsonDecode(
                ScheduleBackupService().encodeToJson([], settings: portable),
              )
              as Map<String, dynamic>;
      raw['localPresentation'] = {'cardEntrance': 'nearby'};
      final original = jsonEncode(raw);
      final nine = DowngradeService.convert(original, '1.5.5')!;
      final ten = DowngradeService.convert(original, '1.5.7')!;
      final eleven = DowngradeService.convert(original, '1.6.0')!;
      expect(
        legacy9.ScheduleBackupService().decodeBackup(nine.json).version,
        9,
      );
      expect(
        legacy10.ScheduleBackupService().decodeBackup(ten.json).version,
        10,
      );
      expect(
        legacy11.ScheduleBackupService().decodeBackup(eleven.json).version,
        11,
      );
      expect(nine.losses, contains('typography'));
      expect(eleven.losses, contains('launch'));
      expect(
        (jsonDecode(nine.json)['settings'] as Map).containsKey('typography'),
        isFalse,
      );
      expect(raw['version'], 12);
      expect(raw.containsKey('localPresentation'), isTrue);
    },
  );
  test('unknown versions have no automatic conversion contract', () {
    for (final version in ['1.0.0', '1.5.4', '1.7.0', 'garbage']) {
      expect(DowngradeService.backupVersionFor(version), isNull);
      expect(DowngradeService.convert('{}', version), isNull);
    }
  });
}
