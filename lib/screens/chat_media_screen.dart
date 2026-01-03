import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/utils/download_path_helper.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as io;
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:gwid/app_sizes.dart';

class ChatMediaScreen extends StatefulWidget {
  final int chatId;
  final String chatTitle;
  final List<Message> messages;
  final Function(String messageId)? onGoToMessage;

  const ChatMediaScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.messages,
    this.onGoToMessage,
  });

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _error = '';

  List<Message> _mediaMessages = [];
  List<Message> _fileMessages = [];
  List<Message> _audioMessages = [];
  List<Message> _linkMessages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _processMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _processMessages() {
    final allMessages = List<Message>.from(widget.messages);

    allMessages.sort((a, b) => b.time.compareTo(a.time));

    _filterMessages(allMessages);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterMessages(List<Message> messages) {
    _mediaMessages.clear();
    _fileMessages.clear();
    _audioMessages.clear();
    _linkMessages.clear();

    for (final message in messages) {
      final hasMedia = message.attaches.any((attach) {
        final type = attach['_type'] as String?;
        return type == 'PHOTO' || type == 'VIDEO';
      });
      if (hasMedia) {
        _mediaMessages.add(message);
      }

      final hasFile = message.attaches.any((attach) {
        final type = attach['_type'] as String?;
        return type == 'FILE';
      });
      if (hasFile) {
        _fileMessages.add(message);
      }

      final hasAudio = message.attaches.any((attach) {
        final type = attach['_type'] as String?;
        return type == 'AUDIO' || type == 'VOICE';
      });
      if (hasAudio) {
        _audioMessages.add(message);
      }

      bool hasLink = false;
      if (message.text.isNotEmpty) {
        for (final element in message.elements) {
          if (element['type'] == 'LINK' ||
              element['attributes']?['url'] != null) {
            hasLink = true;
            break;
          }
        }

        if (!hasLink) {
          final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
          hasLink = urlPattern.hasMatch(message.text);
        }
      }
      if (hasLink) {
        _linkMessages.add(message);
      }
    }
  }

  void _goToMessage(String messageId) {
    if (!mounted) return;
    Navigator.of(context).pop();

    if (widget.onGoToMessage != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return; //бля а может и не надо сюда
        widget.onGoToMessage!(messageId);
      });
    }
  }

  Future<void> _downloadFile(
    Message message,
    Map<String, dynamic> attach,
  ) async {
    try {
      final url = attach['url'] ?? attach['baseUrl'];
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('URL файла не найден')));
        return;
      }

      final downloadDir = await DownloadPathHelper.getDownloadDirectory();
      if (downloadDir == null || !await downloadDir.exists()) {
        throw Exception('Папка загрузок не найдена');
      }

      String fileName = attach['name'] as String? ?? 'file';
      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last;
        if (lastSegment.contains('.')) {
          fileName = lastSegment;
        }
      }

      final filePath = '${downloadDir.path}/$fileName';
      final file = io.File(filePath);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Загрузка файла...')));

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);

        final prefs = await SharedPreferences.getInstance();
        final List<String> downloadedFiles =
            prefs.getStringList('downloaded_files') ?? [];
        if (!downloadedFiles.contains(filePath)) {
          downloadedFiles.add(filePath);
          await prefs.setStringList('downloaded_files', downloadedFiles);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Файл сохранен: $fileName'),
              action: SnackBarAction(
                label: 'Открыть',
                onPressed: () => OpenFile.open(filePath),
              ),
            ),
          );
        }
      } else {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при скачивании: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _playAudio(Message message, Map<String, dynamic> attach) {
    _goToMessage(message.id);
  }

  void _viewMedia(Message message, Map<String, dynamic> attach) {
    final url = attach['url'] ?? attach['baseUrl'];
    final preview = attach['previewData'];

    Widget? imageChild;
    if (url is String && url.isNotEmpty) {
      if (url.startsWith('file://')) {
        final path = url.replaceFirst('file://', '');
        imageChild = Image.file(
          io.File(path),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      } else {
        String fullQualityUrl = url;
        if (!url.contains('?')) {
          fullQualityUrl = '$url?size=original&quality=high&format=original';
        } else {
          fullQualityUrl = '$url&size=original&quality=high&format=original';
        }
        imageChild = Image.network(fullQualityUrl, fit: BoxFit.contain);
      }
    } else if (preview is String && preview.startsWith('data:')) {
      final idx = preview.indexOf('base64,');
      if (idx != -1) {
        final b64 = preview.substring(idx + 7);
        try {
          final bytes = base64Decode(b64);
          imageChild = Image.memory(bytes, fit: BoxFit.contain);
        } catch (_) {
          imageChild = null;
        }
      }
    }

    if (imageChild != null) {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (BuildContext context, _, __) {
            return _FullScreenPhotoViewer(
              imageChild: imageChild!,
              attach: attach,
            );
          },
          transitionsBuilder: (_, animation, __, page) {
            return FadeTransition(opacity: animation, child: page);
          },
        ),
      );
    } else {
      _goToMessage(message.id);
    }
  }

  void _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть ссылку: $url')),
        );
      }
    }
  }

  String _extractLinkFromMessage(Message message) {
    for (final element in message.elements) {
      if (element['type'] == 'LINK') {
        return element['attributes']?['url'] as String? ?? '';
      }
    }

    final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final match = urlPattern.firstMatch(message.text);
    return match?.group(0) ?? '';
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  Widget _buildMediaPreview(Map<String, dynamic> attach) {
    final previewData = attach['previewData'] as String?;
    final url = attach['url'] ?? attach['baseUrl'] as String?;
    final type = attach['_type'] as String?;

    Uint8List? previewBytes;
    if (previewData != null && previewData.startsWith('data:')) {
      final idx = previewData.indexOf('base64,');
      if (idx != -1) {
        final b64 = previewData.substring(idx + 7);
        try {
          previewBytes = base64Decode(b64);
        } catch (_) {}
      }
    }

    String? previewUrl;
    if (url != null && url.isNotEmpty) {
      if (!url.contains('?')) {
        previewUrl = '$url?size=medium&quality=high&format=jpeg';
      } else {
        previewUrl = '$url&size=medium&quality=high&format=jpeg';
      }
    }

    Widget imageWidget;
    if (previewBytes != null) {
      imageWidget = Image.memory(
        previewBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          type == 'VIDEO' ? Icons.videocam : Icons.image,
          color: Colors.grey[600],
        ),
      );
    } else if (previewUrl != null) {
      imageWidget = Image.network(
        previewUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (_, __, ___) => Icon(
          type == 'VIDEO' ? Icons.videocam : Icons.image,
          color: Colors.grey[600],
        ),
      );
    } else {
      imageWidget = Icon(
        type == 'VIDEO' ? Icons.videocam : Icons.image,
        color: Colors.grey[600],
      );
    }

    if (type == 'VIDEO') {
      return Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      );
    }

    return imageWidget;
  }

  Widget _buildMediaGrid(List<Message> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет медиафайлов',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final mediaAttach = message.attaches.firstWhere(
          (attach) => attach['_type'] == 'PHOTO' || attach['_type'] == 'VIDEO',
        );

        return GestureDetector(
          onTap: () => _viewMedia(message, mediaAttach),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildMediaPreview(mediaAttach),
              ),

              Positioned(
                bottom: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      _showMediaActions(context, message, mediaAttach),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(24, 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileList(List<Message> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет файлов',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final fileAttach = message.attaches.firstWhere(
          (attach) => attach['_type'] == 'FILE',
        );

        final fileName = fileAttach['name'] as String? ?? 'Файл';
        final fileSize = fileAttach['size'] as int?;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(fileName),
            subtitle: Text(
              fileSize != null
                  ? '${(fileSize / 1024 / 1024).toStringAsFixed(2)} МБ • ${_formatTime(message.time)}'
                  : _formatTime(message.time),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _downloadFile(message, fileAttach),
                  tooltip: 'Скачать',
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _goToMessage(message.id),
                  tooltip: 'Перейти к сообщению',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioList(List<Message> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.audiotrack, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет голосовых сообщений',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final audioAttach = message.attaches.firstWhere(
          (attach) => attach['_type'] == 'AUDIO' || attach['_type'] == 'VOICE',
        );

        final duration = audioAttach['duration'] as int? ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.audiotrack, size: 32),
            title: Text('Голосовое сообщение'),
            subtitle: Text(
              '${Duration(seconds: duration).inMinutes}:${(Duration(seconds: duration).inSeconds % 60).toString().padLeft(2, '0')} • ${_formatTime(message.time)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _playAudio(message, audioAttach),
                  tooltip: 'Прослушать',
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _goToMessage(message.id),
                  tooltip: 'Перейти к сообщению',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinkList(List<Message> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет ссылок',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final link = _extractLinkFromMessage(message);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.link),
            title: Text(
              link.length > 50 ? '${link.substring(0, 50)}...' : link,
            ),
            subtitle: Text(_formatTime(message.time)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _openLink(link),
                  tooltip: 'Открыть ссылку',
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _goToMessage(message.id),
                  tooltip: 'Перейти к сообщению',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMediaActions(
    BuildContext context,
    Message message,
    Map<String, dynamic> attach,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Просмотреть'),
              onTap: () {
                Navigator.pop(context);
                _viewMedia(message, attach);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward),
              title: const Text('Перейти к сообщению'),
              onTap: () {
                Navigator.pop(context);
                _goToMessage(message.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.photo_library), text: 'Медиа'),
            Tab(icon: Icon(Icons.insert_drive_file), text: 'Файлы'),
            Tab(icon: Icon(Icons.audiotrack), text: 'Голосовые'),
            Tab(icon: Icon(Icons.link), text: 'Ссылки'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (!mounted) return;
                      setState(() {
                        _isLoading = true;
                        _error = '';
                      });
                      _processMessages();
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMediaGrid(_mediaMessages),
                _buildFileList(_fileMessages),
                _buildAudioList(_audioMessages),
                _buildLinkList(_linkMessages),
              ],
            ),
    );
  }
}

class _FullScreenPhotoViewer extends StatelessWidget {
  final Widget imageChild;
  final Map<String, dynamic> attach;

  const _FullScreenPhotoViewer({
    required this.imageChild,
    required this.attach,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: imageChild,
        ),
      ),
    );
  }
}
