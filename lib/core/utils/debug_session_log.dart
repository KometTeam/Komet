import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../protocol/opcode_map.dart';
import 'app_foreground.dart';
import 'format.dart';
import 'log_redact.dart';

// #***! файл в архиве экспорта
class DebugExportFile {
  final String name;
  final String content;

  DebugExportFile(this.name, this.content);
}

// #***! запрос с ответом, сматчены по seq
class _LogEntry {
  final int opcode;
  final int seq;
  final DateTime requestTime;
  final dynamic request;
  DateTime? responseTime;
  int? cmd;
  dynamic response;
  String? error;

  _LogEntry({
    required this.opcode,
    required this.seq,
    required this.requestTime,
    required this.request,
  });

  // #***! в файл сессии джейсоном
  Map<String, dynamic> toJson() => {
    'opcode': opcode,
    'seq': seq,
    'requestTime': requestTime.toIso8601String(),
    'request': request,
    if (responseTime != null) 'responseTime': responseTime!.toIso8601String(),
    if (cmd != null) 'cmd': cmd,
    if (response != null) 'response': response,
    if (error != null) 'error': error,
  };

  static _LogEntry fromJson(Map data) {
    final entry = _LogEntry(
      opcode: (data['opcode'] as num?)?.toInt() ?? 0,
      seq: (data['seq'] as num?)?.toInt() ?? 0,
      requestTime:
          DateTime.tryParse(data['requestTime']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      request: data['request'],
    );
    final rt = data['responseTime']?.toString();
    if (rt != null) entry.responseTime = DateTime.tryParse(rt);
    entry.cmd = (data['cmd'] as num?)?.toInt();
    entry.response = data['response'];
    entry.error = data['error']?.toString();
    return entry;
  }
}

// #***! одна сессия, запросы плюс строки лога
class _SessionData {
  final DateTime startedAt;
  final List<_LogEntry> entries;
  final bool truncated;
  final List<String> logLines;
  final bool logsTruncated;

  _SessionData({
    required this.startedAt,
    required this.entries,
    this.truncated = false,
    this.logLines = const [],
    this.logsTruncated = false,
  });

  static _SessionData fromJson(Map data) {
    final list = data['entries'];
    final entries = <_LogEntry>[];
    if (list is List) {
      for (final e in list) {
        if (e is Map) entries.add(_LogEntry.fromJson(e));
      }
    }
    final rawLogs = data['logs'];
    final logLines = <String>[];
    if (rawLogs is List) {
      for (final l in rawLogs) {
        logLines.add(l.toString());
      }
    }
    return _SessionData(
      startedAt:
          DateTime.tryParse(data['startedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entries: entries,
      truncated: data['truncated'] == true,
      logLines: logLines,
      logsTruncated: data['logsTruncated'] == true,
    );
  }
}

// #***! отладочный лог, пишется на диск и выгружается архивом из дев меню
class DebugSessionLog {
  DebugSessionLog._();
  static final DebugSessionLog instance = DebugSessionLog._();

  // #***! старше суток и лишние сверх 30 удаляем
  static const Duration _retention = Duration(hours: 24);
  static const int _maxStoredSessions = 30;
  // #***! потолки на сессию чтоб файл не рос бесконечно
  static const int _maxEntriesPerSession = 2000;
  static const int _maxLogLinesPerSession = 5000;
  // #***! в фоне пишем раз в минуту а не в три секунды, батарея
  static const Duration _flushDebounce = Duration(seconds: 3);
  static const Duration _backgroundFlushDebounce = Duration(seconds: 60);

  static final RegExp _ansiEscape = RegExp(r'\x1B\[[0-9;]*m');

  Directory? _dir;
  File? _currentFile;
  DateTime? _currentStart;
  final List<_LogEntry> _entries = [];
  final List<String> _logLines = [];
  bool _truncated = false;
  bool _logsTruncated = false;
  bool _initialized = false;
  bool _dirty = false;
  Timer? _flushTimer;

  // #***! каталог сессий и ротация
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _currentStart = DateTime.now();
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/debug_sessions');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
      await _rotate();
      _currentFile = File(
        '${dir.path}/session_${_currentStart!.millisecondsSinceEpoch}.json',
      );
      if (_dirty) _scheduleFlush();
    } catch (_) {
      _dir = null;
      _currentFile = null;
    }
  }

  // #***! чистим ANSI цвета иначе в файле мусор
  void recordLogLine(String line) {
    final clean = line.replaceAll(_ansiEscape, '');
    _logLines.add(clean);
    if (_logLines.length > _maxLogLinesPerSession) {
      _logLines.removeRange(0, _logLines.length - _maxLogLinesPerSession);
      _logsTruncated = true;
    }
    _scheduleFlush();
  }

  // #***! исходящий запрос, payload чистим от секретов
  void recordRequest(int opcode, int seq, dynamic payload) {
    _entries.add(
      _LogEntry(
        opcode: opcode,
        seq: seq,
        requestTime: DateTime.now(),
        request: redactForLog(payload),
      ),
    );
    if (_entries.length > _maxEntriesPerSession) {
      _entries.removeRange(0, _entries.length - _maxEntriesPerSession);
      _truncated = true;
    }
    _scheduleFlush();
  }

  // #***! ответ подшиваем к запросу по seq
  void recordResponse(int seq, int cmd, dynamic payload) {
    final entry = _findPending(seq);
    if (entry == null) return;
    entry.responseTime = DateTime.now();
    entry.cmd = cmd;
    entry.response = redactForLog(payload);
    _scheduleFlush();
  }

  // #***! ошибку тоже подшиваем
  void recordError(int seq, Object error) {
    final entry = _findPending(seq);
    if (entry == null) return;
    entry.responseTime = DateTime.now();
    entry.error = error.toString();
    _scheduleFlush();
  }

  // #***! ищем с конца, seq переиспользуются нужен последний неотвеченный
  _LogEntry? _findPending(int seq) {
    for (var i = _entries.length - 1; i >= 0; i--) {
      final entry = _entries[i];
      if (entry.seq == seq &&
          entry.responseTime == null &&
          entry.error == null) {
        return entry;
      }
    }
    return null;
  }

  // #***! пишем с задержкой иначе файл переписывается на каждый пакет
  void _scheduleFlush() {
    _dirty = true;
    if (_currentFile == null) return;
    _flushTimer ??= Timer(
      AppForeground.value ? _flushDebounce : _backgroundFlushDebounce,
      () {
        _flushTimer = null;
        _flush();
      },
    );
  }

  // #***! снимок сессии целиком одним джейсоном
  Future<void> _flush() async {
    final file = _currentFile;
    if (file == null || !_dirty) return;
    _dirty = false;
    try {
      final data = jsonEncode({
        'startedAt': _currentStart?.toIso8601String(),
        'truncated': _truncated,
        'entries': _entries.map((e) => e.toJson()).toList(),
        'logsTruncated': _logsTruncated,
        'logs': List.of(_logLines),
      });
      await file.writeAsString(data);
    } catch (_) {}
  }

  Future<void> flushNow() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flush();
  }

  // #***! ротация, удаляем протухшие и лишние
  Future<void> _rotate() async {
    final files = await _sessionFiles();
    final cutoff = DateTime.now().subtract(_retention).millisecondsSinceEpoch;
    final stale = <File>[];
    final fresh = <File>[];
    for (final file in files) {
      (_startMillis(file) < cutoff ? stale : fresh).add(file);
    }
    const keep = _maxStoredSessions - 1;
    if (fresh.length > keep) {
      stale.addAll(fresh.take(fresh.length - keep));
    }
    for (final file in stale) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<List<File>> _sessionFiles() async {
    final dir = _dir;
    if (dir == null) return [];
    final entries = await dir.list().toList();
    final files = entries.whereType<File>().where((f) {
      final name = f.uri.pathSegments.last;
      return name.startsWith('session_') && name.endsWith('.json');
    }).toList();
    files.sort((a, b) => _startMillis(a).compareTo(_startMillis(b)));
    return files;
  }

  int _startMillis(File file) {
    final name = file.uri.pathSegments.last;
    final digits = name.substring(
      'session_'.length,
      name.length - '.json'.length,
    );
    return int.tryParse(digits) ?? 0;
  }

  // #***! сборка архива для выгрузки
  Future<List<DebugExportFile>?> buildExportFiles({String? endpoint}) async {
    final cutoff = DateTime.now().subtract(_retention);
    final sessions = <_SessionData>[];
    final dir = _dir;
    if (dir != null) {
      for (final file in await _sessionFiles()) {
        if (_currentFile != null && file.path == _currentFile!.path) continue;
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is Map) {
            final session = _SessionData.fromJson(decoded);
            if (!session.startedAt.isBefore(cutoff)) sessions.add(session);
          }
        } catch (_) {}
      }
    }
    sessions.add(
      _SessionData(
        startedAt: _currentStart ?? DateTime.now(),
        entries: List.of(_entries),
        truncated: _truncated,
        logLines: List.of(_logLines),
        logsTruncated: _logsTruncated,
      ),
    );
    sessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final totalEntries = sessions.fold<int>(
      0,
      (sum, s) => sum + s.entries.length,
    );
    final totalLogs = sessions.fold<int>(
      0,
      (sum, s) => sum + s.logLines.length,
    );
    if (totalEntries == 0 && totalLogs == 0) return null;

    final info = StringBuffer();
    info.writeln('Komet — отладочный лог');
    if (endpoint != null) info.writeln('Сервер: $endpoint');
    info.writeln('Экспортирован: ${DateTime.now().toIso8601String()}');
    info.writeln('Период: последние ${_retention.inHours} часа');
    info.writeln('Заходов в приложение: ${sessions.length}');
    info.writeln('Всего запросов: $totalEntries');
    info.writeln('Всего строк лога: $totalLogs');
    info.writeln('Скрыто: токен полностью, номер кроме первых 3 символов');

    final files = <DebugExportFile>[DebugExportFile('info.txt', '$info')];
    for (var s = 0; s < sessions.length; s++) {
      final session = sessions[s];
      final name =
          'session_${(s + 1).toString().padLeft(2, '0')}_'
          '${formatFileStamp(session.startedAt)}.txt';
      files.add(DebugExportFile(name, _buildSessionText(s + 1, session)));
    }
    return files;
  }

  // #***! сессия в читаемый текст
  String _buildSessionText(int index, _SessionData session) {
    final buffer = StringBuffer();
    buffer.writeln('==================================================');
    buffer.writeln('ЗАХОД #$index — ${session.startedAt.toIso8601String()}');
    buffer.writeln(
      'запросов: ${session.entries.length}'
      '${session.truncated ? ' (обрезано до $_maxEntriesPerSession)' : ''}'
      ' · строк лога: ${session.logLines.length}'
      '${session.logsTruncated ? ' (обрезано до $_maxLogLinesPerSession)' : ''}',
    );
    buffer.writeln('==================================================');
    buffer.writeln();

    buffer.writeln('----- ЛОГИ ПРИЛОЖЕНИЯ -----');
    if (session.logLines.isEmpty) {
      buffer.writeln('(пусто)');
    } else {
      for (final line in session.logLines) {
        buffer.writeln(line);
      }
    }
    buffer.writeln();

    buffer.writeln('----- ЗАПРОСЫ -----');
    if (session.entries.isEmpty) {
      buffer.writeln('(пусто)');
    } else {
      for (var i = 0; i < session.entries.length; i++) {
        _writeEntry(buffer, i + 1, session.entries[i]);
      }
    }
    return buffer.toString();
  }

  void _writeEntry(StringBuffer buffer, int index, _LogEntry e) {
    buffer.writeln('----- запрос #$index -----');
    buffer.writeln('время:  ${e.requestTime.toIso8601String()}');
    buffer.writeln('opcode: ${e.opcode} (${Opcode.name(e.opcode)})');
    buffer.writeln('seq:    ${e.seq}');
    buffer.writeln('=> payload:');
    buffer.writeln(_pretty(e.request));
    if (e.error != null) {
      buffer.writeln('<= ошибка: ${e.error}');
    } else if (e.responseTime != null) {
      buffer.writeln(
        '<= ответ: ${e.responseTime!.toIso8601String()} '
        'cmd ${e.cmd} (${_cmdName(e.cmd)})',
      );
      buffer.writeln('payload:');
      buffer.writeln(_pretty(e.response));
    } else {
      buffer.writeln('<= (ответ не получен)');
    }
    buffer.writeln();
  }

  String _pretty(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}

// #***! числовой cmd в имя
String _cmdName(int? cmd) {
  switch (cmd) {
    case 0:
      return 'request';
    case 1:
      return 'ok';
    case 2:
      return 'notFound';
    case 3:
      return 'error';
    default:
      return 'cmd$cmd';
  }
}
