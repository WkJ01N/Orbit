import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final file = File(
      Platform.environment['ORBIT_BACKGROUND_REPORT'] ??
          'build/background-transition-profile.json',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  },
  writeResponseOnFailure: true,
);
