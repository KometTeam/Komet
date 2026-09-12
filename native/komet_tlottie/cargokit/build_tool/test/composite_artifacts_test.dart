import 'dart:convert';
import 'dart:io';

import 'package:build_tool/src/build_tool.dart';
import 'package:build_tool/src/builder.dart';
import 'package:build_tool/src/composite_artifacts.dart';
import 'package:build_tool/src/options.dart';
import 'package:build_tool/src/precompile_binaries.dart';
import 'package:build_tool/src/target.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late Directory workspace;
  late Directory targetRoot;
  late CompositeGroup group;

  setUp(() {
    final systemTemp =
        Directory(Directory.systemTemp.resolveSymbolicLinksSync());
    temp = systemTemp.createTempSync('composite-artifacts-test.');
    workspace = Directory(path.join(temp.path, 'workspace'))..createSync();
    targetRoot = Directory(path.join(temp.path, 'targets'))..createSync();
    File(path.join(workspace.path, 'assemble.sh'))
        .writeAsStringSync('#!/bin/sh\n');
    Directory(path.join(targetRoot.path, 'aarch64-apple-ios')).createSync();
    group = CompositeGroup(
      name: 'swiftpm',
      host: CompositeHost.macos,
      requiredTargets: const ['aarch64-apple-ios'],
      argv: const ['assemble.sh', r'$literal'],
      environment: const {'LC_ALL': 'C', 'PATH': '/usr/bin:/bin'},
      timeout: const Duration(seconds: 3),
      outputs: const ['bundle.zip', 'bundle.zip.checksum'],
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('local generation command requires explicit paths and repeats targets',
      () {
    final command = BuildPrecompiledGenerationCommand();
    final arguments = command.argParser.parse(const [
      '--manifest-dir',
      '/manifest',
      '--output-dir',
      '/output',
      '--temp-dir',
      '/temp',
      '--target',
      'aarch64-apple-ios',
      '--target',
      'aarch64-apple-darwin',
    ]);

    expect(command.name, 'build-precompiled-generation');
    expect(arguments['manifest-dir'], '/manifest');
    expect(arguments['output-dir'], '/output');
    expect(arguments['temp-dir'], '/temp');
    expect(arguments['target'], [
      'aarch64-apple-ios',
      'aarch64-apple-darwin',
    ]);
  });

  test('composite uses controlled argv/env and atomically retains outputs',
      () async {
    CompositeProcessInvocation? invocation;
    final outputRoot = path.join(temp.path, 'output');
    final builder = CompositeArtifactBuilder(
      workspaceRoot: workspace.path,
      generationHash: 'generation-hash',
      targetOutputRoot: targetRoot.path,
      outputRoot: outputRoot,
      currentHost: CompositeHost.macos,
      processRunner: (value) async {
        invocation = value;
        final output = Directory(value.environment['CARGOKIT_OUTPUT_ROOT']!);
        File(path.join(output.path, 'bundle.zip')).writeAsBytesSync([1, 2, 3]);
        File(path.join(output.path, 'bundle.zip.checksum'))
            .writeAsStringSync('checksum\n');
        return const CompositeProcessResult(exitCode: 0);
      },
    );

    final result = await builder.build(group);

    expect(invocation!.executable, path.join(workspace.path, 'assemble.sh'));
    expect(invocation!.arguments, [r'$literal']);
    expect(invocation!.workingDirectory, workspace.path);
    expect(invocation!.timeout, const Duration(seconds: 3));
    expect(invocation!.environment, {
      'LC_ALL': 'C',
      'PATH': '/usr/bin:/bin',
      'CARGOKIT_GENERATION_HASH': 'generation-hash',
      'CARGOKIT_WORKSPACE_ROOT': workspace.path,
      'CARGOKIT_TARGET_OUTPUT_ROOT': targetRoot.path,
      'CARGOKIT_OUTPUT_ROOT': isNotEmpty,
      'CARGOKIT_DART_EXECUTABLE': Platform.resolvedExecutable,
    });
    expect(File(result.outputs['bundle.zip']!).readAsBytesSync(), [1, 2, 3]);
    expect(
      Directory(outputRoot).listSync(recursive: true).where(
          (entity) => path.basename(entity.path).startsWith('.swiftpm.')),
      isEmpty,
    );
  });

  test('composite rejects host/target, timeout, nonzero, and missing output',
      () async {
    Future<void> expectFailure(
      String name,
      CompositeProcessResult result,
    ) async {
      final builder = CompositeArtifactBuilder(
        workspaceRoot: workspace.path,
        generationHash: 'generation-hash',
        targetOutputRoot: targetRoot.path,
        outputRoot: path.join(temp.path, name),
        currentHost: CompositeHost.macos,
        processRunner: (_) async => result,
      );
      await expectLater(
        builder.build(group),
        throwsA(isA<CompositeArtifactException>()),
      );
    }

    final wrongHost = CompositeArtifactBuilder(
      workspaceRoot: workspace.path,
      generationHash: 'generation-hash',
      targetOutputRoot: targetRoot.path,
      outputRoot: path.join(temp.path, 'wrong-host'),
      currentHost: CompositeHost.linux,
    );
    await expectLater(
      wrongHost.build(group),
      throwsA(isA<CompositeArtifactException>()),
    );
    Directory(path.join(targetRoot.path, 'aarch64-apple-ios'))
        .deleteSync(recursive: true);
    final missingTarget = CompositeArtifactBuilder(
      workspaceRoot: workspace.path,
      generationHash: 'generation-hash',
      targetOutputRoot: targetRoot.path,
      outputRoot: path.join(temp.path, 'missing-target'),
      currentHost: CompositeHost.macos,
    );
    await expectLater(
      missingTarget.build(group),
      throwsA(isA<CompositeArtifactException>()),
    );
    Directory(path.join(targetRoot.path, 'aarch64-apple-ios')).createSync();

    await expectFailure(
      'timeout',
      const CompositeProcessResult(exitCode: -1, timedOut: true),
    );
    await expectFailure(
      'nonzero',
      const CompositeProcessResult(exitCode: 9, stderr: 'failed'),
    );
    await expectFailure(
      'missing-output',
      const CompositeProcessResult(exitCode: 0),
    );
  });

  test(
      'local generation builds targets once, retains both forms, and is deterministic',
      () async {
    _writeCrate(workspace);
    final buildCalls = <String, int>{};
    var compositeCalls = 0;

    Future<String> buildTarget(
      Target target,
      BuildEnvironment environment,
      String toolchain,
    ) async {
      expect(toolchain, '1.88.0');
      buildCalls.update(target.rust, (value) => value + 1, ifAbsent: () => 1);
      final output =
          Directory(path.join(environment.targetTempDir, target.rust))
            ..createSync(recursive: true);
      File(path.join(output.path, 'libfjs.a'))
          .writeAsStringSync('static:${target.rust}');
      File(path.join(output.path, 'libfjs.dylib'))
          .writeAsStringSync('dynamic:${target.rust}');
      return output.path;
    }

    Future<CompositeProcessResult> assemble(
        CompositeProcessInvocation invocation) async {
      compositeCalls++;
      final output = Directory(invocation.environment['CARGOKIT_OUTPUT_ROOT']!);
      File(path.join(output.path, 'bundle.zip')).writeAsStringSync('archive');
      File(path.join(output.path, 'bundle.zip.checksum'))
          .writeAsStringSync('checksum\n');
      return const CompositeProcessResult(exitCode: 0);
    }

    final output = path.join(temp.path, 'generation');
    final generator = LocalPrecompiledGeneration(
      manifestDir: workspace.path,
      outputDir: output,
      tempDir: path.join(temp.path, 'build'),
      targetTriples: const [
        'aarch64-apple-ios',
        'aarch64-apple-darwin',
      ],
      targetBuilder: buildTarget,
      currentHost: CompositeHost.macos,
      compositeProcessRunner: assemble,
    );

    final firstFragment = await generator.run();
    final firstBytes = firstFragment.readAsBytesSync();
    expect(buildCalls, {
      'aarch64-apple-ios': 1,
      'aarch64-apple-darwin': 1,
    });
    expect(compositeCalls, 1);
    final secondFragment = await generator.run();

    expect(buildCalls, {
      'aarch64-apple-ios': 2,
      'aarch64-apple-darwin': 2,
    });
    expect(compositeCalls, 2);
    expect(secondFragment.readAsBytesSync(), firstBytes);
    for (final target in buildCalls.keys) {
      expect(
        File(path.join(output, 'targets', target, '${target}_libfjs.a'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(path.join(output, 'targets', target, '${target}_libfjs.dylib'))
            .existsSync(),
        isTrue,
      );
    }
    final fragment =
        jsonDecode(utf8.decode(firstBytes)) as Map<String, dynamic>;
    expect(fragment['schema_version'], 1);
    expect(fragment['scope'], 'cargokit-local-precompiled-generation');
    expect(fragment['generation_hash'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect((fragment['recipe'] as Map)['rust_toolchain'], '1.88.0');
    expect(fragment['assets'], hasLength(6));
    expect(fragment.containsKey('signature'), isFalse);
  });

  test('local generation rejects duplicate, unknown, and unpinned targets',
      () async {
    _writeCrate(workspace);

    Future<void> rejects(List<String> targets, String suffix) async {
      final generator = LocalPrecompiledGeneration(
        manifestDir: workspace.path,
        outputDir: path.join(temp.path, 'invalid-$suffix'),
        tempDir: path.join(temp.path, 'invalid-build-$suffix'),
        targetTriples: targets,
        targetBuilder: (_, __, ___) => throw StateError('must not build'),
        currentHost: CompositeHost.macos,
      );
      await expectLater(
        generator.run(),
        throwsA(isA<ArgumentError>()),
      );
    }

    await rejects(
      const ['aarch64-apple-ios', 'aarch64-apple-ios'],
      'duplicate',
    );
    await rejects(const ['invented-target'], 'unknown');
    await rejects(const ['x86_64-apple-ios'], 'unpinned');
    await rejects(const ['aarch64-apple-ios'], 'incomplete-composite');
  });
}

void _writeCrate(Directory workspace) {
  File(path.join(workspace.path, 'Cargo.toml')).writeAsStringSync('''
[package]
name = "fjs"
version = "1.0.0"
''');
  Directory(path.join(workspace.path, 'src')).createSync();
  File(path.join(workspace.path, 'src/lib.rs'))
      .writeAsStringSync('pub fn fjs() {}\n');
  File(path.join(workspace.path, 'cargokit.yaml')).writeAsStringSync('''
precompiled_binaries:
  url_prefix: https://example.com/precompiled_
  public_key: a4c3433798eb2c36edf2b94dbb4dd899d57496ca373a8982d8a792410b7f6445
  workspace_root: .
  build_recipe:
    rust_toolchain: '1.88.0'
    flutter_version: '3.32.8'
    xcode_version: '16.4'
    sdk_versions:
      iphoneos: '18.5'
      macosx: '15.5'
    deployment_targets:
      ios: '12.0'
      macos: '10.14'
    rust_targets:
      - aarch64-apple-ios
      - aarch64-apple-darwin
  composite_groups:
    - name: swiftpm
      host: macos
      required_targets:
        - aarch64-apple-ios
        - aarch64-apple-darwin
      argv:
        - assemble.sh
        - --retained
      environment:
        LC_ALL: C
        PATH: /usr/bin:/bin
      timeout_seconds: 3
      outputs:
        - bundle.zip
        - bundle.zip.checksum
''');
}
