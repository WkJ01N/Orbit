import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:orbit/models/custom_reminder_rule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ReminderAudioService {
  @visibleForTesting
  static Future<Directory> Function() supportDirectory =
      getApplicationSupportDirectory;
  static const maxFileBytes = 5 * 1024 * 1024;
  static const maxBackupBytes = 50 * 1024 * 1024;
  static void validate(String extension, Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw const FormatException('audio_size');
    }
    final wav =
        bytes.length >= 44 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WAVE' &&
        _validWav(bytes);
    final mp3 = bytes.length >= 4 && _hasMp3Frame(bytes);
    final m4a =
        bytes.length >= 16 &&
        String.fromCharCodes(bytes.skip(4).take(4)) == 'ftyp' &&
        _validM4a(bytes);
    if (!switch (extension.toLowerCase()) {
      '.mp3' => mp3,
      '.wav' => wav,
      '.m4a' => m4a,
      _ => false,
    }) {
      throw const FormatException('audio_type');
    }
  }

  static bool _validWav(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(4, Endian.little) + 8 > bytes.length) return false;
    var offset = 12, format = false, audio = false;
    while (offset + 8 <= bytes.length) {
      final size = data.getUint32(offset + 4, Endian.little);
      if (offset + 8 + size > bytes.length) return false;
      final name = String.fromCharCodes(bytes.skip(offset).take(4));
      if (name == 'fmt ') {
        if (size < 16) return false;
        final encoding = data.getUint16(offset + 8, Endian.little);
        final channels = data.getUint16(offset + 10, Endian.little);
        final sampleRate = data.getUint32(offset + 12, Endian.little);
        final byteRate = data.getUint32(offset + 16, Endian.little);
        final alignment = data.getUint16(offset + 20, Endian.little);
        if (![1, 3, 6, 7, 65534].contains(encoding) ||
            channels < 1 ||
            channels > 32 ||
            sampleRate == 0 ||
            sampleRate > 768000 ||
            byteRate == 0 ||
            alignment == 0) {
          return false;
        }
        format = true;
      }
      if (name == 'data' && size > 0) audio = true;
      offset += 8 + size + (size % 2);
    }
    return format && audio;
  }

  static bool _validM4a(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 0, metadata = false, audio = false;
    while (offset + 8 <= bytes.length) {
      var size = data.getUint32(offset, Endian.big);
      final name = String.fromCharCodes(bytes.skip(offset + 4).take(4));
      if (size == 0) size = bytes.length - offset;
      if (size == 1) {
        if (offset + 16 > bytes.length) return false;
        size = data.getUint64(offset + 8, Endian.big);
      }
      if (size < 8 || offset + size > bytes.length) return false;
      if (name == 'moov') metadata = true;
      if (name == 'mdat' && size > 8) audio = true;
      offset += size;
    }
    return metadata && audio;
  }

  static bool _hasMp3Frame(Uint8List bytes) {
    var start = 0;
    if (String.fromCharCodes(bytes.take(3)) == 'ID3') {
      if (bytes.length < 10) return false;
      if (bytes.skip(6).take(4).any((v) => v >= 128)) return false;
      start =
          10 + (bytes[6] << 21) + (bytes[7] << 14) + (bytes[8] << 7) + bytes[9];
    }
    for (var i = start; i + 4 < bytes.length && i < start + 4096; i++) {
      if (bytes[i] == 255 &&
          (bytes[i + 1] & 224) == 224 &&
          (bytes[i + 1] & 24) != 8 &&
          (bytes[i + 1] & 6) != 0 &&
          (bytes[i + 2] >> 4) > 0 &&
          (bytes[i + 2] >> 4) < 15 &&
          (bytes[i + 2] & 12) != 12) {
        return true;
      }
    }
    return false;
  }

  static Future<ReminderSound> importFile(File file) async {
    if (await file.length() > maxFileBytes) {
      throw const FormatException('audio_size');
    }
    return importBytes(p.basename(file.path), await file.readAsBytes());
  }

  static Future<ReminderSound> importBytes(String name, Uint8List bytes) async {
    final ext = p.extension(name).toLowerCase();
    validate(ext, bytes);
    final root = await supportDirectory();
    final directory = await Directory(
      p.join(root.path, 'reminder_audio'),
    ).create(recursive: true);
    final target = File(p.join(directory.path, '${newReminderId()}$ext'));
    await target.writeAsBytes(bytes, flush: true);
    if (Platform.isAndroid) {
      try {
        await const MethodChannel(
          'com.must.orbit.orbit/reminders',
        ).invokeMethod<void>('validateAudio', {'path': target.path});
      } catch (_) {
        await target.delete();
        rethrow;
      }
    }
    return ReminderSound(
      kind: 'file',
      value: target.path,
      name: p.basename(name),
    );
  }
}
