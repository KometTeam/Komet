/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'target.dart';
import 'util.dart';

class DarwinEnvironment {
  DarwinEnvironment({
    required this.target,
    required this.deploymentTarget,
  });

  final Target target;
  final String deploymentTarget;

  Map<String, String> buildEnvironment() {
    final platform = target.darwinPlatform;
    if (platform == null || platform == 'macosx') {
      return {};
    }

    final sdkPath = _resolveSdkPath(platform);
    final flags = _clangFlags(sdkPath);
    final rustTarget = target.rust;

    return {
      'SDKROOT': sdkPath,
      'IPHONEOS_DEPLOYMENT_TARGET': deploymentTarget,
      'CC_$rustTarget': _findTool(platform, 'clang'),
      'CFLAGS_$rustTarget': flags,
      'CXX_$rustTarget': _findTool(platform, 'clang++'),
      'CXXFLAGS_$rustTarget': flags,
      'AR_$rustTarget': _findTool(platform, 'ar'),
      'RANLIB_$rustTarget': _findTool(platform, 'ranlib'),
      'BINDGEN_EXTRA_CLANG_ARGS_$rustTarget': flags,
    };
  }

  String _resolveSdkPath(String platform) {
    final result = runCommand('xcrun', [
      '--sdk',
      platform,
      '--show-sdk-path',
    ]);
    return (result.stdout as String).trim();
  }

  String _findTool(String platform, String tool) {
    final result = runCommand('xcrun', [
      '--sdk',
      platform,
      '--find',
      tool,
    ]);
    return (result.stdout as String).trim();
  }

  String _clangFlags(String sdkPath) {
    final flags = <String>[];
    final clangTarget = _clangTarget();
    if (clangTarget != null) {
      flags.add('--target=$clangTarget');
    }
    flags.add('-isysroot $sdkPath');
    flags.add(_deploymentFlag());
    return flags.join(' ');
  }

  String _deploymentFlag() {
    return switch (target.darwinPlatform) {
      'iphonesimulator' => '-mios-simulator-version-min=$deploymentTarget',
      'iphoneos' => '-miphoneos-version-min=$deploymentTarget',
      _ => throw ArgumentError(
          'Unsupported Darwin platform: ${target.darwinPlatform}'),
    };
  }

  String? _clangTarget() {
    return switch (target.rust) {
      'aarch64-apple-ios-sim' => 'arm64-apple-ios-simulator',
      'x86_64-apple-ios' => 'x86_64-apple-ios-simulator',
      'aarch64-apple-ios' => 'arm64-apple-ios',
      _ => null,
    };
  }
}
