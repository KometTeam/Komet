import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/account.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/frontend/screens/auth/call_out_controller.dart';

const _params = CallOutParams(
  trackId: 'track-1',
  ttl: Duration(minutes: 5),
  pollingInterval: Duration(seconds: 2),
);

class _FakeServer {
  final List<Object> answers;
  final List<String> asked = [];

  _FakeServer(this.answers);

  Future<CallOutCheck> check(String trackId) async {
    asked.add(trackId);
    final answer = answers.length > 1 ? answers.removeAt(0) : answers.first;
    if (answer is CallOutCheck) return answer;
    throw answer;
  }
}

CallOutCheck _status(CallOutStatus status, [String? number]) =>
    CallOutCheck(status: status, callNumber: number);

void main() {
  group('callOutParams из ответа AUTH_REQUEST', () {
    test('полный набор полей даёт параметры звонка в миллисекундах', () {
      final params = CallOutParams.tryParse({
        'trackId': 'abc',
        'ttl': 300000,
        'pollingInterval': 3000,
      });

      expect(params, isNotNull);
      expect(params!.trackId, 'abc');
      expect(params.ttl, const Duration(minutes: 5));
      expect(params.pollingInterval, const Duration(seconds: 3));
    });

    test('без trackId или с нулевым ttl звонка нет', () {
      expect(
        CallOutParams.tryParse({'ttl': 1000, 'pollingInterval': 1000}),
        isNull,
      );
      expect(
        CallOutParams.tryParse({
          'trackId': 'abc',
          'ttl': 0,
          'pollingInterval': 1000,
        }),
        isNull,
      );
      expect(CallOutParams.tryParse(null), isNull);
    });
  });

  group('ответ AUTH_CHECK_CALL', () {
    test('статусы читаются по коду', () {
      expect(
        CallOutCheck.fromPayload({
          'status': 1,
          'callNumber': '+70000000000',
        }).status,
        CallOutStatus.numberAssigned,
      );
      expect(
        CallOutCheck.fromPayload({'status': 2}).status,
        CallOutStatus.verificationPassed,
      );
      expect(CallOutCheck.fromPayload({'status': 9}).status, isNull);
    });

    test('пустой номер считается отсутствующим', () {
      expect(
        CallOutCheck.fromPayload({'status': 1, 'callNumber': ''}).callNumber,
        isNull,
      );
    });
  });

  group('опрос звонка', () {
    testWidgets('номер выдан, звонок принят — опрос останавливается', (
      tester,
    ) async {
      final server = _FakeServer([
        _status(CallOutStatus.numberNotAssigned),
        _status(CallOutStatus.numberAssigned, '+70000000001'),
        _status(CallOutStatus.verificationPassed),
      ]);
      final controller = CallOutController(params: _params, check: server.check)
        ..start();

      await tester.pump();
      expect(controller.phase, CallOutPhase.waitingForNumber);

      await tester.pump(_params.pollingInterval);
      expect(controller.phase, CallOutPhase.awaitingCall);
      expect(controller.callNumber, '+70000000001');

      await tester.pump(_params.pollingInterval);
      expect(controller.phase, CallOutPhase.verified);

      final asked = server.asked.length;
      await tester.pump(_params.pollingInterval * 3);
      expect(server.asked.length, asked);
      expect(server.asked, everyElement('track-1'));

      controller.dispose();
    });

    testWidgets('обрыв связи не прерывает опрос', (tester) async {
      final server = _FakeServer([
        StateError('AccountModule: сессия не онлайн'),
        _status(CallOutStatus.numberAssigned, '+70000000002'),
      ]);
      final controller = CallOutController(params: _params, check: server.check)
        ..start();

      await tester.pump();
      expect(controller.phase, CallOutPhase.waitingForNumber);

      await tester.pump(_params.pollingInterval);
      expect(controller.phase, CallOutPhase.awaitingCall);

      controller.dispose();
    });

    testWidgets('ошибка сервера останавливает опрос', (tester) async {
      final server = _FakeServer([const PacketError('Трек не найден')]);
      final controller = CallOutController(params: _params, check: server.check)
        ..start();

      await tester.pump();
      expect(controller.phase, CallOutPhase.failed);
      expect(controller.error, isA<PacketError>());

      await tester.pump(_params.pollingInterval * 3);
      expect(server.asked, hasLength(1));

      controller.dispose();
    });

    testWidgets('таймаут на сервере — номер надо обновить', (tester) async {
      final server = _FakeServer([_status(CallOutStatus.verificationTimeout)]);
      final controller = CallOutController(params: _params, check: server.check)
        ..start();

      await tester.pump();
      expect(controller.phase, CallOutPhase.expired);
      expect(controller.remaining.value, Duration.zero);

      controller.dispose();
    });

    testWidgets('новый номер сбрасывает прошлое состояние', (tester) async {
      final server = _FakeServer([
        _status(CallOutStatus.verificationTimeout),
        _status(CallOutStatus.numberAssigned, '+70000000003'),
      ]);
      final controller = CallOutController(params: _params, check: server.check)
        ..start();

      await tester.pump();
      expect(controller.phase, CallOutPhase.expired);

      controller.restart(
        const CallOutParams(
          trackId: 'track-2',
          ttl: Duration(minutes: 5),
          pollingInterval: Duration(seconds: 2),
        ),
      );
      await tester.pump();
      expect(controller.phase, CallOutPhase.awaitingCall);
      expect(controller.trackId, 'track-2');
      expect(server.asked.last, 'track-2');

      controller.dispose();
    });

    testWidgets('после dispose запросов больше нет', (tester) async {
      final server = _FakeServer([_status(CallOutStatus.numberNotAssigned)]);
      final controller = CallOutController(params: _params, check: server.check)
        ..start();

      await tester.pump();
      controller.dispose();
      final asked = server.asked.length;

      await tester.pump(_params.pollingInterval * 3);
      expect(server.asked.length, asked);
    });
  });
}
