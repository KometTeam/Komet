/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:github/github.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'artifacts_provider.dart';
import 'builder.dart';
import 'cargo.dart';
import 'composite_artifacts.dart';
import 'crate_hash.dart';
import 'options.dart';
import 'precompiled_generation.dart';
import 'rustup.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('precompile_binaries');

const localPrecompiledGenerationFragmentFileName = 'local-generation.json';

typedef LocalPrecompiledTargetBuilder = Future<String> Function(
  Target target,
  BuildEnvironment environment,
  String toolchain,
);

enum LocalGenerationFinalizationScope {
  full,
  darwinAcceptance,
}

class FinalizedPrecompiledGeneration {
  FinalizedPrecompiledGeneration({
    required this.manifest,
    required this.scope,
    required Map<String, File> publicationFiles,
  }) : publicationFiles = Map.unmodifiable(publicationFiles);

  final PrecompiledGenerationManifest manifest;
  final LocalGenerationFinalizationScope scope;
  final Map<String, File> publicationFiles;
}

class LocalGenerationFinalizer {
  LocalGenerationFinalizer({
    required this.manifestDir,
    required this.generationDir,
    required this.privateKey,
    required this.scope,
    this.sourceCommit,
  });

  final String manifestDir;
  final String generationDir;
  final PrivateKey privateKey;
  final LocalGenerationFinalizationScope scope;
  final String? sourceCommit;

  Future<FinalizedPrecompiledGeneration> run() async {
    final manifestRoot = path.normalize(path.absolute(manifestDir));
    final generationRoot = path.normalize(path.absolute(generationDir));
    final options = CargokitCrateOptions.load(manifestDir: manifestRoot);
    final precompiled = options.precompiledBinaries;
    final recipe = precompiled?.buildRecipe;
    if (precompiled == null || recipe == null) {
      throw PrecompiledGenerationException(
        'A complete precompiled config and recipe are required.',
      );
    }
    if (!_sameBytes(public(privateKey).bytes, precompiled.publicKey.bytes)) {
      throw PrecompiledGenerationException(
        'Private key does not match the configured public key.',
      );
    }

    final fragmentFile = File(
      path.join(generationRoot, localPrecompiledGenerationFragmentFileName),
    );
    final fragment = _localFragment(fragmentFile.readAsBytesSync());
    final generationHash = fragment['generation_hash'] as String;
    if (generationHash != CrateHash.compute(manifestRoot)) {
      throw PrecompiledGenerationException(
        'Local fragment generation hash does not match current inputs.',
      );
    }
    final fragmentRecipe = _fragmentRecipe(fragment['recipe']);
    if (!PrecompiledBuildIdentity.fromRecipe(fragmentRecipe)
        .matches(PrecompiledBuildIdentity.fromRecipe(recipe))) {
      throw PrecompiledGenerationException(
        'Local fragment recipe does not match the pinned recipe.',
      );
    }

    final crateInfo = CrateInfo.load(manifestRoot);
    final expectedNames = _expectedGenerationAssetNames(
      recipe,
      precompiled,
      crateInfo.packageName,
    );
    final assetsValue = fragment['assets'] as List<dynamic>;
    final assets = <PrecompiledAsset>[];
    final assetFiles = <String, File>{};
    final declaredPaths = <String>{
      localPrecompiledGenerationFragmentFileName,
    };
    String? previousName;
    for (final value in assetsValue) {
      final asset = _localAsset(value, generationRoot);
      if (previousName != null && asset.name.compareTo(previousName) <= 0) {
        throw PrecompiledGenerationException(
          'Local fragment assets must be sorted and unique.',
        );
      }
      previousName = asset.name;
      if (!assetFiles.containsKey(asset.name)) {
        assets.add(asset.metadata);
        assetFiles[asset.name] = asset.file;
      }
      if (!declaredPaths.add(asset.relativePath)) {
        throw PrecompiledGenerationException(
          'Local fragment contains a duplicate asset path.',
        );
      }
    }
    final actualNames = assetFiles.keys.toSet();
    if (scope == LocalGenerationFinalizationScope.full) {
      if (!_sameSet(actualNames, expectedNames)) {
        throw PrecompiledGenerationException(
          'Full local generation asset inventory is incomplete or unexpected.',
        );
      }
    } else if (!expectedNames.containsAll(actualNames)) {
      throw PrecompiledGenerationException(
        'Darwin acceptance generation contains unexpected assets.',
      );
    }
    _validateLocalInventory(generationRoot, declaredPaths);

    final composites = _compositeChecksums(precompiled);
    final manifest = PrecompiledGenerationManifest(
      generationHash: generationHash,
      sourceCommit: sourceCommit ?? _gitSourceCommit(manifestRoot),
      provenance: PrecompiledGenerationProvenance.fromRecipe(recipe),
      assets: assets,
      compositeChecksums: composites,
    );
    manifest.validateCompositeChecksums({
      for (final binding in composites) ...{
        binding.archive: assetFiles[binding.archive]!.readAsBytesSync(),
        binding.checksum: assetFiles[binding.checksum]!.readAsBytesSync(),
      },
    });

    final signaturesRoot = Directory(
      path.join(generationRoot, 'signatures'),
    )..createSync();
    final publicationFiles = <String, File>{};
    for (final asset in manifest.assets) {
      final signatureFile = File(
        path.join(signaturesRoot.path, '${asset.name}.sig'),
      );
      signatureFile.parent.createSync(recursive: true);
      _writeAtomic(
        signatureFile,
        signPrecompiledAssetMetadata(
          privateKey,
          generationHash: generationHash,
          name: asset.name,
          length: asset.length,
          sha256: asset.sha256,
        ),
      );
      publicationFiles[asset.name] = assetFiles[asset.name]!;
      publicationFiles['${asset.name}.sig'] = signatureFile;
    }
    final completion = File(
      path.join(generationRoot, precompiledGenerationManifestFileName),
    );
    final completionSignature = File(
      path.join(
        generationRoot,
        precompiledGenerationManifestSignatureFileName,
      ),
    );
    _writeAtomic(completion, manifest.canonicalBytes());
    _writeAtomic(completionSignature, manifest.sign(privateKey));
    final parsed = PrecompiledGenerationManifest.parse(
      completion.readAsBytesSync(),
    );
    parsed.verifySignature(
      precompiled.publicKey,
      completionSignature.readAsBytesSync(),
    );
    publicationFiles[precompiledGenerationManifestFileName] = completion;
    publicationFiles[precompiledGenerationManifestSignatureFileName] =
        completionSignature;
    return FinalizedPrecompiledGeneration(
      manifest: parsed,
      scope: scope,
      publicationFiles: publicationFiles,
    );
  }
}

typedef _LocalAssetRecord = ({
  PrecompiledAsset metadata,
  File file,
  String name,
  String relativePath,
});

Map<String, dynamic> _localFragment(List<int> bytes) {
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, dynamic> ||
      !_sameSet(value.keys.toSet(), const {
        'schema_version',
        'scope',
        'generation_hash',
        'recipe',
        'assets',
      }) ||
      value['schema_version'] != 1 ||
      value['scope'] != 'cargokit-local-precompiled-generation' ||
      value['generation_hash'] is! String ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['generation_hash'] as String) ||
      value['assets'] is! List ||
      (value['assets'] as List).isEmpty) {
    throw PrecompiledGenerationException('Local fragment is malformed.');
  }
  return value;
}

PrecompiledBuildRecipe _fragmentRecipe(Object? value) {
  if (value is! Map<String, dynamic> ||
      !_sameSet(value.keys.toSet(), const {
        'rust_toolchain',
        'flutter_version',
        'xcode_version',
        'sdk_versions',
        'deployment_targets',
        'rust_targets',
      })) {
    throw PrecompiledGenerationException('Local fragment recipe is malformed.');
  }
  Map<String, String> stringMap(String key) {
    final map = value[key];
    if (map is! Map<String, dynamic> ||
        map.values.any((item) => item is! String)) {
      throw PrecompiledGenerationException(
        'Local fragment recipe $key is malformed.',
      );
    }
    return map.cast<String, String>();
  }

  final targets = value['rust_targets'];
  if (targets is! List || targets.any((item) => item is! String)) {
    throw PrecompiledGenerationException(
      'Local fragment recipe targets are malformed.',
    );
  }
  return PrecompiledBuildRecipe(
    rustToolchain: value['rust_toolchain'] as String,
    flutterVersion: value['flutter_version'] as String,
    xcodeVersion: value['xcode_version'] as String,
    sdkVersions: stringMap('sdk_versions'),
    deploymentTargets: stringMap('deployment_targets'),
    rustTargets: targets.cast<String>(),
  );
}

_LocalAssetRecord _localAsset(Object? value, String generationRoot) {
  if (value is! Map<String, dynamic> ||
      !_sameSet(value.keys.toSet(), const {
        'name',
        'length',
        'sha256',
        'path',
      })) {
    throw PrecompiledGenerationException('Local asset metadata is malformed.');
  }
  final name = value['name'];
  final length = value['length'];
  final digest = value['sha256'];
  final relativePath = value['path'];
  if (name is! String ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name) ||
      length is! int ||
      length < 0 ||
      digest is! String ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
      relativePath is! String ||
      relativePath.contains('\\') ||
      path.posix.isAbsolute(relativePath) ||
      path.posix.normalize(relativePath) != relativePath ||
      relativePath == '..' ||
      relativePath.startsWith('../')) {
    throw PrecompiledGenerationException('Local asset metadata is malformed.');
  }
  final filePath = path.normalize(path.joinAll([
    generationRoot,
    ...path.posix.split(relativePath),
  ]));
  if (!path.isWithin(generationRoot, filePath) ||
      FileSystemEntity.typeSync(filePath, followLinks: false) !=
          FileSystemEntityType.file) {
    throw PrecompiledGenerationException(
        'Local asset file is missing or unsafe.');
  }
  final file = File(filePath);
  final bytes = file.readAsBytesSync();
  if (bytes.length != length || sha256.convert(bytes).toString() != digest) {
    throw PrecompiledGenerationException(
      'Local asset does not match fragment metadata.',
    );
  }
  return (
    metadata: PrecompiledAsset(name: name, length: length, sha256: digest),
    file: file,
    name: name,
    relativePath: relativePath,
  );
}

Set<String> _expectedGenerationAssetNames(
  PrecompiledBuildRecipe recipe,
  PrecompiledBinaries precompiled,
  String libraryName,
) {
  final result = <String>{};
  for (final triple in recipe.rustTargets) {
    final target = Target.forRustTriple(triple)!;
    for (final type in AritifactType.values) {
      for (final artifact in getArtifactNames(
        target: target,
        libraryName: libraryName,
        remote: true,
        aritifactType: type,
      )) {
        result.add(PrecompileBinaries.fileName(target, artifact));
      }
    }
  }
  for (final group in precompiled.compositeGroups) {
    result.addAll(group.outputs);
  }
  return result;
}

List<PrecompiledCompositeChecksum> _compositeChecksums(
  PrecompiledBinaries precompiled,
) {
  final result = <PrecompiledCompositeChecksum>[];
  for (final group in precompiled.compositeGroups) {
    for (final checksum in group.outputs.where(
      (output) => output.endsWith('.checksum'),
    )) {
      final archive =
          checksum.substring(0, checksum.length - '.checksum'.length);
      if (group.outputs.contains(archive)) {
        result.add(PrecompiledCompositeChecksum(
          archive: archive,
          checksum: checksum,
        ));
      }
    }
  }
  return result;
}

void _validateLocalInventory(String root, Set<String> declaredPaths) {
  final actual = <String>{};
  for (final entity in Directory(root).listSync(
    recursive: true,
    followLinks: false,
  )) {
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    if (type == FileSystemEntityType.directory) continue;
    if (type != FileSystemEntityType.file) {
      throw PrecompiledGenerationException(
        'Local generation contains an unsafe filesystem entry.',
      );
    }
    actual.add(
        path.posix.joinAll(path.split(path.relative(entity.path, from: root))));
  }
  if (!_sameSet(actual, declaredPaths)) {
    throw PrecompiledGenerationException(
      'Local generation file inventory is incomplete or unexpected.',
    );
  }
}

String _gitSourceCommit(String manifestRoot) {
  final result = runCommand(
    'git',
    const ['rev-parse', 'HEAD'],
    workingDirectory: manifestRoot,
  );
  return (result.stdout as String).trim();
}

void _writeAtomic(File destination, List<int> bytes) {
  final temporary = File('${destination.path}.staging.$pid');
  if (temporary.existsSync()) temporary.deleteSync();
  temporary.writeAsBytesSync(bytes, flush: true);
  temporary.renameSync(destination.path);
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

class LocalPrecompiledGeneration {
  LocalPrecompiledGeneration({
    required this.manifestDir,
    required this.outputDir,
    required this.tempDir,
    required this.targetTriples,
    LocalPrecompiledTargetBuilder? targetBuilder,
    this.currentHost,
    this.compositeProcessRunner,
  }) : targetBuilder = targetBuilder ?? _buildTarget;

  final String manifestDir;
  final String outputDir;
  final String tempDir;
  final List<String> targetTriples;
  final LocalPrecompiledTargetBuilder targetBuilder;
  final CompositeHost? currentHost;
  final CompositeProcessRunner? compositeProcessRunner;

  Future<File> run() async {
    final manifest = path.normalize(path.absolute(manifestDir));
    if (FileSystemEntity.typeSync(manifest, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw ArgumentError('Manifest directory does not exist: $manifestDir');
    }
    final crateOptions = CargokitCrateOptions.load(manifestDir: manifest);
    final precompiled = crateOptions.precompiledBinaries;
    final recipe = precompiled?.buildRecipe;
    if (precompiled == null || recipe == null) {
      throw ArgumentError(
        'A complete precompiled binaries config and build recipe are required.',
      );
    }
    if (targetTriples.isEmpty) {
      throw ArgumentError('At least one --target is required.');
    }

    final requested = <Target>[];
    final seen = <String>{};
    final pinned = recipe.rustTargets.toSet();
    for (final triple in targetTriples) {
      if (!seen.add(triple)) {
        throw ArgumentError('Duplicate target: $triple');
      }
      final target = Target.forRustTriple(triple);
      if (target == null) throw ArgumentError('Unknown target: $triple');
      if (!pinned.contains(triple)) {
        throw ArgumentError('Target is not in the build recipe: $triple');
      }
      requested.add(target);
    }
    for (final group in precompiled.compositeGroups) {
      final overlap = group.requiredTargets.any(seen.contains);
      if (overlap && !group.requiredTargets.every(seen.contains)) {
        throw ArgumentError(
          'Requested targets are incomplete for composite group ${group.name}.',
        );
      }
    }

    final generationHash = CrateHash.compute(manifest);
    final workspaceRoot = path.normalize(path.absolute(path.join(
      manifest,
      precompiled.workspaceRoot,
    )));
    final finalOutput = path.normalize(path.absolute(outputDir));
    final finalParent = Directory(path.dirname(finalOutput))
      ..createSync(recursive: true);
    final staging = Directory(path.join(
      finalParent.path,
      '.${path.basename(finalOutput)}.$pid.${DateTime.now().microsecondsSinceEpoch}',
    ))
      ..createSync();
    final targetOutputRoot = Directory(path.join(staging.path, 'targets'))
      ..createSync();
    final buildTemp = Directory(path.normalize(path.absolute(tempDir)))
      ..createSync(recursive: true);
    final assets = <Map<String, Object>>[];

    try {
      final environment = BuildEnvironment(
        configuration: BuildConfiguration.release,
        crateOptions: crateOptions,
        targetTempDir: buildTemp.path,
        manifestDir: manifest,
        crateInfo: CrateInfo.load(manifest),
        isAndroid: false,
        iosDeploymentTarget: recipe.deploymentTargets['ios'],
        macosDeploymentTarget: recipe.deploymentTargets['macos'],
      );
      for (final target in requested) {
        final buildOutput = path.normalize(path.absolute(
          await targetBuilder(target, environment, recipe.rustToolchain),
        ));
        final retained =
            Directory(path.join(targetOutputRoot.path, target.rust))
              ..createSync();
        for (final artifactType in AritifactType.values) {
          for (final localName in getArtifactNames(
            target: target,
            libraryName: environment.crateInfo.packageName,
            remote: true,
            aritifactType: artifactType,
          )) {
            final source = path.join(buildOutput, localName);
            _requireBuildFile(buildOutput, source);
            final remoteName = PrecompileBinaries.fileName(target, localName);
            final destination = path.join(retained.path, remoteName);
            File(source).copySync(destination);
            assets.add(_assetJson(
              name: remoteName,
              relativePath: path.posix.join('targets', target.rust, remoteName),
              file: File(destination),
            ));
          }
        }
      }

      final selected = seen.toSet();
      final compositeBuilder = CompositeArtifactBuilder(
        workspaceRoot: workspaceRoot,
        generationHash: generationHash,
        targetOutputRoot: targetOutputRoot.path,
        outputRoot: staging.path,
        currentHost: currentHost,
        processRunner: compositeProcessRunner,
      );
      for (final group in precompiled.compositeGroups) {
        if (!compositeBuilder.supports(group, selected)) continue;
        final result = await compositeBuilder.build(group);
        for (final output in group.outputs) {
          assets.add(_assetJson(
            name: output,
            relativePath: path.posix.join('composites', group.name, output),
            file: File(result.outputs[output]!),
          ));
        }
      }

      assets.sort((left, right) =>
          (left['name'] as String).compareTo(right['name'] as String));
      final fragment = <String, Object>{
        'schema_version': 1,
        'scope': 'cargokit-local-precompiled-generation',
        'generation_hash': generationHash,
        'recipe': _recipeJson(recipe),
        'assets': assets,
      };
      File(path.join(staging.path, localPrecompiledGenerationFragmentFileName))
          .writeAsStringSync('${jsonEncode(fragment)}\n', flush: true);
      _publishDirectory(staging, finalOutput);
      return File(
        path.join(finalOutput, localPrecompiledGenerationFragmentFileName),
      );
    } finally {
      if (staging.existsSync()) staging.deleteSync(recursive: true);
    }
  }

  static Future<String> _buildTarget(
    Target target,
    BuildEnvironment environment,
    String toolchain,
  ) async {
    final rustup = Rustup();
    final builder = RustBuilder(
      target: target,
      environment: environment,
      toolchain: toolchain,
    );
    builder.prepare(rustup);
    return builder.build();
  }
}

Map<String, Object> _assetJson({
  required String name,
  required String relativePath,
  required File file,
}) {
  final bytes = file.readAsBytesSync();
  return {
    'name': name,
    'length': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
    'path': relativePath,
  };
}

Map<String, Object> _recipeJson(PrecompiledBuildRecipe recipe) => {
      'rust_toolchain': recipe.rustToolchain,
      'flutter_version': recipe.flutterVersion,
      'xcode_version': recipe.xcodeVersion,
      'sdk_versions': Map.fromEntries(
        recipe.sdkVersions.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      ),
      'deployment_targets': Map.fromEntries(
        recipe.deploymentTargets.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      ),
      'rust_targets': [...recipe.rustTargets]..sort(),
    };

void _requireBuildFile(String root, String filePath) {
  final normalizedRoot = path.normalize(path.absolute(root));
  final normalizedFile = path.normalize(path.absolute(filePath));
  if (!path.isWithin(normalizedRoot, normalizedFile) ||
      FileSystemEntity.typeSync(normalizedFile, followLinks: false) !=
          FileSystemEntityType.file) {
    throw FileSystemException(
        'Missing or invalid Rust build artifact.', filePath);
  }
}

void _publishDirectory(Directory staging, String finalPath) {
  final existingType = FileSystemEntity.typeSync(finalPath, followLinks: false);
  if (existingType != FileSystemEntityType.notFound &&
      existingType != FileSystemEntityType.directory) {
    throw FileSystemException(
        'Generation output must be a directory.', finalPath);
  }
  final backup = '$finalPath.previous.$pid';
  if (Directory(backup).existsSync()) {
    Directory(backup).deleteSync(recursive: true);
  }
  if (existingType == FileSystemEntityType.directory) {
    Directory(finalPath).renameSync(backup);
  }
  try {
    staging.renameSync(finalPath);
    if (Directory(backup).existsSync()) {
      Directory(backup).deleteSync(recursive: true);
    }
  } on Object {
    if (!Directory(finalPath).existsSync() && Directory(backup).existsSync()) {
      Directory(backup).renameSync(finalPath);
    }
    rethrow;
  }
}

class PrecompiledRelease {
  PrecompiledRelease({
    required this.id,
    required this.tagName,
    required this.isDraft,
    required Set<String> assetNames,
  }) : assetNames = Set.unmodifiable(assetNames);

  final Object id;
  final String tagName;
  final bool isDraft;
  final Set<String> assetNames;
}

abstract class PrecompiledReleaseGateway {
  Future<PrecompiledRelease?> find(String tagName);

  Future<PrecompiledRelease> createDraft(String tagName);

  Future<List<int>> readAsset(PrecompiledRelease release, String name);

  Future<void> upload(
    PrecompiledRelease release,
    String name,
    List<int> bytes,
  );

  Future<void> publish(PrecompiledRelease release);
}

class PrecompiledPublicationResult {
  const PrecompiledPublicationResult({required this.reused});

  final bool reused;
}

class PrecompiledGenerationPublisher {
  PrecompiledGenerationPublisher({
    required this.generation,
    required this.gateway,
  });

  final FinalizedPrecompiledGeneration generation;
  final PrecompiledReleaseGateway gateway;

  Future<PrecompiledPublicationResult> publish() async {
    if (generation.scope != LocalGenerationFinalizationScope.full) {
      throw PrecompiledGenerationException(
        'GitHub publication accepts only full generations.',
      );
    }
    final files = generation.publicationFiles;
    final expectedNames = files.keys.toSet();
    final tagName = 'precompiled_${generation.manifest.generationHash}';
    var release = await gateway.find(tagName);
    if (release != null && !release.isDraft) {
      if (await _matches(release, files, expectedNames)) {
        return const PrecompiledPublicationResult(reused: true);
      }
      throw PrecompiledGenerationException(
        'Published generation conflicts with local finalized bytes.',
      );
    }
    release ??= await gateway.createDraft(tagName);

    final completionNames = {
      precompiledGenerationManifestFileName,
      precompiledGenerationManifestSignatureFileName,
    };
    final uploadOrder =
        files.keys.where((name) => !completionNames.contains(name)).toList()
          ..sort()
          ..add(precompiledGenerationManifestFileName)
          ..add(precompiledGenerationManifestSignatureFileName);
    for (final name in uploadOrder) {
      final bytes = files[name]!.readAsBytesSync();
      if (release.assetNames.contains(name)) {
        final existing = await gateway.readAsset(release, name);
        if (!_sameBytes(existing, bytes)) {
          throw PrecompiledGenerationException(
            'Draft release asset "$name" conflicts with finalized bytes.',
          );
        }
        continue;
      }
      await gateway.upload(release, name, bytes);
    }
    await gateway.publish(release);
    return const PrecompiledPublicationResult(reused: false);
  }

  Future<bool> _matches(
    PrecompiledRelease release,
    Map<String, File> files,
    Set<String> expectedNames,
  ) async {
    if (!_sameSet(release.assetNames, expectedNames)) return false;
    for (final entry in files.entries) {
      if (!_sameBytes(
        await gateway.readAsset(release, entry.key),
        entry.value.readAsBytesSync(),
      )) {
        return false;
      }
    }
    return true;
  }
}

class GitHubPrecompiledReleaseGateway implements PrecompiledReleaseGateway {
  GitHubPrecompiledReleaseGateway({
    required this.repositories,
    required this.repository,
  });

  final RepositoriesService repositories;
  final RepositorySlug repository;

  @override
  Future<PrecompiledRelease?> find(String tagName) async {
    try {
      return _fromRelease(
        await repositories.getReleaseByTagName(repository, tagName),
      );
    } on ReleaseNotFound {
      return null;
    }
  }

  @override
  Future<PrecompiledRelease> createDraft(String tagName) async {
    final release = await repositories.createRelease(
      repository,
      CreateRelease.from(
        tagName: tagName,
        name:
            'Precompiled binaries ${tagName.substring('precompiled_'.length, 'precompiled_'.length + 8)}',
        targetCommitish: null,
        isDraft: true,
        isPrerelease: false,
      ),
    );
    return _fromRelease(release);
  }

  @override
  Future<List<int>> readAsset(
    PrecompiledRelease release,
    String name,
  ) async {
    final githubRelease = release.id as Release;
    final asset = (githubRelease.assets ?? const <ReleaseAsset>[])
        .firstWhere((item) => item.name == name);
    final response = await repositories.github.request(
      'GET',
      '/repos/${repository.fullName}/releases/assets/${asset.id}',
      headers: {'Accept': 'application/octet-stream'},
      statusCode: 200,
    );
    return response.bodyBytes;
  }

  @override
  Future<void> upload(
    PrecompiledRelease release,
    String name,
    List<int> bytes,
  ) async {
    await repositories.uploadReleaseAssets(
      release.id as Release,
      [
        CreateReleaseAsset(
          name: name,
          contentType: 'application/octet-stream',
          assetData: Uint8List.fromList(bytes),
        ),
      ],
    );
  }

  @override
  Future<void> publish(PrecompiledRelease release) async {
    await repositories.editRelease(
      repository,
      release.id as Release,
      draft: false,
    );
  }

  PrecompiledRelease _fromRelease(Release release) {
    final tagName = release.tagName;
    final isDraft = release.isDraft;
    if (tagName == null || isDraft == null) {
      throw PrecompiledGenerationException(
          'GitHub returned an incomplete release.');
    }
    return PrecompiledRelease(
      id: release,
      tagName: tagName,
      isDraft: isDraft,
      assetNames: {
        for (final asset in release.assets ?? const <ReleaseAsset>[])
          asset.name!,
      },
    );
  }
}

class PrecompileBinaries {
  PrecompileBinaries({
    required this.privateKey,
    required this.githubToken,
    required this.repositorySlug,
    required this.manifestDir,
    required this.targets,
    this.androidSdkLocation,
    this.androidNdkVersion,
    this.androidMinSdkVersion,
    this.tempDir,
  });

  final PrivateKey privateKey;
  final String githubToken;
  final RepositorySlug repositorySlug;
  final String manifestDir;
  final List<Target> targets;
  final String? androidSdkLocation;
  final String? androidNdkVersion;
  final int? androidMinSdkVersion;
  final String? tempDir;

  static String fileName(Target target, String name) {
    return '${target.rust}_$name';
  }

  static String signatureFileName(Target target, String name) {
    return '${target.rust}_$name.sig';
  }

  Future<void> run() async {
    final crateInfo = CrateInfo.load(manifestDir);

    final targets = List.of(this.targets);
    if (targets.isEmpty) {
      targets.addAll([
        ...Target.buildableTargets(),
        if (androidSdkLocation != null) ...Target.androidTargets(),
      ]);
    }

    _log.info('Precompiling binaries for $targets');

    final hash = CrateHash.compute(manifestDir);
    _log.info('Computed crate hash: $hash');

    final String tagName = 'precompiled_$hash';

    final github = GitHub(auth: Authentication.withToken(githubToken));
    final repo = github.repositories;
    final release = await _getOrCreateRelease(
      repo: repo,
      tagName: tagName,
      packageName: crateInfo.packageName,
      hash: hash,
    );

    final tempDir = this.tempDir != null
        ? Directory(this.tempDir!)
        : Directory.systemTemp.createTempSync('precompiled_');

    tempDir.createSync(recursive: true);

    final crateOptions = CargokitCrateOptions.load(
      manifestDir: manifestDir,
    );

    final buildEnvironment = BuildEnvironment(
      configuration: BuildConfiguration.release,
      crateOptions: crateOptions,
      targetTempDir: tempDir.path,
      manifestDir: manifestDir,
      crateInfo: crateInfo,
      isAndroid: androidSdkLocation != null,
      androidSdkPath: androidSdkLocation,
      androidNdkVersion: androidNdkVersion,
      androidMinSdkVersion: androidMinSdkVersion,
    );

    final rustup = Rustup();

    for (final target in targets) {
      final artifactNames = getArtifactNames(
        target: target,
        libraryName: crateInfo.packageName,
        remote: true,
      );

      if (artifactNames.every((name) {
        final fileName = PrecompileBinaries.fileName(target, name);
        return (release.assets ?? []).any((e) => e.name == fileName);
      })) {
        _log.info("All artifacts for $target already exist - skipping");
        continue;
      }

      _log.info('Building for $target');

      final builder =
          RustBuilder(target: target, environment: buildEnvironment);
      builder.prepare(rustup);
      final res = await builder.build();

      final assets = <CreateReleaseAsset>[];
      for (final name in artifactNames) {
        final file = File(path.join(res, name));
        if (!file.existsSync()) {
          throw Exception('Missing artifact: ${file.path}');
        }

        final data = file.readAsBytesSync();
        final create = CreateReleaseAsset(
          name: PrecompileBinaries.fileName(target, name),
          contentType: "application/octet-stream",
          assetData: data,
        );
        final signature = sign(privateKey, data);
        final signatureCreate = CreateReleaseAsset(
          name: signatureFileName(target, name),
          contentType: "application/octet-stream",
          assetData: signature,
        );
        bool verified = verify(public(privateKey), data, signature);
        if (!verified) {
          throw Exception('Signature verification failed');
        }
        assets.add(create);
        assets.add(signatureCreate);
      }
      _log.info('Uploading assets: ${assets.map((e) => e.name)}');
      for (final asset in assets) {
        // This seems to be failing on CI so do it one by one
        int retryCount = 0;
        while (true) {
          try {
            await repo.uploadReleaseAssets(release, [asset]);
            break;
          } on Exception catch (e) {
            if (retryCount == 10) {
              rethrow;
            }
            ++retryCount;
            _log.shout(
                'Upload failed (attempt $retryCount, will retry): ${e.toString()}');
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }
    }

    _log.info('Cleaning up');
    tempDir.deleteSync(recursive: true);
  }

  Future<Release> _getOrCreateRelease({
    required RepositoriesService repo,
    required String tagName,
    required String packageName,
    required String hash,
  }) async {
    Release release;
    try {
      _log.info('Fetching release $tagName');
      release = await repo.getReleaseByTagName(repositorySlug, tagName);
    } on ReleaseNotFound {
      _log.info('Release not found - creating release $tagName');
      release = await repo.createRelease(
          repositorySlug,
          CreateRelease.from(
            tagName: tagName,
            name: 'Precompiled binaries ${hash.substring(0, 8)}',
            targetCommitish: null,
            isDraft: false,
            isPrerelease: false,
            body: 'Precompiled binaries for crate $packageName, '
                'crate hash $hash.',
          ));
    }
    return release;
  }
}
