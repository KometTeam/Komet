import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

Level _minimumLogLevel() {
  const raw = String.fromEnvironment('KOMET_LOG_LEVEL', defaultValue: '');
  switch (raw.toLowerCase()) {
    case 'trace':
      return Level.trace;
    case 'debug':
      return Level.debug;
    case 'info':
      return Level.info;
    case 'warning':
    case 'warn':
      return Level.warning;
    case 'error':
      return Level.error;
    case 'fatal':
      return Level.fatal;
    case 'off':
      return Level.off;
    default:
      break;
  }
  if (kReleaseMode) {
    return Level.info;
  }
  return Level.trace;
}

LogFilter _logFilter() {
  if (kReleaseMode) {
    return ProductionFilter();
  }
  return DevelopmentFilter();
}

final logger = Logger(
  filter: _logFilter(),
  level: _minimumLogLevel(),
  printer: KometLogPrinter(),
);

int _importanceSortKey(Level level) {
  final v = level.value;
  if (v >= 5999) {
    return 0;
  }
  if (v >= 5000) {
    return 1;
  }
  if (v >= 4000) {
    return 2;
  }
  if (v >= 3000) {
    return 3;
  }
  if (v >= 2000) {
    return 4;
  }
  return 5;
}

String _levelLetter(Level level) {
  final v = level.value;
  if (v >= 5999) {
    return 'F';
  }
  if (v >= 5000) {
    return 'E';
  }
  if (v >= 4000) {
    return 'W';
  }
  if (v >= 3000) {
    return 'I';
  }
  if (v >= 2000) {
    return 'D';
  }
  return 'T';
}

AnsiColor _levelColor(Level level) {
  final v = level.value;
  if (v >= 5999) {
    return const AnsiColor.fg(199);
  }
  if (v >= 5000) {
    return const AnsiColor.fg(196);
  }
  if (v >= 4000) {
    return const AnsiColor.fg(208);
  }
  if (v >= 3000) {
    return const AnsiColor.fg(12);
  }
  if (v >= 2000) {
    return const AnsiColor.none();
  }
  return AnsiColor.fg(AnsiColor.grey(0.5));
}

class KometLogPrinter extends LogPrinter {
  KometLogPrinter({this.colors = true});

  final bool colors;

  @override
  List<String> log(LogEvent event) {
    final lines = <String>[];
    final t = event.time;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}.${t.millisecond.toString().padLeft(3, '0')}';
    final ord = _importanceSortKey(event.level).toString().padLeft(2, '0');
    final letter = _levelLetter(event.level);
    final label = colors ? _levelColor(event.level)(letter) : letter;
    final msg = _stringifyMessage(event.message);
    lines.add('$ord|$timeStr $label $msg');
    if (event.error != null) {
      lines.add('${' ' * 3}|         ${event.error}');
    }
    if (event.stackTrace != null && event.level.value >= 5000) {
      final st = event.stackTrace.toString().split('\n');
      const limit = 12;
      for (var i = 0; i < st.length && i < limit; i++) {
        lines.add('${' ' * 3}|         ${st[i]}');
      }
    }
    return lines;
  }

  String _stringifyMessage(dynamic message) {
    final finalMessage = message is Function ? message() : message;
    if (finalMessage is Map || finalMessage is Iterable) {
      return const JsonEncoder.withIndent(null).convert(finalMessage);
    }
    return finalMessage.toString();
  }
}
