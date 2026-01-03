import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as io;
import 'package:gwid/app_sizes.dart';

class FileDownloadProgressService {
  static final FileDownloadProgressService _instance =
      FileDownloadProgressService._internal();
  factory FileDownloadProgressService() => _instance;
  FileDownloadProgressService._internal();

  final Map<String, ValueNotifier<double>> _progressNotifiers = {};
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final fileIdMap = prefs.getStringList('file_id_to_path_map') ?? [];

      for (final mapping in fileIdMap) {
        final parts = mapping.split(':');
        if (parts.length >= 2) {
          final fileId = parts[0];
          final filePath = parts.skip(1).join(':');

          final file = io.File(filePath);
          if (await file.exists()) {
            if (!_progressNotifiers.containsKey(fileId)) {
              _progressNotifiers[fileId] = ValueNotifier<double>(1.0);
            } else {
              _progressNotifiers[fileId]!.value = 1.0;
            }
          }
        }
      }

      _initialized = true;
    } catch (e) {
      _initialized = true;
    }
  }

  ValueNotifier<double> getProgress(String fileId) {
    _ensureInitialized();
    if (!_progressNotifiers.containsKey(fileId)) {
      _progressNotifiers[fileId] = ValueNotifier<double>(-1);
    }
    return _progressNotifiers[fileId]!;
  }

  void updateProgress(String fileId, double progress) {
    if (!_progressNotifiers.containsKey(fileId)) {
      _progressNotifiers[fileId] = ValueNotifier<double>(progress);
    } else {
      _progressNotifiers[fileId]!.value = progress;
    }
  }

  void clearProgress(String fileId) {
    _progressNotifiers.remove(fileId);
  }
}
