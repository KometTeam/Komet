import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/contacts.dart';
import 'package:komet/core/contacts/contact_labels.dart';
import 'package:komet/core/storage/local_contact_avatars.dart';
import 'package:komet/core/utils/image_utils.dart';
import 'package:komet/frontend/widgets/komet_avatar.dart';
import 'package:komet/frontend/widgets/lost_account_dialog.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BlockedApi extends Api {
  final List<Completer<Map<dynamic, dynamic>?>> calls = [];

  @override
  Future<Map<dynamic, dynamic>?> sendRequestMap(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
  }) {
    final call = Completer<Map<dynamic, dynamic>?>();
    calls.add(call);
    return call.future;
  }
}

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

Map<String, Object> _blockedPage(List<int> ids) => {
  'contacts': [
    for (final id in ids) {'id': id},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contactMatchesQuery', () {
    test('matches names regardless of case', () {
      expect(
        contactMatchesQuery(
          'алис',
          title: 'Алиса Синтетическая',
          firstName: 'Алиса',
          lastName: 'Синтетическая',
          phone: 70000000001,
        ),
        isTrue,
      );
    });

    test('matches phone digits only from three digits on', () {
      bool matches(String query) => contactMatchesQuery(
        query,
        title: 'Синтетический контакт',
        phone: 70000012345,
      );

      expect(matches('+7 000 001'), isTrue);
      expect(matches('12'), isFalse);
      expect(matches('999'), isFalse);
    });

    test('an empty query keeps everyone', () {
      expect(contactMatchesQuery('  ', title: 'Кто угодно'), isTrue);
    });
  });

  group('blocked contacts', () {
    tearDown(ContactsModule.clearBlockedCache);

    test('load once and announce the change', () async {
      final api = _BlockedApi();
      final revision = ContactsModule.revision.value;

      final first = ContactsModule.ensureBlockedLoaded(api);
      final second = ContactsModule.ensureBlockedLoaded(api);
      expect(api.calls, hasLength(1));
      api.calls.single.complete(_blockedPage([7, 9]));
      await Future.wait([first, second]);

      expect(ContactsModule.blockedIds, {7, 9});
      expect(ContactsModule.revision.value, revision + 1);
      await ContactsModule.ensureBlockedLoaded(api);
      expect(api.calls, hasLength(1));
    });

    test('a list fetched for the previous account is dropped', () async {
      final api = _BlockedApi();

      final pending = ContactsModule.ensureBlockedLoaded(api);
      ContactsModule.clearBlockedCache();
      api.calls.single.complete(_blockedPage([5]));
      await pending;

      expect(ContactsModule.blockedIds, isEmpty);
    });
  });

  group('local contact avatars', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('synthetic_avatars');
      PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await LocalContactAvatars.instance.clear(42);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    test('replacing a photo removes the previous file', () async {
      final store = LocalContactAvatars.instance;
      final revision = store.revision.value;

      await store.set(42, Uint8List.fromList([1, 2, 3]));
      final first = (store.imageFor(42)! as FileImage).file;
      await store.set(42, Uint8List.fromList([4, 5, 6]));
      final second = (store.imageFor(42)! as FileImage).file;

      expect(first.existsSync(), isFalse);
      expect(second.readAsBytesSync(), [4, 5, 6]);
      expect(store.revision.value, revision + 2);

      await store.clear(42);
      expect(store.has(42), isFalse);
      expect(second.existsSync(), isFalse);
    });

    testWidgets('the avatar prefers the local photo', (tester) async {
      await tester.runAsync(
        () => LocalContactAvatars.instance.set(42, Uint8List(4)),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: KometAvatar(name: 'Синтетика', size: 40, userId: 42),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as ResizeImage).imageProvider, isA<FileImage>());
    });
  });

  test('photos are cropped to a centred square', () {
    final wide = img.Image(width: 300, height: 200);
    final huge = img.Image(width: 1200, height: 900);

    final small = img.decodeJpg(encodeSquareAvatar(img.encodePng(wide))!)!;
    final big = img.decodeJpg(encodeSquareAvatar(img.encodePng(huge))!)!;

    expect([small.width, small.height], [200, 200]);
    expect([big.width, big.height], [512, 512]);
  });

  testWidgets('a lost account offers to sign in or remove it', (tester) async {
    LostAccountChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showLostAccountDialog(context, name: 'Синтетика');
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('«Синтетика»'), findsOne);

    await tester.tap(find.text('Удалить с устройства'));
    await tester.pumpAndSettle();
    expect(choice, LostAccountChoice.remove);
  });
}
