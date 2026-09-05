import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'plugin_manifest.dart';
import 'plugin_models.dart';

class PluginSignatureVerification {
  const PluginSignatureVerification({required this.status, this.fingerprint});

  final PluginSignatureStatus status;
  final String? fingerprint;
}

class PluginSigning {
  PluginSigning._();

  static final Ed25519 _algorithm = Ed25519();

  static Future<PluginSignatureVerification> verify(
    PluginManifest manifest,
    Map<String, Uint8List> files,
  ) async {
    final signature = manifest.signature;
    if (signature == null) {
      return const PluginSignatureVerification(
        status: PluginSignatureStatus.unsigned,
      );
    }
    try {
      final publicKeyBytes = base64Decode(signature.publicKey);
      final signatureBytes = base64Decode(signature.value);
      if (publicKeyBytes.length != 32 || signatureBytes.length != 64) {
        throw const FormatException('Некорректный размер ключа или подписи');
      }
      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );
      final valid = await _algorithm.verify(
        payload(manifest, files),
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
      if (!valid) {
        throw const FormatException('Подпись плагина недействительна');
      }
      return PluginSignatureVerification(
        status: PluginSignatureStatus.verified,
        fingerprint: fingerprint(publicKeyBytes),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Подпись плагина недействительна');
    }
  }

  static Uint8List payload(
    PluginManifest manifest,
    Map<String, Uint8List> files,
  ) {
    final modules = <String, String>{};
    final paths = files.keys.where((path) => path.endsWith('.js')).toList()
      ..sort();
    for (final path in paths) {
      modules[path] = sha256.convert(files[path]!).toString();
    }
    final canonical = _canonicalJson({
      'format': 'komet-plugin-signature-v1',
      'manifest': manifest.toUnsignedJson(),
      'modules': modules,
    });
    return Uint8List.fromList(utf8.encode(canonical));
  }

  static Future<PluginSignatureManifest> sign(
    PluginManifest manifest,
    Map<String, Uint8List> files,
    List<int> privateKeyBytes,
  ) async {
    if (privateKeyBytes.length != 32) {
      throw const FormatException(
        'Приватный Ed25519 ключ должен содержать 32 байта',
      );
    }
    final keyPair = await _algorithm.newKeyPairFromSeed(privateKeyBytes);
    final signed = await _algorithm.sign(
      payload(manifest, files),
      keyPair: keyPair,
    );
    final publicKey = await keyPair.extractPublicKey();
    return PluginSignatureManifest(
      algorithm: 'ed25519',
      publicKey: base64Encode(publicKey.bytes),
      value: base64Encode(signed.bytes),
    );
  }

  static Future<({List<int> privateKey, List<int> publicKey})>
  generateKeyPair() async {
    final keyPair = await _algorithm.newKeyPair();
    return (
      privateKey: await keyPair.extractPrivateKeyBytes(),
      publicKey: (await keyPair.extractPublicKey()).bytes,
    );
  }

  static String fingerprint(List<int> publicKey) {
    final digest = sha256.convert(publicKey).toString().toUpperCase();
    return List.generate(
      8,
      (index) => digest.substring(index * 4, index * 4 + 4),
    ).join(':');
  }

  static String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    return jsonEncode(value);
  }
}
