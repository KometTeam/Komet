import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitedLinkSites {
  static const prefKey = 'visited_link_sites';
  static const int _limit = 500;

  static LinkedHashSet<String>? _sites;

  static String siteOf(String url) {
    final trimmed = url.trim();
    final host = Uri.tryParse(trimmed)?.host.toLowerCase() ?? '';
    if (host.isEmpty) return trimmed.toLowerCase();
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static Future<LinkedHashSet<String>> _load() async {
    final loaded = _sites;
    if (loaded != null) return loaded;
    final prefs = await SharedPreferences.getInstance();
    return _sites ??= LinkedHashSet.of(prefs.getStringList(prefKey) ?? []);
  }

  static Future<bool> contains(String url) async =>
      (await _load()).contains(siteOf(url));

  static Future<void> remember(String url) async {
    final sites = await _load();
    final site = siteOf(url);
    if (sites.contains(site)) return;
    sites.add(site);
    while (sites.length > _limit) {
      sites.remove(sites.first);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefKey, sites.toList());
  }

  @visibleForTesting
  static void resetForTest() => _sites = null;
}
