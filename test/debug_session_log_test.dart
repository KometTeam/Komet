import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/debug_session_log.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

void main() {
  late Directory sessions;
  late File staleSession;

  File currentSession() => sessions
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.jsonl'))
      .reduce((a, b) => a.path.compareTo(b.path) > 0 ? a : b);

  setUpAll(() async {
    final root = Directory.systemTemp.createTempSync('synthetic_debug_log');
    addTearDown(() => root.deleteSync(recursive: true));
    PathProviderPlatform.instance = _SyntheticPathProvider(root.path);
    sessions = Directory('${root.path}/debug_sessions')..createSync();

    final now = DateTime.now();
    final previous = now.subtract(const Duration(hours: 1));
    File(
      '${sessions.path}/session_${previous.millisecondsSinceEpoch}.jsonl',
    ).writeAsStringSync(
      [
        {
          'k': 'q',
          'op': 1,
          'seq': 5,
          't': previous.toIso8601String(),
          'p': {'probe': 'synthetic-request'},
        },
        {'k': 'l', 'v': 'synthetic log line'},
        {
          'k': 'r',
          'seq': 5,
          'cmd': 1,
          't': previous.toIso8601String(),
          'p': {'probe': 'synthetic-response'},
        },
        {'k': 'q', 'op': 2, 'seq': 6, 't': previous.toIso8601String(), 'p': {}},
        {
          'k': 'e',
          'seq': 6,
          't': previous.toIso8601String(),
          'err': 'synthetic failure',
        },
      ].map(jsonEncode).join('\n'),
    );

    final legacy = now.subtract(const Duration(hours: 2));
    File(
      '${sessions.path}/session_${legacy.millisecondsSinceEpoch}.json',
    ).writeAsStringSync(
      jsonEncode({
        'startedAt': legacy.toIso8601String(),
        'entries': [],
        'logs': ['synthetic legacy line'],
      }),
    );

    final stale = now.subtract(const Duration(hours: 48));
    staleSession = File(
      '${sessions.path}/session_${stale.millisecondsSinceEpoch}.jsonl',
    )..writeAsStringSync('');

    await DebugSessionLog.instance.init();
  });

  test('sessions older than a day are rotated away', () {
    expect(staleSession.existsSync(), isFalse);
  });

  test('new records are appended instead of rewriting the session', () async {
    final log = DebugSessionLog.instance;
    log.recordLogLine('first synthetic line');
    log.recordRequest(1, 7, {'probe': 'first'});
    await log.flushNow();
    final before = currentSession().readAsStringSync();

    log.recordResponse(7, 1, {'probe': 'answer'});
    log.recordLogLine('second synthetic line');
    await log.flushNow();
    final after = currentSession().readAsStringSync();

    expect(after.startsWith(before), isTrue);
    expect(const LineSplitter().convert(after).length, 4);
  });

  test('a payload with non-string keys still reaches the file', () async {
    final log = DebugSessionLog.instance;
    log.recordRequest(3, 8, {1: 'numeric key'});
    await log.flushNow();

    final last = const LineSplitter()
        .convert(currentSession().readAsStringSync())
        .last;
    expect(jsonDecode(last)['p'], {'1': 'numeric key'});
  });

  test('export reads both the appended and the legacy format', () async {
    final files = await DebugSessionLog.instance.buildExportFiles();
    final text = files!.map((file) => file.content).join('\n');

    expect(text, contains('synthetic-request'));
    expect(text, contains('synthetic-response'));
    expect(text, contains('synthetic log line'));
    expect(text, contains('<= ошибка: synthetic failure'));
    expect(text, contains('synthetic legacy line'));
    expect(text, contains('first synthetic line'));
    expect(files.where((file) => file.name.startsWith('session_')).length, 3);
  });
}
