import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/contacts.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String directory;

  _SyntheticPathProvider(this.directory);

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

CachedMessage _contactMessage({
  required String id,
  required int contactId,
  required String firstName,
  required String lastName,
}) {
  return CachedMessage(
    id: id,
    accountId: 1,
    chatId: 2,
    senderId: 3,
    text: '',
    time: DateTime(2026, 1, 2, 5, 46).millisecondsSinceEpoch,
    attachments: [
      ContactAttachment(
        contactId: contactId,
        firstName: firstName,
        lastName: lastName,
        name: '$firstName $lastName',
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('contact bubble shows profile and contextual contact action', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_contact_bubble_test',
    );
    addTearDown(() async {
      await AppDatabase.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);

    await tester.runAsync(() async {
      await AppDatabase.init();
      await AppDatabase.saveProfile(
        ProfileData(
          id: 1,
          firstName: 'Synthetic owner',
          phone: 100000,
          country: 'ZZ',
          accountStatus: 0,
          updateTime: 1,
        ),
      );
      await AppDatabase.saveContacts([
        {
          'id': 77,
          'account_id': 1,
          'first_name': 'Existing',
          'last_name': 'Contact',
          'phone': 100001,
          'photo_id': null,
          'base_url': null,
          'base_raw_url': null,
          'update_time': 1,
          'options': '',
        },
      ]);
      expect(await ContactsModule.getContact(1, 77), isNotNull);
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MessageBubble(
                message: _contactMessage(
                  id: 'synthetic-existing-message',
                  contactId: 77,
                  firstName: 'Existing',
                  lastName: 'Contact',
                ),
                isMe: false,
                myId: 1,
                chatType: 'DIALOG',
              ),
              MessageBubble(
                message: _contactMessage(
                  id: 'synthetic-new-message',
                  contactId: 88,
                  firstName: 'New',
                  lastName: 'Contact',
                ),
                isMe: false,
                myId: 1,
                chatType: 'DIALOG',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Existing Contact'), findsOneWidget);
    expect(find.text('Уже твой контакт'), findsOneWidget);
    expect(find.text('New Contact'), findsOneWidget);
    expect(find.text('Новый контакт'), findsOneWidget);
    expect(find.byKey(const ValueKey('contact-add-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contact-profile-button')),
      findsNWidgets(2),
    );
    expect(find.text('05:46'), findsNWidgets(2));
    expect(
      tester.getSize(find.byKey(const ValueKey('contact-card')).first).width,
      320,
    );
  });
}
