import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:gwid/api/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gwid/utils/download_path_helper.dart';
import 'package:gwid/app_sizes.dart';

class StorageScreen extends StatefulWidget {
  final bool isModal;

  const StorageScreen({super.key, this.isModal = false});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  StorageInfo? _storageInfo;
  bool _isLoading = true;

  Widget buildModalContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                _buildStorageChart(colors),
                const SizedBox(height: AppSpacing.xxxl),

                _buildStorageDetails(colors),
                const SizedBox(height: AppSpacing.xxxl),

                _buildDownloadFolderSetting(colors),
                const SizedBox(height: AppSpacing.xxxl),

                _buildActionButtons(colors),
              ],
            ),
          );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadStorageInfo();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStorageInfo() async {
    try {
      final info = await _getStorageInfo();
      setState(() {
        _storageInfo = info;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<StorageInfo> _getStorageInfo() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = await getTemporaryDirectory();

    final appSize = await _getDirectorySize(appDir);
    final cacheSize = await _getDirectorySize(cacheDir);
    final totalSize = appSize + cacheSize;

    final messagesSize = totalSize > 0 ? (totalSize * 0.3).round() : 0;
    final mediaSize = totalSize > 0 ? (totalSize * 0.25).round() : 0;
    final cacheSizeAdjusted = totalSize > 0 ? (totalSize * 0.2).round() : 0;
    final otherSize = totalSize - messagesSize - mediaSize - cacheSizeAdjusted;

    return StorageInfo(
      totalSize: totalSize,
      messagesSize: messagesSize,
      mediaSize: mediaSize,
      cacheSize: cacheSizeAdjusted,
      otherSize: otherSize,
    );
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int totalSize = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      print('Ошибка при подсчете размера директории ${dir.path}: $e');
      totalSize = 0;
    }
    return totalSize;
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить кэш'),
        content: const Text(
          'Это действие очистит весь кэш приложения, включая кэш сообщений, медиафайлов и аватаров. '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      ApiService.instance.clearAllCaches();

      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }

      await _loadStorageInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Кэш успешно очищен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при очистке кэша: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить все данные'),
        content: const Text(
          'Это действие удалит все сообщения, медиафайлы и другие данные приложения. '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final cacheDir = await getTemporaryDirectory();

        if (await appDir.exists()) {
          await appDir.delete(recursive: true);
          await appDir.create();
        }
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          await cacheDir.create();
        }

        await _loadStorageInfo();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Все данные успешно удалены'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при удалении данных: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (widget.isModal) {
      return buildModalContent(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Хранилище'),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _storageInfo == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storage_outlined,
                    size: 64,
                    color: colors.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Не удалось загрузить информацию о хранилище',
                    style: TextStyle(
                      color: colors.onSurface.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadStorageInfo,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStorageChart(colors),

                  const SizedBox(height: 32),

                  _buildStorageDetails(colors),

                  const SizedBox(height: 32),

                  _buildDownloadFolderSetting(colors),

                  const SizedBox(height: 32),

                  _buildActionButtons(colors),
                ],
              ),
            ),
    );
  }

  Widget _buildModalSettings(BuildContext context, ColorScheme colors) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.3),
            ),
          ),

          Center(
            child: Container(
              width: 400,
              height: 600,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Назад',
                        ),
                        const Expanded(
                          child: Text(
                            "Хранилище",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Закрыть',
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildStorageChart(colors),
                                const SizedBox(height: 20),

                                _buildStorageDetails(colors),
                                const SizedBox(height: 20),

                                _buildDownloadFolderSetting(colors),
                                const SizedBox(height: 20),

                                _buildActionButtons(colors),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageChart(ColorScheme colors) {
    final totalSize = _storageInfo!.totalSize;
    final usedSize =
        _storageInfo!.messagesSize +
        _storageInfo!.mediaSize +
        _storageInfo!.otherSize;
    final usagePercentage = totalSize > 0 ? usedSize / totalSize : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Использование хранилища',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surfaceContainerHighest,
                      ),
                    ),

                    CustomPaint(
                      size: const Size(200, 200),
                      painter: StorageChartPainter(
                        progress: usagePercentage * _animation.value,
                        colors: colors,
                        storageInfo: _storageInfo!,
                        animationValue: _animation.value,
                      ),
                    ),

                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatBytes(usedSize),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                          Text(
                            'из ${_formatBytes(totalSize)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                'Сообщения',
                _formatBytes(_storageInfo!.messagesSize),
                Colors.blue,
              ),
              _buildLegendItem(
                'Медиафайлы',
                _formatBytes(_storageInfo!.mediaSize),
                Colors.green,
              ),
              _buildLegendItem(
                'Кэш',
                _formatBytes(_storageInfo!.cacheSize),
                Colors.orange,
              ),
              _buildLegendItem(
                'Другие',
                _formatBytes(_storageInfo!.otherSize),
                Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStorageDetails(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Детали использования',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          _buildStorageItem(
            'Сообщения',
            _formatBytes(_storageInfo!.messagesSize),
            Icons.message_outlined,
            colors.primary,
            (_storageInfo!.messagesSize / _storageInfo!.totalSize),
          ),

          _buildStorageItem(
            'Медиафайлы',
            _formatBytes(_storageInfo!.mediaSize),
            Icons.photo_library_outlined,
            colors.secondary,
            (_storageInfo!.mediaSize / _storageInfo!.totalSize),
          ),

          _buildStorageItem(
            'Кэш',
            _formatBytes(_storageInfo!.cacheSize),
            Icons.cached,
            colors.tertiary,
            (_storageInfo!.cacheSize / _storageInfo!.totalSize),
          ),

          _buildStorageItem(
            'Другие данные',
            _formatBytes(_storageInfo!.otherSize),
            Icons.folder_outlined,
            colors.outline,
            (_storageInfo!.otherSize / _storageInfo!.totalSize),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageItem(
    String title,
    String size,
    IconData icon,
    Color color,
    double percentage,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  size,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.zero,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDownloadFolder() async {
    try {
      String? selectedDirectory;

      selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        await DownloadPathHelper.setDownloadDirectory(selectedDirectory);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Папка загрузки установлена: $selectedDirectory'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при выборе папки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetDownloadFolder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить папку загрузки'),
        content: const Text('Вернуть папку загрузки к значению по умолчанию?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DownloadPathHelper.setDownloadDirectory(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Папка загрузки сброшена к значению по умолчанию'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    }
  }

  Widget _buildDownloadFolderSetting(ColorScheme colors) {
    return FutureBuilder<String>(
      future: DownloadPathHelper.getDisplayPath(),
      builder: (context, snapshot) {
        final currentPath = snapshot.data ?? 'Загрузка...';
        final isCustom =
            snapshot.hasData &&
            currentPath != 'Не указано' &&
            !currentPath.contains('Downloads') &&
            !currentPath.contains('Download');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Папка загрузки файлов',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Текущая папка:',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentPath,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isCustom)
                      Icon(Icons.check_circle, color: colors.primary, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDownloadFolder,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Выбрать папку'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (isCustom) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _resetDownloadFolder,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      child: const Icon(Icons.refresh),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Действия',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearCache,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Очистить кэш'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _clearAllData,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Очистить всё'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class StorageInfo {
  final int totalSize;
  final int messagesSize;
  final int mediaSize;
  final int cacheSize;
  final int otherSize;

  StorageInfo({
    required this.totalSize,
    required this.messagesSize,
    required this.mediaSize,
    required this.cacheSize,
    required this.otherSize,
  });
}

class StorageChartPainter extends CustomPainter {
  final double progress;
  final ColorScheme colors;
  final StorageInfo storageInfo;
  final double animationValue;

  StorageChartPainter({
    required this.progress,
    required this.colors,
    required this.storageInfo,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.butt;

    paint.color = colors.surfaceContainerHighest;
    canvas.drawCircle(center, radius, paint);

    final totalSize = storageInfo.totalSize;
    if (totalSize > 0) {
      final messagesRatio = storageInfo.messagesSize / totalSize;
      final mediaRatio = storageInfo.mediaSize / totalSize;
      final cacheRatio = storageInfo.cacheSize / totalSize;
      final otherRatio = storageInfo.otherSize / totalSize;

      double currentAngle = -pi / 2;

      if (messagesRatio > 0) {
        paint.color = Colors.blue;
        final sweepAngle = 2 * pi * messagesRatio * animationValue;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          currentAngle,
          sweepAngle,
          false,
          paint,
        );
        currentAngle += sweepAngle;
      }

      if (mediaRatio > 0) {
        paint.color = Colors.green;
        final sweepAngle = 2 * pi * mediaRatio * animationValue;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          currentAngle,
          sweepAngle,
          false,
          paint,
        );
        currentAngle += sweepAngle;
      }

      if (cacheRatio > 0) {
        paint.color = Colors.orange;
        final sweepAngle = 2 * pi * cacheRatio * animationValue;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          currentAngle,
          sweepAngle,
          false,
          paint,
        );
        currentAngle += sweepAngle;
      }

      if (otherRatio > 0) {
        paint.color = Colors.grey;
        final sweepAngle = 2 * pi * otherRatio * animationValue;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          currentAngle,
          sweepAngle,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is StorageChartPainter &&
        (oldDelegate.progress != progress ||
            oldDelegate.animationValue != animationValue);
  }
}
