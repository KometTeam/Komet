import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../utils/logger.dart';

class PulseSource {
  const PulseSource({
    required this.name,
    required this.label,
    required this.isMonitor,
  });

  final String name;
  final String label;
  final bool isMonitor;
}

class PulseRouteException implements Exception {
  const PulseRouteException(this.source);

  final String source;

  @override
  String toString() => source;
}

class PulseAudio {
  PulseAudio._();

  static const String bridgePrefix = 'komet_capture_';

  static String? _bridgeModule;
  static String? _bridgeMaster;
  static String? _bridgeSource;

  static bool get supported => !kIsWeb && Platform.isLinux;

  static String get _bridgeName => '$bridgePrefix$pid';

  static Future<ProcessResult?> _pactl(List<String> args) async {
    if (!supported) return null;
    try {
      return await Process.run(
        'pactl',
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } on ProcessException catch (e) {
      logger.w('[call][pulse] pactl ${args.first}: ${e.message}');
      return null;
    }
  }

  static Future<bool> isAvailable() async =>
      (await _pactl(const ['info']))?.exitCode == 0;

  static Future<List<PulseSource>> sources() async {
    final result = await _pactl(const ['-f', 'json', 'list', 'sources']);
    if (result == null || result.exitCode != 0) return const [];
    return parseSources(result.stdout as String);
  }

  static List<PulseSource> parseSources(String json) {
    final List<dynamic> entries;
    try {
      entries = jsonDecode(json) as List<dynamic>;
    } catch (e) {
      logger.w('[call][pulse] список источников: $e');
      return const [];
    }
    final sources = <PulseSource>[];
    for (final entry in entries.whereType<Map<String, dynamic>>()) {
      final name = entry['name'];
      if (name is! String || name.isEmpty) continue;
      if (name.startsWith(bridgePrefix)) continue;
      final monitorOf = entry['monitor_source'];
      final isMonitor = monitorOf is String && monitorOf.isNotEmpty;
      sources.add(
        PulseSource(
          name: name,
          label: _labelOf(entry, name, isMonitor),
          isMonitor: isMonitor,
        ),
      );
    }
    return sources;
  }

  static Future<PulseSource?> find(String name) async {
    for (final source in await sources()) {
      if (source.name == name) return source;
    }
    return null;
  }

  static Future<String?> openBridge(String master) async {
    if (_bridgeMaster == master && _bridgeSource != null) return _bridgeSource;
    await closeBridge();
    await _dropStaleBridges();
    final name = _bridgeName;
    final result = await _pactl([
      'load-module',
      'module-remap-source',
      'master=$master',
      'source_name=$name',
      'source_properties=device.description=$name',
    ]);
    if (result == null || result.exitCode != 0) {
      logger.w('[call][pulse] remap-source($master): ${result?.stderr}');
      return null;
    }
    final module = (result.stdout as String).trim();
    if (module.isEmpty) return null;
    _bridgeModule = module;
    _bridgeMaster = master;
    _bridgeSource = name;
    logger.i('[call][pulse] мост $name ← $master (модуль $module)');
    return name;
  }

  static Future<void> closeBridge() async {
    final module = _bridgeModule;
    _bridgeModule = null;
    _bridgeMaster = null;
    _bridgeSource = null;
    if (module == null) return;
    await _pactl(['unload-module', module]);
  }

  static Future<void> _dropStaleBridges() async {
    final result = await _pactl(const ['list', 'modules', 'short']);
    if (result == null || result.exitCode != 0) return;
    for (final line in const LineSplitter().convert(result.stdout as String)) {
      final columns = line.split('\t');
      if (columns.length < 3) continue;
      final owner = _bridgeOwnerPid(columns[2]);
      if (owner == null || Directory('/proc/$owner').existsSync()) continue;
      logger.i('[call][pulse] снимаю зависший мост процесса $owner');
      await _pactl(['unload-module', columns[0]]);
    }
  }

  static int? _bridgeOwnerPid(String argument) {
    final match = RegExp('$bridgePrefix([0-9]+)').firstMatch(argument);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String _labelOf(
    Map<String, dynamic> entry,
    String name,
    bool isMonitor,
  ) {
    final description = entry['description'];
    if (_usable(description)) return description as String;
    final properties = entry['properties'];
    final device = properties is Map ? properties['device.description'] : null;
    if (_usable(device)) {
      return isMonitor ? 'Monitor of $device' : device as String;
    }
    return name;
  }

  static bool _usable(Object? value) =>
      value is String && value.isNotEmpty && value != '(null)';
}
