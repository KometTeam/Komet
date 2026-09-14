import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:path/path.dart' as path;

import 'options.dart';

/// The manifest authenticates release bytes. Apple code signing remains a
/// separate platform concern and is intentionally outside this boundary.
const precompiledGenerationManifestFileName = 'completion.json';
const precompiledGenerationManifestSignatureFileName = 'completion.json.sig';

const _manifestSchemaVersion = 2;
const _manifestScope = 'cargokit-precompiled-generation';
const precompiledAssetSignatureScheme = 'ed25519-cargokit-v2';
const _assetSignatureDomain = 'cargokit-precompiled-asset-signature';
final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final _commitPattern = RegExp(r'^[0-9a-f]{40}(?:[0-9a-f]{24})?$');
final _assetNamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

class PrecompiledGenerationException implements Exception {
  PrecompiledGenerationException(this.message);

  final String message;

  @override
  String toString() => 'PrecompiledGenerationException: $message';
}

class PrecompiledAsset {
  const PrecompiledAsset({
    required this.name,
    required this.length,
    required this.sha256,
  });

  final String name;
  final int length;
  final String sha256;
}

class PrecompiledCompositeChecksum {
  const PrecompiledCompositeChecksum({
    required this.archive,
    required this.checksum,
    this.algorithm = 'sha256',
  });

  final String archive;
  final String checksum;
  final String algorithm;
}

class PrecompiledBuildIdentity {
  PrecompiledBuildIdentity({
    required this.rustToolchain,
    required this.flutterVersion,
    required this.xcodeVersion,
    required Map<String, String> sdkVersions,
    required Map<String, String> deploymentTargets,
    required Iterable<String> rustTargets,
  })  : sdkVersions = Map.unmodifiable(Map.from(sdkVersions)),
        deploymentTargets = Map.unmodifiable(Map.from(deploymentTargets)),
        rustTargets = List.unmodifiable(rustTargets);

  factory PrecompiledBuildIdentity.fromRecipe(PrecompiledBuildRecipe recipe) {
    return PrecompiledBuildIdentity(
      rustToolchain: recipe.rustToolchain,
      flutterVersion: recipe.flutterVersion,
      xcodeVersion: recipe.xcodeVersion,
      sdkVersions: recipe.sdkVersions,
      deploymentTargets: recipe.deploymentTargets,
      rustTargets: recipe.rustTargets,
    );
  }

  final String rustToolchain;
  final String flutterVersion;
  final String xcodeVersion;
  final Map<String, String> sdkVersions;
  final Map<String, String> deploymentTargets;
  final List<String> rustTargets;

  Map<String, dynamic> _json() => {
        'deployment_targets': _sortedStringMap(deploymentTargets),
        'flutter_version': flutterVersion,
        'rust_targets': [...rustTargets]..sort(),
        'rust_toolchain': rustToolchain,
        'sdk_versions': _sortedStringMap(sdkVersions),
        'xcode_version': xcodeVersion,
      };

  bool matches(PrecompiledBuildIdentity other) =>
      _canonicalJson(_json()) == _canonicalJson(other._json());
}

class PrecompiledGenerationProvenance {
  PrecompiledGenerationProvenance({
    required this.pinned,
    required this.actual,
  });

  factory PrecompiledGenerationProvenance.fromRecipe(
      PrecompiledBuildRecipe recipe) {
    final identity = PrecompiledBuildIdentity.fromRecipe(recipe);
    return PrecompiledGenerationProvenance(pinned: identity, actual: identity);
  }

  final PrecompiledBuildIdentity pinned;
  final PrecompiledBuildIdentity actual;

  Map<String, dynamic> _json() => {
        'actual': actual._json(),
        'pinned': pinned._json(),
      };
}

class PrecompiledGenerationManifest {
  PrecompiledGenerationManifest({
    required this.generationHash,
    required this.sourceCommit,
    required this.provenance,
    required Iterable<PrecompiledAsset> assets,
    required Iterable<PrecompiledCompositeChecksum> compositeChecksums,
  })  : assets = List.unmodifiable(assets),
        compositeChecksums = List.unmodifiable(compositeChecksums) {
    _validateCompositeMetadata(this.assets, this.compositeChecksums);
  }

  final String generationHash;
  final String sourceCommit;
  final PrecompiledGenerationProvenance provenance;
  final List<PrecompiledAsset> assets;
  final List<PrecompiledCompositeChecksum> compositeChecksums;

  PrecompiledAsset? asset(String name) {
    for (final item in assets) {
      if (item.name == name) return item;
    }
    return null;
  }

  List<int> canonicalBytes() => utf8.encode(_canonicalJson(_json()));

  Map<String, dynamic> _json() => {
        'asset_signature_scheme': precompiledAssetSignatureScheme,
        'assets': [
          ...assets.map((asset) => {
                'length': asset.length,
                'name': asset.name,
                'sha256': asset.sha256,
              })
        ]..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String)),
        'composite_checksums': [
          ...compositeChecksums.map((binding) => {
                'algorithm': binding.algorithm,
                'archive': binding.archive,
                'checksum': binding.checksum,
              })
        ]..sort((a, b) {
            final archive =
                (a['archive'] as String).compareTo(b['archive'] as String);
            return archive != 0
                ? archive
                : (a['checksum'] as String).compareTo(b['checksum'] as String);
          }),
        'generation_hash': generationHash,
        'provenance': provenance._json(),
        'schema_version': _manifestSchemaVersion,
        'scope': _manifestScope,
        'source_commit': sourceCommit,
      };

  Uint8List sign(PrivateKey privateKey) =>
      ed25519Sign(privateKey, Uint8List.fromList(canonicalBytes()));

  void verifySignature(PublicKey publicKey, List<int> signature) {
    _verifySignature(publicKey, canonicalBytes(), signature, 'manifest');
  }

  void validateFor({
    required String generationHash,
    required PrecompiledBuildRecipe recipe,
    required Set<String> expectedAssetNames,
  }) {
    if (this.generationHash != generationHash) {
      throw PrecompiledGenerationException(
          'Manifest generation hash does not match the current generation.');
    }
    final expected = PrecompiledBuildIdentity.fromRecipe(recipe);
    if (!provenance.pinned.matches(expected) ||
        !provenance.actual.matches(provenance.pinned)) {
      throw PrecompiledGenerationException(
          'Manifest provenance does not match the build recipe.');
    }
    final actualNames = assets.map((asset) => asset.name).toSet();
    if (actualNames.length != assets.length ||
        actualNames.length != expectedAssetNames.length ||
        !actualNames.containsAll(expectedAssetNames) ||
        !expectedAssetNames.containsAll(actualNames)) {
      throw PrecompiledGenerationException(
          'Manifest asset inventory is incomplete or unexpected.');
    }
  }

  void verifyAsset({
    required String name,
    required List<int> bytes,
    required List<int> signature,
    required PublicKey publicKey,
  }) {
    final expected = asset(name);
    if (expected == null) {
      throw PrecompiledGenerationException(
          'Asset "$name" is not in the manifest inventory.');
    }
    if (bytes.length != expected.length ||
        sha256.convert(bytes).toString() != expected.sha256) {
      throw PrecompiledGenerationException(
          'Asset "$name" does not match its manifest digest or length.');
    }
    verifyAssetMetadataSignature(
      name: name,
      signature: signature,
      publicKey: publicKey,
    );
  }

  void verifyAssetMetadataSignature({
    required String name,
    required List<int> signature,
    required PublicKey publicKey,
  }) {
    final expected = asset(name);
    if (expected == null) {
      throw PrecompiledGenerationException(
          'Asset "$name" is not in the manifest inventory.');
    }
    verifyPrecompiledAssetMetadataSignature(
      publicKey,
      generationHash: generationHash,
      name: expected.name,
      length: expected.length,
      sha256: expected.sha256,
      signature: signature,
    );
  }

  void validateCompositeChecksums(Map<String, List<int>> bytesByName) {
    for (final binding in compositeChecksums) {
      if (binding.algorithm != 'sha256') {
        throw PrecompiledGenerationException('Unsupported checksum algorithm.');
      }
      final archive = bytesByName[binding.archive];
      final checksum = bytesByName[binding.checksum];
      if (archive == null || checksum == null) {
        throw PrecompiledGenerationException(
            'Composite checksum assets are incomplete.');
      }
      final expected = ascii.encode('${sha256.convert(archive)}\n');
      if (checksum.length != expected.length ||
          !List<int>.generate(
            expected.length,
            (index) => checksum[index] ^ expected[index],
          ).every((difference) => difference == 0)) {
        throw PrecompiledGenerationException(
            'Composite checksum does not match its archive.');
      }
    }
  }

  static PrecompiledGenerationManifest parse(List<int> bytes) {
    final text = _decodeUtf8(bytes);
    final value = _StrictJsonParser(text).parse();
    final map = _object(value, 'manifest');
    _requireFields(
      map,
      const {
        'schema_version',
        'scope',
        'asset_signature_scheme',
        'generation_hash',
        'source_commit',
        'provenance',
        'assets',
        'composite_checksums',
      },
      'manifest',
    );
    if (map['schema_version'] != _manifestSchemaVersion) {
      throw PrecompiledGenerationException(
          'Unsupported manifest schema version.');
    }
    if (map['scope'] != _manifestScope) {
      throw PrecompiledGenerationException('Unsupported manifest scope.');
    }
    if (map['asset_signature_scheme'] != precompiledAssetSignatureScheme) {
      throw PrecompiledGenerationException(
          'Unsupported asset signature scheme.');
    }
    final generationHash = _string(map['generation_hash'], 'generation hash');
    if (!_sha256Pattern.hasMatch(generationHash)) {
      throw PrecompiledGenerationException('Malformed generation hash.');
    }
    final sourceCommit = _string(map['source_commit'], 'source commit');
    if (!_commitPattern.hasMatch(sourceCommit)) {
      throw PrecompiledGenerationException('Malformed source commit.');
    }

    final provenanceMap = _object(map['provenance'], 'provenance');
    _requireFields(provenanceMap, const {'pinned', 'actual'}, 'provenance');
    final provenance = PrecompiledGenerationProvenance(
      pinned: _identity(provenanceMap['pinned'], 'pinned provenance'),
      actual: _identity(provenanceMap['actual'], 'actual provenance'),
    );

    final assetsValue = map['assets'];
    if (assetsValue is! List || assetsValue.isEmpty) {
      throw PrecompiledGenerationException(
          'Manifest assets must be a non-empty list.');
    }
    final assets = <PrecompiledAsset>[];
    String? previousName;
    final seenAssets = <String>{};
    for (final value in assetsValue) {
      final assetMap = _object(value, 'asset');
      _requireFields(assetMap, const {'name', 'length', 'sha256'}, 'asset');
      final name =
          _safeName(_string(assetMap['name'], 'asset name'), 'asset name');
      if (!seenAssets.add(name)) {
        throw PrecompiledGenerationException('Duplicate asset "$name".');
      }
      if (previousName != null && name.compareTo(previousName) <= 0) {
        throw PrecompiledGenerationException(
            'Manifest assets must be sorted by name.');
      }
      previousName = name;
      final length = _nonNegativeInt(assetMap['length'], 'asset length');
      final hash = _string(assetMap['sha256'], 'asset hash');
      if (!_sha256Pattern.hasMatch(hash)) {
        throw PrecompiledGenerationException('Malformed asset hash.');
      }
      assets.add(PrecompiledAsset(name: name, length: length, sha256: hash));
    }

    final compositesValue = map['composite_checksums'];
    if (compositesValue is! List) {
      throw PrecompiledGenerationException(
          'Composite checksum relationships must be a list.');
    }
    final composites = <PrecompiledCompositeChecksum>[];
    final seenComposites = <String>{};
    String? previousComposite;
    for (final value in compositesValue) {
      final bindingMap = _object(value, 'composite checksum');
      _requireFields(bindingMap, const {'algorithm', 'archive', 'checksum'},
          'composite checksum');
      final algorithm = _string(bindingMap['algorithm'], 'checksum algorithm');
      final archive = _safeName(
          _string(bindingMap['archive'], 'archive asset'), 'archive asset');
      final checksum = _safeName(
          _string(bindingMap['checksum'], 'checksum asset'), 'checksum asset');
      if (algorithm != 'sha256') {
        throw PrecompiledGenerationException('Unsupported checksum algorithm.');
      }
      final identity = '$archive\u0000$checksum';
      if (!seenComposites.add(identity)) {
        throw PrecompiledGenerationException(
            'Duplicate composite checksum relationship.');
      }
      if (previousComposite != null &&
          identity.compareTo(previousComposite) <= 0) {
        throw PrecompiledGenerationException(
            'Composite checksum relationships must be sorted.');
      }
      previousComposite = identity;
      if (!seenAssets.contains(archive) || !seenAssets.contains(checksum)) {
        throw PrecompiledGenerationException(
            'Composite checksum references an unknown asset.');
      }
      composites.add(PrecompiledCompositeChecksum(
        archive: archive,
        checksum: checksum,
        algorithm: algorithm,
      ));
    }
    return PrecompiledGenerationManifest(
      generationHash: generationHash,
      sourceCommit: sourceCommit,
      provenance: provenance,
      assets: assets,
      compositeChecksums: composites,
    );
  }
}

Uint8List signPrecompiledAsset(PrivateKey privateKey, List<int> bytes) =>
    ed25519Sign(privateKey, Uint8List.fromList(bytes));

Uint8List precompiledAssetSignaturePayload({
  required String generationHash,
  required String name,
  required Object length,
  required String sha256,
}) {
  if (!_sha256Pattern.hasMatch(generationHash) ||
      !_sha256Pattern.hasMatch(sha256)) {
    throw PrecompiledGenerationException(
        'Asset signature metadata contains a malformed digest.');
  }
  _safeName(name, 'asset name');
  final lengthValue = switch (length) {
    int value => BigInt.from(value),
    BigInt value => value,
    _ => throw PrecompiledGenerationException(
        'Asset signature metadata length is not an integer.'),
  };
  if (lengthValue < BigInt.zero ||
      lengthValue > (BigInt.one << 64) - BigInt.one) {
    throw PrecompiledGenerationException(
        'Asset signature metadata length is outside u64.');
  }
  final nameBytes = utf8.encode(name);
  if (nameBytes.length > 0xffffffff) {
    throw PrecompiledGenerationException('Asset name is too long.');
  }
  final nameLength = ByteData(4)..setUint32(0, nameBytes.length, Endian.big);
  final wordMask = BigInt.from(0xffffffff);
  final assetLength = ByteData(8)
    ..setUint32(0, (lengthValue >> 32).toInt(), Endian.big)
    ..setUint32(4, (lengthValue & wordMask).toInt(), Endian.big);
  return Uint8List.fromList([
    ...ascii.encode(_assetSignatureDomain),
    0,
    2,
    ..._decodeSha256(generationHash),
    ...nameLength.buffer.asUint8List(),
    ...nameBytes,
    ...assetLength.buffer.asUint8List(),
    ..._decodeSha256(sha256),
  ]);
}

Uint8List signPrecompiledAssetMetadata(
  PrivateKey privateKey, {
  required String generationHash,
  required String name,
  required int length,
  required String sha256,
}) =>
    ed25519Sign(
      privateKey,
      precompiledAssetSignaturePayload(
        generationHash: generationHash,
        name: name,
        length: length,
        sha256: sha256,
      ),
    );

void verifyPrecompiledAssetMetadataSignature(
  PublicKey publicKey, {
  required String generationHash,
  required String name,
  required int length,
  required String sha256,
  required List<int> signature,
}) {
  _verifySignature(
    publicKey,
    precompiledAssetSignaturePayload(
      generationHash: generationHash,
      name: name,
      length: length,
      sha256: sha256,
    ),
    signature,
    'asset "$name" metadata',
  );
}

Uint8List ed25519Sign(PrivateKey privateKey, Uint8List bytes) =>
    sign(privateKey, bytes);

void _verifySignature(
    PublicKey publicKey, List<int> bytes, List<int> signature, String subject) {
  if (signature.length != 64 ||
      !verify(publicKey, Uint8List.fromList(bytes),
          Uint8List.fromList(signature))) {
    throw PrecompiledGenerationException(
        'Invalid Ed25519 signature for $subject.');
  }
}

Uint8List _decodeSha256(String value) => Uint8List.fromList([
      for (var index = 0; index < value.length; index += 2)
        int.parse(value.substring(index, index + 2), radix: 16),
    ]);

void _validateCompositeMetadata(
  List<PrecompiledAsset> assets,
  List<PrecompiledCompositeChecksum> composites,
) {
  final byName = {for (final asset in assets) asset.name: asset};
  final boundAssets = <String>{};
  for (final binding in composites) {
    if (binding.algorithm != 'sha256') {
      throw PrecompiledGenerationException('Unsupported checksum algorithm.');
    }
    if (binding.archive == binding.checksum) {
      throw PrecompiledGenerationException(
          'Composite archive and checksum must be distinct assets.');
    }
    if (!boundAssets.add(binding.archive) ||
        !boundAssets.add(binding.checksum)) {
      throw PrecompiledGenerationException(
          'An asset may appear in at most one composite binding.');
    }
    final archive = byName[binding.archive];
    final checksum = byName[binding.checksum];
    if (archive == null || checksum == null) {
      throw PrecompiledGenerationException(
          'Composite checksum references an unknown asset.');
    }
    final expectedBytes = ascii.encode('${archive.sha256}\n');
    if (checksum.length != 65 ||
        checksum.sha256 != sha256.convert(expectedBytes).toString()) {
      throw PrecompiledGenerationException(
          'Composite checksum metadata is inconsistent with its archive.');
    }
  }
}

PrecompiledBuildIdentity _identity(Object? value, String context) {
  final map = _object(value, context);
  _requireFields(
      map,
      const {
        'rust_toolchain',
        'flutter_version',
        'xcode_version',
        'sdk_versions',
        'deployment_targets',
        'rust_targets',
      },
      context);
  return PrecompiledBuildIdentity(
    rustToolchain: _string(map['rust_toolchain'], '$context Rust toolchain'),
    flutterVersion: _string(map['flutter_version'], '$context Flutter version'),
    xcodeVersion: _string(map['xcode_version'], '$context Xcode version'),
    sdkVersions: _stringMap(map['sdk_versions'], '$context SDK versions'),
    deploymentTargets:
        _stringMap(map['deployment_targets'], '$context deployment targets'),
    rustTargets:
        _sortedUniqueStrings(map['rust_targets'], '$context Rust targets'),
  );
}

Map<String, String> _stringMap(Object? value, String context) {
  final map = _object(value, context);
  final result = <String, String>{};
  for (final entry in map.entries) {
    if (entry.key.isEmpty) {
      throw PrecompiledGenerationException('$context contains an empty key.');
    }
    result[entry.key] = _string(entry.value, '$context value');
  }
  return result;
}

List<String> _sortedUniqueStrings(Object? value, String context) {
  if (value is! List || value.isEmpty) {
    throw PrecompiledGenerationException('$context must be a non-empty list.');
  }
  final result = <String>[];
  final seen = <String>{};
  for (final item in value) {
    final string = _string(item, '$context entry');
    if (!seen.add(string)) {
      throw PrecompiledGenerationException('Duplicate $context entry.');
    }
    result.add(string);
  }
  return result;
}

Map<String, dynamic> _object(Object? value, String context) {
  if (value is Map<String, dynamic>) return value;
  throw PrecompiledGenerationException('$context must be an object.');
}

void _requireFields(
    Map<String, dynamic> map, Set<String> required, String context) {
  if (map.keys.length != required.length ||
      !map.keys.toSet().containsAll(required)) {
    final unknown = map.keys.where((key) => !required.contains(key));
    final missing = required.where((key) => !map.containsKey(key));
    throw PrecompiledGenerationException(
        '$context fields are invalid (unknown: ${unknown.join(', ')}, missing: ${missing.join(', ')}).');
  }
}

String _string(Object? value, String context) {
  if (value is String && value.isNotEmpty) return value;
  throw PrecompiledGenerationException('$context must be a non-empty string.');
}

int _nonNegativeInt(Object? value, String context) {
  if (value is int && value >= 0) return value;
  throw PrecompiledGenerationException(
      '$context must be a non-negative integer.');
}

String _safeName(String value, String context) {
  if (value.contains('\\') ||
      path.posix.isAbsolute(value) ||
      path.windows.isAbsolute(value) ||
      path.posix.normalize(value) != value ||
      value.split('/').any((part) =>
          part.isEmpty ||
          part == '.' ||
          part == '..' ||
          !_assetNamePattern.hasMatch(part))) {
    throw PrecompiledGenerationException('$context is unsafe.');
  }
  return value;
}

Map<String, String> _sortedStringMap(Map<String, String> map) {
  final keys = map.keys.toList()..sort();
  return {for (final key in keys) key: map[key]!};
}

String _canonicalJson(Object? value) {
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is List) return '[${value.map(_canonicalJson).join(',')}]';
  return jsonEncode(value);
}

String _decodeUtf8(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw PrecompiledGenerationException('Manifest is not valid UTF-8.');
  }
}

class _StrictJsonParser {
  _StrictJsonParser(this.input);

  final String input;
  int index = 0;

  Object? parse() {
    _space();
    final value = _value();
    _space();
    if (index != input.length) _fail('Trailing data.');
    return value;
  }

  Object? _value() {
    _space();
    if (index >= input.length) _fail('Unexpected end of JSON.');
    return switch (input.codeUnitAt(index)) {
      0x7b => _objectValue(),
      0x5b => _arrayValue(),
      0x22 => _stringValue(),
      0x74 => _literal('true', true),
      0x66 => _literal('false', false),
      0x6e => _literal('null', null),
      _ => _numberValue(),
    };
  }

  Map<String, dynamic> _objectValue() {
    index++;
    final result = <String, dynamic>{};
    _space();
    if (_take(0x7d)) return result;
    while (true) {
      _space();
      if (index >= input.length || input.codeUnitAt(index) != 0x22) {
        _fail('Object key must be a string.');
      }
      final key = _stringValue();
      if (result.containsKey(key)) _fail('Duplicate object key "$key".');
      _space();
      if (!_take(0x3a)) _fail('Expected colon after object key.');
      result[key] = _value();
      _space();
      if (_take(0x7d)) return result;
      if (!_take(0x2c)) _fail('Expected comma between object fields.');
    }
  }

  List<dynamic> _arrayValue() {
    index++;
    final result = <dynamic>[];
    _space();
    if (_take(0x5d)) return result;
    while (true) {
      result.add(_value());
      _space();
      if (_take(0x5d)) return result;
      if (!_take(0x2c)) _fail('Expected comma between array values.');
    }
  }

  String _stringValue() {
    final start = index;
    index++;
    while (index < input.length) {
      final code = input.codeUnitAt(index++);
      if (code == 0x22) {
        final raw = input.substring(start, index);
        try {
          final value = jsonDecode(raw);
          if (value is String) return value;
        } on FormatException {
          _fail('Malformed string.');
        }
        _fail('Malformed string.');
      }
      if (code == 0x5c) {
        if (index >= input.length) _fail('Malformed escape.');
        final escaped = input.codeUnitAt(index++);
        if (escaped == 0x75) {
          if (index + 4 > input.length ||
              !RegExp(r'^[0-9a-fA-F]{4}$')
                  .hasMatch(input.substring(index, index + 4))) {
            _fail('Malformed unicode escape.');
          }
          index += 4;
        } else if (!const [0x22, 0x5c, 0x2f, 0x62, 0x66, 0x6e, 0x72, 0x74]
            .contains(escaped)) {
          _fail('Malformed escape.');
        }
      } else if (code < 0x20) {
        _fail('Unescaped control character.');
      }
    }
    _fail('Unterminated string.');
  }

  Object? _literal(String literal, Object? value) {
    if (!input.startsWith(literal, index)) _fail('Malformed literal.');
    index += literal.length;
    return value;
  }

  Object _numberValue() {
    final match =
        RegExp(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?')
            .matchAsPrefix(input.substring(index));
    if (match == null) _fail('Malformed JSON value.');
    index += match.end;
    final text = match.group(0)!;
    return text.contains('.') || text.contains('e') || text.contains('E')
        ? double.parse(text)
        : int.parse(text);
  }

  bool _take(int code) {
    if (index < input.length && input.codeUnitAt(index) == code) {
      index++;
      return true;
    }
    return false;
  }

  void _space() {
    while (index < input.length &&
        const [0x20, 0x09, 0x0a, 0x0d].contains(input.codeUnitAt(index))) {
      index++;
    }
  }

  Never _fail(String message) => throw PrecompiledGenerationException(message);
}
