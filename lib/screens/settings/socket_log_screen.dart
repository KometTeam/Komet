

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gwid/api/api_service.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';


enum LogType { send, receive, status, pingpong }


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

class SocketLogScreen extends StatefulWidget {
  const SocketLogScreen({super.key});

  @override
  State<SocketLogScreen> createState() => _SocketLogScreenState();
}

class _SocketLogScreenState extends State<SocketLogScreen> {
  final List<LogEntry> _allLogEntries = [];
  List<LogEntry> _filteredLogEntries = [];
  StreamSubscription? _logSubscription;
  final ScrollController _scrollController = ScrollController();
  int _logIdCounter = 0;
  bool _isAutoScrollEnabled = true;


  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';


  final Set<LogType> _activeFilters = {
    LogType.send,
    LogType.receive,
    LogType.status,
    LogType.pingpong,
  };

  @override
  void initState() {
    super.initState();

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

  LogType _getLogType(String message) {
    if (message.contains('(ping)') || message.contains('(pong)')) {
      return LogType.pingpong;
    }
    if (message.startsWith('➡️ SEND')) return LogType.send;
    if (message.startsWith('⬅️ RECV')) return LogType.receive;
    return LogType.status;
  }


  void _addLogEntry(String logMessage, {bool isInitial = false}) {
    final newEntry = LogEntry(
      id: _logIdCounter++,
      timestamp: DateTime.now(),
      message: logMessage,
      type: _getLogType(logMessage),
    );
    _allLogEntries.add(newEntry);


    if (!isInitial) {
      _applyFiltersAndSearch();
      if (_isAutoScrollEnabled) _scrollToBottom();
    }
  }

  void _loadInitialLogs() {
    final cachedLogs = ApiService.instance.connectionLogCache;
    for (var log in cachedLogs) {
      _addLogEntry(log, isInitial: true);
    }
    _applyFiltersAndSearch();
    setState(
      () {},
    ); 
  }

  void _subscribeToNewLogs() {
    _logSubscription = ApiService.instance.connectionLog.listen((logMessage) {
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


  void _applyFiltersAndSearch() {
    List<LogEntry> tempFiltered = _allLogEntries.where((entry) {
      return _activeFilters.contains(entry.type);
    }).toList();

    if (_searchQuery.isNotEmpty) {
      tempFiltered = tempFiltered.where((entry) {
        return entry.message.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredLogEntries = tempFiltered;
    });
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

  void _clearLogs() {
    setState(() {
      _allLogEntries.clear();
      _filteredLogEntries.clear();


    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Фильтры логов",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Исходящие (SEND)'),
                    value: _activeFilters.contains(LogType.send),
                    onChanged: (val) {
                      setSheetState(
                        () => val
                            ? _activeFilters.add(LogType.send)
                            : _activeFilters.remove(LogType.send),
                      );
                      _applyFiltersAndSearch();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Входящие (RECV)'),
                    value: _activeFilters.contains(LogType.receive),
                    onChanged: (val) {
                      setSheetState(
                        () => val
                            ? _activeFilters.add(LogType.receive)
                            : _activeFilters.remove(LogType.receive),
                      );
                      _applyFiltersAndSearch();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Статус подключения'),
                    value: _activeFilters.contains(LogType.status),
                    onChanged: (val) {
                      setSheetState(
                        () => val
                            ? _activeFilters.add(LogType.status)
                            : _activeFilters.remove(LogType.status),
                      );
                      _applyFiltersAndSearch();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Ping/Pong'),
                    value: _activeFilters.contains(LogType.pingpong),
                    onChanged: (val) {
                      setSheetState(
                        () => val
                            ? _activeFilters.add(LogType.pingpong)
                            : _activeFilters.remove(LogType.pingpong),
                      );
                      _applyFiltersAndSearch();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  AppBar _buildDefaultAppBar() {
    return AppBar(
      title: const Text("Журнал подключения"),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: "Поиск",
          onPressed: () => setState(() => _isSearchActive = true),
        ),
        IconButton(
          icon: Icon(
            _activeFilters.length == 4
                ? Icons.filter_list
                : Icons.filter_list_off,
          ),
          tooltip: "Фильтры",
          onPressed: _showFilterDialog,
        ),
        IconButton(
          icon: const Icon(Icons.delete_sweep),
          tooltip: "Очистить",
          onPressed: _allLogEntries.isNotEmpty ? _clearLogs : null,
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
      body: _filteredLogEntries.isEmpty
          ? Center(
              child: Text(
                _allLogEntries.isEmpty ? "Журнал пуст." : "Записей не найдено.",
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                8,
                8,
                8,
                80,
              ), 
              itemCount: _filteredLogEntries.length,
              itemBuilder: (context, index) {
                return LogEntryCard(
                  key: ValueKey(_filteredLogEntries[index].id),
                  entry: _filteredLogEntries[index],
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: () =>
                setState(() => _isAutoScrollEnabled = !_isAutoScrollEnabled),
            mini: true,
            tooltip: _isAutoScrollEnabled
                ? 'Остановить автопрокрутку'
                : 'Возобновить автопрокрутку',
            child: Icon(
              _isAutoScrollEnabled ? Icons.pause : Icons.arrow_downward,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            onPressed: _shareLogs,
            icon: const Icon(Icons.share),
            label: const Text("Поделиться"),
            tooltip: "Поделиться отфильтрованными логами",
          ),
        ],
      ),
    );
  }
}


class LogEntryCard extends StatelessWidget {
  final LogEntry entry;

  const LogEntryCard({super.key, required this.entry});

  (IconData, Color) _getVisuals(
    LogType type,
    String message,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    switch (type) {
      case LogType.send:
        return (Icons.arrow_upward, theme.colorScheme.primary);
      case LogType.receive:
        return (Icons.arrow_downward, Colors.green);
      case LogType.pingpong:
        return (Icons.sync_alt, Colors.grey);
      case LogType.status:
        if (message.startsWith('✅')) return (Icons.check_circle, Colors.green);
        if (message.startsWith('❌')) {
          return (Icons.error, theme.colorScheme.error);
        }
        return (Icons.info, Colors.orange.shade600);
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
          title: const Text("Содержимое пакета (JSON)"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                prettyJson,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
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

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getVisuals(entry.type, entry.message, context);
    final (opcode, seq) = _extractInfo(entry.message);
    final formattedTime = DateFormat('HH:mm:ss.SSS').format(entry.timestamp);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () => _showJsonViewer(context, entry.message),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    formattedTime,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (opcode != null)
                    Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      label: Text(
                        'OP: $opcode',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  const SizedBox(width: 4),
                  if (seq != null)
                    Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      label: Text(
                        'SEQ: $seq',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                entry.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
