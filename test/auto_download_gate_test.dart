import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/auto_download_gate.dart';

const _cached = 'https://cdn.invalid/cached.jpg';
const _missing = 'https://cdn.invalid/missing.jpg';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() {
    AutoDownloadGate.reset();
    AutoDownloadGate.isCached = (key) async => key == _cached;
  });

  test('auto-download on always allows without asking the cache', () {
    var asked = false;
    AutoDownloadGate.isCached = (_) async => asked = true;
    expect(AutoDownloadGate.allows(true, _missing), isTrue);
    expect(asked, isFalse);
  });

  test('a picture already in the cache opens without a tap', () async {
    expect(AutoDownloadGate.allows(false, _cached), isFalse);
    expect(AutoDownloadGate.awaitsTap(false, _cached), isFalse);
    await _settle();
    expect(AutoDownloadGate.allows(false, _cached), isTrue);
    expect(AutoDownloadGate.listen(_cached).value, ManualLoad.loaded);
  });

  test('a picture missing from the cache waits for a tap', () async {
    expect(AutoDownloadGate.awaitsTap(false, _missing), isFalse);
    await _settle();
    expect(AutoDownloadGate.awaitsTap(false, _missing), isTrue);
    AutoDownloadGate.loadManually(_missing);
    expect(AutoDownloadGate.allows(false, _missing), isTrue);
    expect(AutoDownloadGate.awaitsTap(false, _missing), isFalse);
  });

  test(
    'a tap during the cache lookup is not overwritten by its answer',
    () async {
      expect(AutoDownloadGate.allows(false, _missing), isFalse);
      AutoDownloadGate.loadManually(_missing);
      await _settle();
      expect(AutoDownloadGate.allows(false, _missing), isTrue);
    },
  );

  test('a failing cache lookup falls back to the button', () async {
    AutoDownloadGate.isCached = (_) async => throw StateError('disk');
    AutoDownloadGate.allows(false, _cached);
    await _settle();
    expect(AutoDownloadGate.awaitsTap(false, _cached), isTrue);
  });

  test('idle entries are evicted once the gate is full', () async {
    AutoDownloadGate.capacity = 3;
    for (var i = 0; i < 10; i++) {
      AutoDownloadGate.allows(false, 'https://cdn.invalid/$i.jpg');
    }
    expect(AutoDownloadGate.size, 3);
    await _settle();
  });

  test('an entry a bubble listens to is never evicted', () async {
    AutoDownloadGate.capacity = 2;
    final watched = AutoDownloadGate.listen(_cached);
    AutoDownloadGate.allows(false, _cached);
    void onChange() {}
    watched.addListener(onChange);
    addTearDown(() => watched.removeListener(onChange));
    for (var i = 0; i < 10; i++) {
      AutoDownloadGate.allows(false, 'https://cdn.invalid/$i.jpg');
    }
    expect(identical(AutoDownloadGate.listen(_cached), watched), isTrue);
    await _settle();
    expect(watched.value, ManualLoad.loaded);
  });

  test('an evicted picture asks the cache again when it comes back', () async {
    AutoDownloadGate.capacity = 1;
    AutoDownloadGate.loadManually(_missing);
    AutoDownloadGate.allows(false, _cached);
    await _settle();
    expect(AutoDownloadGate.allows(false, _missing), isFalse);
    await _settle();
    expect(AutoDownloadGate.awaitsTap(false, _missing), isTrue);
  });
}
