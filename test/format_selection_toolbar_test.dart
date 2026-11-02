import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/widgets/format_selection_toolbar.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';
import 'package:komet/frontend/widgets/selection_toolbar.dart';
import 'package:komet/l10n/app_localizations.dart';

const _text = 'первое слово и второе слово';
const _keyboard = 300.0;
const _formatting = 'Форматирование';
const _bold = 'Жирный';
const _link = 'Ссылка';
const _replyKey = ValueKey('reply');
const _floorKey = ValueKey('floor');

final _android = TargetPlatformVariant.only(TargetPlatform.android);

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, this.floored = false});

  final RichMessageController controller;
  final bool floored;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      maxLines: 4,
      contextMenuBuilder: (_, state) =>
          FormatSelectionToolbar(controller: controller, editableState: state),
    );
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            const Spacer(),
            if (floored)
              SelectionToolbarFloor(
                child: Column(
                  key: _floorKey,
                  children: [
                    const SizedBox(key: _replyKey, height: 56),
                    field,
                  ],
                ),
              )
            else
              field,
          ],
        ),
      ),
    );
  }
}

Future<RichMessageController> _openComposer(
  WidgetTester tester, {
  double width = 393,
  double keyboard = 0,
  String text = _text,
  bool floored = false,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 800)
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final controller = RichMessageController(text: text);
  addTearDown(controller.dispose);
  await tester.pumpWidget(_Composer(controller: controller, floored: floored));
  await tester.showKeyboard(find.byType(TextField));
  return controller;
}

Future<void> _showToolbar(
  WidgetTester tester,
  RichMessageController controller,
  TextSelection selection,
) async {
  controller.selection = selection;
  await tester.pump();
  expect(_editable(tester).showToolbar(), isTrue);
  await tester.pumpAndSettle();
}

Future<void> _hideToolbar(WidgetTester tester) async {
  _editable(tester).hideToolbar();
  await tester.pumpAndSettle();
}

EditableTextState _editable(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText));

MaterialLocalizations _material(WidgetTester tester) =>
    MaterialLocalizations.of(tester.element(find.byType(TextField)));

Rect _toolbarRect(WidgetTester tester) =>
    tester.getRect(find.byType(SelectionToolbarSurface));

Future<void> _tapTooltip(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

const _firstWord = TextSelection(baseOffset: 0, extentOffset: 6);
const _lastWord = TextSelection(baseOffset: 22, extentOffset: 27);

void main() {
  testWidgets('opens on the text actions with an entry to formatting', (
    tester,
  ) async {
    final controller = await _openComposer(tester, width: 800);
    await _showToolbar(tester, controller, _firstWord);

    expect(find.byTooltip(_formatting), findsOneWidget);
    expect(find.text(_material(tester).copyButtonLabel), findsOneWidget);
    expect(find.byTooltip(_bold), findsNothing);
  }, variant: _android);

  testWidgets('formats in place and keeps the toolbar open', (tester) async {
    final controller = await _openComposer(tester);
    await _showToolbar(tester, controller, _firstWord);
    await _tapTooltip(tester, _formatting);
    await _tapTooltip(tester, _bold);

    expect(controller.isFormatActive(TextFormat.strong), isTrue);
    expect(find.byTooltip(_bold), findsOneWidget);

    await _tapTooltip(tester, _bold);
    expect(controller.isFormatActive(TextFormat.strong), isFalse);
  }, variant: _android);

  testWidgets('back returns to the text actions', (tester) async {
    final controller = await _openComposer(tester);
    await _showToolbar(tester, controller, _firstWord);
    await _tapTooltip(tester, _formatting);
    await _tapTooltip(tester, _material(tester).backButtonTooltip);

    expect(find.byTooltip(_formatting), findsOneWidget);
    expect(find.byTooltip(_bold), findsNothing);
  }, variant: _android);

  testWidgets('stays one row high above the keyboard on every page', (
    tester,
  ) async {
    final controller = await _openComposer(
      tester,
      width: 320,
      keyboard: _keyboard,
    );
    await _showToolbar(tester, controller, _firstWord);
    final visibleBottom = 800 - _keyboard;
    final textTop = tester.getRect(find.byType(EditableText)).top;

    void expectAboveKeyboard() {
      final rect = _toolbarRect(tester);
      expect(rect.height, SelectionToolbarStyle.height);
      expect(rect.bottom, lessThanOrEqualTo(textTop));
      expect(rect.bottom, lessThanOrEqualTo(visibleBottom));
      expect(
        rect.left,
        greaterThanOrEqualTo(SelectionToolbarStyle.screenMargin),
      );
      expect(
        rect.right,
        lessThanOrEqualTo(320 - SelectionToolbarStyle.screenMargin),
      );
    }

    expectAboveKeyboard();
    await _tapTooltip(tester, _formatting);
    expectAboveKeyboard();
    await _tapTooltip(tester, _material(tester).moreButtonTooltip);
    expectAboveKeyboard();
  }, variant: _android);

  testWidgets('pages a row that does not fit and keeps a wide one whole', (
    tester,
  ) async {
    final narrow = await _openComposer(tester, width: 320);
    await _showToolbar(tester, narrow, _firstWord);
    await _tapTooltip(tester, _formatting);

    expect(find.byTooltip(_link), findsNothing);
    await _tapTooltip(tester, _material(tester).moreButtonTooltip);
    expect(find.byTooltip(_link), findsOneWidget);
    expect(find.byTooltip(_bold), findsNothing);
    await _hideToolbar(tester);

    final wide = await _openComposer(tester, width: 412);
    await _showToolbar(tester, wide, _lastWord);
    await _tapTooltip(tester, _formatting);

    expect(find.byTooltip(_bold), findsOneWidget);
    expect(find.byTooltip(_link), findsOneWidget);
    expect(find.byTooltip(_material(tester).moreButtonTooltip), findsNothing);
  }, variant: _android);

  testWidgets('returns to formatting only for the same selection', (
    tester,
  ) async {
    final controller = await _openComposer(tester);
    await _showToolbar(tester, controller, _firstWord);
    await _tapTooltip(tester, _formatting);
    await _hideToolbar(tester);

    await _showToolbar(
      tester,
      controller,
      const TextSelection(baseOffset: 0, extentOffset: 12),
    );
    expect(find.byTooltip(_bold), findsOneWidget);
    await _hideToolbar(tester);

    await _showToolbar(tester, controller, _lastWord);
    expect(find.byTooltip(_formatting), findsOneWidget);
    expect(find.byTooltip(_bold), findsNothing);
  }, variant: _android);

  testWidgets('drops formatting once the selection collapses', (tester) async {
    final controller = await _openComposer(tester);
    await _showToolbar(tester, controller, _firstWord);
    await _tapTooltip(tester, _formatting);

    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pumpAndSettle();
    expect(find.byTooltip(_bold), findsNothing);
    await _hideToolbar(tester);

    await _showToolbar(tester, controller, _firstWord);
    expect(find.byTooltip(_formatting), findsOneWidget);
  }, variant: _android);

  testWidgets('never sinks below the top of the input panel', (tester) async {
    const lines = 'один\nдва\nтри\nчетыре';
    final lastLine = TextSelection(
      baseOffset: lines.lastIndexOf('\n') + 1,
      extentOffset: lines.length,
    );
    final controller = await _openComposer(
      tester,
      text: lines,
      floored: true,
      keyboard: _keyboard,
    );
    await _showToolbar(tester, controller, lastLine);
    final floorTop = tester.getRect(find.byKey(_floorKey)).top;

    void expectAbovePanel() {
      final rect = _toolbarRect(tester);
      expect(
        rect.bottom,
        lessThanOrEqualTo(floorTop - SelectionToolbarStyle.screenMargin),
      );
      expect(rect.top, greaterThanOrEqualTo(0));
    }

    expectAbovePanel();
    expect(
      tester.getRect(find.byKey(_replyKey)).top,
      greaterThanOrEqualTo(_toolbarRect(tester).bottom),
    );
    await _tapTooltip(tester, _formatting);
    expectAbovePanel();
  }, variant: _android);

  testWidgets('opens above the input panel on a right click', (tester) async {
    final controller = await _openComposer(
      tester,
      width: 900,
      text: 'один\nдва\nтри\nчетыре',
      floored: true,
    );
    final text = tester.getRect(find.byType(EditableText));
    final click = await tester.startGesture(
      Offset(text.left + 12, text.bottom - 6),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await click.up();
    await tester.pumpAndSettle();

    final floorTop = tester.getRect(find.byKey(_floorKey)).top;
    final rect = _toolbarRect(tester);
    expect(
      rect.bottom,
      lessThanOrEqualTo(floorTop - SelectionToolbarStyle.screenMargin),
    );
    expect(rect.height, SelectionToolbarStyle.height);
    expect(controller.selection.isValid, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
