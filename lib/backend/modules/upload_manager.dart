import 'dart:async';
import 'dart:io';

import '../../main.dart';
import 'cloud_storage.dart';
import 'file_uploader.dart';
import 'upload_notification_service.dart';

class UploadManager {
  UploadManager._();
  static final instance = UploadManager._();

  StreamSubscription<UploadEvent>? _sub;
  bool get isActive => _sub != null;

  // UI callbacks — registered by the screen while it is mounted
  void Function(double progress, int speedBps)? onProgress;
  void Function(CloudFile file)? onDone;
  void Function(String error)? onError;

  Future<void> start({
    required int chatId,
    required int accountId,
    required File file,
    required String filename,
    required int totalSize,
  }) async {
    await cancel(); // cancel any previous upload

    await UploadNotificationService.start(filename);

    var lastSentBytes = 0;
    var lastSpeedMs = DateTime.now().millisecondsSinceEpoch;
    var speedBps = 0;
    var lastNotifPercent = -1;

    _sub = fileUploader
        .upload(
          chatId: chatId,
          file: file,
          filename: filename,
          totalSize: totalSize,
        )
        .listen(
          (event) async {
            switch (event) {
              case UploadProgress(:final sent, :final total):
                final progress = total > 0 ? sent / total : 0.0;

                // Speed: recompute every 500 ms
                final nowMs = DateTime.now().millisecondsSinceEpoch;
                final elapsed = nowMs - lastSpeedMs;
                if (elapsed >= 500) {
                  speedBps = ((sent - lastSentBytes) * 1000 / elapsed).round();
                  lastSentBytes = sent;
                  lastSpeedMs = nowMs;
                }

                onProgress?.call(progress, speedBps);

                // Throttle notification to once per 1% change
                final percent = total > 0 ? (sent * 100 ~/ total) : 0;
                if (percent != lastNotifPercent) {
                  lastNotifPercent = percent;
                  UploadNotificationService.update(
                    filename: filename,
                    progressPercent: percent,
                    speedBps: speedBps,
                  );
                }

              case UploadDone(:final fileId):
                _sub = null;
                UploadNotificationService.stop();
                final newest = await CloudStorageModule.fetchLatestFile(
                  messagesModule,
                  accountId,
                  chatId,
                  expectedFileId: fileId,
                );
                if (newest != null) {
                  onDone?.call(newest);
                }

              case UploadError(:final message):
                _sub = null;
                UploadNotificationService.stop();
                onError?.call(message);
            }
          },
          onError: (_) {
            _sub = null;
            UploadNotificationService.stop();
          },
        );
  }

  Future<void> cancel() async {
    await _sub?.cancel();
    _sub = null;
    await UploadNotificationService.stop();
  }
}
