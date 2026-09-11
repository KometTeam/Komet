import 'package:build_tool/src/darwin_environment.dart';
import 'package:build_tool/src/target.dart';
import 'package:build_tool/src/util.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    testRunCommandOverride = (args) {
      if (args.executable != 'xcrun') {
        throw StateError('Unexpected executable: ${args.executable}');
      }

      final sdk = args.arguments[1];
      if (args.arguments[2] == '--show-sdk-path') {
        return TestRunCommandResult(stdout: '/sdk/$sdk\n');
      }
      if (args.arguments[2] == '--find') {
        final tool = args.arguments[3];
        return TestRunCommandResult(stdout: '/toolchain/$sdk/$tool\n');
      }

      throw StateError('Unexpected xcrun args: ${args.arguments}');
    };
  });

  tearDown(() {
    testRunCommandOverride = null;
  });

  test('builds simulator environment for arm64 ios sim target', () {
    final env = DarwinEnvironment(
      target: Target.forRustTriple('aarch64-apple-ios-sim')!,
      deploymentTarget: '12.0',
    ).buildEnvironment();

    expect(env['SDKROOT'], '/sdk/iphonesimulator');
    expect(env['CC_aarch64-apple-ios-sim'], '/toolchain/iphonesimulator/clang');
    expect(
      env['CFLAGS_aarch64-apple-ios-sim'],
      '--target=arm64-apple-ios-simulator -isysroot /sdk/iphonesimulator -mios-simulator-version-min=12.0',
    );
    expect(
      env['BINDGEN_EXTRA_CLANG_ARGS_aarch64-apple-ios-sim'],
      '--target=arm64-apple-ios-simulator -isysroot /sdk/iphonesimulator -mios-simulator-version-min=12.0',
    );
  });

  test('builds simulator environment for x86_64 ios target', () {
    final env = DarwinEnvironment(
      target: Target.forRustTriple('x86_64-apple-ios')!,
      deploymentTarget: '12.0',
    ).buildEnvironment();

    expect(env['SDKROOT'], '/sdk/iphonesimulator');
    expect(
      env['CFLAGS_x86_64-apple-ios'],
      '--target=x86_64-apple-ios-simulator -isysroot /sdk/iphonesimulator -mios-simulator-version-min=12.0',
    );
  });

  test('builds device environment for arm64 ios target', () {
    final env = DarwinEnvironment(
      target: Target.forRustTriple('aarch64-apple-ios')!,
      deploymentTarget: '12.0',
    ).buildEnvironment();

    expect(env['SDKROOT'], '/sdk/iphoneos');
    expect(
      env['CFLAGS_aarch64-apple-ios'],
      '--target=arm64-apple-ios -isysroot /sdk/iphoneos -miphoneos-version-min=12.0',
    );
  });
}
