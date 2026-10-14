import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/links/visited_link_sites.dart';
import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/widgets/formatted_message_text.dart';
import 'package:komet/frontend/widgets/link_confirm_sheet.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

Future<void> _pumpMessage(WidgetTester tester, String text, String url) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: FormattedMessageText(
            text: text,
            ranges: [
              FormatRange(
                format: TextFormat.link,
                start: 0,
                length: text.length,
                attributes: {'url': url},
              ),
            ],
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    ),
  );
}

Future<void> _tapLink(WidgetTester tester, String text) async {
  await tester.tapOnText(find.textRange.ofSubstring(text));
  await tester.pumpAndSettle();
}

void main() {
  final launched = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisitedLinkSites.resetForTest();
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcher, (call) async {
          if (call.method == 'launch') {
            launched.add((call.arguments as Map)['url'] as String);
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcher, null);
  });

  test('a link is hidden only when its text hides the address', () {
    expect(linkShowsItsTarget('example.com', 'https://example.com/'), isTrue);
    expect(
      linkShowsItsTarget('Https://WWW.Example.com', 'https://example.com'),
      isTrue,
    );
    expect(linkShowsItsTarget('Synthetic', 'https://example.com'), isFalse);
    expect(linkShowsItsTarget('safe.org', 'https://example.com'), isFalse);
  });

  test('visited sites are kept per host', () async {
    expect(
      VisitedLinkSites.siteOf('https://WWW.Example.com/a?b'),
      'example.com',
    );
    expect(await VisitedLinkSites.contains('https://example.com/x'), isFalse);

    await VisitedLinkSites.remember('https://www.example.com/first');
    VisitedLinkSites.resetForTest();

    expect(await VisitedLinkSites.contains('http://example.com/other'), isTrue);
    expect(await VisitedLinkSites.contains('https://other.example'), isFalse);
  });

  testWidgets('cancelling the sheet keeps the user in the app', (tester) async {
    await _pumpMessage(tester, 'Synthetic link', 'https://example.com/path');
    await _tapLink(tester, 'Synthetic link');

    expect(find.text('Открыть ссылку?'), findsOneWidget);
    expect(find.textContaining('example.com/path'), findsOneWidget);
    expect(find.text('Перейти'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.text('Открыть ссылку?'), findsNothing);
    expect(launched, isEmpty);
    expect(await VisitedLinkSites.contains('https://example.com'), isFalse);
  });

  testWidgets('a confirmed site opens without asking next time', (
    tester,
  ) async {
    await _pumpMessage(tester, 'Synthetic link', 'https://example.com/path');
    await _tapLink(tester, 'Synthetic link');
    await tester.tap(find.text('Перейти'));
    await tester.pumpAndSettle();

    expect(launched, ['https://example.com/path']);

    await _tapLink(tester, 'Synthetic link');
    expect(find.text('Открыть ссылку?'), findsNothing);
    expect(launched, hasLength(2));
  });

  testWidgets('a link that shows its own address opens directly', (
    tester,
  ) async {
    await _pumpMessage(tester, 'example.com', 'https://example.com');
    await _tapLink(tester, 'example.com');

    expect(find.text('Открыть ссылку?'), findsNothing);
    expect(launched, ['https://example.com']);
  });
}
