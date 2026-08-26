import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/models/chat_folder.dart';
import 'package:komet/backend/modules/folders.dart';
import 'package:komet/frontend/screens/chats/folder_action_sheet.dart';

Future<void> _openSheet(WidgetTester tester, ChatFolder folder) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFolderActionSheet(context, folder: folder),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a user folder offers edit, create and delete', (tester) async {
    await _openSheet(
      tester,
      const ChatFolder(id: 'synthetic-folder', title: 'Работа'),
    );

    expect(find.text('Работа'), findsOneWidget);
    expect(find.text('Изменить'), findsOneWidget);
    expect(find.text('Новая папка'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
  });

  testWidgets('the all-chats folder can only spawn a new folder', (
    tester,
  ) async {
    await _openSheet(
      tester,
      const ChatFolder(id: FoldersModule.allChatsFolderId, title: 'Все чаты'),
    );

    expect(find.text('Изменить'), findsNothing);
    expect(find.text('Удалить'), findsNothing);
    expect(find.text('Новая папка'), findsOneWidget);
  });

  testWidgets('server options hide the forbidden actions', (tester) async {
    await _openSheet(
      tester,
      const ChatFolder(
        id: 'synthetic-system-folder',
        title: 'Каналы',
        options: [
          FolderOption.noDelete,
          FolderOption.noTitleEdit,
          FolderOption.noFiltersEdit,
        ],
      ),
    );

    expect(find.text('Изменить'), findsNothing);
    expect(find.text('Удалить'), findsNothing);
    expect(find.text('Новая папка'), findsOneWidget);
  });
}
