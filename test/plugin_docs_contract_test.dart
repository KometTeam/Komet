import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/plugins/plugin_manifest.dart';

void main() {
  test('plugin schemas are valid JSON objects', () {
    for (final path in [
      'plugin_sdk/manifest.schema.json',
      'plugin_sdk/update-manifest.schema.json',
    ]) {
      final decoded = jsonDecode(File(path).readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>(), reason: path);
    }
  });

  test('manifest schema lists every runtime permission', () {
    final schema =
        jsonDecode(File('plugin_sdk/manifest.schema.json').readAsStringSync())
            as Map<String, dynamic>;
    final definitions = schema[r'$defs'] as Map<String, dynamic>;
    final permission = definitions['permission'] as Map<String, dynamic>;
    final documented = (permission['enum'] as List).cast<String>().toSet();
    final runtime = PluginPermission.values.map((item) => item.id).toSet();

    expect(documented, runtime);
  });

  test('reference documents every public API method', () {
    final markdown = File('PLUGINS.md').readAsStringSync();
    final declarations = File('plugin_sdk/komet-api.d.ts').readAsStringSync();
    const methods = [
      'chat.sendText',
      'chat.editText',
      'chat.sendPhoto',
      'chat.sendFile',
      'network.fetch',
      'ui.notify',
      'contact.getPeer',
      'runtime.sleep',
      'runtime.isOnline',
      'runtime.isActive',
      'storage.get',
      'storage.set',
      'storage.remove',
    ];

    for (final method in methods) {
      expect(markdown, contains(method), reason: method);
      expect(declarations, contains(method.split('.').last), reason: method);
    }
  });

  test('bundled manifests are accepted by the documented schema contract', () {
    for (final entity in Directory('assets/plugins').listSync()) {
      if (entity is! Directory) continue;
      final file = File('${entity.path}/manifest.json');
      if (!file.existsSync()) continue;
      final manifest = PluginManifest.decode(file.readAsStringSync());
      expect(manifest.commands, isNotEmpty, reason: file.path);
    }
  });
}
