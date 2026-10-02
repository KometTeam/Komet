import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/ios_release.dart';
import 'package:komet/frontend/screens/contacts/contacts_tab.dart';

Future<void> _pump(WidgetTester tester, VoidCallback onPressed) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ContactsNfcExchangeButton(
            tooltip: 'Synthetic exchange',
            onPressed: onPressed,
          )),
      ),
    );

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('iOS hides the contact exchange button', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(IosRelease.nfcContactExchange, isFalse);
    await _pump(tester, () {});
    expect(find.byKey(const ValueKey('contacts-nfc-exchange')), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android keeps the contact exchange button', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(IosRelease.nfcContactExchange, isTrue);
    var taps = 0;
    await _pump(tester, () => taps++);
    await tester.tap(find.byKey(const ValueKey('contacts-nfc-exchange')));
    expect(taps, 1);
    debugDefaultTargetPlatformOverride = null;
  });
}
