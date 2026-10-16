import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

Future<bool> exportBackupPackage(File source) async {
  if (Platform.isAndroid) {
    return await const MethodChannel(
          'com.must.orbit.orbit/files',
        ).invokeMethod<bool>('exportFile', {
          'path': source.path,
          'name': 'orbit-backup.orbit',
        }) ??
        false;
  }
  final destination = await FilePicker.platform.saveFile(
    fileName: 'orbit-backup.orbit',
    type: FileType.custom,
    allowedExtensions: ['orbit'],
  );
  if (destination == null) return false;
  await source.openRead().pipe(File(destination).openWrite());
  return true;
}
