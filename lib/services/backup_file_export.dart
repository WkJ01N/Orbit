import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

Future<bool> exportBackupPackage(File source) =>
    exportPersistentFile(source, name: 'orbit-backup.orbit');

Future<bool> exportPersistentFile(File source, {String? name}) async {
  final filename = name ?? p.basename(source.path);
  if (Platform.isAndroid) {
    return await const MethodChannel(
          'com.must.orbit.orbit/files',
        ).invokeMethod<bool>('exportFile', {
          'path': source.path,
          'name': filename,
        }) ??
        false;
  }
  final destination = await FilePicker.platform.saveFile(
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: [p.extension(filename).replaceFirst('.', '')],
  );
  if (destination == null) return false;
  final support = p.normalize(
    p.absolute((await getApplicationSupportDirectory()).path),
  );
  final target = p.normalize(p.absolute(destination));
  if (p.equals(support, target) || p.isWithin(support, target)) {
    throw const FileSystemException('Choose a folder outside Orbit app data');
  }
  await source.openRead().pipe(File(target).openWrite());
  if (await source.length() != await File(target).length() ||
      (await sha256.bind(source.openRead()).first).toString() !=
          (await sha256.bind(File(target).openRead()).first).toString()) {
    throw const FileSystemException('Export verification failed');
  }
  return true;
}
