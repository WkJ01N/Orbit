import 'package:orbit/services/component_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orbit/models/typography_settings.dart';

typedef RegisterFont =
    Future<void> Function(String family, List<Uint8List> bytes);

class FontService {
  FontService({
    this.directory,
    ComponentService? components,
    RegisterFont? register,
  }) : components = components ?? ComponentService.shared,
       _register = register ?? _registerNative;
  static final shared = FontService();
  static const preferenceKey = 'typography_v1';
  static const maxFileBytes = 50 * 1024 * 1024;
  static const maxBackupBytes = 250 * 1024 * 1024;
  final Directory? directory;
  final ComponentService components;
  final RegisterFont _register;
  final _loaded = <String, Future<void>>{};
  Future<Directory> fontDirectory() async =>
      directory ??
      Directory(p.join((await getApplicationSupportDirectory()).path, 'fonts'));
  Future<File> file(ImportedFont font) async => File(
    p.join((await fontDirectory()).path, '${font.id}.${font.extension}'),
  );

  static Future<void> _registerNative(
    String family,
    List<Uint8List> bytes,
  ) async {
    final loader = FontLoader(family);
    for (final data in bytes) {
      loader.addFont(Future.value(ByteData.sublistView(data)));
    }
    await loader.load();
  }

  static void validate(Uint8List bytes) {
    if (bytes.length < 12 || bytes.length > maxFileBytes) {
      throw const FormatException('Font size');
    }
    final data = ByteData.sublistView(bytes);
    final signature = data.getUint32(0);
    if (signature != 0x00010000 && signature != 0x4f54544f) {
      throw const FormatException('Use a TTF or OTF font');
    }
    final count = data.getUint16(4);
    if (count == 0 || count > 256 || 12 + count * 16 > bytes.length) {
      throw const FormatException('Invalid font tables');
    }
    final tags = <String>{};
    for (var i = 0; i < count; i++) {
      final at = 12 + i * 16;
      final tag = String.fromCharCodes(bytes.sublist(at, at + 4));
      final offset = data.getUint32(at + 8), length = data.getUint32(at + 12);
      if (!tags.add(tag) ||
          offset < 12 + count * 16 ||
          offset + length > bytes.length) {
        throw const FormatException('Invalid font table bounds');
      }
    }
    if (!tags.containsAll({'cmap', 'head', 'hhea', 'maxp', 'name'}) ||
        !tags.any({'glyf', 'CFF ', 'CFF2'}.contains)) {
      throw const FormatException('Missing font tables');
    }
  }

  Future<TypographySettings> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      preferenceKey,
    );
    return raw == null
        ? const TypographySettings()
        : TypographySettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
  }

  Future<void> save(TypographySettings settings) async {
    // Also validate values created by UI code before making them persistent.
    TypographySettings.fromJson(settings.toJson());
    if (!await (await SharedPreferences.getInstance()).setString(
      preferenceKey,
      jsonEncode(settings.toJson()),
    )) {
      throw StateError('Could not save typography');
    }
  }

  Future<void> load(String id, Map<String, ImportedFont> imports) async {
    if (id == 'system') return;
    final existing = _loaded[id];
    if (existing != null) return existing;
    final future = () async {
      final List<Uint8List> bytes;
      final assets = FontCatalog.builtins[id];
      if (assets != null) {
        if (id == 'nunito') {
          bytes = [(await rootBundle.load(assets.single)).buffer.asUint8List()];
        } else {
          final folder = await components.installed(id);
          bytes = [
            for (final asset in assets)
              await File(p.join(folder.path, p.basename(asset))).readAsBytes(),
          ];
        }
      } else {
        final font = imports[id];
        if (font == null) throw const FormatException('Font unavailable');
        final source = await file(font);
        if (await source.length() > maxFileBytes) {
          throw const FormatException('Font size');
        }
        final data = await source.readAsBytes();
        validate(data);
        if (sha256.convert(data).toString() != id) {
          throw const FormatException('Font hash mismatch');
        }
        bytes = [data];
      }
      await _register(FontCatalog.family(id), bytes);
    }();
    _loaded[id] = future;
    try {
      await future;
    } catch (_) {
      _loaded.remove(id);
      rethrow;
    }
  }

  Future<TypographySettings> prepare(
    TypographySettings value, {
    bool recover = false,
  }) async {
    var settings = value.copyWith(unavailableFontIds: {}, loadWarning: false);
    final unavailable = <String>{};
    for (final launch in [false, true]) {
      final id = launch ? settings.launchFontId : settings.appFontId;
      try {
        await load(id, settings.imports);
      } on ComponentMissing {
        if (!recover) rethrow;
        unavailable.add(id);
        settings = settings.copyWith(loadWarning: true);
      } catch (_) {
        if (!recover) rethrow;
        unavailable.add(id);
        settings = settings.copyWith(loadWarning: true);
        if (launch) {
          try {
            await load('nunito', const {});
          } catch (_) {
            /* Native fallback remains usable. */
          }
        }
      }
    }
    for (final id in settings.fallbackFontIds) {
      try {
        await load(id, settings.imports);
      } catch (_) {
        unavailable.add(id);
        settings = settings.copyWith(loadWarning: true);
      }
    }
    return settings.copyWith(unavailableFontIds: unavailable);
  }

  Future<TypographySettings> initialize() async {
    try {
      return await prepare(await read(), recover: true);
    } catch (_) {
      return const TypographySettings(loadWarning: true);
    }
  }

  Future<({ImportedFont font, bool created})> importBytes(
    String name,
    Uint8List bytes,
  ) async {
    final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
    if (!['ttf', 'otf'].contains(ext)) {
      throw const FormatException('Use TTF or OTF');
    }
    validate(bytes);
    final id = sha256.convert(bytes).toString();
    final font = ImportedFont(
      id: id,
      name: p.basenameWithoutExtension(name).trim().isEmpty
          ? 'Imported font'
          : p
                .basenameWithoutExtension(name)
                .substring(
                  0,
                  p.basenameWithoutExtension(name).length.clamp(0, 120),
                ),
      extension: ext,
    );
    // The signature, rather than the supplied suffix, defines its storage type.
    final normalized = ImportedFont(
      id: id,
      name: font.name,
      extension: ByteData.sublistView(bytes).getUint32(0) == 0x4f54544f
          ? 'otf'
          : 'ttf',
    );
    final target = await file(normalized);
    final exists = await target.exists();
    if (exists && sha256.convert(await target.readAsBytes()).toString() != id) {
      throw const FormatException('Stored font is damaged');
    }
    await target.parent.create(recursive: true);
    if (!exists) await target.writeAsBytes(bytes, flush: true);
    try {
      await load(id, {id: normalized});
    } catch (_) {
      if (!exists) await target.delete();
      rethrow;
    }
    return (font: normalized, created: !exists);
  }

  Future<void> deleteFile(ImportedFont font) async {
    final target = await file(font);
    if (await target.exists()) await target.delete();
    // Flutter cannot unload an already registered face. IDs are content hashes,
    // so retaining it for this process cannot replace a different font.
  }

  Future<Map<String, dynamic>> exportFonts(
    TypographySettings value, {
    bool allLibrary = false,
  }) async {
    final output = <String, dynamic>{};
    var total = 0;
    for (final id
        in (allLibrary
            ? value.imports.keys
            : value.selected.where(value.imports.containsKey))) {
      final font = value.imports[id]!;
      final source = await file(font);
      if (await source.length() > maxFileBytes) {
        throw const FormatException('Font size');
      }
      final data = await source.readAsBytes();
      validate(data);
      if (sha256.convert(data).toString() != id) {
        throw const FormatException('Font hash mismatch');
      }
      total += data.length;
      if (total > maxBackupBytes) {
        throw const FormatException('Font backup size');
      }
      output[id] = {...font.toJson(), 'data': base64Encode(data)};
    }
    return output;
  }
}
