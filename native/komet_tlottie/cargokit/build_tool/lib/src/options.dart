/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:hex/hex.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'builder.dart';
import 'environment.dart';
import 'rustup.dart';
import 'target.dart';

final _log = Logger('options');

/// A class for exceptions that have source span information attached.
class SourceSpanException implements Exception {
  // This is a getter so that subclasses can override it.
  /// A message describing the exception.
  String get message => _message;
  final String _message;

  // This is a getter so that subclasses can override it.
  /// The span associated with this exception.
  ///
  /// This may be `null` if the source location can't be determined.
  SourceSpan? get span => _span;
  final SourceSpan? _span;

  SourceSpanException(this._message, this._span);

  /// Returns a string representation of `this`.
  ///
  /// [color] may either be a [String], a [bool], or `null`. If it's a string,
  /// it indicates an ANSI terminal color escape that should be used to
  /// highlight the span's text. If it's `true`, it indicates that the text
  /// should be highlighted using the default color. If it's `false` or `null`,
  /// it indicates that the text shouldn't be highlighted.
  @override
  String toString({Object? color}) {
    if (span == null) return message;
    return 'Error on ${span!.message(message, color: color)}';
  }
}

enum Toolchain {
  stable,
  beta,
  nightly,
}

class CargoBuildOptions {
  final Toolchain toolchain;
  final List<String> flags;

  CargoBuildOptions({
    required this.toolchain,
    required this.flags,
  });

  static Toolchain _toolchainFromNode(YamlNode node) {
    if (node case YamlScalar(value: String name)) {
      final toolchain =
          Toolchain.values.firstWhereOrNull((element) => element.name == name);
      if (toolchain != null) {
        return toolchain;
      }
    }
    throw SourceSpanException(
        'Unknown toolchain. Must be one of ${Toolchain.values.map((e) => e.name)}.',
        node.span);
  }

  static CargoBuildOptions parse(YamlNode node) {
    if (node is! YamlMap) {
      throw SourceSpanException('Cargo options must be a map', node.span);
    }
    Toolchain toolchain = Toolchain.stable;
    List<String> flags = [];
    for (final MapEntry(:key, :value) in node.nodes.entries) {
      if (key case YamlScalar(value: 'toolchain')) {
        toolchain = _toolchainFromNode(value);
      } else if (key case YamlScalar(value: 'extra_flags')) {
        if (value case YamlList(nodes: List<YamlNode> list)) {
          if (list.every((element) {
            if (element case YamlScalar(value: String _)) {
              return true;
            }
            return false;
          })) {
            flags = list.map((e) => e.value as String).toList();
            continue;
          }
        }
        throw SourceSpanException(
            'Extra flags must be a list of strings', value.span);
      } else {
        throw SourceSpanException(
            'Unknown cargo option type. Must be "toolchain" or "extra_flags".',
            key.span);
      }
    }
    return CargoBuildOptions(toolchain: toolchain, flags: flags);
  }
}

void _rejectUnknownFields(
  YamlMap map,
  Set<String> allowedFields,
  String context,
) {
  for (final key in map.nodes.keys) {
    if (key is! YamlScalar ||
        key.value is! String ||
        !allowedFields.contains(key.value)) {
      throw SourceSpanException(
          'Unknown $context field "${key.value}".', key.span);
    }
  }
}

YamlMap _mapFromNode(YamlNode node, String context) {
  if (node is YamlMap) {
    return node;
  }
  throw SourceSpanException('$context must be a map.', node.span);
}

YamlNode _requiredNode(YamlMap map, String key, String context) {
  final node = map.nodes[YamlScalar.wrap(key)];
  if (node != null) {
    return node;
  }
  throw SourceSpanException(
    '$context must contain "$key".',
    map.span,
  );
}

String _stringFromNode(YamlNode node, String description,
    {bool allowEmpty = false}) {
  if (node case YamlScalar(value: String value)) {
    if (allowEmpty || value.isNotEmpty) {
      return value;
    }
  }
  throw SourceSpanException(
      '$description must be a non-empty string.', node.span);
}

List<String> _stringListFromNode(
  YamlNode node,
  String description, {
  bool allowEmpty = false,
}) {
  if (node is YamlList) {
    final result = <String>[];
    for (final item in node.nodes) {
      result.add(_stringFromNode(item, '$description entry'));
    }
    if (allowEmpty || result.isNotEmpty) {
      return List.unmodifiable(result);
    }
  }
  throw SourceSpanException(
    '$description must be a non-empty list of strings.',
    node.span,
  );
}

Map<String, String> _stringMapFromNode(
  YamlNode node,
  String description, {
  bool allowEmpty = false,
  bool allowEmptyValues = false,
}) {
  if (node is YamlMap) {
    final result = <String, String>{};
    for (final MapEntry(:key, :value) in node.nodes.entries) {
      final name = _stringFromNode(key, '$description key');
      result[name] = _stringFromNode(
        value,
        '$description value',
        allowEmpty: allowEmptyValues,
      );
    }
    if (allowEmpty || result.isNotEmpty) {
      return Map.unmodifiable(result);
    }
  }
  throw SourceSpanException(
    '$description must be a map of strings to strings.',
    node.span,
  );
}

String _relativePathFromNode(
  YamlNode node,
  String description, {
  bool allowParent = false,
}) {
  final value = _stringFromNode(node, description);
  if (value.contains('\\') ||
      path.posix.isAbsolute(value) ||
      path.windows.isAbsolute(value)) {
    throw SourceSpanException(
        '$description must be a relative path.', node.span);
  }
  final normalized = path.posix.normalize(value);
  if (!allowParent && (normalized == '..' || normalized.startsWith('../'))) {
    throw SourceSpanException(
      '$description must not escape the workspace root.',
      node.span,
    );
  }
  return normalized;
}

List<String> _rustTargetsFromNode(YamlNode node, String description) {
  final targets = _stringListFromNode(node, description);
  final seen = <String>{};
  for (final target in targets) {
    if (Target.forRustTriple(target) == null) {
      throw SourceSpanException('Invalid Rust target "$target".', node.span);
    }
    if (!seen.add(target)) {
      throw SourceSpanException('Duplicate Rust target "$target".', node.span);
    }
  }
  return targets;
}

enum CompositeHost {
  linux,
  macos,
  windows,
}

class PrecompiledBuildRecipe {
  PrecompiledBuildRecipe({
    required this.rustToolchain,
    required this.flutterVersion,
    required this.xcodeVersion,
    required this.sdkVersions,
    required this.deploymentTargets,
    required this.rustTargets,
  });

  static PrecompiledBuildRecipe parse(YamlNode node) {
    final map = _mapFromNode(node, 'Build recipe');
    _rejectUnknownFields(
        map,
        const {
          'rust_toolchain',
          'flutter_version',
          'xcode_version',
          'sdk_versions',
          'deployment_targets',
          'rust_targets',
        },
        'build recipe');
    return PrecompiledBuildRecipe(
      rustToolchain: _stringFromNode(
        _requiredNode(map, 'rust_toolchain', 'Build recipe'),
        'Rust toolchain',
      ),
      flutterVersion: _stringFromNode(
        _requiredNode(map, 'flutter_version', 'Build recipe'),
        'Flutter version',
      ),
      xcodeVersion: _stringFromNode(
        _requiredNode(map, 'xcode_version', 'Build recipe'),
        'Xcode version',
      ),
      sdkVersions: _stringMapFromNode(
        _requiredNode(map, 'sdk_versions', 'Build recipe'),
        'SDK versions',
      ),
      deploymentTargets: _stringMapFromNode(
        _requiredNode(map, 'deployment_targets', 'Build recipe'),
        'Deployment targets',
      ),
      rustTargets: _rustTargetsFromNode(
        _requiredNode(map, 'rust_targets', 'Build recipe'),
        'Build recipe Rust targets',
      ),
    );
  }

  final String rustToolchain;
  final String flutterVersion;
  final String xcodeVersion;
  final Map<String, String> sdkVersions;
  final Map<String, String> deploymentTargets;
  final List<String> rustTargets;
}

class CompositeGroup {
  CompositeGroup({
    required this.name,
    required this.host,
    required this.requiredTargets,
    required this.argv,
    required this.environment,
    required this.timeout,
    required this.outputs,
  });

  static CompositeGroup parse(YamlNode node) {
    final map = _mapFromNode(node, 'Composite group');
    _rejectUnknownFields(
        map,
        const {
          'name',
          'host',
          'required_targets',
          'argv',
          'environment',
          'timeout_seconds',
          'outputs',
        },
        'composite group');

    final nameNode = _requiredNode(map, 'name', 'Composite group');
    final name = _safeNameFromNode(nameNode, 'Composite group name');
    final hostNode = _requiredNode(map, 'host', 'Composite group');
    final hostName = _stringFromNode(hostNode, 'Composite host');
    final host = CompositeHost.values
        .firstWhereOrNull((element) => element.name == hostName);
    if (host == null) {
      throw SourceSpanException(
        'Invalid composite host "$hostName". Must be one of '
        '${CompositeHost.values.map((host) => host.name)}.',
        hostNode.span,
      );
    }

    final argvNode = _requiredNode(map, 'argv', 'Composite group');
    final argv = _stringListFromNode(argvNode, 'Composite argv');
    final argvList = argvNode as YamlList;
    final command = _relativePathFromNode(argvList.nodes.first, 'Command path');
    final normalizedArgv =
        List<String>.unmodifiable([command, ...argv.skip(1)]);

    final timeoutNode =
        _requiredNode(map, 'timeout_seconds', 'Composite group');
    final timeoutSeconds = switch (timeoutNode) {
      YamlScalar(value: int value) when value > 0 => value,
      _ => throw SourceSpanException(
          'Composite timeout must be a positive integer.', timeoutNode.span),
    };

    final outputsNode = _requiredNode(map, 'outputs', 'Composite group');
    final outputNodes = switch (outputsNode) {
      YamlList(nodes: final nodes) when nodes.isNotEmpty => nodes,
      _ => throw SourceSpanException(
          'Composite outputs must be a non-empty list.', outputsNode.span),
    };
    final outputs = <String>[];
    final seenOutputs = <String>{};
    for (final outputNode in outputNodes) {
      final output = _safeNameFromNode(outputNode, 'Composite output name');
      if (!seenOutputs.add(output)) {
        throw SourceSpanException(
          'Duplicate composite output "$output".',
          outputNode.span,
        );
      }
      outputs.add(output);
    }

    final environmentNode = map.nodes[YamlScalar.wrap('environment')];
    final environment = environmentNode == null
        ? const <String, String>{}
        : _stringMapFromNode(
            environmentNode,
            'Composite environment',
            allowEmpty: true,
            allowEmptyValues: true,
          );
    for (final key in environment.keys) {
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
        throw SourceSpanException(
          'Invalid composite environment variable "$key".',
          environmentNode?.span,
        );
      }
    }

    return CompositeGroup(
      name: name,
      host: host,
      requiredTargets: _rustTargetsFromNode(
        _requiredNode(map, 'required_targets', 'Composite group'),
        'Composite required targets',
      ),
      argv: normalizedArgv,
      environment: environment,
      timeout: Duration(seconds: timeoutSeconds),
      outputs: List.unmodifiable(outputs),
    );
  }

  static String _safeNameFromNode(YamlNode node, String description) {
    final value = _stringFromNode(node, description);
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value) ||
        value == '.' ||
        value == '..') {
      throw SourceSpanException('$description is unsafe.', node.span);
    }
    return value;
  }

  final String name;
  final CompositeHost host;
  final List<String> requiredTargets;
  final List<String> argv;
  final Map<String, String> environment;
  final Duration timeout;
  final List<String> outputs;
}

class PrecompiledBinaries {
  final String uriPrefix;
  final PublicKey publicKey;
  final String workspaceRoot;
  final List<String> hashInputs;
  final PrecompiledBuildRecipe? buildRecipe;
  final List<CompositeGroup> compositeGroups;

  PrecompiledBinaries({
    required this.uriPrefix,
    required this.publicKey,
    this.workspaceRoot = '.',
    this.hashInputs = const [],
    this.buildRecipe,
    this.compositeGroups = const [],
  });

  static PublicKey _publicKeyFromHex(String key, SourceSpan? span) {
    final bytes = HEX.decode(key);
    if (bytes.length != 32) {
      throw SourceSpanException(
          'Invalid public key. Must be 32 bytes long.', span);
    }
    return PublicKey(bytes);
  }

  static PrecompiledBinaries parse(YamlNode node) {
    final map = _mapFromNode(node, 'Precompiled binaries');
    _rejectUnknownFields(
        map,
        const {
          'url_prefix',
          'public_key',
          'workspace_root',
          'hash_inputs',
          'build_recipe',
          'composite_groups',
        },
        'precompiled binaries');
    final urlPrefixNode =
        _requiredNode(map, 'url_prefix', 'Precompiled binaries');
    final publicKeyNode =
        _requiredNode(map, 'public_key', 'Precompiled binaries');
    final workspaceRootNode = map.nodes[YamlScalar.wrap('workspace_root')];
    final hashInputsNode = map.nodes[YamlScalar.wrap('hash_inputs')];
    final buildRecipeNode = map.nodes[YamlScalar.wrap('build_recipe')];
    final compositeGroupsNode = map.nodes[YamlScalar.wrap('composite_groups')];

    final hashInputs = <String>[];
    final seenHashInputs = <String>{};
    if (hashInputsNode != null) {
      if (hashInputsNode is! YamlList) {
        throw SourceSpanException(
          'Hash inputs must be a list of relative paths.',
          hashInputsNode.span,
        );
      }
      for (final inputNode in hashInputsNode.nodes) {
        final input = _relativePathFromNode(inputNode, 'Hash input');
        if (!seenHashInputs.add(input)) {
          throw SourceSpanException(
              'Duplicate hash input "$input".', inputNode.span);
        }
        hashInputs.add(input);
      }
    }

    final compositeGroups = <CompositeGroup>[];
    final groupNames = <String>{};
    final outputNames = <String>{};
    if (compositeGroupsNode != null) {
      if (compositeGroupsNode is! YamlList) {
        throw SourceSpanException(
          'Composite groups must be a list.',
          compositeGroupsNode.span,
        );
      }
      for (final groupNode in compositeGroupsNode.nodes) {
        final group = CompositeGroup.parse(groupNode);
        if (!groupNames.add(group.name)) {
          throw SourceSpanException(
            'Duplicate composite group "${group.name}".',
            groupNode.span,
          );
        }
        for (final output in group.outputs) {
          if (!outputNames.add(output)) {
            throw SourceSpanException(
              'Duplicate composite output "$output".',
              groupNode.span,
            );
          }
        }
        compositeGroups.add(group);
      }
    }

    final publicKeyValue = _stringFromNode(publicKeyNode, 'Public key');
    return PrecompiledBinaries(
      uriPrefix: _stringFromNode(urlPrefixNode, 'URL prefix'),
      publicKey: _publicKeyFromHex(publicKeyValue, publicKeyNode.span),
      workspaceRoot: workspaceRootNode == null
          ? '.'
          : _relativePathFromNode(
              workspaceRootNode,
              'Workspace root',
              allowParent: true,
            ),
      hashInputs: List.unmodifiable(hashInputs),
      buildRecipe: buildRecipeNode == null
          ? null
          : PrecompiledBuildRecipe.parse(buildRecipeNode),
      compositeGroups: List.unmodifiable(compositeGroups),
    );
  }
}

/// Cargokit options specified for Rust crate.
class CargokitCrateOptions {
  CargokitCrateOptions({
    this.cargo = const {},
    this.precompiledBinaries,
  });

  final Map<BuildConfiguration, CargoBuildOptions> cargo;
  final PrecompiledBinaries? precompiledBinaries;

  static CargokitCrateOptions parse(YamlNode node) {
    if (node is! YamlMap) {
      throw SourceSpanException('Cargokit options must be a map', node.span);
    }
    final options = <BuildConfiguration, CargoBuildOptions>{};
    PrecompiledBinaries? precompiledBinaries;

    for (final entry in node.nodes.entries) {
      if (entry
          case MapEntry(
            key: YamlScalar(value: 'cargo'),
            value: YamlNode node,
          )) {
        if (node is! YamlMap) {
          throw SourceSpanException('Cargo options must be a map', node.span);
        }
        for (final MapEntry(:YamlNode key, :value) in node.nodes.entries) {
          if (key case YamlScalar(value: String name)) {
            final configuration = BuildConfiguration.values
                .firstWhereOrNull((element) => element.name == name);
            if (configuration != null) {
              options[configuration] = CargoBuildOptions.parse(value);
              continue;
            }
          }
          throw SourceSpanException(
              'Unknown build configuration. Must be one of ${BuildConfiguration.values.map((e) => e.name)}.',
              key.span);
        }
      } else if (entry.key case YamlScalar(value: 'precompiled_binaries')) {
        precompiledBinaries = PrecompiledBinaries.parse(entry.value);
      } else {
        throw SourceSpanException(
            'Unknown cargokit option type. Must be "cargo" or "precompiled_binaries".',
            entry.key.span);
      }
    }
    return CargokitCrateOptions(
      cargo: options,
      precompiledBinaries: precompiledBinaries,
    );
  }

  static CargokitCrateOptions load({
    required String manifestDir,
  }) {
    final uri = Uri.file(path.join(manifestDir, "cargokit.yaml"));
    final file = File.fromUri(uri);
    if (file.existsSync()) {
      final contents = loadYamlNode(file.readAsStringSync(), sourceUrl: uri);
      return parse(contents);
    } else {
      return CargokitCrateOptions();
    }
  }
}

enum PrecompiledBinariesMode {
  auto,
  disabled,
  required,
}

class CargokitUserOptions {
  // When Rustup is installed always build locally unless user opts into
  // using precompiled binaries.
  static bool defaultUsePrecompiledBinaries() {
    return Rustup.executablePath() == null;
  }

  factory CargokitUserOptions({
    bool? usePrecompiledBinaries,
    PrecompiledBinariesMode? precompiledBinariesMode,
    required bool verboseLogging,
  }) {
    if (usePrecompiledBinaries != null && precompiledBinariesMode != null) {
      throw ArgumentError(
        'usePrecompiledBinaries and precompiledBinariesMode are mutually exclusive.',
      );
    }
    return CargokitUserOptions._values(
      precompiledBinariesMode: precompiledBinariesMode ??
          (usePrecompiledBinaries == null
              ? _defaultMode()
              : _legacyMode(usePrecompiledBinaries)),
      verboseLogging: verboseLogging,
    );
  }

  CargokitUserOptions._defaults()
      : precompiledBinariesMode = _defaultMode(),
        verboseLogging = false;

  CargokitUserOptions._values({
    required this.precompiledBinariesMode,
    required this.verboseLogging,
  });

  static PrecompiledBinariesMode _defaultMode() =>
      defaultUsePrecompiledBinaries()
          ? PrecompiledBinariesMode.auto
          : PrecompiledBinariesMode.disabled;

  static PrecompiledBinariesMode _legacyMode(bool value) =>
      value ? PrecompiledBinariesMode.auto : PrecompiledBinariesMode.disabled;

  static CargokitUserOptions parse(YamlNode node) {
    if (node is! YamlMap) {
      throw SourceSpanException('Cargokit options must be a map', node.span);
    }
    var precompiledBinariesMode = _defaultMode();
    bool verboseLogging = false;
    SourceSpan? legacySettingSpan;
    SourceSpan? modeSettingSpan;

    for (final entry in node.nodes.entries) {
      if (entry.key case YamlScalar(value: 'use_precompiled_binaries')) {
        if (entry.value case YamlScalar(value: bool value)) {
          precompiledBinariesMode = _legacyMode(value);
          legacySettingSpan = entry.key.span;
          continue;
        }
        throw SourceSpanException(
            'Invalid value for "use_precompiled_binaries". Must be a boolean.',
            entry.value.span);
      } else if (entry.key
          case YamlScalar(value: 'precompiled_binaries_mode')) {
        final modeName = switch (entry.value) {
          YamlScalar(value: String value) => value,
          _ => throw SourceSpanException(
              'Invalid value for "precompiled_binaries_mode". Must be one of '
              '${PrecompiledBinariesMode.values.map((mode) => mode.name)}.',
              entry.value.span,
            ),
        };
        final mode = PrecompiledBinariesMode.values
            .firstWhereOrNull((element) => element.name == modeName);
        if (mode == null) {
          throw SourceSpanException(
            'Invalid value for "precompiled_binaries_mode". Must be one of '
            '${PrecompiledBinariesMode.values.map((mode) => mode.name)}.',
            entry.value.span,
          );
        }
        precompiledBinariesMode = mode;
        modeSettingSpan = entry.key.span;
      } else if (entry.key case YamlScalar(value: 'verbose_logging')) {
        if (entry.value case YamlScalar(value: bool value)) {
          verboseLogging = value;
          continue;
        }
        throw SourceSpanException(
            'Invalid value for "verbose_logging". Must be a boolean.',
            entry.value.span);
      } else {
        throw SourceSpanException(
            'Unknown cargokit option type. Must be "precompiled_binaries_mode", '
            '"use_precompiled_binaries", or "verbose_logging".',
            entry.key.span);
      }
    }
    if (legacySettingSpan != null && modeSettingSpan != null) {
      throw SourceSpanException(
        '"precompiled_binaries_mode" and legacy '
        '"use_precompiled_binaries" cannot both be set.',
        modeSettingSpan,
      );
    }
    return CargokitUserOptions(
      precompiledBinariesMode: precompiledBinariesMode,
      verboseLogging: verboseLogging,
    );
  }

  static CargokitUserOptions load() {
    String fileName = "cargokit_options.yaml";
    var userProjectDir = Directory(Environment.rootProjectDir);

    while (userProjectDir.parent.path != userProjectDir.path) {
      final configFile = File(path.join(userProjectDir.path, fileName));
      if (configFile.existsSync()) {
        final contents = loadYamlNode(
          configFile.readAsStringSync(),
          sourceUrl: configFile.uri,
        );
        final res = parse(contents);
        if (res.verboseLogging) {
          _log.info('Found user options file at ${configFile.path}');
        }
        return res;
      }
      userProjectDir = userProjectDir.parent;
    }
    return CargokitUserOptions._defaults();
  }

  final PrecompiledBinariesMode precompiledBinariesMode;

  bool get usePrecompiledBinaries =>
      precompiledBinariesMode != PrecompiledBinariesMode.disabled;

  bool get allowLocalBuild =>
      precompiledBinariesMode != PrecompiledBinariesMode.required;

  final bool verboseLogging;
}
