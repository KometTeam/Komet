import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class AdBlockService {
  static final AdBlockService instance = AdBlockService._();
  AdBlockService._();

  static const String _hostsFilesKey = 'ad_block_hosts_files';
  static const String _customDomainsKey = 'ad_block_custom_domains';
  static const String _enabledKey = 'ad_block_enabled';
  static const int _cacheMaxSize = 500;

  final Set<String> _blockedDomains = {};
  final Set<String> _customDomains = {};
  final Map<String, bool> _hostCache = {}; // Кэш результатов проверки
  final List<String> _cacheOrder = []; // Порядок для LRU
  List<String> _hostsFilePaths = [];
  bool _isEnabled = true;
  bool _isInitialized = false;

  bool get isEnabled => _isEnabled;
  int get blockedDomainsCount => _blockedDomains.length;
  int get customDomainsCount => _customDomains.length;
  List<String> get hostsFilePaths => List.unmodifiable(_hostsFilePaths);
  List<String> get customDomains => _customDomains.toList()..sort();

  Future<void> init() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? true;
    
    // Загружаем hosts-файлы
    final hostsJson = prefs.getString(_hostsFilesKey);
    if (hostsJson != null) {
      _hostsFilePaths = List<String>.from(jsonDecode(hostsJson));
      await _loadAllHostsFiles();
    }
    
    // Загружаем пользовательские домены
    final customJson = prefs.getString(_customDomainsKey);
    if (customJson != null) {
      _customDomains.addAll(List<String>.from(jsonDecode(customJson)));
      _blockedDomains.addAll(_customDomains);
    }
    
    _isInitialized = true;
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<bool> addHostsFile(String filePath) async {
    if (_hostsFilePaths.contains(filePath)) {
      return false;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }

    _hostsFilePaths.add(filePath);
    await _saveHostsFilePaths();
    await _parseHostsFile(filePath);
    return true;
  }

  Future<void> removeHostsFile(String filePath) async {
    _hostsFilePaths.remove(filePath);
    await _saveHostsFilePaths();
    await _reloadAllDomains();
  }

  Future<void> reloadAllHostsFiles() async {
    await _reloadAllDomains();
  }

  /// Добавить пользовательский домен
  Future<bool> addCustomDomain(String domain) async {
    final normalized = _normalizeDomain(domain);
    if (normalized == null || _customDomains.contains(normalized)) {
      return false;
    }
    
    _customDomains.add(normalized);
    _blockedDomains.add(normalized);
    await _saveCustomDomains();
    return true;
  }

  /// Удалить пользовательский домен
  Future<void> removeCustomDomain(String domain) async {
    _customDomains.remove(domain);
    await _saveCustomDomains();
    await _reloadAllDomains();
  }

  /// Нормализация домена
  String? _normalizeDomain(String input) {
    var domain = input.trim().toLowerCase();
    
    // Убираем протокол если есть
    if (domain.startsWith('http://')) {
      domain = domain.substring(7);
    } else if (domain.startsWith('https://')) {
      domain = domain.substring(8);
    }
    
    // Убираем путь если есть
    final slashIndex = domain.indexOf('/');
    if (slashIndex != -1) {
      domain = domain.substring(0, slashIndex);
    }
    
    // Убираем www если есть
    if (domain.startsWith('www.')) {
      domain = domain.substring(4);
    }
    
    // Проверяем валидность
    if (domain.isEmpty || !domain.contains('.')) {
      return null;
    }
    
    return domain;
  }

  Future<void> _saveCustomDomains() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customDomainsKey, jsonEncode(_customDomains.toList()));
  }

  Future<void> _reloadAllDomains() async {
    _blockedDomains.clear();
    _clearCache();
    await _loadAllHostsFiles();
    _blockedDomains.addAll(_customDomains);
  }

  bool shouldBlockDomain(String url) {
    if (!_isEnabled || _blockedDomains.isEmpty) {
      return false;
    }

    try {
      // Быстро извлекаем хост без полного парсинга URI
      final host = _extractHost(url);
      if (host == null || host.isEmpty) return false;
      
      // Проверяем кэш
      final cached = _hostCache[host];
      if (cached != null) {
        return cached;
      }
      
      // Проверяем и кэшируем результат
      final result = _checkHost(host);
      _addToCache(host, result);
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Быстрое извлечение хоста из URL без Uri.parse
  String? _extractHost(String url) {
    var start = 0;
    
    // Пропускаем протокол
    if (url.startsWith('https://')) {
      start = 8;
    } else if (url.startsWith('http://')) {
      start = 7;
    }
    
    // Находим конец хоста
    var end = url.indexOf('/', start);
    if (end == -1) end = url.indexOf('?', start);
    if (end == -1) end = url.indexOf('#', start);
    if (end == -1) end = url.length;
    
    // Извлекаем хост
    var host = url.substring(start, end).toLowerCase();
    
    // Убираем порт если есть
    final colonIndex = host.indexOf(':');
    if (colonIndex != -1) {
      host = host.substring(0, colonIndex);
    }
    
    return host.isEmpty ? null : host;
  }

  /// Проверка хоста в списке заблокированных
  bool _checkHost(String host) {
    // Точное совпадение
    if (_blockedDomains.contains(host)) {
      return true;
    }
    
    // Проверяем без www
    if (host.startsWith('www.')) {
      if (_blockedDomains.contains(host.substring(4))) {
        return true;
      }
    }
    
    // Проверяем поддомены (только если точек больше одной)
    var dotCount = 0;
    for (var i = 0; i < host.length; i++) {
      if (host[i] == '.') dotCount++;
    }
    
    if (dotCount > 1) {
      var idx = host.indexOf('.');
      while (idx != -1 && idx < host.length - 1) {
        final subdomain = host.substring(idx + 1);
        if (_blockedDomains.contains(subdomain)) {
          return true;
        }
        idx = host.indexOf('.', idx + 1);
      }
    }
    
    return false;
  }

  /// Добавление в кэш с LRU вытеснением
  void _addToCache(String host, bool blocked) {
    if (_cacheOrder.length >= _cacheMaxSize) {
      // Удаляем старые записи
      final toRemove = _cacheOrder.take(50).toList();
      for (final key in toRemove) {
        _hostCache.remove(key);
        _cacheOrder.remove(key);
      }
    }
    _hostCache[host] = blocked;
    _cacheOrder.add(host);
  }

  /// Очистка кэша (вызывать при изменении списка доменов)
  void _clearCache() {
    _hostCache.clear();
    _cacheOrder.clear();
  }

  Future<void> _saveHostsFilePaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostsFilesKey, jsonEncode(_hostsFilePaths));
  }

  Future<void> _loadAllHostsFiles() async {
    for (final filePath in _hostsFilePaths) {
      await _parseHostsFile(filePath);
    }
  }

  Future<void> _parseHostsFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return;
      }

      final lines = await file.readAsLines();
      
      for (final line in lines) {
        final trimmed = line.trim();
        
        // Пропускаем комментарии и пустые строки
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }

        // Парсим строку hosts: "0.0.0.0 domain.com" или "127.0.0.1 domain.com"
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final ip = parts[0];
          final domain = parts[1].toLowerCase();
          
          // Добавляем только блокирующие записи (0.0.0.0 или 127.0.0.1)
          // и игнорируем localhost
          if ((ip == '0.0.0.0' || ip == '127.0.0.1') && 
              domain != 'localhost' &&
              domain.contains('.')) {
            _blockedDomains.add(domain);
          }
        }
      }
    } catch (e) {
      print('❌ Error parsing hosts file $filePath: $e');
    }
  }

  /// Получить имя файла из пути
  String getFileName(String filePath) {
    return filePath.split('/').last;
  }
}

