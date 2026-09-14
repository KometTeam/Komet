import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build_tool/src/options.dart';
import 'package:build_tool/src/precompiled_asset_store.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Expected one JSON configuration argument.');
    exitCode = 64;
    return;
  }
  final config = (jsonDecode(arguments.single) as Map).cast<String, dynamic>();
  final mode = config['mode'] as String;
  _emit({'event': 'ready', 'mode': mode});
  final commands = StreamIterator(
    stdin.transform(utf8.decoder).transform(const LineSplitter()),
  );
  if (!await commands.moveNext()) return;
  final first = (jsonDecode(commands.current) as Map).cast<String, dynamic>();
  if (first['command'] != 'proceed') {
    _emit({
      'event': 'result',
      'ok': false,
      'path': null,
      'error': 'expected proceed',
    });
    await commands.cancel();
    exitCode = 64;
    return;
  }

  try {
    if (mode == 'install') {
      try {
        final snapshotPath = await _install(config);
        _emit({
          'event': 'result',
          'ok': true,
          'path': snapshotPath,
          'error': null,
        });
      } on Object catch (error) {
        _emit({
          'event': 'result',
          'ok': false,
          'path': null,
          'error': '$error',
        });
        exitCode = 1;
      }
      await commands.cancel();
      return;
    }
    if (!const {
      'hold-generation-lock',
      'hold-request-lock',
      'crash-with-lock',
      'acquire',
    }.contains(mode)) {
      throw ArgumentError.value(mode, 'mode', 'Unsupported worker mode.');
    }
    final lockPath = config['lock_path'] as String;
    final file = File(lockPath)..createSync(recursive: true);
    final lock = file.openSync(mode: FileMode.append);
    if (mode == 'acquire') {
      final acquired = await _acquire(
        lock,
        timeout: Duration(milliseconds: (config['timeout_ms'] as int?) ?? 1000),
        poll: Duration(milliseconds: (config['poll_ms'] as int?) ?? 10),
      );
      _emit({
        'event': 'result',
        'ok': acquired,
        'path': null,
        'error': acquired ? null : 'lock not acquired',
        'acquired': acquired,
      });
      if (acquired) lock.unlockSync();
      lock.closeSync();
      await commands.cancel();
      return;
    }
    lock.lockSync(FileLock.exclusive);
    _emit({
      'event': 'result',
      'ok': true,
      'path': null,
      'error': null,
      'acquired': true,
    });
    if (mode == 'crash-with-lock') {
      exit(23);
    }
    if (await commands.moveNext()) {
      final command =
          (jsonDecode(commands.current) as Map).cast<String, dynamic>();
      if (command['command'] == 'release') {
        lock.unlockSync();
        lock.closeSync();
        await commands.cancel();
        return;
      }
    }
    lock.unlockSync();
    lock.closeSync();
    await commands.cancel();
  } on Object catch (error, stackTrace) {
    _emit({
      'event': 'result',
      'ok': false,
      'path': null,
      'error': '$error',
      'stack': '$stackTrace',
    });
    await commands.cancel();
    exitCode = 1;
  }
}

Future<bool> _acquire(
  RandomAccessFile lock, {
  required Duration timeout,
  required Duration poll,
}) async {
  final stopwatch = Stopwatch()..start();
  while (true) {
    try {
      lock.lockSync(FileLock.exclusive);
      return true;
    } on FileSystemException {
      if (stopwatch.elapsed >= timeout) return false;
      await Future<void>.delayed(poll);
    }
  }
}

Future<String?> _install(Map<String, dynamic> config) async {
  final recipeJson = (config['recipe'] as Map).cast<String, dynamic>();
  final recipe = PrecompiledBuildRecipe(
    rustToolchain: recipeJson['rust_toolchain'] as String,
    flutterVersion: recipeJson['flutter_version'] as String,
    xcodeVersion: recipeJson['xcode_version'] as String,
    sdkVersions: (recipeJson['sdk_versions'] as Map).cast<String, String>(),
    deploymentTargets:
        (recipeJson['deployment_targets'] as Map).cast<String, String>(),
    rustTargets: (recipeJson['rust_targets'] as List).cast<String>(),
  );
  final transport = PrecompiledAssetTransport();
  try {
    final store = PrecompiledAssetStore(
      cacheRoot: config['cache_root'] as String,
      uriPrefix: Uri.parse(config['uri_prefix'] as String),
      publicKey: PublicKey((config['public_key'] as List).cast<int>()),
      recipe: recipe,
      expectedAssetNames:
          (config['expected_asset_names'] as List).cast<String>().toSet(),
      expectedCompositeChecksums:
          (config['expected_composites'] as List).cast<String>().toSet(),
      transport: transport,
      policy: PrecompiledAssetStorePolicy(
        lockTimeout: Duration(
            milliseconds: (config['lock_timeout_ms'] as int?) ?? 30000),
      ),
    );
    final snapshot = await store.snapshot(
      generationHash: config['generation_hash'] as String,
      requestedAssetNames:
          (config['requested_assets'] as List).cast<String>().toSet(),
    );
    return snapshot?.directory;
  } finally {
    transport.close();
  }
}

void _emit(Map<String, Object?> value) {
  stdout.writeln(jsonEncode(value));
}
