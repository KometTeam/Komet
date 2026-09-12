/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'dart:io';

import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'builder.dart';
import 'crate_hash.dart';
import 'options.dart';
import 'precompile_binaries.dart';
import 'precompiled_asset_store.dart';
import 'precompiled_generation.dart';
import 'rustup.dart';
import 'target.dart';

class Artifact {
  Artifact({
    required this.path,
    required this.finalFileName,
  });

  /// File system location of the artifact.
  final String path;

  /// Actual file name that the artifact should have in destination folder.
  final String finalFileName;

  AritifactType get type {
    if (finalFileName.endsWith('.dll') ||
        finalFileName.endsWith('.dll.lib') ||
        finalFileName.endsWith('.pdb') ||
        finalFileName.endsWith('.so') ||
        finalFileName.endsWith('.dylib')) {
      return AritifactType.dylib;
    } else if (finalFileName.endsWith('.lib') || finalFileName.endsWith('.a')) {
      return AritifactType.staticlib;
    }
    throw Exception('Unknown artifact type for $finalFileName');
  }
}

typedef ArtifactHttpGet = Future<Response> Function(Uri url);
typedef ArtifactGenerationHash = String Function(BuildEnvironment environment);
typedef ArtifactLocalBuilder = Future<List<Artifact>> Function(
    Target target, BuildEnvironment environment);
typedef ArtifactTransportFactory = PrecompiledAssetTransport Function();

final _log = Logger('artifacts_provider');

class ArtifactProvider {
  ArtifactProvider({
    required this.environment,
    required this.userOptions,
    ArtifactHttpGet? httpGet,
    PrecompiledHttpSend? httpSend,
    ArtifactGenerationHash? generationHash,
    ArtifactLocalBuilder? localBuilder,
    ArtifactTransportFactory? transportFactory,
    PrecompiledTransportPolicy transportPolicy =
        const PrecompiledTransportPolicy(),
    this.storePolicy = const PrecompiledAssetStorePolicy(),
  })  : generationHash = generationHash ??
            ((environment) => CrateHash.compute(
                  environment.manifestDir,
                  tempStorage: environment.targetTempDir,
                )),
        localBuilder = localBuilder ?? _defaultLocalBuilder,
        transportFactory = transportFactory ??
            (() => PrecompiledAssetTransport(
                  send: httpSend ??
                      (httpGet == null ? null : _sendFromGet(httpGet)),
                  policy: transportPolicy,
                ));

  final BuildEnvironment environment;
  final CargokitUserOptions userOptions;
  final ArtifactGenerationHash generationHash;
  final ArtifactLocalBuilder localBuilder;
  final ArtifactTransportFactory transportFactory;
  final PrecompiledAssetStorePolicy storePolicy;

  Future<Map<Target, List<Artifact>>> getArtifacts(List<Target> targets) async {
    final result = await _getPrecompiledArtifacts(targets);
    final pendingTargets = List.of(targets)
      ..removeWhere((target) => result.containsKey(target));

    if (pendingTargets.isEmpty) return result;
    if (!userOptions.allowLocalBuild) {
      throw PrecompiledGenerationException(
          'Required precompiled generation did not provide all requested targets.');
    }
    for (final target in pendingTargets) {
      _log.info('Building ${environment.crateInfo.packageName} for $target');
      result[target] = await localBuilder(target, environment);
    }
    return result;
  }

  Future<Map<Target, List<Artifact>>> _getPrecompiledArtifacts(
      List<Target> targets) async {
    if (userOptions.precompiledBinariesMode ==
        PrecompiledBinariesMode.disabled) {
      _log.info('Precompiled binaries are disabled');
      return {};
    }
    final precompiled = environment.crateOptions.precompiledBinaries;
    if (precompiled == null) return {};
    final recipe = precompiled.buildRecipe;
    if (recipe == null) {
      throw PrecompiledGenerationException(
          'Configured precompiled binaries need a complete build recipe.');
    }
    final pinnedTargets = recipe.rustTargets.toSet();
    if (targets.any((target) => !pinnedTargets.contains(target.rust))) {
      throw PrecompiledGenerationException(
          'Requested Rust target is not included in the signed build recipe.');
    }

    final requiredForTargets = <Target, List<String>>{
      for (final target in targets)
        target: getArtifactNames(
          target: target,
          libraryName: environment.crateInfo.packageName,
          remote: true,
        ).map((name) => PrecompileBinaries.fileName(target, name)).toList(),
    };
    final generation = generationHash(environment);
    final uriPrefix = Uri.parse(precompiled.uriPrefix);
    final expectedAssetNames = _expectedAssetNames(recipe, precompiled);
    final expectedCompositeChecksums = _expectedCompositeChecksums(precompiled);
    final transport = transportFactory();
    try {
      final store = PrecompiledAssetStore(
        cacheRoot: path.join(environment.targetTempDir, 'precompiled'),
        uriPrefix: uriPrefix,
        publicKey: precompiled.publicKey,
        recipe: recipe,
        expectedAssetNames: expectedAssetNames,
        expectedCompositeChecksums: expectedCompositeChecksums,
        transport: transport,
        policy: storePolicy,
        logger: _log.info,
      );
      final snapshot = await store.snapshot(
        generationHash: generation,
        requestedAssetNames:
            requiredForTargets.values.expand((names) => names).toSet(),
      );
      if (snapshot == null) {
        if (userOptions.precompiledBinariesMode ==
            PrecompiledBinariesMode.auto) {
          if (!store.hasAnyState(generation)) return {};
          throw PrecompiledGenerationException(
              'Precompiled generation manifest is unavailable for existing cache state.');
        }
        throw PrecompiledGenerationException(
            'Required precompiled generation manifest is unavailable.');
      }

      return {
        for (final entry in requiredForTargets.entries)
          entry.key: [
            for (final remoteName in entry.value)
              Artifact(
                path: snapshot.pathFor(remoteName),
                finalFileName:
                    remoteName.substring('${entry.key.rust}_'.length),
              ),
          ],
      };
    } finally {
      transport.close();
    }
  }

  Set<String> _expectedAssetNames(
      PrecompiledBuildRecipe recipe, PrecompiledBinaries precompiled) {
    final names = <String>{};
    for (final rustTarget in recipe.rustTargets) {
      final target = Target.forRustTriple(rustTarget);
      if (target == null) {
        throw PrecompiledGenerationException(
            'Manifest recipe has an unsupported Rust target.');
      }
      for (final type in AritifactType.values) {
        for (final name in getArtifactNames(
          target: target,
          libraryName: environment.crateInfo.packageName,
          remote: true,
          aritifactType: type,
        )) {
          names.add(PrecompileBinaries.fileName(target, name));
        }
      }
    }
    for (final group in precompiled.compositeGroups) {
      names.addAll(group.outputs);
    }
    return names;
  }

  static Set<String> _expectedCompositeChecksums(
      PrecompiledBinaries precompiled) {
    final result = <String>{};
    for (final group in precompiled.compositeGroups) {
      for (final output in group.outputs) {
        if (!output.endsWith('.checksum')) continue;
        final archive = output.substring(0, output.length - '.checksum'.length);
        if (group.outputs.contains(archive)) {
          result.add('$archive\u0000$output');
        }
      }
    }
    return result;
  }

  static PrecompiledHttpSend _sendFromGet(ArtifactHttpGet get) {
    return (request) async {
      final response = await get(request.url);
      return StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        contentLength: response.bodyBytes.length,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        request: request,
        isRedirect: response.isRedirect,
      );
    };
  }
}

Future<List<Artifact>> _defaultLocalBuilder(
    Target target, BuildEnvironment environment) async {
  final rustup = Rustup();
  final builder = RustBuilder(target: target, environment: environment);
  builder.prepare(rustup);
  final targetDir = await builder.build();
  final artifactNames = <String>{
    ...getArtifactNames(
      target: target,
      libraryName: environment.crateInfo.packageName,
      aritifactType: AritifactType.dylib,
      remote: false,
    ),
    ...getArtifactNames(
      target: target,
      libraryName: environment.crateInfo.packageName,
      aritifactType: AritifactType.staticlib,
      remote: false,
    ),
  };
  return artifactNames
      .map((artifactName) => Artifact(
            path: path.join(targetDir, artifactName),
            finalFileName: artifactName,
          ))
      .where((artifact) => File(artifact.path).existsSync())
      .toList();
}

enum AritifactType {
  staticlib,
  dylib,
}

AritifactType artifactTypeForTarget(Target target) {
  if (target.darwinPlatform != null) {
    return AritifactType.staticlib;
  }
  return AritifactType.dylib;
}

List<String> getArtifactNames({
  required Target target,
  required String libraryName,
  required bool remote,
  AritifactType? aritifactType,
}) {
  aritifactType ??= artifactTypeForTarget(target);
  if (target.darwinArch != null) {
    if (aritifactType == AritifactType.staticlib) {
      return ['lib$libraryName.a'];
    }
    return ['lib$libraryName.dylib'];
  } else if (target.rust.contains('-windows-')) {
    if (aritifactType == AritifactType.staticlib) {
      return ['$libraryName.lib'];
    }
    return [
      '$libraryName.dll',
      '$libraryName.dll.lib',
      if (!remote) '$libraryName.pdb',
    ];
  } else if (target.rust.contains('-linux-')) {
    if (aritifactType == AritifactType.staticlib) {
      return ['lib$libraryName.a'];
    }
    return ['lib$libraryName.so'];
  }
  throw Exception('Unsupported target: ${target.rust}');
}
