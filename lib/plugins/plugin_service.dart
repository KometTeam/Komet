import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'plugin_model.dart';

class PluginService {
  static final PluginService _instance = PluginService._internal();
  factory PluginService() => _instance;
  PluginService._internal();

  final List<KometPlugin> _plugins = [];
  final Map<String, dynamic> _overriddenConstants = {};
  final Map<String, dynamic> _pluginValues = {};

  bool _initialized = false;

  List<KometPlugin> get plugins => List.unmodifiable(_plugins);
  List<KometPlugin> get enabledPlugins =>
      _plugins.where((p) => p.isEnabled).toList();

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final pluginPaths = prefs.getStringList('installed_plugins') ?? [];

    for (final path in pluginPaths) {
      try {
        final plugin = await _loadPluginFromPath(path);
        if (plugin != null) {
          _plugins.add(plugin);
          if (plugin.isEnabled) {
            _applyPluginConstants(plugin);
          }
        }
      } catch (e) {
        print('Ошибка загрузки плагина $path: $e');
      }
    }

    final savedValues = prefs.getString('plugin_values');
    if (savedValues != null) {
      _pluginValues.addAll(jsonDecode(savedValues));
    }

    _initialized = true;
  }

  Future<KometPlugin?> _loadPluginFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return KometPlugin.fromJson(json, path);
  }

  Future<KometPlugin?> loadPluginFile(String filePath) async {
    try {
      return await _loadPluginFromPath(filePath);
    } catch (e) {
      print('Ошибка чтения плагина: $e');
      return null;
    }
  }

  Future<bool> installPlugin(KometPlugin plugin) async {
    if (_plugins.any((p) => p.id == plugin.id)) {
      final existingIndex = _plugins.indexWhere((p) => p.id == plugin.id);
      _plugins[existingIndex] = plugin;
    } else {
      _plugins.add(plugin);
    }

    await _savePluginList();

    if (plugin.isEnabled) {
      _applyPluginConstants(plugin);
    }

    return true;
  }

  Future<void> uninstallPlugin(String pluginId) async {
    final plugin = _plugins.firstWhere(
      (p) => p.id == pluginId,
      orElse: () => throw Exception('Plugin not found'),
    );
    _removePluginConstants(plugin);
    _plugins.removeWhere((p) => p.id == pluginId);
    await _savePluginList();
  }

  Future<void> setPluginEnabled(String pluginId, bool enabled) async {
    final plugin = _plugins.firstWhere((p) => p.id == pluginId);
    plugin.isEnabled = enabled;

    if (enabled) {
      _applyPluginConstants(plugin);
    } else {
      _removePluginConstants(plugin);
    }

    await _savePluginList();
  }

  void _applyPluginConstants(KometPlugin plugin) {
    for (final entry in plugin.overrideConstants.entries) {
      _overriddenConstants[entry.key] = entry.value;
    }
  }

  void _removePluginConstants(KometPlugin plugin) {
    for (final key in plugin.overrideConstants.keys) {
      _overriddenConstants.remove(key);
    }
  }

  Future<void> _savePluginList() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = _plugins.map((p) => p.filePath).toList();
    await prefs.setStringList('installed_plugins', paths);
  }

  T? getConstant<T>(String key, T defaultValue) {
    if (_overriddenConstants.containsKey(key)) {
      return _overriddenConstants[key] as T;
    }
    return defaultValue;
  }

  dynamic getPluginValue(String key, dynamic defaultValue) {
    return _pluginValues[key] ?? defaultValue;
  }

  Future<void> setPluginValue(String key, dynamic value) async {
    _pluginValues[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plugin_values', jsonEncode(_pluginValues));
  }

  List<PluginSection> getAllPluginSections() {
    final sections = <PluginSection>[];
    for (final plugin in enabledPlugins) {
      sections.addAll(plugin.settingsSections);
    }
    return sections;
  }

  List<PluginSubsection> getSubsectionsFor(String parentSection) {
    final subsections = <PluginSubsection>[];
    for (final plugin in enabledPlugins) {
      subsections.addAll(
        plugin.settingsSubsections.where(
          (s) => s.parentSection == parentSection,
        ),
      );
    }
    return subsections;
  }

  PluginScreen? getReplacementScreen(String screenId) {
    for (final plugin in enabledPlugins) {
      if (plugin.replaceScreens.containsKey(screenId)) {
        return plugin.replaceScreens[screenId];
      }
    }
    return null;
  }

  bool isScreenReplaced(String screenId) {
    if (screenId == 'PluginsScreen') return false;
    return enabledPlugins.any((p) => p.replaceScreens.containsKey(screenId));
  }

  Future<void> executeAction(PluginAction action, BuildContext context) async {
    switch (action.type) {
      case PluginActionType.setValue:
        await setPluginValue(action.target, action.value);
        break;
      case PluginActionType.callAction:
        await _executeBuiltinAction(action.target, context);
        break;
      case PluginActionType.openUrl:
        final uri = Uri.parse(action.target);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
      case PluginActionType.navigate:
        break;
    }
  }

  Future<void> _executeBuiltinAction(
    String actionId,
    BuildContext context,
  ) async {
    switch (actionId) {
      case 'clear_cache':
        break;
      case 'reconnect':
        break;
      case 'show_snackbar':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Действие выполнено!')));
        break;
    }
  }

  static const Map<String, String> availableActions = {
    'clear_cache': 'Очистить кэш',
    'reconnect': 'Переподключиться',
    'show_snackbar': 'Показать уведомление',
  };
}
