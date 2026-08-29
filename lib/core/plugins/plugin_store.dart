import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/app_instance.dart';
import 'plugin_manifest.dart';
import 'plugin_models.dart';
import 'plugin_package.dart';

class PluginStore {
  PluginStore._();

  static final PluginStore instance = PluginStore._();
  static const _stateKey = 'plugins_state_v1';
  static const _bundled = <String>[
    'assets/plugins/anim',
    'assets/plugins/epsh',
    'assets/plugins/fox',
    'assets/plugins/info',
    'assets/plugins/weather',
  ];

  final ValueNotifier<List<PluginDescriptor>> plugins = ValueNotifier(const []);
  Directory? _root;
  Map<String, dynamic> _state = {};

  static bool isBundledId(String id) => id.startsWith('pw.komet.');

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawState = prefs.getString(_stateKey);
    if (rawState != null) {
      try {
        final decoded = jsonDecode(rawState);
        if (decoded is Map) _state = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    final base = await getApplicationSupportDirectory();
    _root = Directory(p.join(base.path, 'plugins${AppInstance.suffix}'));
    await _root!.create(recursive: true);
    await _recoverInterruptedInstalls();
    await refresh();
  }

  Future<void> _recoverInterruptedInstalls() async {
    final root = _root;
    if (root == null) return;
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('.')) continue;
      if (name.endsWith('.backup')) {
        final pluginId = name.substring(1, name.length - '.backup'.length);
        final target = Directory(p.join(root.path, pluginId));
        if (await target.exists()) {
          await entity.delete(recursive: true);
        } else {
          await entity.rename(target.path);
        }
      } else {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<void> refresh() async {
    final descriptors = <PluginDescriptor>[];
    for (final assetPath in _bundled) {
      descriptors.add(await _loadBundled(assetPath));
    }
    final root = _root;
    if (root != null && await root.exists()) {
      await for (final entity in root.list()) {
        if (entity is! Directory || p.basename(entity.path).startsWith('.')) {
          continue;
        }
        try {
          descriptors.add(await _loadInstalled(entity));
        } catch (_) {}
      }
    }
    descriptors.sort((a, b) {
      final origin = a.origin.index.compareTo(b.origin.index);
      return origin != 0 ? origin : a.manifest.name.compareTo(b.manifest.name);
    });
    plugins.value = List.unmodifiable(descriptors);
  }

  Future<PluginDescriptor> _loadBundled(String assetPath) async {
    final manifest = PluginManifest.decode(
      await rootBundle.loadString('$assetPath/manifest.json'),
    );
    return PluginDescriptor(
      manifest: manifest,
      origin: PluginOrigin.bundled,
      enabled: _enabled(manifest.id, fallback: true),
      grantedPermissions: manifest.permissions,
      loadModules: () async => {
        manifest.main: await rootBundle.loadString(
          '$assetPath/${manifest.main}',
        ),
      },
    );
  }

  Future<PluginDescriptor> _loadInstalled(Directory directory) async {
    final manifest = PluginManifest.decode(
      await File(p.join(directory.path, 'manifest.json')).readAsString(),
    );
    final state = _pluginState(manifest.id);
    final granted = <PluginPermission>{};
    final rawGranted = state['granted'];
    if (rawGranted is List) {
      for (final raw in rawGranted.whereType<String>()) {
        final permission = PluginPermission.fromId(raw);
        if (permission != null && manifest.permissions.contains(permission)) {
          granted.add(permission);
        }
      }
    }
    return PluginDescriptor(
      manifest: manifest,
      origin: PluginOrigin.installed,
      enabled: _enabled(manifest.id, fallback: true),
      grantedPermissions: Set.unmodifiable(granted),
      loadModules: () => _loadInstalledModules(directory),
    );
  }

  Future<Map<String, String>> _loadInstalledModules(Directory directory) async {
    final modules = <String, String>{};
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.js')) continue;
      final relative = p
          .relative(entity.path, from: directory.path)
          .replaceAll('\\', '/');
      modules[relative] = await entity.readAsString();
    }
    return modules;
  }

  Future<PluginDescriptor> install(
    List<int> bytes, {
    required Set<PluginPermission> grantedPermissions,
    Uri? sourceUrl,
  }) async {
    final package = PluginPackage.decode(bytes);
    if (isBundledId(package.manifest.id)) {
      throw const FormatException('Этот id зарезервирован Komet');
    }
    if (!package.manifest.permissions.containsAll(grantedPermissions)) {
      throw const FormatException('Выданы неизвестные разрешения');
    }
    final root = _root;
    if (root == null) throw StateError('PluginStore не инициализирован');
    final target = Directory(p.join(root.path, package.manifest.id));
    final staging = Directory(
      p.join(
        root.path,
        '.${package.manifest.id}.${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final backup = Directory(
      p.join(root.path, '.${package.manifest.id}.backup'),
    );
    await staging.create(recursive: true);
    try {
      for (final entry in package.files.entries) {
        final file = File(p.join(staging.path, entry.key));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.value, flush: true);
      }
      if (await backup.exists()) await backup.delete(recursive: true);
      if (await target.exists()) await target.rename(backup.path);
      try {
        await staging.rename(target.path);
      } catch (_) {
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
      if (await backup.exists()) await backup.delete(recursive: true);
      _state[package.manifest.id] = {
        'enabled': true,
        'granted': grantedPermissions
            .map((permission) => permission.id)
            .toList(),
        if (sourceUrl != null) 'sourceUrl': sourceUrl.toString(),
      };
      await _persistState();
      await refresh();
      return plugins.value.firstWhere(
        (plugin) => plugin.manifest.id == package.manifest.id,
      );
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<void> setEnabled(String pluginId, bool enabled) async {
    final state = _pluginState(pluginId);
    state['enabled'] = enabled;
    _state[pluginId] = state;
    await _persistState();
    await refresh();
  }

  Future<void> uninstall(String pluginId) async {
    final plugin = plugins.value.firstWhere(
      (item) => item.manifest.id == pluginId,
    );
    if (plugin.origin == PluginOrigin.bundled) {
      throw StateError('Встроенный плагин нельзя удалить');
    }
    final root = _root;
    if (root != null) {
      final directory = Directory(p.join(root.path, pluginId));
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    _state.remove(pluginId);
    await _persistState();
    await refresh();
  }

  Uri? sourceUrl(String pluginId) {
    final raw = _pluginState(pluginId)['sourceUrl'];
    return raw is String ? Uri.tryParse(raw) : null;
  }

  bool _enabled(String pluginId, {required bool fallback}) {
    final value = _pluginState(pluginId)['enabled'];
    return value is bool ? value : fallback;
  }

  Map<String, dynamic> _pluginState(String pluginId) {
    final raw = _state[pluginId];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(_state));
  }
}
