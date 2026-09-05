import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/read_marker_gate.dart';

void main() {
  group('ReadMarkerGate', () {
    testWidgets('debounced flush runs once the delay elapses', (tester) async {
      var flushes = 0;
      final gate = ReadMarkerGate(onFlush: () => flushes++);

      gate.schedule();
      await tester.pump(const Duration(milliseconds: 200));
      gate.schedule();
      await tester.pump(const Duration(milliseconds: 200));
      expect(flushes, 0);

      await tester.pump(const Duration(milliseconds: 200));
      expect(flushes, 1);
      gate.dispose();
    });

    testWidgets('a hold swallows scheduled and immediate flushes', (
      tester,
    ) async {
      var flushes = 0;
      final gate = ReadMarkerGate(onFlush: () => flushes++);

      gate.schedule();
      gate.hold();
      await tester.pump(const Duration(seconds: 1));
      gate.flush();
      gate.schedule();
      await tester.pump(const Duration(seconds: 1));
      expect(flushes, 0);
      gate.dispose();
    });

    testWidgets('nested holds release in pairs', (tester) async {
      var flushes = 0;
      final gate = ReadMarkerGate(onFlush: () => flushes++);

      gate.hold();
      gate.hold();
      gate.release();
      await tester.pump(const Duration(seconds: 1));
      expect(flushes, 0);

      gate.release();
      await tester.pump(const Duration(seconds: 1));
      expect(flushes, 1);
      gate.dispose();
    });

    testWidgets('release re-arms the debounce instead of flushing instantly', (
      tester,
    ) async {
      var flushes = 0;
      final gate = ReadMarkerGate(onFlush: () => flushes++);

      gate.hold();
      gate.release();
      expect(flushes, 0);
      await tester.pump(const Duration(milliseconds: 350));
      expect(flushes, 1);
      gate.dispose();
    });

    testWidgets('a hold taken while the timer is pending cancels it', (
      tester,
    ) async {
      var flushes = 0;
      final gate = ReadMarkerGate(onFlush: () => flushes++);

      gate.schedule();
      await tester.pump(const Duration(milliseconds: 340));
      gate.hold();
      await tester.pump(const Duration(seconds: 1));
      expect(flushes, 0);
      gate.dispose();
    });

    testWidgets('an unheld gate flushes immediately on demand', (tester) async {
      var flushes = 0;
      final gate = ReadMarkerGate(onFlush: () => flushes++);

      gate.schedule();
      gate.flush();
      expect(flushes, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(flushes, 1);
      gate.dispose();
    });

    testWidgets('dispose stops a pending flush', (tester) async {
      var flushes = 0;
      final gate = ReadMarkerGate(onFlush: () => flushes++);

      gate.schedule();
      gate.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(flushes, 0);
    });
  });
}
