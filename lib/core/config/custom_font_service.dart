import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomFontService {
  static const String prefKey = 'app_custom_fonts';
  static const String _userAgent = 'Mozilla/5.0 (X11; Linux x86_64) Chrome/120';

  static final Set<String> _loaded = <String>{};

  static Future<List<String>> families() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(prefKey) ?? const <String>[];
  }

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

  static Future<String?> addFamily(String family) async {
    final dir = await _cacheDir();
    final file = _fileFor(dir, family);
    Uint8List? bytes;
    if (await file.exists()) {
      bytes = await file.readAsBytes();
    } else {
      bytes = await _download(family);
      if (bytes == null) return null;
      await file.writeAsBytes(bytes);
    }
    try {
      await _register(family, bytes);
    } catch (_) {
      if (await file.exists()) await file.delete();
      return null;
    }
    await _persist(family);
    return family;
  }

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

  static File _fileFor(Directory dir, String family) {
    final safe = family.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${dir.path}/$safe.ttf');
  }

  static Future<void> _register(String family, Uint8List bytes) async {
    if (!_isSfnt(bytes)) {
      throw const FormatException('downloaded data is not a ttf/otf font');
    }
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loaded.add(family);
  }

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

  static Future<Uint8List?> _download(String family) async {
    final encoded = Uri.encodeQueryComponent(family);
    final variants = <String>[
      'https://fonts.googleapis.com/css2?family=$encoded:wght@100..900',
      'https://fonts.googleapis.com/css2?family=$encoded',
    ];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      for (final url in variants) {
        final css = await _fetchText(client, Uri.parse(url));
        if (css == null) continue;
        final ttf = RegExp(r'url\((https://[^)]+\.ttf)\)').firstMatch(css);
        final ttfUrl = ttf?.group(1);
        if (ttfUrl == null) continue;
        final bytes = await _fetchBytes(client, Uri.parse(ttfUrl));
        if (bytes != null && _isSfnt(bytes)) return bytes;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String?> _fetchText(HttpClient client, Uri uri) async {
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    final resp = await req.close();
    if (resp.statusCode != HttpStatus.ok) {
      await resp.drain<void>();
      return null;
    }
    return resp.transform(const Utf8Decoder()).join();
  }

  static Future<Uint8List?> _fetchBytes(HttpClient client, Uri uri) async {
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    final resp = await req.close();
    if (resp.statusCode != HttpStatus.ok) {
      await resp.drain<void>();
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in resp) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
