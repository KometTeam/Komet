import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gwid/utils/log_utils.dart';

enum LogLevel { debug, info, warning, error, critical }

class ConnectionLogger {
  static final ConnectionLogger _instance = ConnectionLogger._internal();
  factory ConnectionLogger() => _instance;
  ConnectionLogger._internal();

  final List<LogEntry> _logs = [];
  final StreamController<LogEntry> _logController =
      StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get logStream => _logController.stream;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  static const int maxLogs = 1000;

  LogLevel _currentLevel = LogLevel.debug;

  void setLogLevel(LogLevel level) {
    _currentLevel = level;
  }

  void log(
    String message, {
    LogLevel level = LogLevel.info,
    String? category,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _currentLevel.index) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      category: category ?? 'CONNECTION',
      data: data,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.add(entry);

    if (_logs.length > maxLogs) {
      _logs.removeRange(0, _logs.length - maxLogs);
    }

    _logController.add(entry);

    if (kDebugMode) {
      final emoji = _getEmojiForLevel(level);
      final timestamp = entry.timestamp.toIso8601String().substring(11, 23);
      final categoryStr = category != null ? '[$category]' : '';
      final dataStr = data != null
          ? ' | Data: ${truncatePayloadForLog(jsonEncode(data))}'
          : '';
      final errorStr = error != null ? ' | Error: $error' : '';

      print('$emoji [$timestamp] $categoryStr $message$dataStr$errorStr');
    }
  }

  void logConnection(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
  }) {
    log(
      message,
      level: LogLevel.info,
      category: 'CONNECTION',
      data: data,
      error: error,
    );
  }

  void logError(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      message,
      level: LogLevel.error,
      category: 'ERROR',
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void logMessage(
    String direction,
    dynamic message, {
    Map<String, dynamic>? metadata,
  }) {
    final data = <String, dynamic>{
      'direction': direction,
      'message': message,
      if (metadata != null) ...metadata,
    };
    log(
      'WebSocket $direction',
      level: LogLevel.debug,
      category: 'WEBSOCKET',
      data: data,
    );
  }

  void logReconnect(int attempt, String reason, {Duration? delay}) {
    final data = <String, dynamic>{
      'attempt': attempt,
      'reason': reason,
      if (delay != null) 'delay_seconds': delay.inSeconds,
    };
    log(
      'Переподключение: $reason (попытка $attempt)',
      level: LogLevel.warning,
      category: 'RECONNECT',
      data: data,
    );
  }

  void logPerformance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metadata,
  }) {
    final data = <String, dynamic>{
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      if (metadata != null) ...metadata,
    };
    log(
      'Performance: $operation за ${duration.inMilliseconds}ms',
      level: LogLevel.debug,
      category: 'PERFORMANCE',
      data: data,
    );
  }

  void logState(String from, String to, {Map<String, dynamic>? metadata}) {
    final data = <String, dynamic>{
      'from': from,
      'to': to,
      if (metadata != null) ...metadata,
    };
    log(
      'Состояние: $from → $to',
      level: LogLevel.info,
      category: 'STATE',
      data: data,
    );
  }

  List<LogEntry> getLogsByCategory(String category) {
    return _logs.where((log) => log.category == category).toList();
  }

  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  Map<String, int> getLogStats() {
    final stats = <String, int>{};
    for (final log in _logs) {
      stats[log.category] = (stats[log.category] ?? 0) + 1;
    }
    return stats;
  }

  void clearLogs() {
    _logs.clear();
    log('Логи очищены', level: LogLevel.info, category: 'LOGGER');
  }

  String exportLogs() {
    final logsJson = _logs.map((log) => log.toJson()).toList();
    return jsonEncode(logsJson);
  }

  void importLogs(String jsonString) {
    try {
      final List<dynamic> logsList = jsonDecode(jsonString);
      _logs.clear();
      for (final logJson in logsList) {
        _logs.add(LogEntry.fromJson(logJson));
      }
      log(
        'Импортировано ${_logs.length} логов',
        level: LogLevel.info,
        category: 'LOGGER',
      );
    } catch (e) {
      logError('Ошибка импорта логов', error: e);
    }
  }

  String _getEmojiForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.critical:
        return '🚨';
    }
  }

  void dispose() {
    _logController.close();
  }
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String category;
  final Map<String, dynamic>? data;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.category,
    this.data,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'category': category,
      'data': data,
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      level: LogLevel.values.firstWhere((l) => l.name == json['level']),
      message: json['message'],
      category: json['category'],
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
      error: json['error'],
      stackTrace: json['stackTrace'] != null
          ? StackTrace.fromString(json['stackTrace'])
          : null,
    );
  }

  @override
  String toString() {
    final emoji = _getEmojiForLevel(level);
    final timestamp = this.timestamp.toIso8601String().substring(11, 23);
    final dataStr = data != null
        ? ' | Data: ${truncatePayloadForLog(jsonEncode(data))}'
        : '';
    final errorStr = error != null ? ' | Error: $error' : '';

    return '$emoji [$timestamp] [$category] $message$dataStr$errorStr';
  }

  String _getEmojiForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.critical:
        return '🚨';
    }
  }
}
