import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/models/chat_folder.dart';
import 'package:komet/frontend/screens/chats/folder_edit_sheet.dart';
import 'package:komet/frontend/widgets/sheet_helpers.dart';

Future<void> _openSheet(WidgetTester tester, {ChatFolder? folder}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFolderEditSheet(context, folder: folder),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -600));
  await tester.pump(const Duration(milliseconds: 300));
}

SheetButton _button(WidgetTester tester, String label) =>
    tester.widget<SheetButton>(
      find.byWidgetPredicate((w) => w is SheetButton && w.label == label),
    );

void main() {
  testWidgets('the create layout shows every picker section', (tester) async {
    await _openSheet(tester);

    expect(find.text('Новая папка'), findsOneWidget);
    expect(find.text('Название папки'), findsOneWidget);
    expect(find.text('0/20'), findsOneWidget);
    expect(find.text('ТИПЫ ЧАТОВ'), findsOneWidget);
    expect(find.text('Контакты'), findsOneWidget);
    expect(find.text('Не в контактах'), findsOneWidget);
    expect(find.text('Группы'), findsOneWidget);
    expect(find.text('Каналы'), findsOneWidget);
    expect(find.text('Боты'), findsOneWidget);

    await _scrollToBottom(tester);
    expect(find.text('ПОКАЗЫВАТЬ ТОЛЬКО'), findsOneWidget);
    expect(find.text('Чаты с уведомлениями'), findsOneWidget);
    expect(find.text('Непрочитанные чаты'), findsOneWidget);
    expect(find.text('Очистить выбор'), findsOneWidget);
    expect(find.text('Создать папку'), findsOneWidget);
  });

  testWidgets('creating needs both a name and a selection', (tester) async {
    await _openSheet(tester);

    expect(_button(tester, 'Создать папку').onTap, isNull);
    expect(_button(tester, 'Очистить выбор').onTap, isNull);

    await tester.enterText(find.byType(TextField).first, 'Работа');
    await tester.pump();
    expect(_button(tester, 'Создать папку').onTap, isNull);
    expect(find.text('6/20'), findsOneWidget);

    await tester.tap(find.text('Каналы'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_button(tester, 'Создать папку').onTap, isNotNull);
    expect(_button(tester, 'Очистить выбор').onTap, isNotNull);

    await tester.tap(find.text('Очистить выбор'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_button(tester, 'Создать папку').onTap, isNull);
  });

  testWidgets('the edit layout preloads the folder and offers delete', (
    tester,
  ) async {
    await _openSheet(
      tester,
      folder: const ChatFolder(
        id: 'synthetic-folder',
        title: 'Каналы',
        filters: [FolderFilter.channel, FolderFilter.unread],
      ),
    );

    expect(find.text('Изменение папки'), findsOneWidget);
    expect(find.text('6/20'), findsOneWidget);
    expect(find.text('Удалить папку'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(_button(tester, 'Сохранить').onTap, isNotNull);
    expect(_button(tester, 'Удалить папку').onTap, isNotNull);

    await _scrollToBottom(tester);
    final unreadSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(unreadSwitch.value, isTrue);
  });

  testWidgets('a folder the server locks cannot be deleted', (tester) async {
    await _openSheet(
      tester,
      folder: const ChatFolder(
        id: 'synthetic-system-folder',
        title: 'Каналы',
        options: [FolderOption.noDelete],
      ),
    );

    expect(_button(tester, 'Удалить папку').onTap, isNull);
  });
}
