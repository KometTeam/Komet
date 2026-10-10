import 'package:flutter_test/flutter_test.dart';
import 'package:kolibri/kolibri.dart' show WireLogEvent;
import 'package:komet/core/config/launch_flags.dart';
import 'package:komet/core/protocol/opcode_map.dart';
import 'package:komet/core/transport/wire_debug_log.dart';
import 'package:komet/core/utils/logger.dart';

const _loginJson = '{"token":"synthetic-token","interactive":true}';

WireLogEvent _event({
  required int opcode,
  String direction = 'out',
  String cmd = 'request',
  String json = '{"chatId":1}',
}) => WireLogEvent(
  direction: direction,
  cmd: cmd,
  opcode: opcode,
  seq: 7,
  json: json,
);

void main() {
  tearDown(LaunchFlags.reset);

  test('--debug включает лог, но не раскрывает LOGIN', () {
    LaunchFlags.parse(const ['--debug-test', '--no-mute']);
    expect(LaunchFlags.debug, isFalse);

    LaunchFlags.parse(const ['--debug']);
    expect(LaunchFlags.debug, isTrue);
    expect(LaunchFlags.revealLoginPayload, isFalse);
    expect(LaunchFlags.activeDebugFlag, '--debug');
  });

  test('--dw19p-im-crazy включает лог вместе с LOGIN', () {
    LaunchFlags.parse(const ['--dw19p-im-crazy']);
    expect(LaunchFlags.debug, isTrue);
    expect(LaunchFlags.revealLoginPayload, isTrue);
    expect(LaunchFlags.activeDebugFlag, '--dw19p-im-crazy');
  });

  test('все флаги разбираются одним проходом', () {
    LaunchFlags.parse(const ['--berserk', '--no-mute', '--contacts', '25']);
    expect(LaunchFlags.berserk, isTrue);
    expect(LaunchFlags.noMute, isTrue);
    expect(LaunchFlags.debugTest, isTrue);
    expect(LaunchFlags.contactCount, 25);
    expect(LaunchFlags.unknown, isEmpty);
    expect(LaunchFlags.summary, [
      '--debug-test',
      '--contacts=25',
      '--berserk',
      '--no-mute',
    ]);
  });

  test('--contacts=N тоже включает тестовый режим', () {
    LaunchFlags.parse(const ['--contacts=7']);
    expect(LaunchFlags.debugTest, isTrue);
    expect(LaunchFlags.contactCount, 7);
  });

  test('неизвестные аргументы собираются для предупреждения', () {
    LaunchFlags.parse(const ['--debgu', '--contacts']);
    expect(LaunchFlags.debug, isFalse);
    expect(LaunchFlags.debugTest, isFalse);
    expect(LaunchFlags.unknown, ['--debgu', '--contacts']);
  });

  test('payload LOGIN скрыт без --dw19p-im-crazy в обе стороны', () {
    for (final direction in const ['out', 'in']) {
      final line = WireDebugLog.describe(
        session: 'api1/auth',
        event: _event(
          opcode: Opcode.login,
          direction: direction,
          json: _loginJson,
        ),
        revealLoginPayload: false,
      );
      expect(line, contains('LOGIN(19)'));
      expect(line, isNot(contains('synthetic-token')));
      expect(line, contains('--dw19p-im-crazy'));
    }
  });

  test('payload LOGIN виден с --dw19p-im-crazy', () {
    final line = WireDebugLog.describe(
      session: 'api1/auth',
      event: _event(opcode: Opcode.login, json: _loginJson),
      revealLoginPayload: true,
    );
    expect(line, contains('synthetic-token'));
  });

  test('остальные опкоды пишутся с payload целиком', () {
    final line = WireDebugLog.describe(
      session: 'api2/web',
      event: _event(
        opcode: Opcode.authRequest,
        direction: 'in',
        cmd: 'ok',
        json: '{"token":"synthetic-auth"}',
      ),
      revealLoginPayload: false,
    );
    expect(line, startsWith('WIRE [api2/web] << ok AUTH_REQUEST(17) seq=7 '));
    expect(line, endsWith('{"token":"synthetic-auth"}'));
  });

  test('длинная строка режется на куски без разрыва суррогатных пар', () {
    final max = KometLogPrinter.maxLineLength;
    final message = '${'a' * (max - 1)}😀${'b' * max}\nхвост';
    final lines = KometLogPrinter.splitForConsole(message);
    expect(lines.every((l) => l.length <= max), isTrue);
    expect(lines.join(), message.replaceAll('\n', ''));
    expect(lines.last, 'хвост');
    for (final line in lines) {
      final last = line.codeUnitAt(line.length - 1);
      expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
    }
  });

  test('пароли в трафике всегда замазаны', () {
    final line = WireDebugLog.describe(
      session: 'api1/pre',
      event: _event(
        opcode: Opcode.authLoginCheckPassword,
        json: r'{"password":"synthetic \"pass\"","trackId":"t-1",'
            r'"newPassword":"synthetic-new"}',
      ),
      revealLoginPayload: true,
    );
    expect(line, isNot(contains('synthetic')));
    expect(line, contains('"password":"***"'));
    expect(line, contains('"newPassword":"***"'));
    expect(line, contains('"trackId":"t-1"'));
  });
}
