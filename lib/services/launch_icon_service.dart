import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:orbit/services/avatar_image_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persist a new, immutable file so a failed preferences write leaves the old
/// image intact and Flutter's image cache cannot retain a replaced image.
Future<String> saveLaunchIcon(
  Uint8List bytes, {
  Directory? supportDirectory,
}) async {
  final normalized = await compute(processAvatarImage, bytes);
  final root = supportDirectory ?? await getApplicationSupportDirectory();
  final directory = Directory(p.join(root.path, 'launch_icons'));
  await directory.create(recursive: true);
  final target = File(
    p.join(directory.path, '${DateTime.now().microsecondsSinceEpoch}.png'),
  );
  await target.writeAsBytes(normalized, flush: true);
  return target.path;
}

Future<void> deleteLaunchIcon(
  String? path, {
  Directory? supportDirectory,
}) async {
  if (path == null) return;
  final root = supportDirectory ?? await getApplicationSupportDirectory();
  final directory = p.normalize(p.absolute(p.join(root.path, 'launch_icons')));
  final target = p.normalize(p.absolute(path));
  if (!p.isWithin(directory, target)) return;
  try {
    final file = File(target);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // An old image can be cleaned up later; saving a preference already worked.
  }
}
