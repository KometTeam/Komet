import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/plugins/plugin_manifest.dart';
import 'package:komet/core/plugins/plugin_package.dart';

void main() {
  test('decodes a valid .kinet package', () {
    final package = PluginPackage.decode(
      _kinet(
        manifest: _manifest(),
        files: {'main.js': 'export async function hello() {}'},
      ),
    );

    expect(package.manifest.id, 'dev.example.synthetic');
    expect(package.manifest.commands.single.name, '/hello');
    expect(package.manifest.commands.single.arguments.single.name, 'text');
    expect(package.manifest.commands.single.arguments.single.rest, isTrue);
    expect(package.manifest.permissions, {PluginPermission.uiNotify});
    expect(package.files, contains('main.js'));
  });

  test('rejects unknown permissions', () {
    final manifest = _manifest()..['permissions'] = ['system.raw'];

    expect(
      () => PluginPackage.decode(
        _kinet(manifest: manifest, files: {'main.js': ''}),
      ),
      throwsFormatException,
    );
  });

  test('rejects a newer API version', () {
    final manifest = _manifest()..['apiVersion'] = kPluginApiVersion + 1;

    expect(
      () => PluginPackage.decode(
        _kinet(manifest: manifest, files: {'main.js': ''}),
      ),
      throwsFormatException,
    );
  });

  test('rejects archive path traversal', () {
    expect(
      () => PluginPackage.decode(
        _kinet(
          manifest: _manifest(),
          files: {'main.js': '', '../escape.js': ''},
        ),
      ),
      throwsFormatException,
    );
  });

  test('rejects unsupported package files', () {
    expect(
      () => PluginPackage.decode(
        _kinet(
          manifest: _manifest(),
          files: {'main.js': '', 'payload.bin': 'synthetic'},
        ),
      ),
      throwsFormatException,
    );
  });

  test('rejects a missing entry module', () {
    expect(
      () => PluginPackage.decode(
        _kinet(manifest: _manifest(), files: {'other.js': ''}),
      ),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _manifest() => {
  'schemaVersion': 1,
  'id': 'dev.example.synthetic',
  'name': 'Synthetic Plugin',
  'version': '1.2.3',
  'apiVersion': 1,
  'description': 'Synthetic fixture',
  'author': 'Test Author',
  'main': 'main.js',
  'permissions': ['ui.notify'],
  'commands': [
    {
      'name': '/hello',
      'description': 'Synthetic command',
      'handler': 'hello',
      'arguments': [
        {'name': 'text', 'description': 'Synthetic text', 'rest': true},
      ],
    },
  ],
};

List<int> _kinet({
  required Map<String, dynamic> manifest,
  required Map<String, String> files,
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}
