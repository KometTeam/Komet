import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalContactAvatars {
  LocalContactAvatars._();

  static final LocalContactAvatars instance = LocalContactAvatars._();

  static const _prefsKey = 'local_contact_avatars';
  static const _dirName = 'contact_avatars';

  final ValueNotifier<int> revision = ValueNotifier(0);
  final Map<int, String> _paths = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    for (final MapEntry(:key, :value) in decoded.entries) {
      final userId = int.tryParse('$key');
      if (userId == null || value is! String) continue;
      if (await File(value).exists()) _paths[userId] = value;
    }
  }

  bool has(int userId) => _paths.containsKey(userId);

  ImageProvider? imageFor(int userId) {
    final path = _paths[userId];
    return path == null ? null : FileImage(File(path));
  }

  Future<void> set(int userId, Uint8List jpeg) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/$_dirName');
    await dir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/${userId}_$stamp.jpg');
    await file.writeAsBytes(jpeg, flush: true);
    await _replace(userId, file.path);
  }

  Future<void> clear(int userId) => _replace(userId, null);

  Future<void> _replace(int userId, String? path) async {
    final previous = _paths[userId];
    if (previous == path) return;
    if (path == null) {
      _paths.remove(userId);
    } else {
      _paths[userId] = path;
    }
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({for (final e in _paths.entries) '${e.key}': e.value}),
    );
    if (previous == null) return;
    try {
      await File(previous).delete();
    } on FileSystemException {
      return;
    }
  }
}
