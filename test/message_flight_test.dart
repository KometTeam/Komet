import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/screens/chats/chat/message_flight.dart';
import 'package:komet/frontend/screens/chats/chat/view/message_enter.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';

const int _me = 1;
const int _peer = 2;
const double _width = 393;

CachedMessage _message(String id, int sender, String text, int minute) =>
    CachedMessage(
      id: id,
      accountId: _me,
      chatId: 5,
      senderId: sender,
      text: text,
      time: DateTime(2026, 1, 1, 10, minute).millisecondsSinceEpoch,
      status: 'sent',
    );

class _MiniChat extends StatefulWidget {
  const _MiniChat({super.key});

  @override
  State<_MiniChat> createState() => _MiniChatState();
}

class _MiniChatState extends State<_MiniChat> with TickerProviderStateMixin {
  final List<CachedMessage> messages = [
    _message('1', _peer, 'Синтетическое входящее сообщение', 1),
    _message('2', _me, 'Синтетический ответ', 2),
  ];
  final TextEditingController input = TextEditingController();
  final FocusNode focus = FocusNode();
  final ValueNotifier<MessageFlight?> flight = ValueNotifier(null);
  final Set<String> entering = {};

  @override
  void dispose() {
    flight.value?.dispose();
    flight.dispose();
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  void send() {
    final id = 'sent_${messages.length}';
    final from = ComposerSnapshot.capture(
      focus,
      fieldColor: const Color(0xFFE0E0E0),
    );
    final next = MessageFlight(messageId: id, from: from, vsync: this);
    next.addListener(() {
      if (!next.done) return;
      if (identical(flight.value, next)) flight.value = null;
      setState(() {});
    });
    flight.value = next;
    setState(() {
      messages.add(_message(id, _me, input.text.trim(), 3));
      input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => next.start());
  }

  void receive(String text) {
    final id = 'in_${messages.length}';
    entering.add(id);
    setState(() => messages.add(_message(id, _peer, text, 4)));
    WidgetsBinding.instance.addPostFrameCallback((_) => entering.clear());
  }

  @override
  Widget build(BuildContext context) {
    return MessageFlightLayer(
      flight: flight,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                final active = flight.value;
                final own = active != null && active.messageId == message.id
                    ? active
                    : null;
                return MessageEnter(
                  key: ValueKey(message.id),
                  entering: own != null || entering.contains(message.id),
                  progress: own?.controller,
                  hidden: own?.carriesBubble ?? false,
                  child: MessageBubble(
                    message: message,
                    isMe: message.senderId == _me,
                    myId: _me,
                    chatType: 'DIALOG',
                    listWidth: _width,
                    geometry: own?.geometry,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: input,
                  focusNode: focus,
                  maxLines: null,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _loadInter() async {
  final font = File('assets/fonts/Inter.ttf').readAsBytesSync();
  final loader = FontLoader('Inter')
    ..addFont(Future.value(ByteData.sublistView(font)));
  await loader.load();
}

Future<_MiniChatState> _pumpChat(WidgetTester tester, GlobalKey frame) async {
  tester.view.physicalSize = const Size(_width * 2, 700 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final chat = GlobalKey<_MiniChatState>();
  await tester.pumpWidget(
    RepaintBoundary(
      key: frame,
      child: MaterialApp(
        locale: const Locale('ru'),
        theme: ThemeData(fontFamily: 'Inter'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _MiniChat(key: chat)),
      ),
    ),
  );
  await tester.pump();
  return chat.currentState!;
}

double _rowHeight(WidgetTester tester, String id) =>
    tester.getSize(find.byKey(ValueKey(id), skipOffstage: false)).height;

void main() {
  setUpAll(_loadInter);

  testWidgets('a sent bubble flies out of the composer and lands in place', (
    tester,
  ) async {
    final frame = GlobalKey();
    final chat = await _pumpChat(tester, frame);
    await tester.enterText(find.byType(TextField), 'Привет из поля ввода');
    await tester.pump();

    final frames = <ui.Image>[];
    Future<void> capture() async {
      if (Platform.environment['KOMET_FLIGHT_FRAMES'] == null) return;
      final boundary =
          frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => boundary.toImage()))!);
    }

    chat.send();
    await tester.pump();
    await capture();
    final flight = chat.flight.value!;
    expect(flight.carriesBubble, isTrue);
    expect(_rowHeight(tester, 'sent_2'), 0);

    final heights = <double>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      heights.add(_rowHeight(tester, 'sent_2'));
      await capture();
    }
    await tester.pumpAndSettle();
    await capture();

    expect(heights.first, greaterThanOrEqualTo(0));
    for (var i = 1; i < heights.length; i++) {
      expect(heights[i], greaterThanOrEqualTo(heights[i - 1]));
    }
    expect(chat.flight.value, isNull);
    final row = find.byKey(const ValueKey('sent_2'));
    expect(_rowHeight(tester, 'sent_2'), greaterThan(20));
    expect(
      find.descendant(of: row, matching: find.textContaining('Привет')),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);

    final out = Platform.environment['KOMET_FLIGHT_FRAMES'];
    if (out != null && frames.isNotEmpty) {
      final strip = await tester.runAsync(() async {
        final w = frames.first.width;
        final h = frames.first.height;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        for (var i = 0; i < frames.length; i++) {
          canvas.drawImage(frames[i], Offset(i * w.toDouble(), 0), Paint());
        }
        final image = await recorder.endRecording().toImage(
          w * frames.length,
          h,
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes!.buffer.asUint8List();
      });
      File(out).writeAsBytesSync(strip!);
    }
  });

  testWidgets('an incoming message pushes the list up as it grows in', (
    tester,
  ) async {
    final chat = await _pumpChat(tester, GlobalKey());
    chat.receive('Синтетическое новое входящее');
    await tester.pump();
    expect(_rowHeight(tester, 'in_2'), 0);

    await tester.pump(const Duration(milliseconds: 125));
    final middle = _rowHeight(tester, 'in_2');
    await tester.pumpAndSettle();
    final full = _rowHeight(tester, 'in_2');

    expect(middle, greaterThan(0));
    expect(middle, lessThan(full));
    expect(full, greaterThan(20));
  });

  test('telegram curves start and land where they should', () {
    expect(TelegramMotion.move.transform(0), 0);
    expect(TelegramMotion.move.transform(1), 1);
    expect(TelegramMotion.horizontal(0.5), greaterThan(0.9));
    expect(TelegramMotion.reveal(0.2), closeTo(0.5, 1e-9));
    expect(TelegramMotion.reveal(0.4), 1);
  });
}
