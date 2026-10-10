import 'package:kolibri/kolibri.dart' show WireLogEvent;

import '../config/launch_flags.dart';
import '../protocol/opcode_map.dart';
import '../utils/logger.dart';
import '../utils/log_redact.dart';

class WireDebugLog {
  WireDebugLog._();

  static void record(String session, WireLogEvent event) {
    logger.d(
      describe(
        session: session,
        event: event,
        revealLoginPayload: LaunchFlags.revealLoginPayload,
      ),
    );
  }

  static String describe({
    required String session,
    required WireLogEvent event,
    required bool revealLoginPayload,
  }) {
    final arrow = event.direction == 'out' ? '>>' : '<<';
    final head =
        'WIRE [$session] $arrow ${event.cmd} '
        '${Opcode.name(event.opcode)}(${event.opcode}) seq=${event.seq}';
    final hidden = event.opcode == Opcode.login && !revealLoginPayload;
    final payload = hidden
        ? '<payload скрыт, ${event.json.length} симв.; '
              'показать: ${LaunchFlags.loginPayloadFlag}>'
        : maskPasswords(event.json);
    return '$head $payload';
  }

  static String maskPasswords(String json) => redactJsonForLog(json);
}
