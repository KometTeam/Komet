import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:komet/core/plugins/plugin_manifest.dart';
import 'package:komet/core/plugins/plugin_package.dart';
import 'package:komet/core/plugins/plugin_signing.dart';

Future<void> main(List<String> args) async {
  try {
    if (args.isEmpty) return _usage();
    switch (args.first) {
      case 'generate-key':
        if (args.length != 2) return _usage();
        await _generateKey(args[1]);
      case 'sign':
        if (args.length < 3 || args.length > 4) return _usage();
        await _sign(args[1], args[2], args.length == 4 ? args[3] : args[1]);
      case 'verify':
        if (args.length != 2) return _usage();
        await _verify(args[1]);
      default:
        _usage();
    }
  } catch (error) {
    stderr.writeln('Ошибка: $error');
    exitCode = 1;
  }
}

Future<void> _generateKey(String outputPath) async {
  final output = File(outputPath);
  if (await output.exists()) {
    throw const FileSystemException('Файл ключа уже существует');
  }
  final keyPair = await PluginSigning.generateKeyPair();
  final key = {
    'algorithm': 'ed25519',
    'privateKey': base64Encode(keyPair.privateKey),
    'publicKey': base64Encode(keyPair.publicKey),
    'fingerprint': PluginSigning.fingerprint(keyPair.publicKey),
  };
  await output.parent.create(recursive: true);
  await output.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(key)}\n',
  );
  if (!Platform.isWindows) {
    final result = await Process.run('chmod', ['600', output.path]);
    if (result.exitCode != 0) {
      await output.delete();
      throw const FileSystemException('Не удалось установить права 0600');
    }
  }
  stdout.writeln('Ключ создан: ${output.path}');
  stdout.writeln('Fingerprint: ${key['fingerprint']}');
}

Future<void> _sign(
  String packagePath,
  String keyPath,
  String outputPath,
) async {
  final bytes = await File(packagePath).readAsBytes();
  final package = PluginPackage.decode(bytes);
  final key = jsonDecode(await File(keyPath).readAsString());
  if (key is! Map || key['algorithm'] != 'ed25519') {
    throw const FormatException('Некорректный файл ключа');
  }
  final privateKey = base64Decode(key['privateKey']?.toString() ?? '');
  final signature = await PluginSigning.sign(
    package.manifest,
    package.files,
    privateKey,
  );
  final manifest = package.manifest.toUnsignedJson();
  manifest['signature'] = signature.toJson();
  final archive = Archive();
  final paths = package.files.keys.toList()..sort();
  for (final path in paths) {
    final content = path == 'manifest.json'
        ? utf8.encode(jsonEncode(manifest))
        : package.files[path]!;
    archive.addFile(ArchiveFile.bytes(path, content));
  }
  final encoded = ZipEncoder().encodeBytes(archive);
  final output = File(outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsBytes(encoded, flush: true);
  final verification = await PluginSigning.verify(
    PluginManifest.fromJson(manifest),
    PluginPackage.decode(encoded).files,
  );
  stdout.writeln('Плагин подписан: ${output.path}');
  stdout.writeln('Fingerprint: ${verification.fingerprint}');
}

Future<void> _verify(String packagePath) async {
  final package = PluginPackage.decode(await File(packagePath).readAsBytes());
  final verification = await PluginSigning.verify(
    package.manifest,
    package.files,
  );
  if (verification.fingerprint == null) {
    throw const FormatException('Плагин не подписан');
  }
  stdout.writeln('Подпись действительна');
  stdout.writeln('Fingerprint: ${verification.fingerprint}');
}

void _usage() {
  stdout.writeln('dart run tool/kinet_sign.dart generate-key <key.json>');
  stdout.writeln(
    'dart run tool/kinet_sign.dart sign <plugin.kinet> <key.json> [output.kinet]',
  );
  stdout.writeln('dart run tool/kinet_sign.dart verify <plugin.kinet>');
}
