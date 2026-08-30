import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/app_info.dart';
import 'package:path/path.dart' as p;

void main() {
  test('kAppVersion matches pubspec.yaml major.minor.patch', () {
    final pubspecPath = p.join(Directory.current.path, 'pubspec.yaml');
    final pubspec = File(pubspecPath).readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml version line not found');
    expect(kAppVersion, match!.group(1));
  });
}
