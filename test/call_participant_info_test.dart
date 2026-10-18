import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/call_info.dart';
import 'package:komet/core/calls/call_session.dart';
import 'package:komet/core/calls/ws2_signaling.dart';
import 'package:komet/frontend/screens/calls/call_participant_info.dart';
import 'package:komet/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ru'));
  final session = CallSession(
    ws2Config: Ws2Config(uri: Uri.parse('wss://calls.invalid/ws'), userId: 1),
    role: CallRole.joiner,
    isGroup: true,
  );

  String? guess(CallParticipant p) {
    for (final row in callParticipantInfo(l10n, session, p)) {
      if (row.label == l10n.callInfoGuess) return row.value;
    }
    return null;
  }

  test('догадка о клиенте собирается из SDP и платформы', () {
    expect(guess(CallParticipant(id: 2)), isNull);
    expect(guess(CallParticipant(id: 2)..platform = 'WEB'), 'браузер');
    expect(
      guess(
        CallParticipant(id: 2)
          ..platform = 'WEB'
          ..engine = CallEngine.firefox,
      ),
      'Firefox',
    );
    expect(
      guess(
        CallParticipant(id: 2)
          ..transport = 'WEB_TRANSPORT'
          ..engine = CallEngine.libwebrtc,
      ),
      'Chrome, Chromium или Safari',
    );
    expect(
      guess(
        CallParticipant(id: 2)
          ..platform = 'ANDROID'
          ..engine = CallEngine.libwebrtc,
      ),
      'приложение для Android',
    );
    expect(
      guess(CallParticipant(id: 2)..platform = 'IOS'),
      'приложение для iOS',
    );
    expect(
      guess(CallParticipant(id: 1, isSelf: true)..platform = 'WEB'),
      isNull,
    );
  });

  test('движок определяется по строке o= в SDP', () {
    expect(
      CallParse.engineKind(
        'v=0\no=mozilla...THIS_IS_SDPARTA-99.0 1 0 IN IP4 0.0.0.0\n',
      ),
      CallEngine.firefox,
    );
    expect(
      CallParse.engineKind('v=0\r\no=- 46117 2 IN IP4 127.0.0.1\r\n'),
      CallEngine.libwebrtc,
    );
    expect(CallParse.engineKind('v=0\n'), isNull);
  });

  test('в звонке через сервер нет статуса сети — значит проблем нет', () {
    String network(CallSession session, CallParticipant p) =>
        callParticipantInfo(
          l10n,
          session,
          p,
        ).firstWhere((row) => row.label == l10n.callInfoNetwork).value;

    final sfu = CallSession(
      ws2Config: Ws2Config(uri: Uri.parse('wss://calls.invalid/ws'), userId: 1),
      role: CallRole.joiner,
      isGroup: true,
    )..debugTopology = 'SERVER';

    expect(network(session, CallParticipant(id: 2)), 'нет данных');
    expect(
      network(sfu, CallParticipant(id: 2)),
      'хорошая, сервер не сообщал о проблемах',
    );
    expect(
      network(sfu, CallParticipant(id: 2)..networkRating = 0.45),
      '45% · средняя',
    );
  });
}
