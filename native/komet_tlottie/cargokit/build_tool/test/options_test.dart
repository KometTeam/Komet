import 'package:build_tool/src/builder.dart';
import 'package:build_tool/src/options.dart';
import 'package:build_tool/src/rustup.dart';
import 'package:build_tool/src/util.dart';
import 'package:hex/hex.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  tearDown(() {
    testRunCommandOverride = null;
    testRustupExecutablePathOverride = null;
  });

  test('parse cargo build options', () {
    final yaml = '''
toolchain: nightly
extra_flags:
  - -Z
  - build-std=panic_abort,std
''';

    final options = CargoBuildOptions.parse(loadYamlNode(yaml));

    expect(options.toolchain, Toolchain.nightly);
    expect(options.flags, ['-Z', 'build-std=panic_abort,std']);
  });

  test('parse precompiled binaries config', () {
    final yaml = '''
url_prefix: https://example.com/precompiled_
public_key: a4c3433798eb2c36edf2b94dbb4dd899d57496ca373a8982d8a792410b7f6445
''';

    final config = PrecompiledBinaries.parse(loadYamlNode(yaml));

    expect(config.uriPrefix, 'https://example.com/precompiled_');
    expect(
      config.publicKey.bytes,
      HEX.decode(
        'a4c3433798eb2c36edf2b94dbb4dd899d57496ca373a8982d8a792410b7f6445',
      ),
    );
  });

  test('parse complete precompiled generation config', () {
    final yaml = '''
url_prefix: https://example.com/precompiled_
public_key: a4c3433798eb2c36edf2b94dbb4dd899d57496ca373a8982d8a792410b7f6445
workspace_root: ..
hash_inputs:
  - pubspec.yaml
  - tool
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
      - tool/assemble_fjs_xcframework.sh
      - --release
    environment:
      LC_ALL: C
    timeout_seconds: 900
    outputs:
      - fjs.xcframework.zip
      - fjs.xcframework.zip.checksum
''';

    final config = PrecompiledBinaries.parse(loadYamlNode(yaml));

    expect(config.workspaceRoot, '..');
    expect(config.hashInputs, ['pubspec.yaml', 'tool']);
    expect(config.buildRecipe?.rustToolchain, '1.88.0');
    expect(config.buildRecipe?.flutterVersion, '3.32.8');
    expect(config.buildRecipe?.xcodeVersion, '16.4');
    expect(config.buildRecipe?.sdkVersions,
        {'iphoneos': '18.5', 'macosx': '15.5'});
    expect(config.buildRecipe?.deploymentTargets,
        {'ios': '12.0', 'macos': '10.14'});
    expect(config.buildRecipe?.rustTargets,
        ['aarch64-apple-ios', 'aarch64-apple-darwin']);
    expect(config.compositeGroups, hasLength(1));
    final group = config.compositeGroups.single;
    expect(group.name, 'swiftpm');
    expect(group.host, CompositeHost.macos);
    expect(
        group.requiredTargets, ['aarch64-apple-ios', 'aarch64-apple-darwin']);
    expect(group.argv, ['tool/assemble_fjs_xcframework.sh', '--release']);
    expect(group.environment, {'LC_ALL': 'C'});
    expect(group.timeout, const Duration(seconds: 900));
    expect(
        group.outputs, ['fjs.xcframework.zip', 'fjs.xcframework.zip.checksum']);
  });

  group('precompiled generation config rejects', () {
    const publicKey =
        'a4c3433798eb2c36edf2b94dbb4dd899d57496ca373a8982d8a792410b7f6445';

    String config(String body) => '''
url_prefix: https://example.com/precompiled_
public_key: $publicKey
$body
''';

    void expectInvalid(String body) {
      expect(
        () => PrecompiledBinaries.parse(loadYamlNode(config(body))),
        throwsA(isA<SourceSpanException>()),
      );
    }

    test('unknown fields', () {
      expectInvalid('unexpected: true');
      expectInvalid('''
build_recipe:
  rust_toolchain: 1.88.0
  flutter_version: 3.32.8
  xcode_version: 16.4
  sdk_versions: {}
  deployment_targets: {}
  rust_targets:
    - aarch64-apple-ios
  unexpected: true
''');
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-ios
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs:
      - output.zip
    unexpected: true
''');
    });

    test('absolute and escaping paths', () {
      expectInvalid('workspace_root: /tmp/workspace');
      expectInvalid('''
hash_inputs:
  - ../outside
''');
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-ios
    argv:
      - /tmp/build.sh
    timeout_seconds: 60
    outputs:
      - output.zip
''');
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-ios
    argv:
      - ../build.sh
    timeout_seconds: 60
    outputs:
      - output.zip
''');
    });

    test('invalid hosts and targets', () {
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: darwin
    required_targets:
      - aarch64-apple-ios
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs:
      - output.zip
''');
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - invented-rust-target
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs:
      - output.zip
''');
    });

    test('empty commands and outputs and invalid timeouts', () {
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-ios
    argv: []
    timeout_seconds: 60
    outputs:
      - output.zip
''');
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-ios
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs: []
''');
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-ios
    argv:
      - tool/build.sh
    timeout_seconds: 0
    outputs:
      - output.zip
''');
    });

    test('unsafe and duplicate output names', () {
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-ios
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs:
      - ../output.zip
''');
      expectInvalid('''
composite_groups:
  - name: first
    host: macos
    required_targets:
      - aarch64-apple-ios
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs:
      - output.zip
  - name: second
    host: macos
    required_targets:
      - aarch64-apple-darwin
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs:
      - output.zip
''');
    });

    test('duplicate groups and targets', () {
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-ios
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs:
      - first.zip
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-darwin
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs:
      - second.zip
''');
      expectInvalid('''
composite_groups:
  - name: swiftpm
    host: macos
    required_targets:
      - aarch64-apple-ios
      - aarch64-apple-ios
    argv:
      - tool/build.sh
    timeout_seconds: 60
    outputs:
      - output.zip
''');
    });
  });

  test('parse crate options with cargo and precompiled binaries', () {
    final yaml = '''
cargo:
  debug:
    toolchain: nightly
    extra_flags:
      - -Z
      - build-std=panic_abort,std
  release:
    toolchain: beta

precompiled_binaries:
  url_prefix: https://example.com/precompiled_
  public_key: a4c3433798eb2c36edf2b94dbb4dd899d57496ca373a8982d8a792410b7f6445
''';

    final options = CargokitCrateOptions.parse(loadYamlNode(yaml));

    expect(
        options.cargo[BuildConfiguration.debug]!.toolchain, Toolchain.nightly);
    expect(
      options.cargo[BuildConfiguration.debug]!.flags,
      ['-Z', 'build-std=panic_abort,std'],
    );
    expect(
        options.cargo[BuildConfiguration.release]!.toolchain, Toolchain.beta);
    expect(options.precompiledBinaries?.uriPrefix,
        'https://example.com/precompiled_');
  });

  test('default user options build locally when rustup is available', () {
    testRustupExecutablePathOverride = () => '/usr/bin/rustup';

    final options = CargokitUserOptions.parse(loadYamlNode('{}'));

    expect(options.usePrecompiledBinaries, false);
    expect(options.verboseLogging, false);
  });

  test('default user options use precompiled binaries when rustup is missing',
      () {
    testRustupExecutablePathOverride = () => null;

    final options = CargokitUserOptions.parse(loadYamlNode('{}'));

    expect(options.usePrecompiledBinaries, true);
    expect(options.verboseLogging, false);
  });

  test('explicit user options override default precompiled binary behavior',
      () {
    final options = CargokitUserOptions.parse(loadYamlNode('''
use_precompiled_binaries: true
verbose_logging: true
'''));

    expect(options.usePrecompiledBinaries, true);
    expect(options.verboseLogging, true);
  });

  test('parse precompiled binary modes', () {
    for (final mode in PrecompiledBinariesMode.values) {
      final options = CargokitUserOptions.parse(loadYamlNode('''
precompiled_binaries_mode: ${mode.name}
'''));

      expect(options.precompiledBinariesMode, mode);
      expect(options.usePrecompiledBinaries,
          mode != PrecompiledBinariesMode.disabled);
      expect(options.allowLocalBuild, mode != PrecompiledBinariesMode.required);
    }
  });

  test('legacy precompiled boolean maps to auto or disabled', () {
    final enabled = CargokitUserOptions.parse(
        loadYamlNode('use_precompiled_binaries: true'));
    final disabled = CargokitUserOptions.parse(
        loadYamlNode('use_precompiled_binaries: false'));

    expect(enabled.precompiledBinariesMode, PrecompiledBinariesMode.auto);
    expect(disabled.precompiledBinariesMode, PrecompiledBinariesMode.disabled);
  });

  test('precompiled mode rejects legacy setting conflict', () {
    expect(
      () => CargokitUserOptions.parse(loadYamlNode('''
precompiled_binaries_mode: required
use_precompiled_binaries: true
''')),
      throwsA(isA<SourceSpanException>()),
    );
  });

  test('precompiled mode rejects unknown values', () {
    expect(
      () => CargokitUserOptions.parse(
          loadYamlNode('precompiled_binaries_mode: sometimes')),
      throwsA(isA<SourceSpanException>()),
    );
  });
}
