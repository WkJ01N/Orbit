import 'dart:convert';
import 'dart:io';
import 'package:orbit/services/component_service.dart';

Future<ComponentService> installedFontComponents(
  Directory root, {
  Iterable<String> ids = const ['rounded', 'huninn', 'maiyuan'],
}) async {
  final json =
      jsonDecode(await File('assets/components/catalog.json').readAsString())
          as Map;
  final descriptors = [
    for (final item in json['components'] as List)
      if (item['platform'] == 'any')
        ComponentDescriptor.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
  final components = ComponentService(directory: root, catalog: descriptors);
  await components.initialize();
  for (final item in descriptors.where((e) => ids.contains(e.id))) {
    await components.restoreFontComponent(item.id, {
      for (final file in item.files.keys)
        file: base64Encode(
          file.endsWith('.txt')
              ? utf8.encode(
                  (await File(
                    'resources/fonts/$file',
                  ).readAsString()).replaceAll('\r\n', '\n'),
                )
              : await File('resources/fonts/$file').readAsBytes(),
        ),
    });
  }
  return components;
}
