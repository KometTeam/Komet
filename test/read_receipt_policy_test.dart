import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/komet_settings.dart';

void main() {
  tearDown(() {
    KometSettings.ghostMode.value = false;
    KometSettings.antiRead.value = false;
  });

  test('ghost mode does not suppress read receipts', () {
    KometSettings.ghostMode.value = true;
    KometSettings.antiRead.value = false;

    expect(KometSettings.readReceiptsStayLocal, isFalse);
  });

  test('anti read is the only setting that keeps receipts local', () {
    KometSettings.ghostMode.value = false;
    KometSettings.antiRead.value = true;
    expect(KometSettings.readReceiptsStayLocal, isTrue);

    KometSettings.ghostMode.value = true;
    expect(KometSettings.readReceiptsStayLocal, isTrue);
  });
}
