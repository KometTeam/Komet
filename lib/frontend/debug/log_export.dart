import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import '../../core/transport/traffic_monitor.dart';
import '../../core/utils/debug_session_log.dart';
import '../../core/utils/format.dart';
import '../widgets/custom_notification.dart';

Future<void> exportDebugLog(BuildContext context) async {
  final exportFiles = await DebugSessionLog.instance.buildExportFiles(
    endpoint: TrafficMonitor.instance.activeEndpoint,
  );
  if (exportFiles == null) {
    if (context.mounted) showCustomNotification(context, 'Лог пуст');
    return;
  }
  final archive = Archive();
  for (final file in exportFiles) {
    final data = utf8.encode(file.content);
    archive.addFile(ArchiveFile(file.name, data.length, data));
  }
  final bytes = ZipEncoder().encodeBytes(archive);
  final fileName = 'komet_debug_${formatFileStamp(DateTime.now())}.zip';
  final isMobile = Platform.isAndroid || Platform.isIOS;
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Сохранить отладочный лог',
      fileName: fileName,
      type: FileType.any,
      bytes: isMobile ? bytes : null,
    );
    if (path == null) return;
    if (!isMobile) {
      await File(path).writeAsBytes(bytes);
    }
    if (context.mounted) {
      showCustomNotification(context, 'Лог сохранён: $path');
    }
  } catch (e) {
    if (context.mounted) {
      showCustomNotification(context, 'Не удалось сохранить лог: $e');
    }
  }
}
