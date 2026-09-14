import 'dart:io';

import 'package:build_tool/src/android_environment.dart';
import 'package:build_tool/src/target.dart';
import 'package:build_tool/src/util.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  tearDown(() {
    testRunCommandOverride = null;
  });

  test('arm64 and x64 android targets use 16 KB page size linker flags',
      () async {
    final sdkPath = _createFakeAndroidSdk();
    final targets = [
      Target.forRustTriple('aarch64-linux-android')!,
      Target.forRustTriple('x86_64-linux-android')!,
    ];

    for (final target in targets) {
      final env = await AndroidEnvironment(
        sdkPath: sdkPath,
        ndkVersion: '26.3.11579264',
        minSdkVersion: 21,
        targetTempDir: '/tmp/fjs-cargokit-test',
        target: target,
      ).buildEnvironment();

      expect(
        env['CARGO_ENCODED_RUSTFLAGS'],
        contains('link-arg=-Wl,-z,max-page-size=16384'),
      );
      expect(
        env['CARGO_ENCODED_RUSTFLAGS'],
        contains('link-arg=-Wl,--hash-style=both'),
      );
    }
  });

  test('32-bit android targets keep the libgcc workaround without 16 KB flags',
      () async {
    final sdkPath = _createFakeAndroidSdk();
    final target = Target.forRustTriple('armv7-linux-androideabi')!;
    final env = await AndroidEnvironment(
      sdkPath: sdkPath,
      ndkVersion: '26.3.11579264',
      minSdkVersion: 16,
      targetTempDir: '/tmp/fjs-cargokit-test',
      target: target,
    ).buildEnvironment();

    expect(env['CARGO_ENCODED_RUSTFLAGS'], contains('libgcc_workaround'));
    expect(
      env['CARGO_ENCODED_RUSTFLAGS'],
      isNot(contains('link-arg=-Wl,-z,max-page-size=16384')),
    );
  });

  test('bindgen clang args use libclang-safe android paths', () async {
    final sdkPath = _createFakeAndroidSdk(
      sdkPathSegment: r'C:\Users\test\AppData\Local\Android\Sdk',
    );
    final target = Target.forRustTriple('aarch64-linux-android')!;
    final env = await AndroidEnvironment(
      sdkPath: sdkPath,
      ndkVersion: '26.3.11579264',
      minSdkVersion: 24,
      targetTempDir: '/tmp/fjs-cargokit-test',
      target: target,
    ).buildEnvironment();

    final bindgenArgs = env['BINDGEN_EXTRA_CLANG_ARGS_aarch64-linux-android'];
    expect(bindgenArgs, isNotNull);
    expect(bindgenArgs, startsWith('--target=aarch64-linux-android24 '));
    expect(bindgenArgs, isNot(contains(r'\')));
    expect(
      bindgenArgs,
      contains('/C:/Users/test/AppData/Local/Android/Sdk/ndk/26.3.11579264/'),
    );
  });
}

String _createFakeAndroidSdk({String? sdkPathSegment}) {
  final temp = Directory.systemTemp.createTempSync('fjs-cargokit-android-sdk-');
  final sdk = sdkPathSegment == null
      ? temp
      : Directory(path.join(temp.path, sdkPathSegment))
    ..createSync(recursive: true);
  final toolchainBin = Directory(path.join(
    sdk.path,
    'ndk',
    '26.3.11579264',
    'toolchains',
    'llvm',
    'prebuilt',
    Platform.isWindows
        ? 'windows-x86_64'
        : Platform.isLinux
            ? 'linux-x86_64'
            : 'darwin-x86_64',
    'bin',
  ))
    ..createSync(recursive: true);

  for (final tool in [
    'llvm-ar',
    'llvm-ranlib',
    'clang',
    'clang++',
    if (Platform.isWindows) ...[
      'llvm-ar.exe',
      'llvm-ranlib.exe',
      'clang.exe',
      'clang++.exe',
    ],
  ]) {
    File(path.join(toolchainBin.path, tool)).writeAsStringSync('');
  }

  return sdk.path;
}
