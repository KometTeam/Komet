import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<io.FileSystemEntity> _files = [];
  bool _isLoading = true;
  String? _downloadsPath;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() {
      _isLoading = true;
    });

    try {
      io.Directory? downloadDir;

      if (io.Platform.isAndroid) {
        downloadDir = await getExternalStorageDirectory();
      } else if (io.Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        downloadDir = directory;
      } else if (io.Platform.isWindows || io.Platform.isLinux) {
        final homeDir =
            io.Platform.environment['HOME'] ??
            io.Platform.environment['USERPROFILE'] ??
            '';
        downloadDir = io.Directory('$homeDir/Downloads');
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      if (downloadDir != null && await downloadDir.exists()) {
        _downloadsPath = downloadDir.path;

        final prefs = await SharedPreferences.getInstance();
        final List<String> downloadedFilePaths =
            prefs.getStringList('downloaded_files') ?? [];

        final files =
            downloadedFilePaths
                .map((path) => io.File(path))
                .where((file) => file.existsSync())
                .toList()
              ..sort((a, b) {
                final aStat = a.statSync();
                final bStat = b.statSync();
                return bStat.modified.compareTo(aStat.modified);
              });

        final existingPaths = files.map((f) => f.path).toSet();
        final cleanPaths = downloadedFilePaths
            .where((path) => existingPaths.contains(path))
            .toList();
        await prefs.setStringList('downloaded_files', cleanPaths);

        setState(() {
          _files = files;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _deleteFile(io.File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text(
          'Вы уверены, что хотите удалить ${file.path.split('/').last}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final List<String> downloadedFilePaths =
            prefs.getStringList('downloaded_files') ?? [];
        downloadedFilePaths.remove(file.path);
        await prefs.setStringList('downloaded_files', downloadedFilePaths);

        await file.delete();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Файл удален')));
        _loadDownloads();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении файла: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloads,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет скачанных файлов',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  if (_downloadsPath != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Файлы сохраняются в:\n$_downloadsPath',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            )
          : Column(
              children: [
                if (_downloadsPath != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                    child: Row(
                      children: [
                        const Icon(Icons.folder, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _downloadsPath!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      if (file is! io.File) return const SizedBox.shrink();

                      final fileName = file.path
                          .split(io.Platform.pathSeparator)
                          .last;
                      final fileStat = file.statSync();
                      final fileSize = fileStat.size;
                      final modifiedDate = fileStat.modified;

                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getFileIcon(fileName),
                            color: theme.primaryColor,
                          ),
                        ),
                        title: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatFileSize(fileSize)),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'dd.MM.yyyy HH:mm',
                              ).format(modifiedDate),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.open_in_new),
                                      title: const Text('Открыть'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await OpenFile.open(file.path);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      title: const Text(
                                        'Удалить',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _deleteFile(file);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        onTap: () async {
                          await OpenFile.open(file.path);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
