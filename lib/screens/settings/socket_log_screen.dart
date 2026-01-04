import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gwid/api/api_service.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

enum LogType { send, receive, status, pingpong }

enum ViewMode { all, split, sendOnly, receiveOnly }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final int id;
  final LogType type;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.id,
    required this.type,
  });
}

class LogStatistics {
  int totalSent = 0;
  int totalReceived = 0;
  int totalStatus = 0;
  int totalPingPong = 0;
  int totalErrors = 0;

  void update(List<LogEntry> entries) {
    totalSent = entries.where((e) => e.type == LogType.send).length;
    totalReceived = entries.where((e) => e.type == LogType.receive).length;
    totalStatus = entries.where((e) => e.type == LogType.status).length;
    totalPingPong = entries.where((e) => e.type == LogType.pingpong).length;
    totalErrors = entries.where((e) => e.message.contains('❌')).length;
  }

  int get total => totalSent + totalReceived + totalStatus + totalPingPong;
}

class SocketLogScreen extends StatefulWidget {
  const SocketLogScreen({super.key});

  @override
  State<SocketLogScreen> createState() => _SocketLogScreenState();
}

class _SocketLogScreenState extends State<SocketLogScreen>
    with SingleTickerProviderStateMixin {
  final List<LogEntry> _allLogEntries = [];
  List<LogEntry> _filteredLogEntries = [];
  StreamSubscription? _logSubscription;
  final ScrollController _scrollController = ScrollController();
  int _logIdCounter = 0;
  bool _isAutoScrollEnabled = true;
  bool _isPaused = false;

  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<LogType> _activeFilters = {
    LogType.send,
    LogType.receive,
    LogType.status,
    LogType.pingpong,
  };

  final LogStatistics _statistics = LogStatistics();
  bool _showStatistics = false;
  late AnimationController _animationController;

  // Режимы отображения
  ViewMode _viewMode = ViewMode.all;
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Слушатель для отслеживания скролла пользователя
    _scrollController.addListener(_onScroll);

    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
          _applyFiltersAndSearch();
        });
      }
    });
    _loadInitialLogs();
    _subscribeToNewLogs();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Проверяем, прокрутил ли пользователь вверх
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isAtBottom = currentScroll >= maxScroll - 50; // 50px допуск

    if (!isAtBottom && _isAutoScrollEnabled) {
      // Пользователь прокрутил вверх - отключаем автопрокрутку
      setState(() {
        _isAutoScrollEnabled = false;
        _userScrolledUp = true;
      });
    } else if (isAtBottom && !_isAutoScrollEnabled && _userScrolledUp) {
      // Пользователь вернулся вниз - можно предложить включить автопрокрутку
      setState(() {
        _userScrolledUp = false;
      });
    }
  }

  LogType _getLogType(String message) {
    if (message.contains('(ping)') || message.contains('(pong)')) {
      return LogType.pingpong;
    }
    if (message.startsWith('➡️ SEND')) return LogType.send;
    if (message.startsWith('⬅️ RECV')) return LogType.receive;
    return LogType.status;
  }

  void _addLogEntry(String logMessage, {bool isInitial = false}) {
    if (_isPaused && !isInitial) return;

    final newEntry = LogEntry(
      id: _logIdCounter++,
      timestamp: DateTime.now(),
      message: logMessage,
      type: _getLogType(logMessage),
    );
    _allLogEntries.add(newEntry);

    if (!isInitial) {
      _statistics.update(_allLogEntries);
      _applyFiltersAndSearch();
      if (_isAutoScrollEnabled) _scrollToBottom();
    }
  }

  void _loadInitialLogs() {
    final cachedLogs = ApiService.instance.connectionLogCache;
    print('Загрузка ${cachedLogs.length} логов из кэша');
    for (var log in cachedLogs) {
      _addLogEntry(log, isInitial: true);
    }
    _statistics.update(_allLogEntries);
    _applyFiltersAndSearch();
    setState(() {});
  }

  void _subscribeToNewLogs() {
    _logSubscription = ApiService.instance.connectionLog.listen((logMessage) {
      print('Получен новый лог: $logMessage');
      if (mounted) {
        if (_allLogEntries.isNotEmpty &&
            _allLogEntries.last.message == logMessage) {
          return;
        }
        setState(() => _addLogEntry(logMessage));
      }
    });
  }

  void _scrollToBottom() {
    if (!_isAutoScrollEnabled) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrollEnabled = !_isAutoScrollEnabled;
      _userScrolledUp = false;
      if (_isAutoScrollEnabled) {
        _scrollToBottom();
      }
    });
  }

  void _showViewModeDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Режим отображения',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.view_list),
              title: const Text('Все сообщения'),
              trailing: _viewMode == ViewMode.all
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() => _viewMode = ViewMode.all);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_split),
              title: const Text('Разделить отправленные/полученные'),
              subtitle: const Text('Два столбца'),
              trailing: _viewMode == ViewMode.split
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() => _viewMode = ViewMode.split);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Только отправленные'),
              trailing: _viewMode == ViewMode.sendOnly
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() => _viewMode = ViewMode.sendOnly);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Только полученные'),
              trailing: _viewMode == ViewMode.receiveOnly
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() => _viewMode = ViewMode.receiveOnly);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _applyFiltersAndSearch() {
    List<LogEntry> tempFiltered = _allLogEntries.where((entry) {
      return _activeFilters.contains(entry.type);
    }).toList();

    // Применяем фильтр по режиму просмотра
    if (_viewMode == ViewMode.sendOnly) {
      tempFiltered = tempFiltered.where((e) => e.type == LogType.send).toList();
    } else if (_viewMode == ViewMode.receiveOnly) {
      tempFiltered = tempFiltered
          .where((e) => e.type == LogType.receive)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      tempFiltered = tempFiltered.where((entry) {
        return entry.message.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredLogEntries = tempFiltered;
    });
  }

  Widget _buildLogsList() {
    if (_filteredLogEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _allLogEntries.isEmpty
                  ? Icons.inbox_outlined
                  : Icons.filter_alt_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _allLogEntries.isEmpty ? "Журнал пуст" : "Записей не найдено",
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_allLogEntries.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                "Логи будут появляться здесь",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
      itemCount: _filteredLogEntries.length,
      itemBuilder: (context, index) {
        return AnimatedLogEntryCard(
          key: ValueKey(_filteredLogEntries[index].id),
          entry: _filteredLogEntries[index],
          index: index,
        );
      },
    );
  }

  Widget _buildSplitView() {
    final sentLogs = _allLogEntries
        .where((e) => e.type == LogType.send)
        .toList();
    final receivedLogs = _allLogEntries
        .where((e) => e.type == LogType.receive)
        .toList();

    // Применяем поиск
    final filteredSent = _searchQuery.isEmpty
        ? sentLogs
        : sentLogs
              .where(
                (e) => e.message.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

    final filteredReceived = _searchQuery.isEmpty
        ? receivedLogs
        : receivedLogs
              .where(
                (e) => e.message.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

    return Row(
      children: [
        // Отправленные
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  border: Border(
                    bottom: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_upward, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Отправлено (${filteredSent.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredSent.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет отправленных',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filteredSent.length,
                        itemBuilder: (context, index) {
                          return AnimatedLogEntryCard(
                            key: ValueKey(filteredSent[index].id),
                            entry: filteredSent[index],
                            index: index,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: Colors.grey.shade700),
        // Полученные
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  border: Border(
                    bottom: BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_downward, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Получено (${filteredReceived.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredReceived.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет полученных',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filteredReceived.length,
                        itemBuilder: (context, index) {
                          return AnimatedLogEntryCard(
                            key: ValueKey(filteredReceived[index].id),
                            entry: filteredReceived[index],
                            index: index,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyLogsToClipboard() {
    final logText = _filteredLogEntries
        .map(
          (entry) =>
              "[${DateFormat('HH:mm:ss.SSS').format(entry.timestamp)}] ${entry.message}",
        )
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: logText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Отфильтрованный журнал скопирован')),
    );
  }

  void _shareLogs() async {
    final logText = _filteredLogEntries
        .map(
          (entry) =>
              "[${DateFormat('HH:mm:ss.SSS').format(entry.timestamp)}] ${entry.message}",
        )
        .join('\n\n');
    await Share.share(logText, subject: 'Gwid Connection Log');
  }

  Future<void> _exportLogsToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final file = File('${directory.path}/socket_logs_$timestamp.txt');

      final logText = _filteredLogEntries
          .map(
            (entry) =>
                "[${DateFormat('HH:mm:ss.SSS').format(entry.timestamp)}] ${entry.message}",
          )
          .join('\n\n');

      await file.writeAsString(logText);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Логи сохранены: ${file.path}'),
            action: SnackBarAction(
              label: 'Открыть',
              onPressed: () => Share.shareXFiles([XFile(file.path)]),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    }
  }

  void _clearLogs() {
    setState(() {
      _allLogEntries.clear();
      _filteredLogEntries.clear();
      _statistics.update(_allLogEntries);
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildStatisticsPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showStatistics ? null : 0,
      child: _showStatistics
          ? Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Статистика',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Всего: ${_statistics.total}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Icons.arrow_upward,
                          'Отправлено',
                          _statistics.totalSent,
                          Colors.blue,
                        ),
                        _buildStatItem(
                          Icons.arrow_downward,
                          'Получено',
                          _statistics.totalReceived,
                          Colors.green,
                        ),
                        _buildStatItem(
                          Icons.sync_alt,
                          'Ping/Pong',
                          _statistics.totalPingPong,
                          Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Icons.info,
                          'Статус',
                          _statistics.totalStatus,
                          Colors.orange,
                        ),
                        _buildStatItem(
                          Icons.error,
                          'Ошибки',
                          _statistics.totalErrors,
                          Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              avatar: const Icon(Icons.arrow_upward, size: 16),
              label: const Text('Отправлено'),
              selected: _activeFilters.contains(LogType.send),
              onSelected: (val) {
                setState(() {
                  val
                      ? _activeFilters.add(LogType.send)
                      : _activeFilters.remove(LogType.send);
                  _applyFiltersAndSearch();
                });
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: const Icon(Icons.arrow_downward, size: 16),
              label: const Text('Получено'),
              selected: _activeFilters.contains(LogType.receive),
              onSelected: (val) {
                setState(() {
                  val
                      ? _activeFilters.add(LogType.receive)
                      : _activeFilters.remove(LogType.receive);
                  _applyFiltersAndSearch();
                });
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: const Icon(Icons.info, size: 16),
              label: const Text('Статус'),
              selected: _activeFilters.contains(LogType.status),
              onSelected: (val) {
                setState(() {
                  val
                      ? _activeFilters.add(LogType.status)
                      : _activeFilters.remove(LogType.status);
                  _applyFiltersAndSearch();
                });
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: const Icon(Icons.sync_alt, size: 16),
              label: const Text('Ping/Pong'),
              selected: _activeFilters.contains(LogType.pingpong),
              onSelected: (val) {
                setState(() {
                  val
                      ? _activeFilters.add(LogType.pingpong)
                      : _activeFilters.remove(LogType.pingpong);
                  _applyFiltersAndSearch();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildDefaultAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Журнал Socket"),
          if (_filteredLogEntries.length != _allLogEntries.length)
            Text(
              '${_filteredLogEntries.length} из ${_allLogEntries.length}',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
          tooltip: _isPaused ? "Возобновить" : "Пауза",
          onPressed: () => setState(() => _isPaused = !_isPaused),
        ),
        IconButton(
          icon: Icon(
            _viewMode == ViewMode.split
                ? Icons.call_split
                : _viewMode == ViewMode.sendOnly
                ? Icons.arrow_upward
                : _viewMode == ViewMode.receiveOnly
                ? Icons.arrow_downward
                : Icons.view_list,
          ),
          tooltip: "Режим отображения",
          onPressed: _showViewModeDialog,
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: "Поиск",
          onPressed: () => setState(() => _isSearchActive = true),
        ),
        IconButton(
          icon: Icon(
            _showStatistics ? Icons.query_stats : Icons.query_stats_outlined,
          ),
          tooltip: "Статистика",
          onPressed: () => setState(() => _showStatistics = !_showStatistics),
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.save_alt),
                  SizedBox(width: 8),
                  Text('Экспорт в файл'),
                ],
              ),
              onTap: () => Future.delayed(
                const Duration(milliseconds: 100),
                _exportLogsToFile,
              ),
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.copy),
                  SizedBox(width: 8),
                  Text('Копировать'),
                ],
              ),
              onTap: () => Future.delayed(
                const Duration(milliseconds: 100),
                _copyLogsToClipboard,
              ),
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.delete_sweep),
                  SizedBox(width: 8),
                  Text('Очистить'),
                ],
              ),
              onTap: () =>
                  Future.delayed(const Duration(milliseconds: 100), _clearLogs),
            ),
          ],
        ),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          setState(() {
            _isSearchActive = false;
            _searchController.clear();
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Поиск по логам...',
          border: InputBorder.none,
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearchActive ? _buildSearchAppBar() : _buildDefaultAppBar(),
      body: Column(
        children: [
          if (!_isSearchActive && _viewMode != ViewMode.split)
            _buildFilterChips(),
          _buildStatisticsPanel(),
          if (_isPaused)
            Container(
              width: double.infinity,
              color: Colors.orange.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pause_circle, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Обновление логов приостановлено',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (!_isAutoScrollEnabled &&
              _userScrolledUp &&
              _viewMode != ViewMode.split)
            Material(
              color: Colors.blue.withValues(alpha: 0.2),
              child: InkWell(
                onTap: _toggleAutoScroll,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Автопрокрутка отключена. Нажмите для включения',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _viewMode == ViewMode.split
                ? _buildSplitView()
                : _buildLogsList(),
          ),
        ],
      ),
      floatingActionButton: _viewMode != ViewMode.split
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_filteredLogEntries.isNotEmpty)
                  FloatingActionButton(
                    onPressed: _toggleAutoScroll,
                    mini: true,
                    heroTag: 'scroll',
                    backgroundColor: _isAutoScrollEnabled
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    tooltip: _isAutoScrollEnabled
                        ? 'Автопрокрутка ВКЛ (нажмите чтобы отключить)'
                        : 'Автопрокрутка ВЫКЛ (нажмите чтобы включить)',
                    child: Icon(
                      _isAutoScrollEnabled
                          ? Icons.arrow_downward
                          : Icons.arrow_downward_outlined,
                      color: _isAutoScrollEnabled
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (_filteredLogEntries.isNotEmpty) const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'share',
                  onPressed: _filteredLogEntries.isNotEmpty ? _shareLogs : null,
                  icon: const Icon(Icons.share),
                  label: const Text("Поделиться"),
                  tooltip: "Поделиться отфильтрованными логами",
                ),
              ],
            )
          : null,
    );
  }
}

class AnimatedLogEntryCard extends StatefulWidget {
  final LogEntry entry;
  final int index;

  const AnimatedLogEntryCard({
    super.key,
    required this.entry,
    required this.index,
  });

  @override
  State<AnimatedLogEntryCard> createState() => _AnimatedLogEntryCardState();
}

class _AnimatedLogEntryCardState extends State<AnimatedLogEntryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    Future.delayed(Duration(milliseconds: widget.index * 20), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (IconData, Color, Color) _getVisuals(
    LogType type,
    String message,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    switch (type) {
      case LogType.send:
        return (
          Icons.arrow_upward_rounded,
          theme.colorScheme.primary,
          theme.colorScheme.primary.withValues(alpha: 0.1),
        );
      case LogType.receive:
        return (
          Icons.arrow_downward_rounded,
          Colors.green,
          Colors.green.withValues(alpha: 0.1),
        );
      case LogType.pingpong:
        return (
          Icons.sync_alt_rounded,
          Colors.grey,
          Colors.grey.withValues(alpha: 0.1),
        );
      case LogType.status:
        if (message.startsWith('✅')) {
          return (
            Icons.check_circle_rounded,
            Colors.green,
            Colors.green.withValues(alpha: 0.1),
          );
        }
        if (message.startsWith('❌')) {
          return (
            Icons.error_rounded,
            theme.colorScheme.error,
            theme.colorScheme.error.withValues(alpha: 0.1),
          );
        }
        return (
          Icons.info_rounded,
          Colors.orange.shade600,
          Colors.orange.withValues(alpha: 0.1),
        );
    }
  }

  void _showJsonViewer(BuildContext context, String message) {
    final jsonRegex = RegExp(r'(\{.*\})');
    final match = jsonRegex.firstMatch(message);
    if (match == null) return;

    try {
      final jsonPart = match.group(0)!;
      final decoded = jsonDecode(jsonPart);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.code, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text("Содержимое пакета"),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  prettyJson,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.greenAccent,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prettyJson));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSON скопирован')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text("Копировать"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Закрыть"),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  (String?, String?) _extractInfo(String message) {
    try {
      final jsonRegex = RegExp(r'(\{.*\})');
      final match = jsonRegex.firstMatch(message);
      if (match == null) return (null, null);
      final jsonPart = match.group(0)!;
      final decoded = jsonDecode(jsonPart) as Map<String, dynamic>;
      final opcode = decoded['opcode']?.toString();
      final seq = decoded['seq']?.toString();
      return (opcode, seq);
    } catch (e) {
      return (null, null);
    }
  }

  String _truncateMessage(String message, int maxLength) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, bgColor) = _getVisuals(
      widget.entry.type,
      widget.entry.message,
      context,
    );
    final (opcode, seq) = _extractInfo(widget.entry.message);
    final formattedTime = DateFormat(
      'HH:mm:ss.SSS',
    ).format(widget.entry.timestamp);
    final theme = Theme.of(context);

    final displayMessage = _isExpanded
        ? widget.entry.message
        : _truncateMessage(widget.entry.message, 200);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          elevation: 2,
          child: InkWell(
            onTap: () {
              if (widget.entry.message.length > 200) {
                setState(() => _isExpanded = !_isExpanded);
              } else {
                _showJsonViewer(context, widget.entry.message);
              }
            },
            onLongPress: () => _showJsonViewer(context, widget.entry.message),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: color, width: 4)),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [bgColor, Colors.transparent],
                  stops: const [0.0, 0.3],
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedTime,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (opcode != null || seq != null)
                              const SizedBox(height: 4),
                            if (opcode != null || seq != null)
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (opcode != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'OP: $opcode',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  if (seq != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'SEQ: $seq',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (widget.entry.message.length > 200)
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    displayMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
