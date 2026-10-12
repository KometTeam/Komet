import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../models/attachment.dart';
import '../config/komet_settings.dart';
import '../storage/app_database.dart';
import '../utils/logger.dart';
import '../utils/media_cache.dart';
import '../utils/media_cache_names.dart';

// #***! удалённое сообщение остаётся, а файл на сервере умирает: пока ссылка
// ещё жива, снимаем копию в закреплённый кэш и прописываем её в payload
Future<void> keepDeletedMedia(
  int accountId,
  int chatId,
  List<String> messageIds,
) async {
  if (!KometSettings.viewDeleted.value || messageIds.isEmpty) return;

  final List<Map<String, dynamic>> rows;
  try {
    rows = await AppDatabase.loadMessagesByIds(accountId, chatId, messageIds);
  } catch (e) {
    logger.w('keepDeletedMedia: не прочитал сообщения: $e');
    return;
  }

  final updated = <Map<String, dynamic>>[];
  for (final row in rows) {
    final payload = _decodePayload(row['payload']);
    final attaches = payload?['attaches'];
    if (payload == null || attaches is! List) continue;
    var changed = false;
    for (final attach in attaches.whereType<Map>()) {
      if (await _keepPhoto(attach)) changed = true;
    }
    if (!changed) continue;
    updated.add(
      Map<String, dynamic>.from(row)..['payload'] = jsonEncode(payload),
    );
  }

  if (updated.isEmpty) return;
  try {
    await AppDatabase.saveMessages(updated);
  } catch (e) {
    logger.w('keepDeletedMedia: не сохранил локальные пути: $e');
  }
}

Future<bool> _keepPhoto(Map<dynamic, dynamic> attach) async {
  if ((attach['_type'] as String?)?.toUpperCase() != 'PHOTO') return false;
  final saved = attach['localPath'] as String?;
  if (saved != null && saved.isNotEmpty && await File(saved).exists()) {
    return false;
  }

  final photo = PhotoAttachment.fromMap(Map<String, dynamic>.from(attach));
  final url = photo.baseUrl ?? '';
  if (url.isEmpty || url.startsWith('data:')) return false;

  final name = photoCacheName(photo, url);
  final source = await MediaCache.existing(name) ?? await _shownCopy(url);
  final kept = await MediaCache.keep(name, source: source, url: url);
  if (kept == null) return false;

  attach['localPath'] = kept.path;
  return true;
}

// #***! то что уже показывали лежит в кэше картинок, из него и копируем
Future<File?> _shownCopy(String url) async {
  try {
    final info = await DefaultCacheManager().getFileFromCache(url);
    final path = info?.file.path;
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _decodePayload(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } catch (_) {
    return null;
  }
}
