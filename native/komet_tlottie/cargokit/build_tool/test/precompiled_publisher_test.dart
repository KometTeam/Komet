import 'dart:io';
import 'dart:typed_data';

import 'package:build_tool/src/builder.dart';
import 'package:build_tool/src/options.dart';
import 'package:build_tool/src/precompile_binaries.dart';
import 'package:build_tool/src/precompiled_asset_store.dart';
import 'package:build_tool/src/precompiled_generation.dart';
import 'package:build_tool/src/target.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:github/github.dart' as github;
import 'package:hex/hex.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late Directory manifestDir;
  late KeyPair keyPair;

  setUp(() {
    temp = Directory(Directory.systemTemp.resolveSymbolicLinksSync())
        .createTempSync('precompiled-publisher-test.');
    manifestDir = Directory(path.join(temp.path, 'crate'))..createSync();
    final privateKey = newKeyFromSeed(
      Uint8List.fromList(List<int>.generate(32, (index) => index)),
    );
    keyPair = KeyPair(privateKey, public(privateKey));
    _writeCrate(manifestDir, HEX.encode(keyPair.publicKey.bytes));
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('finalizer output is accepted by the v2 store without extra assets',
      () async {
    final finalized = await _finalize(temp, manifestDir, keyPair);

    final remote = <String, List<int>>{
      for (final entry in finalized.publicationFiles.entries)
        entry.key: entry.value.readAsBytesSync(),
    };
    final requests = <String>[];
    final transport = PrecompiledAssetTransport(send: (request) async {
      final name = request.url.pathSegments.last;
      requests.add(name);
      final bytes = remote[name];
      return StreamedResponse(
        Stream.value(bytes ?? const <int>[]),
        bytes == null ? 404 : 200,
        contentLength: bytes?.length ?? 0,
      );
    });
    final options = CargokitCrateOptions.load(manifestDir: manifestDir.path);
    final recipe = options.precompiledBinaries!.buildRecipe!;
    final store = PrecompiledAssetStore(
      cacheRoot: path.join(temp.path, 'cache'),
      uriPrefix: Uri.parse('https://assets.example/precompiled_'),
      publicKey: keyPair.publicKey,
      recipe: recipe,
      expectedAssetNames:
          finalized.manifest.assets.map((asset) => asset.name).toSet(),
      expectedCompositeChecksums: const {},
      transport: transport,
    );

    final requested =
        '${Target.forRustTriple('x86_64-unknown-linux-gnu')!.rust}_libfjs.a';
    final snapshot = await store.snapshot(
      generationHash: finalized.manifest.generationHash,
      requestedAssetNames: {requested},
    );

    expect(File(snapshot!.pathFor(requested)).readAsStringSync(), 'static');
    expect(requests, isNot(contains(endsWith('_libfjs.so'))));
    transport.close();
  });

  test('publisher uploads completion last, reuses valid, and rejects mismatch',
      () async {
    final finalized = await _finalize(temp, manifestDir, keyPair);
    final gateway = _FakeReleaseGateway();
    final publisher = PrecompiledGenerationPublisher(
      generation: finalized,
      gateway: gateway,
    );

    final first = await publisher.publish();

    expect(first.reused, isFalse);
    expect(gateway.events.sublist(gateway.events.length - 3), [
      'upload:completion.json',
      'upload:completion.json.sig',
      'publish',
    ]);
    gateway.events.clear();

    final reused = await publisher.publish();

    expect(reused.reused, isTrue);
    expect(
        gateway.events.where((event) => event.startsWith('upload:')), isEmpty);
    gateway.corrupt('completion.json');
    await expectLater(
      publisher.publish(),
      throwsA(isA<PrecompiledGenerationException>()),
    );
  });

  test('GitHub gateway downloads an authenticated release asset', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url,
        Uri.parse(
          'https://api.github.com/repos/fluttercandies/fjs/releases/assets/42',
        ),
      );
      expect(request.headers['Accept'], 'application/octet-stream');
      expect(request.headers['Authorization'], isNotEmpty);
      expect(request.headers['User-Agent'], isNotEmpty);
      return Response.bytes(const [1, 2, 3], 200);
    });
    final githubClient = github.GitHub(
      auth: const github.Authentication.withToken('token'),
      client: client,
    );
    addTearDown(githubClient.dispose);
    final gateway = GitHubPrecompiledReleaseGateway(
      repositories: githubClient.repositories,
      repository: github.RepositorySlug('fluttercandies', 'fjs'),
    );
    final release = PrecompiledRelease(
      id: github.Release(
        id: 7,
        assets: [github.ReleaseAsset(id: 42, name: 'completion.json')],
      ),
      tagName: 'precompiled_hash',
      isDraft: false,
      assetNames: const {'completion.json'},
    );

    expect(
      await gateway.readAsset(release, 'completion.json'),
      const [1, 2, 3],
    );
  });
}

Future<FinalizedPrecompiledGeneration> _finalize(
  Directory temp,
  Directory manifestDir,
  KeyPair keyPair,
) async {
  final generationDir = path.join(temp.path, 'generation');
  await LocalPrecompiledGeneration(
    manifestDir: manifestDir.path,
    outputDir: generationDir,
    tempDir: path.join(temp.path, 'build'),
    targetTriples: const ['x86_64-unknown-linux-gnu'],
    targetBuilder: _buildTarget,
  ).run();
  return LocalGenerationFinalizer(
    manifestDir: manifestDir.path,
    generationDir: generationDir,
    privateKey: keyPair.privateKey,
    scope: LocalGenerationFinalizationScope.full,
    sourceCommit: '1111111111111111111111111111111111111111',
  ).run();
}

class _FakeReleaseGateway implements PrecompiledReleaseGateway {
  PrecompiledRelease? release;
  final assets = <String, List<int>>{};
  final events = <String>[];

  @override
  Future<PrecompiledRelease?> find(String tagName) async => release;

  @override
  Future<PrecompiledRelease> createDraft(String tagName) async {
    events.add('create-draft');
    return release = PrecompiledRelease(
      id: 'release',
      tagName: tagName,
      isDraft: true,
      assetNames: assets.keys.toSet(),
    );
  }

  @override
  Future<List<int>> readAsset(PrecompiledRelease release, String name) async =>
      assets[name]!;

  @override
  Future<void> upload(
    PrecompiledRelease release,
    String name,
    List<int> bytes,
  ) async {
    events.add('upload:$name');
    assets[name] = List.of(bytes);
    this.release = PrecompiledRelease(
      id: release.id,
      tagName: release.tagName,
      isDraft: true,
      assetNames: assets.keys.toSet(),
    );
  }

  @override
  Future<void> publish(PrecompiledRelease release) async {
    events.add('publish');
    this.release = PrecompiledRelease(
      id: release.id,
      tagName: release.tagName,
      isDraft: false,
      assetNames: assets.keys.toSet(),
    );
  }

  void corrupt(String name) => assets[name]![0] ^= 1;
}

Future<String> _buildTarget(
  Target target,
  BuildEnvironment environment,
  String toolchain,
) async {
  final output = Directory(path.join(environment.targetTempDir, target.rust))
    ..createSync(recursive: true);
  File(path.join(output.path, 'libfjs.a')).writeAsStringSync('static');
  File(path.join(output.path, 'libfjs.so')).writeAsStringSync('dynamic');
  return output.path;
}

void _writeCrate(Directory manifestDir, String publicKey) {
  File(path.join(manifestDir.path, 'Cargo.toml')).writeAsStringSync('''
[package]
name = "fjs"
version = "1.0.0"
''');
  Directory(path.join(manifestDir.path, 'src')).createSync();
  File(path.join(manifestDir.path, 'src/lib.rs'))
      .writeAsStringSync('pub fn fjs() {}\n');
  File(path.join(manifestDir.path, 'cargokit.yaml')).writeAsStringSync('''
precompiled_binaries:
  url_prefix: https://assets.example/precompiled_
  public_key: $publicKey
  workspace_root: .
  build_recipe:
    rust_toolchain: '1.88.0'
    flutter_version: '3.32.8'
    xcode_version: '16.4'
    sdk_versions:
      linux: '6.8'
    deployment_targets:
      linux: 'glibc-2.35'
    rust_targets:
      - x86_64-unknown-linux-gnu
''');
}
