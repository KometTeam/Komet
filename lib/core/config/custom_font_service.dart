import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'font_metrics.dart';

// #***! шрифты с гугл фонтс, скачали в кэш зарегистрировали
class CustomFontService {
  static const String prefKey = 'app_custom_fonts';
  // #***! гугл даёт ttf только старым браузерам, современному прилетит woff2 который флаттер не умеет
  static const String _userAgent =
      'Mozilla/5.0 (Linux; U; Android 4.4.2; en-us) '
      'AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30';

  // #***! что уже зарегистрировано, второй раз грузить нельзя
  static final Set<String> _loaded = <String>{};
  static final Map<String, double> _metricScales = <String, double>{};

  static double metricScaleFor(String family) => _metricScales[family] ?? 1.0;

  // #***! список семейств в prefs, файлы в кэше
  static Future<List<String>> families() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(prefKey) ?? const <String>[];
  }

  // #***! на старте поднимаем скачанное с диска, без сети
  static Future<void> preloadCached() async {
    final dir = await _cacheDir();
    for (final family in await families()) {
      if (_loaded.contains(family)) continue;
      final file = _fileFor(dir, family);
      if (!await file.exists()) continue;
      try {
        await _register(family, await file.readAsBytes());
      } catch (_) {}
    }
  }

  // #***! сначала кэш потом сеть
  static Future<String?> addFamily(String family) async {
    try {
      final dir = await _cacheDir();
      final file = _fileFor(dir, family);
      Uint8List? bytes;
      if (await file.exists()) {
        final cached = await file.readAsBytes();
        if (_isSfnt(cached)) bytes = cached;
      }
      if (bytes == null) {
        bytes = await _download(family);
        if (bytes == null) return null;
        await file.writeAsBytes(bytes);
      }
      await _register(family, bytes);
      await _persist(family);
      return family;
    } catch (e) {
      logger.w('CustomFont: не удалось добавить «$family»: $e');
      return null;
    }
  }

  // #***! удаляем из списка и файл с диска
  static Future<void> removeFamily(String family) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(prefKey) ?? <String>[];
    list.remove(family);
    await prefs.setStringList(prefKey, list);
    final file = _fileFor(await _cacheDir(), family);
    if (await file.exists()) await file.delete();
  }

  static Future<Directory> _cacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/custom_fonts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // #***! имя семейства в имя файла, лишнее в подчёркивания
  static File _fileFor(Directory dir, String family) {
    final safe = family.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${dir.path}/$safe.ttf');
  }

  // #***! проверяем что это шрифт и считаем метрику
  static Future<void> _register(String family, Uint8List bytes) async {
    if (!_isSfnt(bytes)) {
      throw const FormatException('downloaded data is not a ttf/otf font');
    }
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loaded.add(family);
    final xHeight = FontMetrics.xHeightRatio(bytes);
    if (xHeight != null) {
      _metricScales[family] = FontMetrics.scaleForXHeight(xHeight);
    }
  }

  // #***! сигнатура шрифта, ttf otf true или ttc
  static bool _isSfnt(Uint8List b) {
    if (b.length < 4) return false;
    final tag = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
    return tag == 0x00010000 ||
        tag == 0x4F54544F ||
        tag == 0x74727565 ||
        tag == 0x74746366;
  }

  static Future<void> _persist(String family) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(prefKey) ?? <String>[];
    if (!list.contains(family)) {
      list.add(family);
      await prefs.setStringList(prefKey, list);
    }
  }

  // #***! три варианта url, у части шрифтов есть только версия с весами
  static Future<Uint8List?> _download(String family) async {
    final encoded = Uri.encodeQueryComponent(family);
    final variants = <String>[
      'https://fonts.googleapis.com/css2?family=$encoded',
      'https://fonts.googleapis.com/css2?family=$encoded:wght@400',
      'https://fonts.googleapis.com/css2?family=$encoded:wght@100..900',
    ];
    final urlRegex = RegExp(r'url\((https://[^)]+)\)');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      for (final url in variants) {
        final css = await _fetchText(client, Uri.parse(url));
        if (css == null) continue;
        for (final match in urlRegex.allMatches(css)) {
          final fontUrl = match.group(1);
          if (fontUrl == null) continue;
          final bytes = await _fetchBytes(client, Uri.parse(fontUrl));
          if (bytes != null && _isSfnt(bytes)) return bytes;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // #***! css со ссылками на файлы
  static Future<String?> _fetchText(HttpClient client, Uri uri) async {
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    final resp = await req.close().timeout(const Duration(seconds: 20));
    if (resp.statusCode != HttpStatus.ok) {
      await resp.drain<void>();
      return null;
    }
    return resp
        .transform(const Utf8Decoder())
        .join()
        .timeout(const Duration(seconds: 20));
  }

  // #***! сам файл шрифта
  static Future<Uint8List?> _fetchBytes(HttpClient client, Uri uri) async {
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    final resp = await req.close().timeout(const Duration(seconds: 20));
    if (resp.statusCode != HttpStatus.ok) {
      await resp.drain<void>();
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await resp.forEach(builder.add).timeout(const Duration(seconds: 30));
    return builder.takeBytes();
  }
}
