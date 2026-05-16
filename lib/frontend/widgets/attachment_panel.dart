import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:komet/backend/modules/messages.dart' show FileHistoryCache, FileHistoryEntry;
import 'package:komet/core/config/proxy_config.dart';
import 'package:komet/core/protocol/opcode_map.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/core/transport/proxy_connector.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/main.dart' show api, messagesModule;
import 'package:material_symbols_icons/symbols.dart';

class AttachmentPanel extends StatefulWidget {
  final int chatId;
  final VoidCallback onClose;

  const AttachmentPanel({
    super.key,
    required this.chatId,
    required this.onClose,
  });

  @override
  State<AttachmentPanel> createState() => _AttachmentPanelState();
}

class _AttachmentPanelState extends State<AttachmentPanel> {
  final TextEditingController _fileIdController = TextEditingController();
  bool _isUploading = false;

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _isUploading = true);

    try {
      final uploadInfo = await messagesModule.requestUploadUrl();
      if (uploadInfo == null) {
        if (mounted) showCustomNotification(context, 'Не удалось получить ссылку');
        return;
      }

      await api.sendRequest(Opcode.msgTyping, {
        'chatId': widget.chatId,
        'type': 'FILE',
      });

      final uri = Uri.parse(uploadInfo.url);
      final fileBytes = await File(file.path!).readAsBytes();
      final proxySettings = await ProxyConfig.load();

      int statusCode;
      if (proxySettings.isEnabled) {
        final connector = ProxyConnector(proxySettings);
        final proxySocket = await connector.connect(uri.host, uri.port);
        final socket = uri.scheme == 'https'
            ? await RawSecureSocket.secure(
                proxySocket,
                host: uri.host,
                onBadCertificate: (_) => true,
              )
            : proxySocket;
        statusCode = await _rawPost(socket, uri, fileBytes, file.name);
      } else {
        final socket = await RawSocket.connect(uri.host, uri.port);
        final secureSocket = uri.scheme == 'https'
            ? await RawSecureSocket.secure(
                socket,
                host: uri.host,
                onBadCertificate: (_) => true,
              )
            : socket;
        statusCode = await _rawPost(secureSocket, uri, fileBytes, file.name);
      }

      if (statusCode != 200) {
        if (mounted) showCustomNotification(context, 'Ошибка загрузки: $statusCode');
        return;
      }

      // Wait for notifAttach push
      final pushCompleter = Completer<void>();
      void Function(Packet)? pushHandler;
      pushHandler = (Packet packet) {
        final payload = packet.payload;
        if (payload is Map && payload['fileId'] == uploadInfo.fileId) {
          api.unregisterPushHandler(Opcode.notifAttach);
          pushCompleter.complete();
        }
      };
      api.registerPushHandler(Opcode.notifAttach, (Packet p) => pushHandler!(p));

      await pushCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          api.unregisterPushHandler(Opcode.notifAttach);
          throw TimeoutException('Тайм-аут подтверждения загрузки');
        },
      );

      // Retry loop: server may say "attachment in progress" (cmd=3)
      for (var attempt = 0; attempt < 5; attempt++) {
        final sent = await messagesModule.sendFileMessage(
          widget.chatId,
          uploadInfo.fileId,
          token: uploadInfo.token,
        );

        // Listen for push again (another notifAttach may come)
        final msgCompleter = Completer<bool>();
        void Function(Packet)? msgHandler;
        msgHandler = (Packet packet) {
          final payload = packet.payload;
          if (payload is Map && payload['fileId'] == uploadInfo.fileId) {
            api.unregisterPushHandler(Opcode.notifAttach);
            msgCompleter.complete(true);
          }
        };
        api.registerPushHandler(Opcode.notifAttach, (Packet p) => msgHandler!(p));

        final pushFuture = msgCompleter.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            api.unregisterPushHandler(Opcode.notifAttach);
            return false;
          },
        );

        final pushReceived = await pushFuture;
        if (pushReceived && sent) {
          FileHistoryCache.add(FileHistoryEntry(
            fileId: uploadInfo.fileId,
            url: uploadInfo.url,
            token: uploadInfo.token,
            sentAt: DateTime.now(),
          ));
          if (mounted) {
            showCustomNotification(context, 'Файл отправлен');
            widget.onClose();
          }
          return;
        }

        // If push was received, check if message was sent
        if (pushReceived) {
          FileHistoryCache.add(FileHistoryEntry(
            fileId: uploadInfo.fileId,
            url: uploadInfo.url,
            token: uploadInfo.token,
            sentAt: DateTime.now(),
          ));
          if (mounted) {
            showCustomNotification(context, 'Файл отправлен');
            widget.onClose();
          }
          return;
        }

        if (!sent) {
          // msgSend failed, maybe server still processing — wait and retry
          await Future.delayed(Duration(seconds: 1 + attempt));
          continue;
        }

        // Sent ok, no push received (already processed earlier)
        FileHistoryCache.add(FileHistoryEntry(
          fileId: uploadInfo.fileId,
          url: uploadInfo.url,
          token: uploadInfo.token,
          sentAt: DateTime.now(),
        ));
        if (mounted) {
          showCustomNotification(context, 'Файл отправлен');
          widget.onClose();
        }
        return;
      }

      if (mounted) showCustomNotification(context, 'Не удалось отправить сообщение');
    } catch (e) {
      if (mounted) showCustomNotification(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<int> _rawPost(RawSocket socket, Uri uri, List<int> body, String filename) async {
    final path = '${uri.path}${uri.hasQuery ? "?${uri.query}" : ""}';
    final host = uri.host;
    final total = body.length;

    final request = StringBuffer()
      ..write('POST $path HTTP/1.1\r\n')
      ..write('Host: $host\r\n')
      ..write('Content-Type: application/x-binary; charset=x-user-defined\r\n')
      ..write('Content-Disposition: attachment; filename=$filename\r\n')
      ..write('Connection: keep-alive\r\n')
      ..write('User-Agent: ${Uri.encodeComponent('OKMessages/26.14.1 (Android 11; TECNO MOBILE LIMITED TECNO LE7n; xxhdpi 480dpi 1080x2208)')}\r\n')
      ..write('Content-Range: bytes 0-${total - 1}/$total\r\n')
      ..write('Content-Length: $total\r\n')
      ..write('\r\n');

    final requestBytes = utf8.encode(request.toString());
    final allBytes = <int>[...requestBytes, ...(body is Uint8List ? body : Uint8List.fromList(body))];
    socket.write(Uint8List.fromList(allBytes));

    final responseBytes = <int>[];
    final completer = Completer<int>();
    Timer? timer;

    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final data = socket.read();
        if (data != null) responseBytes.addAll(data);
      } else if (event == RawSocketEvent.readClosed || event == RawSocketEvent.closed) {
        timer?.cancel();
        if (responseBytes.isEmpty) {
          completer.completeError(const SocketException('Пустой ответ сервера'));
          return;
        }
        final headerEnd = _findHeaderEnd(responseBytes);
        if (headerEnd == -1) {
          completer.completeError(const SocketException('Не удалось прочитать заголовок ответа'));
          return;
        }
        final headerStr = utf8.decode(responseBytes.sublist(0, headerEnd), allowMalformed: true);
        final statusLine = headerStr.split('\r\n').first;
        debugPrint('HTTP Response: $statusLine');
        final parts = statusLine.split(' ');
        completer.complete(parts.length >= 2 ? int.tryParse(parts[1]) ?? 0 : 0);
      }
    }, onError: (e) {
      timer?.cancel();
      completer.completeError(e);
    });

    timer = Timer(const Duration(minutes: 5), () {
      socket.close();
      completer.completeError(TimeoutException('Тайм-аут загрузки'));
    });

    return completer.future;
  }

  int _findHeaderEnd(List<int> bytes) {
    for (var i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == 0x0D && bytes[i + 1] == 0x0A &&
          bytes[i + 2] == 0x0D && bytes[i + 3] == 0x0A) {
        return i + 4;
      }
    }
    return -1;
  }

  Future<void> _uploadByFileId() async {
    final fileIdStr = _fileIdController.text.trim();
    if (fileIdStr.isEmpty) return;
    final fileId = int.tryParse(fileIdStr);
    if (fileId == null) {
      if (mounted) showCustomNotification(context, 'Неверный fileId');
      return;
    }
    setState(() => _isUploading = true);
    try {
      final sent = await messagesModule.sendFileMessage(widget.chatId, fileId);
      if (sent) {
        if (mounted) {
          showCustomNotification(context, 'Файл отправлен');
          widget.onClose();
        }
      } else {
        if (mounted) showCustomNotification(context, 'Ошибка отправки');
      }
    } catch (e) {
      if (mounted) showCustomNotification(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _fileIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy > 300) widget.onClose();
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Expanded(child: _buildButton(
                label: 'Выбрать из файла',
                icon: Symbols.folder_open,
                filled: true,
                onTap: _isUploading ? null : _pickAndUploadFile,
                cs: cs,
              )),
              const SizedBox(width: 8),
              Expanded(child: _buildButton(
                label: 'Отправить по id',
                icon: null,
                filled: false,
                onTap: _isUploading ? null : _uploadByFileId,
                cs: cs,
              )),
            ]),
          ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _fileIdController,
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'fileId...',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('История', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
          if (FileHistoryCache.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('история пуста...', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: FileHistoryCache.history.length,
                itemBuilder: (ctx, idx) {
                  final e = FileHistoryCache.history[idx];
                  return Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.description, color: cs.onSurfaceVariant, size: 28),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('${e.fileId}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 9), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        ),
                      ],
                    )),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData? icon,
    required bool filled,
    required VoidCallback? onTap,
    required ColorScheme cs,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: filled ? cs.onPrimaryContainer : cs.onSurface),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(
              color: filled ? cs.onPrimaryContainer : cs.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            )),
          ],
        ),
      ),
    );
  }
}
