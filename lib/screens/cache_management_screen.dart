import 'package:flutter/material.dart';
import 'package:gwid/services/cache_service.dart';
import 'package:gwid/services/avatar_cache_service.dart';
import 'package:gwid/services/chat_cache_service.dart';

class CacheManagementScreen extends StatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends State<CacheManagementScreen> {
  Map<String, dynamic> _cacheStats = {};
  Map<String, dynamic> _avatarCacheStats = {};
  Map<String, dynamic> _chatCacheStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final cacheService = CacheService();
      final avatarService = AvatarCacheService();
      final chatService = ChatCacheService();

      await cacheService.initialize();
      await chatService.initialize();
      await avatarService.initialize();

      final cacheStats = await cacheService.getCacheStats();
      final avatarStats = await avatarService.getAvatarCacheStats();
      final chatStats = await chatService.getChatCacheStats();

      if (!mounted) return;

      setState(() {
        _cacheStats = cacheStats;
        _avatarCacheStats = avatarStats;
        _chatCacheStats = chatStats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки статистики кэша: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить весь кэш?'),
        content: const Text(
          'Это действие удалит все кэшированные данные, включая чаты, сообщения и аватарки. '
          'Приложение будет работать медленнее до повторной загрузки данных.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final cacheService = CacheService();
        final avatarService = AvatarCacheService();
        final chatService = ChatCacheService();

        await cacheService.initialize();
        await chatService.initialize();
        await avatarService.initialize();

        await cacheService.clear();

        await Future.delayed(const Duration(milliseconds: 100));
        await avatarService.clearAvatarCache();
        await Future.delayed(const Duration(milliseconds: 100));
        await chatService.clearAllChatCache();

        await _loadCacheStats();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Весь кэш очищен'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка очистки кэша: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAvatarCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить кэш аватарок?'),
        content: const Text(
          'Это действие удалит все кэшированные аватарки. '
          'Они будут загружены заново при следующем просмотре.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final avatarService = AvatarCacheService();

        await avatarService.initialize();
        await avatarService.clearAvatarCache();

        await Future.delayed(const Duration(milliseconds: 50));
        await _loadCacheStats();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Кэш аватарок очищен'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка очистки кэша аватарок: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheSection(String title, Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...data.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Управление кэшем"),
        actions: [
          IconButton(
            onPressed: _loadCacheStats,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  "Общая статистика",
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildStatCard(
                      "Чаты в кэше",
                      _chatCacheStats['cachedChats']?.toString() ?? "0",
                      Icons.chat,
                      colors.primary,
                    ),
                    _buildStatCard(
                      "Контакты в кэше",
                      _chatCacheStats['cachedContacts']?.toString() ?? "0",
                      Icons.contacts,
                      colors.secondary,
                    ),
                    _buildStatCard(
                      "Аватарки в памяти",
                      _avatarCacheStats['memoryImages']?.toString() ?? "0",
                      Icons.person,
                      colors.tertiary,
                    ),
                    _buildStatCard(
                      "Размер кэша",
                      "${_avatarCacheStats['diskSizeMB'] ?? "0"} МБ",
                      Icons.storage,
                      colors.error,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  "Детальная статистика",
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),

                _buildCacheSection("Кэш чатов", _chatCacheStats['cacheStats']),
                const SizedBox(height: 12),
                _buildCacheSection("Кэш аватарок", _avatarCacheStats),
                const SizedBox(height: 12),
                _buildCacheSection("Общий кэш", _cacheStats),
                const SizedBox(height: 12),
                _buildCacheSection("Кэш в памяти", {
                  'Записей в памяти': _cacheStats['memoryEntries'] ?? 0,
                  'Максимум записей': _cacheStats['maxMemorySize'] ?? 0,
                }),

                const SizedBox(height: 32),

                Text(
                  "Управление кэшем",
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete_sweep),
                        title: const Text("Очистить кэш аватарок"),
                        subtitle: const Text(
                          "Удалить все кэшированные аватарки",
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _clearAvatarCache,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever,
                          color: colors.error,
                        ),
                        title: Text(
                          "Очистить весь кэш",
                          style: TextStyle(color: colors.error),
                        ),
                        subtitle: const Text("Удалить все кэшированные данные"),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: colors.error,
                        ),
                        onTap: _clearAllCache,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: colors.primary),
                            const SizedBox(width: 8),
                            Text(
                              "О кэшировании",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Кэширование ускоряет работу приложения, сохраняя часто используемые данные локально. "
                          "Все файлы сжимаются с помощью LZ4 для экономии места. "
                          "Чаты кэшируются на 1 час, контакты на 6 часов, сообщения на 2 часа, аватарки на 7 дней.",
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Очистка кэша может замедлить работу приложения до повторной загрузки данных.",
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.compress,
                                color: colors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Сжатие LZ4 включено - экономия места до 70%",
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
}
