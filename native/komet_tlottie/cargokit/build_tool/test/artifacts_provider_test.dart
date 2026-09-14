import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:build_tool/src/artifacts_provider.dart';
import 'package:build_tool/src/builder.dart';
import 'package:build_tool/src/cargo.dart';
import 'package:build_tool/src/options.dart';
import 'package:build_tool/src/precompile_binaries.dart';
import 'package:build_tool/src/precompiled_asset_store.dart';
import 'package:build_tool/src/precompiled_generation.dart';
import 'package:build_tool/src/target.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sourceCommit = '1111111111111111111111111111111111111111';
const _privateSeed = <int>[
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
];

void main() {
  late Directory temp;
  late Target target;
  late KeyPair keyPair;
  late PrecompiledBuildRecipe recipe;
  late BuildEnvironment environment;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('artifacts-provider-test-');
    target = Target.forRustTriple('x86_64-unknown-linux-gnu')!;
    keyPair = newKeyPair();
    recipe = PrecompiledBuildRecipe(
      rustToolchain: '1.88.0',
      flutterVersion: '3.32.8',
      xcodeVersion: '16.4',
      sdkVersions: const {'linux': '6.8'},
      deploymentTargets: const {'linux': 'glibc-2.35'},
      rustTargets: [target.rust],
    );
    environment = BuildEnvironment(
      configuration: BuildConfiguration.release,
      crateOptions: CargokitCrateOptions(
        precompiledBinaries: PrecompiledBinaries(
          uriPrefix: 'https://assets.example/precompiled/',
          publicKey: keyPair.publicKey,
          buildRecipe: recipe,
        ),
      ),
      targetTempDir: temp.path,
      manifestDir: temp.path,
      crateInfo: CrateInfo(packageName: 'fjs'),
      isAndroid: false,
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('disabled mode uses local Rust and never contacts remote', () async {
    var localCalls = 0;
    var remoteCalls = 0;
    final local = await _localArtifact(temp, target, 'local.a');
    final provider = _provider(
      environment,
      PrecompiledBinariesMode.disabled,
      httpGet: (_) async {
        remoteCalls++;
        return Response('', 500);
      },
      localBuilder: (target, _) async {
        localCalls++;
        return [local];
      },
    );

    final result = await provider.getArtifacts([target]);

    expect(result[target]!.single.path, local.path);
    expect(localCalls, 1);
    expect(remoteCalls, 0);
  });

  test('auto mode falls back locally only when completion manifest is absent',
      () async {
    var localCalls = 0;
    var requested = <String>[];
    final local = await _localArtifact(temp, target, 'local.a');
    final provider = _provider(
      environment,
      PrecompiledBinariesMode.auto,
      httpGet: (url) async {
        requested.add(url.path);
        return Response('', 404);
      },
      localBuilder: (target, _) async {
        localCalls++;
        return [local];
      },
    );

    final result = await provider.getArtifacts([target]);

    expect(result[target]!.single.path, local.path);
    expect(localCalls, 1);
    expect(requested, hasLength(1));
    expect(requested.single, contains('completion.json'));
  });

  test('auto mode fails closed when completion is missing for existing cache',
      () async {
    final fixture = _fixture(recipe, target: target, keyPair: keyPair);
    final installProvider = _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async => fixture.responses[url.path] ?? Response('', 404),
    );
    await installProvider.getArtifacts([target]);
    final cacheFile = File(path.join(
      temp.path,
      'precompiled',
      'v2',
      _hash,
      'snapshots',
      PrecompiledAssetStore.requestKey({fixture.assetName}),
      fixture.assetName,
    ));
    cacheFile.writeAsBytesSync([0, 0, 0]);

    final requested = <String>[];
    var localCalls = 0;
    final orphanedProvider = _provider(
      environment,
      PrecompiledBinariesMode.auto,
      httpGet: (url) async {
        requested.add(url.path);
        return Response('', 404);
      },
      localBuilder: (target, _) async {
        localCalls++;
        return const [];
      },
    );

    await expectLater(
      orphanedProvider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );

    expect(cacheFile.readAsBytesSync(), [0, 0, 0]);
    expect(requested, [
      '/precompiled/$_hash/completion.json',
    ]);
    expect(localCalls, 0);
  });

  test('auto 404 fails closed for legacy staging previous and malformed v2',
      () async {
    final precompiledRoot = Directory(path.join(temp.path, 'precompiled'))
      ..createSync();
    final states = <FileSystemEntity>[
      Directory(path.join(precompiledRoot.path, '$_hash.staging-foreign')),
      Directory(path.join(precompiledRoot.path, '$_hash.previous-foreign')),
      File(path.join(precompiledRoot.path, 'v2')),
    ];
    for (final state in states) {
      if (state is Directory) {
        state.createSync();
      } else if (state is File) {
        state.writeAsStringSync('malformed');
      }
      var localCalls = 0;
      final provider = _provider(
        environment,
        PrecompiledBinariesMode.auto,
        httpGet: (_) async => Response('', 404),
        localBuilder: (_, __) async {
          localCalls++;
          return const [];
        },
      );
      await expectLater(
        provider.getArtifacts([target]),
        throwsA(isA<PrecompiledGenerationException>()),
      );
      expect(localCalls, 0);
      if (state.existsSync()) state.deleteSync(recursive: true);
    }
  });

  test(
      'auto mode distinguishes unsupported precompilation from incomplete config',
      () async {
    var localCalls = 0;
    var remoteCalls = 0;
    final local = await _localArtifact(temp, target, 'local.a');
    final noPrecompiled = _withPrecompiled(environment, null);
    final unsupportedProvider = _provider(
      noPrecompiled,
      PrecompiledBinariesMode.auto,
      httpGet: (_) async {
        remoteCalls++;
        return Response('', 500);
      },
      localBuilder: (target, _) async {
        localCalls++;
        return [local];
      },
    );

    final localResult = await unsupportedProvider.getArtifacts([target]);

    expect(localResult[target]!.single.path, local.path);
    expect(localCalls, 1);
    expect(remoteCalls, 0);

    final incompleteConfig = _withPrecompiled(
      environment,
      PrecompiledBinaries(
        uriPrefix: 'https://assets.example/precompiled/',
        publicKey: keyPair.publicKey,
      ),
    );
    final incompleteProvider = _provider(
      incompleteConfig,
      PrecompiledBinariesMode.auto,
      httpGet: (_) async {
        remoteCalls++;
        return Response('', 500);
      },
      localBuilder: (target, _) async {
        localCalls++;
        return [local];
      },
    );
    await expectLater(
      incompleteProvider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );
    expect(localCalls, 1);
    expect(remoteCalls, 0);

    final disabledProvider = _provider(
      incompleteConfig,
      PrecompiledBinariesMode.disabled,
      httpGet: (_) async {
        remoteCalls++;
        return Response('', 500);
      },
      localBuilder: (target, _) async {
        localCalls++;
        return [local];
      },
    );
    final disabledResult = await disabledProvider.getArtifacts([target]);
    expect(disabledResult[target]!.single.path, local.path);
    expect(localCalls, 2);
    expect(remoteCalls, 0);

    final requiredProvider = _provider(
      incompleteConfig,
      PrecompiledBinariesMode.required,
      httpGet: (_) async {
        remoteCalls++;
        return Response('', 500);
      },
      localBuilder: (target, _) async {
        localCalls++;
        return [local];
      },
    );
    await expectLater(
      requiredProvider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );
    expect(localCalls, 2);
    expect(remoteCalls, 0);
  });

  test('required mode fails on missing completion and never invokes local Rust',
      () async {
    var localCalls = 0;
    final provider = _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async => Response('', 404),
      localBuilder: (target, _) async {
        localCalls++;
        return const [];
      },
    );

    await expectLater(
      provider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );
    expect(localCalls, 0);
  });

  test('fetches signed completion first and only exact requested target assets',
      () async {
    final fixture = _fixture(recipe, target: target, keyPair: keyPair);
    final calls = <String>[];
    final provider = _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async {
        calls.add(url.path);
        return fixture.responses[url.path] ?? Response('', 404);
      },
    );

    final result = await provider.getArtifacts([target]);

    expect(result[target], hasLength(1));
    expect(result[target]!.single.finalFileName, 'libfjs.so');
    expect(calls.first, contains('completion.json'));
    expect(calls[1], contains('completion.json.sig'));
    expect(calls.where((call) => call.endsWith('.sig')).length, 2);
    expect(calls, everyElement(isNot(contains('other-target'))));
  });

  test(
      'rejects a requested target outside the signed recipe before asset requests',
      () async {
    final fixture = _fixture(recipe, target: target, keyPair: keyPair);
    final unsupportedTarget =
        Target.forRustTriple('aarch64-unknown-linux-gnu')!;
    final calls = <String>[];
    var localCalls = 0;
    final provider = _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async {
        calls.add(url.path);
        return fixture.responses[url.path] ?? Response('', 404);
      },
      localBuilder: (target, _) async {
        localCalls++;
        return const [];
      },
    );

    await expectLater(
      provider.getArtifacts([unsupportedTarget]),
      throwsA(isA<PrecompiledGenerationException>()),
    );

    expect(calls, isEmpty);
    expect(localCalls, 0);
  });

  test('target-only request does not download unrelated composite assets',
      () async {
    final group = _compositeGroup(target);
    final compositeEnvironment = _withPrecompiled(
      environment,
      PrecompiledBinaries(
        uriPrefix: 'https://assets.example/precompiled/',
        publicKey: keyPair.publicKey,
        buildRecipe: recipe,
        compositeGroups: [group],
      ),
    );
    final fixture = _fixture(
      recipe,
      target: target,
      keyPair: keyPair,
      includeComposite: true,
    );
    final calls = <String>[];
    var localCalls = 0;
    final provider = _provider(
      compositeEnvironment,
      PrecompiledBinariesMode.auto,
      httpGet: (url) async {
        calls.add(url.path);
        return fixture.responses[url.path] ?? Response('', 404);
      },
      localBuilder: (target, _) async {
        localCalls++;
        return const [];
      },
    );

    final result = await provider.getArtifacts([target]);

    expect(result[target], hasLength(1));
    expect(calls, isNot(contains(endsWith('/fjs.xcframework.zip'))));
    expect(calls, isNot(contains(endsWith('/fjs.xcframework.zip.checksum'))));
    expect(localCalls, 0);
  });

  test('revalidates immutable snapshot on every use and never repairs tamper',
      () async {
    final fixture = _fixture(recipe, target: target, keyPair: keyPair);
    var assetRequests = 0;
    final provider = _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async {
        if (url.path.endsWith('.so') || url.path.endsWith('.so.sig')) {
          assetRequests++;
        }
        return fixture.responses[url.path] ?? Response('', 404);
      },
    );
    await provider.getArtifacts([target]);
    final cacheFile = File(path.join(
      temp.path,
      'precompiled',
      'v2',
      _hash,
      'snapshots',
      PrecompiledAssetStore.requestKey({fixture.assetName}),
      fixture.assetName,
    ));
    cacheFile.writeAsBytesSync([0, 0, 0]);

    await expectLater(
      provider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );

    expect(cacheFile.readAsBytesSync(), [0, 0, 0]);
    expect(assetRequests, 2);
  });

  test(
      'tampered cache plus invalid remote repair fails closed without local Rust',
      () async {
    final fixture = _fixture(recipe, target: target, keyPair: keyPair);
    final initialProvider = _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async => fixture.responses[url.path] ?? Response('', 404),
    );
    await initialProvider.getArtifacts([target]);
    final cacheFile = File(path.join(
      temp.path,
      'precompiled',
      'v2',
      _hash,
      'snapshots',
      PrecompiledAssetStore.requestKey({fixture.assetName}),
      fixture.assetName,
    ));
    cacheFile.writeAsBytesSync([0, 0, 0]);

    final invalidRemote = Map<String, Response>.from(fixture.responses);
    final signaturePath = invalidRemote.keys
        .firstWhere((key) => key.endsWith('${fixture.assetName}.sig'));
    invalidRemote[signaturePath] = Response.bytes(Uint8List(64), 200);
    var localCalls = 0;
    final repairProvider = _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async => invalidRemote[url.path] ?? Response('', 404),
      localBuilder: (target, _) async {
        localCalls++;
        return const [];
      },
    );

    await expectLater(
      repairProvider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );

    expect(cacheFile.readAsBytesSync(), [0, 0, 0]);
    expect(localCalls, 0);
  });

  test('tampered manifest anchor remains unchanged and never builds locally',
      () async {
    final fixture = _fixture(recipe, target: target, keyPair: keyPair);
    await _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async => fixture.responses[url.path] ?? Response('', 404),
    ).getArtifacts([target]);
    final anchor = File(path.join(
      temp.path,
      'precompiled',
      'v2',
      _hash,
      'anchor',
      precompiledGenerationManifestFileName,
    ))
      ..writeAsBytesSync([0]);
    var localCalls = 0;

    await expectLater(
      _provider(
        environment,
        PrecompiledBinariesMode.auto,
        httpGet: (url) async =>
            fixture.responses[url.path] ?? Response('', 404),
        localBuilder: (_, __) async {
          localCalls++;
          return const [];
        },
      ).getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );

    expect(anchor.readAsBytesSync(), [0]);
    expect(localCalls, 0);
  });

  test(
      'partial or signature-invalid remote generation fails closed without local fallback',
      () async {
    final fixture = _fixture(recipe, target: target, keyPair: keyPair);
    var localCalls = 0;
    final missingAssetResponses = Map<String, Response>.from(fixture.responses)
      ..removeWhere((key, _) => key.endsWith('.so'));
    final provider = _provider(
      environment,
      PrecompiledBinariesMode.auto,
      httpGet: (url) async =>
          missingAssetResponses[url.path] ?? Response('', 404),
      localBuilder: (target, _) async {
        localCalls++;
        return const [];
      },
    );
    await expectLater(
      provider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );
    expect(localCalls, 0);

    final badSignatureResponses = Map<String, Response>.from(fixture.responses);
    final signaturePath =
        badSignatureResponses.keys.firstWhere((key) => key.endsWith('.so.sig'));
    badSignatureResponses[signaturePath] = Response.bytes(Uint8List(64), 200);
    final badProvider = _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async =>
          badSignatureResponses[url.path] ?? Response('', 404),
      localBuilder: (target, _) async {
        localCalls++;
        return const [];
      },
    );
    await expectLater(
      badProvider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );
    expect(localCalls, 0);
  });

  test('download failure leaves anchor but no partial snapshot staging',
      () async {
    final fixture = _fixture(recipe, target: target, keyPair: keyPair);
    final responses = Map<String, Response>.from(fixture.responses);
    final assetPath = responses.keys.firstWhere((key) => key.endsWith('.so'));
    responses[assetPath] = Response.bytes([1, 2, 3], 200);
    final provider = _provider(
      environment,
      PrecompiledBinariesMode.required,
      httpGet: (url) async => responses[url.path] ?? Response('', 404),
    );

    await expectLater(
      provider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );
    final generation =
        Directory(path.join(temp.path, 'precompiled', 'v2', _hash));
    expect(
        Directory(path.join(generation.path, 'anchor')).existsSync(), isTrue);
    expect(
      Directory(path.join(generation.path, 'snapshots'))
          .listSync(followLinks: false)
          .where((entity) => path.basename(entity.path).contains('.staging-')),
      isEmpty,
    );
  });

  test('creates and closes a fresh transport for every remote lookup',
      () async {
    final fixture = _fixture(recipe, target: target, keyPair: keyPair);
    final transports = <_TrackingTransport>[];
    final provider = ArtifactProvider(
      environment: environment,
      userOptions: CargokitUserOptions(
        precompiledBinariesMode: PrecompiledBinariesMode.required,
        verboseLogging: false,
      ),
      generationHash: (_) => _hash,
      transportFactory: () {
        final transport = _TrackingTransport(
          (request) async => _streamedResponse(
            fixture.responses[request.url.path] ?? Response('', 404),
            request,
          ),
        );
        transports.add(transport);
        return transport;
      },
    );

    await provider.getArtifacts([target]);
    await provider.getArtifacts([target]);

    expect(transports, hasLength(2));
    expect(transports.map((transport) => transport.closeCalls), [1, 1]);
  });

  test('closes its transport when a remote lookup fails', () async {
    _TrackingTransport? transport;
    final provider = ArtifactProvider(
      environment: environment,
      userOptions: CargokitUserOptions(
        precompiledBinariesMode: PrecompiledBinariesMode.required,
        verboseLogging: false,
      ),
      generationHash: (_) => _hash,
      transportFactory: () => transport = _TrackingTransport(
        (_) async => StreamedResponse(
          const Stream<List<int>>.empty(),
          500,
        ),
      ),
    );

    await expectLater(
      provider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );

    expect(transport!.closeCalls, 1);
  });

  test('validates the complete recipe before creating a transport', () async {
    final invalidRecipe = PrecompiledBuildRecipe(
      rustToolchain: recipe.rustToolchain,
      flutterVersion: recipe.flutterVersion,
      xcodeVersion: recipe.xcodeVersion,
      sdkVersions: recipe.sdkVersions,
      deploymentTargets: recipe.deploymentTargets,
      rustTargets: [target.rust, 'unsupported-target'],
    );
    final invalidEnvironment = _withPrecompiled(
      environment,
      PrecompiledBinaries(
        uriPrefix: 'https://assets.example/precompiled/',
        publicKey: keyPair.publicKey,
        buildRecipe: invalidRecipe,
      ),
    );
    var transports = 0;
    final provider = ArtifactProvider(
      environment: invalidEnvironment,
      userOptions: CargokitUserOptions(
        precompiledBinariesMode: PrecompiledBinariesMode.required,
        verboseLogging: false,
      ),
      generationHash: (_) => _hash,
      transportFactory: () {
        transports++;
        return PrecompiledAssetTransport(
          send: (_) async =>
              StreamedResponse(const Stream<List<int>>.empty(), 500),
        );
      },
    );

    await expectLater(
      provider.getArtifacts([target]),
      throwsA(isA<PrecompiledGenerationException>()),
    );

    expect(transports, 0);
  });
}

class _TrackingTransport extends PrecompiledAssetTransport {
  _TrackingTransport(PrecompiledHttpSend send) : super(send: send);

  var closeCalls = 0;

  @override
  void close() {
    closeCalls++;
    super.close();
  }
}

StreamedResponse _streamedResponse(Response response, BaseRequest request) {
  return StreamedResponse(
    Stream.value(response.bodyBytes),
    response.statusCode,
    contentLength: response.bodyBytes.length,
    headers: response.headers,
    reasonPhrase: response.reasonPhrase,
    request: request,
    isRedirect: response.isRedirect,
  );
}

ArtifactProvider _provider(
  BuildEnvironment environment,
  PrecompiledBinariesMode mode, {
  required ArtifactHttpGet httpGet,
  ArtifactLocalBuilder? localBuilder,
}) {
  return ArtifactProvider(
    environment: environment,
    userOptions: CargokitUserOptions(
      precompiledBinariesMode: mode,
      verboseLogging: false,
    ),
    httpGet: httpGet,
    generationHash: (_) => _hash,
    localBuilder: localBuilder,
  );
}

Future<Artifact> _localArtifact(
    Directory temp, Target target, String name) async {
  final file = File(path.join(temp.path, name))..writeAsBytesSync([1]);
  return Artifact(path: file.path, finalFileName: name);
}

class _Fixture {
  _Fixture(
      {required this.responses,
      required this.assetName,
      required this.assetBytes});
  final Map<String, Response> responses;
  final String assetName;
  final Uint8List assetBytes;
}

_Fixture _fixture(
  PrecompiledBuildRecipe recipe, {
  required Target target,
  required KeyPair keyPair,
  bool includeComposite = false,
}) {
  final assetName = PrecompileBinaries.fileName(target, 'libfjs.so');
  final assetBytes = Uint8List.fromList([5, 4, 3, 2]);
  final staticAssetName = PrecompileBinaries.fileName(target, 'libfjs.a');
  final staticAssetBytes = Uint8List.fromList([4, 3, 2, 1]);
  final archiveBytes = Uint8List.fromList([8, 7, 6, 5]);
  final checksumText = sha256Bytes(archiveBytes);
  final checksumBytes = Uint8List.fromList(utf8.encode('$checksumText\n'));
  final assets = <PrecompiledAsset>[
    PrecompiledAsset(
      name: assetName,
      length: assetBytes.length,
      sha256: sha256Bytes(assetBytes),
    ),
    PrecompiledAsset(
      name: staticAssetName,
      length: staticAssetBytes.length,
      sha256: sha256Bytes(staticAssetBytes),
    ),
    if (includeComposite) ...[
      PrecompiledAsset(
        name: 'fjs.xcframework.zip',
        length: archiveBytes.length,
        sha256: sha256Bytes(archiveBytes),
      ),
      PrecompiledAsset(
        name: 'fjs.xcframework.zip.checksum',
        length: checksumBytes.length,
        sha256: sha256Bytes(checksumBytes),
      ),
    ],
  ]..sort((a, b) => a.name.compareTo(b.name));
  final manifest = PrecompiledGenerationManifest(
    generationHash: _hash,
    sourceCommit: _sourceCommit,
    provenance: PrecompiledGenerationProvenance.fromRecipe(recipe),
    assets: assets,
    compositeChecksums: includeComposite
        ? const [
            PrecompiledCompositeChecksum(
              archive: 'fjs.xcframework.zip',
              checksum: 'fjs.xcframework.zip.checksum',
            ),
          ]
        : const [],
  );
  final prefix = 'https://assets.example/precompiled/$_hash/';
  return _Fixture(
    assetName: assetName,
    assetBytes: assetBytes,
    responses: {
      '/precompiled/$_hash/completion.json.sig':
          Response.bytes(manifest.sign(keyPair.privateKey), 200),
      '/precompiled/$_hash/completion.json':
          Response.bytes(manifest.canonicalBytes(), 200),
      '/precompiled/$_hash/$assetName.sig': Response.bytes(
          signPrecompiledAssetMetadata(
            keyPair.privateKey,
            generationHash: _hash,
            name: assetName,
            length: assetBytes.length,
            sha256: sha256Bytes(assetBytes),
          ),
          200),
      '/precompiled/$_hash/$assetName': Response.bytes(assetBytes, 200),
      if (includeComposite) ...{
        '/precompiled/$_hash/fjs.xcframework.zip.sig': Response.bytes(
          signPrecompiledAssetMetadata(
            keyPair.privateKey,
            generationHash: _hash,
            name: 'fjs.xcframework.zip',
            length: archiveBytes.length,
            sha256: sha256Bytes(archiveBytes),
          ),
          200,
        ),
        '/precompiled/$_hash/fjs.xcframework.zip':
            Response.bytes(archiveBytes, 200),
        '/precompiled/$_hash/fjs.xcframework.zip.checksum.sig': Response.bytes(
          signPrecompiledAssetMetadata(
            keyPair.privateKey,
            generationHash: _hash,
            name: 'fjs.xcframework.zip.checksum',
            length: checksumBytes.length,
            sha256: sha256Bytes(checksumBytes),
          ),
          200,
        ),
        '/precompiled/$_hash/fjs.xcframework.zip.checksum':
            Response.bytes(checksumBytes, 200),
      },
      prefix: Response('', 404),
    },
  );
}

BuildEnvironment _withPrecompiled(
  BuildEnvironment environment,
  PrecompiledBinaries? precompiled,
) {
  return BuildEnvironment(
    configuration: environment.configuration,
    crateOptions: CargokitCrateOptions(precompiledBinaries: precompiled),
    targetTempDir: environment.targetTempDir,
    manifestDir: environment.manifestDir,
    crateInfo: environment.crateInfo,
    isAndroid: environment.isAndroid,
    androidSdkPath: environment.androidSdkPath,
    androidNdkVersion: environment.androidNdkVersion,
    androidMinSdkVersion: environment.androidMinSdkVersion,
    javaHome: environment.javaHome,
  );
}

CompositeGroup _compositeGroup(Target target) {
  return CompositeGroup(
    name: 'swiftpm',
    host: CompositeHost.linux,
    requiredTargets: [target.rust],
    argv: const ['tool/build.sh'],
    environment: const {},
    timeout: const Duration(minutes: 1),
    outputs: const [
      'fjs.xcframework.zip',
      'fjs.xcframework.zip.checksum',
    ],
  );
}

String sha256Bytes(List<int> bytes) => sha256.convert(bytes).toString();

KeyPair newKeyPair() {
  final private = newKeyFromSeed(Uint8List.fromList(_privateSeed));
  return KeyPair(private, public(private));
}
