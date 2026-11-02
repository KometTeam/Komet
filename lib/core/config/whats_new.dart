import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import '../whats_new/whats_new_document.dart';
import 'build_profile.dart';

abstract final class WhatsNew {
  static const String _seenBuildKey = 'whats_new_seen_build';
  static const String _notesDir = 'assets/whats_new';
  static const String _fallbackLanguage = 'en';

  static final ValueNotifier<String?> pendingVersion = ValueNotifier(null);
  static int? _build;

  static bool get enabled => !BuildProfile.selfUpdate;

  static Future<void> load() async {
    if (!enabled) return;
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber);
    if (build == null) return;
    _build = build;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt(_seenBuildKey);
    if (seen == null) {
      await prefs.setInt(_seenBuildKey, build);
      return;
    }
    if (build > seen) pendingVersion.value = info.version;
  }

  static Future<void> dismiss() async {
    if (pendingVersion.value == null) return;
    pendingVersion.value = null;
    final build = _build;
    if (build == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seenBuildKey, build);
  }

  static Future<void> preview(bool on) async {
    if (!on) {
      pendingVersion.value = null;
      return;
    }
    pendingVersion.value = (await PackageInfo.fromPlatform()).version;
  }

  static Future<WhatsNewDocument> document(String languageCode) async {
    final String source;
    try {
      source = await rootBundle.loadString('$_notesDir/$languageCode.txt');
    } on FlutterError {
      if (languageCode == _fallbackLanguage) return WhatsNewDocument.empty;
      return document(_fallbackLanguage);
    }
    final parsed = WhatsNewDocument.parse(source);
    for (final problem in parsed.problems) {
      logger.w('[whats-new] $languageCode.txt, $problem');
    }
    return parsed;
  }
}
