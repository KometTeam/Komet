import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/links/visited_link_sites.dart';
import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/widgets/formatted_message_text.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _launcher = MethodChannel('plugins.flutter.io/url_launcher');
const _text = 'Synthetic bold and https://example.com';
final _ranges = [
  const FormatRange(format: TextFormat.strong, start: 10, length: 4),
];

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Color color = Colors.black;
  int ticks = 0;

  void bump() => setState(() => ticks++);

  void recolor(Color value) => setState(() => color = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            Text('rebuilt $ticks'),
            FormattedMessageText(
              text: _text,
              ranges: _ranges,
              style: TextStyle(fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

InlineSpan _messageSpan(WidgetTester tester) => tester
    .renderObjectList<RenderParagraph>(
      find.descendant(
        of: find.byType(FormattedMessageText),
        matching: find.byType(RichText),
      ),
    )
    .single
    .text;

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

  testWidgets('an unchanged message keeps its built text across rebuilds', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final before = _messageSpan(tester);

    tester.state<_HostState>(find.byType(_Host)).bump();
    await tester.pump();

    expect(find.text('rebuilt 1'), findsOneWidget);
    expect(_messageSpan(tester), same(before));

    await tester.tapOnText(find.textRange.ofSubstring('https://example.com'));
    await tester.pumpAndSettle();
    expect(launched, ['https://example.com']);
  });

  testWidgets('a new style rebuilds the text', (tester) async {
    await tester.pumpWidget(const _Host());
    final before = _messageSpan(tester);

    tester.state<_HostState>(find.byType(_Host)).recolor(Colors.blue);
    await tester.pump();

    final after = _messageSpan(tester);
    expect(after, isNot(same(before)));
    final message = (after as TextSpan).children!.single;
    expect(message.style?.color, Colors.blue);
  });
}
