import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'options.dart';

class CompositeArtifactException implements Exception {
  CompositeArtifactException(this.message);

  final String message;

  @override
  String toString() => 'CompositeArtifactException: $message';
}

class CompositeProcessInvocation {
  const CompositeProcessInvocation({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
    required this.timeout,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String> environment;
  final Duration timeout;
}

class CompositeProcessResult {
  const CompositeProcessResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.timedOut = false,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;
}

typedef CompositeProcessRunner = Future<CompositeProcessResult> Function(
  CompositeProcessInvocation invocation,
);

class CompositeArtifactResult {
  CompositeArtifactResult(this.outputs);

  final Map<String, String> outputs;
}

class CompositeArtifactBuilder {
  CompositeArtifactBuilder({
    required String workspaceRoot,
    required this.generationHash,
    required String targetOutputRoot,
    required String outputRoot,
    CompositeHost? currentHost,
    CompositeProcessRunner? processRunner,
  })  : workspaceRoot = path.normalize(path.absolute(workspaceRoot)),
        targetOutputRoot = path.normalize(path.absolute(targetOutputRoot)),
        outputRoot = path.normalize(path.absolute(outputRoot)),
        currentHost = currentHost ?? _platformHost(),
        processRunner = processRunner ?? _runProcess;

  final String workspaceRoot;
  final String generationHash;
  final String targetOutputRoot;
  final String outputRoot;
  final CompositeHost currentHost;
  final CompositeProcessRunner processRunner;

  bool supports(CompositeGroup group, Set<String> targets) =>
      group.host == currentHost &&
      group.requiredTargets.every(targets.contains);

  Future<CompositeArtifactResult> build(CompositeGroup group) async {
    if (group.host != currentHost) {
      throw CompositeArtifactException(
        'Composite group ${group.name} requires host ${group.host.name}.',
      );
    }
    _requireDirectory(workspaceRoot, 'Workspace root');
    _requireDirectory(targetOutputRoot, 'Target output root');
    for (final target in group.requiredTargets) {
      final targetDirectory = path.join(targetOutputRoot, target);
      _requireContainedDirectory(
        targetOutputRoot,
        targetDirectory,
        'Required target output $target',
      );
    }

    final executable = path.normalize(path.joinAll([
      workspaceRoot,
      ...path.posix.split(group.argv.first),
    ]));
    _requireContainedFile(workspaceRoot, executable, 'Composite executable');

    _ensureNoSymlinkComponents(outputRoot, 'Composite output root');
    Directory(outputRoot).createSync(recursive: true);
    _ensureNoSymlinkComponents(outputRoot, 'Composite output root');
    final staging = Directory(path.join(
      outputRoot,
      '.${group.name}.$pid.${DateTime.now().microsecondsSinceEpoch}',
    ))
      ..createSync();
    final finalDirectory = Directory(
      path.join(outputRoot, 'composites', group.name),
    );

    try {
      final environment = <String, String>{
        ...group.environment,
        'CARGOKIT_GENERATION_HASH': generationHash,
        'CARGOKIT_WORKSPACE_ROOT': workspaceRoot,
        'CARGOKIT_TARGET_OUTPUT_ROOT': targetOutputRoot,
        'CARGOKIT_OUTPUT_ROOT': staging.path,
        'CARGOKIT_DART_EXECUTABLE': Platform.resolvedExecutable,
      };
      final result = await processRunner(CompositeProcessInvocation(
        executable: executable,
        arguments: List.unmodifiable(group.argv.skip(1)),
        workingDirectory: workspaceRoot,
        environment: Map.unmodifiable(environment),
        timeout: group.timeout,
      ));
      if (result.timedOut) {
        throw CompositeArtifactException(
          'Composite group ${group.name} timed out.',
        );
      }
      if (result.exitCode != 0) {
        throw CompositeArtifactException(
          'Composite group ${group.name} failed with exit code '
          '${result.exitCode}: ${result.stderr.trim()}',
        );
      }

      for (final output in group.outputs) {
        _requireContainedFile(
          staging.path,
          path.join(staging.path, output),
          'Composite output $output',
        );
      }
      if (FileSystemEntity.typeSync(finalDirectory.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw CompositeArtifactException(
          'Composite output already exists for ${group.name}.',
        );
      }
      finalDirectory.parent.createSync(recursive: true);
      staging.renameSync(finalDirectory.path);
      return CompositeArtifactResult(Map.unmodifiable({
        for (final output in group.outputs)
          output: path.join(finalDirectory.path, output),
      }));
    } on CompositeArtifactException {
      rethrow;
    } on Object catch (error) {
      throw CompositeArtifactException(
        'Composite group ${group.name} could not be built: $error',
      );
    } finally {
      if (staging.existsSync()) staging.deleteSync(recursive: true);
    }
  }

  static Future<CompositeProcessResult> _runProcess(
    CompositeProcessInvocation invocation,
  ) async {
    final process = await Process.start(
      invocation.executable,
      invocation.arguments,
      workingDirectory: invocation.workingDirectory,
      environment: invocation.environment,
      includeParentEnvironment: false,
      runInShell: false,
    );
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    var timedOut = false;
    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(invocation.timeout);
    } on TimeoutException {
      timedOut = true;
      process.kill();
      exitCode = await process.exitCode;
    }
    return CompositeProcessResult(
      exitCode: exitCode,
      stdout: await stdout,
      stderr: await stderr,
      timedOut: timedOut,
    );
  }

  static CompositeHost _platformHost() {
    if (Platform.isMacOS) return CompositeHost.macos;
    if (Platform.isWindows) return CompositeHost.windows;
    return CompositeHost.linux;
  }
}

void _requireDirectory(String value, String description) {
  _ensureNoSymlinkComponents(value, description);
  if (FileSystemEntity.typeSync(value, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw CompositeArtifactException('$description is not a directory: $value');
  }
}

void _requireContainedDirectory(
  String root,
  String value,
  String description,
) {
  _requireContained(root, value, description);
  _requireDirectory(value, description);
}

void _requireContainedFile(String root, String value, String description) {
  _requireContained(root, value, description);
  _ensureNoSymlinkComponents(value, description);
  if (FileSystemEntity.typeSync(value, followLinks: false) !=
      FileSystemEntityType.file) {
    throw CompositeArtifactException('$description is not a file: $value');
  }
}

void _requireContained(String root, String value, String description) {
  final normalizedRoot = path.normalize(path.absolute(root));
  final normalizedValue = path.normalize(path.absolute(value));
  if (!path.isWithin(normalizedRoot, normalizedValue)) {
    throw CompositeArtifactException('$description escapes $normalizedRoot.');
  }
}

void _ensureNoSymlinkComponents(String value, String description) {
  final absolute = path.normalize(path.absolute(value));
  var current = path.rootPrefix(absolute);
  final relative = path.relative(absolute, from: current);
  if (relative == '.') return;
  for (final component in path.split(relative)) {
    current = path.join(current, component);
    if (FileSystemEntity.typeSync(current, followLinks: false) ==
        FileSystemEntityType.link) {
      throw CompositeArtifactException(
        '$description must not contain symbolic links: $current',
      );
    }
  }
}
