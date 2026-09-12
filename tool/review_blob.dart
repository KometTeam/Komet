import 'dart:convert';
import 'dart:io';

import 'package:komet_crypto/komet_crypto.dart';

String _libraryName() {
  if (Platform.isMacOS) return 'libkomet_crypto.dylib';
  if (Platform.isWindows) return 'komet_crypto.dll';
  return 'libkomet_crypto.so';
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: dart run tool/review_blob.dart <phone> <code>');
    stderr.writeln('reads the JSON payload from stdin');
    exitCode = 2;
    return;
  }

  final library = 'native/crypto-core/build/${_libraryName()}';
  if (!File(library).existsSync()) {
    stderr.writeln('run `make shared` in native/crypto-core first');
    exitCode = 1;
    return;
  }
  KometCrypto.libraryPath = library;

  final digits = args[0].replaceAll(RegExp(r'\D'), '');
  final plaintext = utf8.decode(_readAll());
  if (jsonDecode(plaintext) is! Map<String, dynamic>) {
    stderr.writeln('payload must be a JSON object');
    exitCode = 2;
    return;
  }

  final key = KometCrypto.deriveKey('$digits:${args[1]}');
  try {
    stdout.write(KometCrypto.encryptMessage(plaintext, key).replaceAll(' ', ''));
  } finally {
    KometCrypto.wipe(key);
  }
}

List<int> _readAll() {
  final bytes = <int>[];
  while (true) {
    final byte = stdin.readByteSync();
    if (byte == -1) return bytes;
    bytes.add(byte);
  }
}
