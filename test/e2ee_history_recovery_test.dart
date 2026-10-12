import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/crypto/e2ee_service.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet_crypto/komet_crypto.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _accountId = 101;
const _chatId = 202;
const _peerId = 303;

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

({Uint8List sender, Uint8List receiver, String offer, String answer})
_session() {
  final senderIdentity = KometCrypto.identityCreate(
    seed: Uint8List.fromList(List.filled(32, 3)),
  );
  final receiverIdentity = KometCrypto.identityCreate(
    seed: Uint8List.fromList(List.filled(32, 7)),
  );
  final offer = KometCrypto.sessionOffer(
    identity: senderIdentity,
    chatId: _chatId,
    myId: _peerId,
    peerId: _accountId,
  );
  final answer = KometCrypto.sessionAnswer(
    identity: receiverIdentity,
    chatId: _chatId,
    myId: _accountId,
    peerId: _peerId,
    offerText: offer.text,
  );
  final senderState = KometCrypto.sessionAccept(
    identity: senderIdentity,
    pending: offer.pending,
    answerText: answer.text,
  );
  return (
    sender: senderState,
    receiver: answer.state,
    offer: offer.text,
    answer: answer.text,
  );
}

CachedMessage _incoming(String id, String text, int time) => CachedMessage(
  id: id,
  accountId: _accountId,
  chatId: _chatId,
  senderId: _peerId,
  time: time,
  text: text,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final libraryPath = Platform.environment['KOMET_CRYPTO_TEST_LIB'];
  if (libraryPath != null) KometCrypto.libraryPath = libraryPath;
  final available = KometCrypto.isAvailable;
  late E2eeService service;
  late Uint8List localKey;

  Future<void> saveSession(Uint8List state) => AppDatabase.saveE2eeSession({
    'account_id': _accountId,
    'chat_id': _chatId,
    'peer_id': _peerId,
    'phase': 'established',
    'verified': 1,
    'updated': 1,
    'state': KometCrypto.localSeal(
      key: localKey,
      plaintext: state,
      aad: _bytes('session/101/202'),
    ),
  });

  group('native history recovery', () {
    setUpAll(AppDatabase.init);

    setUp(() async {
      final directory = Directory.systemTemp.createTempSync(
        'synthetic_e2ee_history',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
      localKey = Uint8List.fromList(List.filled(32, 9));
      FlutterSecureStorage.setMockInitialValues({
        'e2ee_local_101': base64Encode(localKey),
      });
      service = E2eeService();
      addTearDown(() async {
        service.forgetAccount(_accountId);
        await AppDatabase.close();
        PathProviderPlatform.instance = previousPathProvider;
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      await AppDatabase.saveProfile(
        ProfileData(
          id: _accountId,
          firstName: 'Synthetic receiver',
          phone: 100000,
          country: 'ZZ',
          accountStatus: 0,
          updateTime: 1,
        ),
      );
      await AppDatabase.saveChats([
        {
          'id': _chatId,
          'account_id': _accountId,
          'type': 'DIALOG',
          'cached_at': 1,
        },
      ]);
    });

    test(
      'recovers cached ciphertext and keeps the recovered ratchet state',
      () async {
        final pair = _session();
        final missed = KometCrypto.sessionEncrypt(
          state: pair.sender,
          contentType: ContentType.text,
          plaintext: _bytes('Synthetic missed message'),
        );
        final next = KometCrypto.sessionEncrypt(
          state: missed.state,
          contentType: ContentType.text,
          plaintext: _bytes('Synthetic next message'),
        );
        final advanced = KometCrypto.sessionDecrypt(
          state: pair.receiver,
          text: next.text,
        );
        await saveSession(advanced.state);
        final message = _incoming('synthetic-missed', missed.text, 1);
        await AppDatabase.saveMessages([message.toDbRow()]);

        final recovered = await service.inspectHistory(_accountId, _chatId, [
          message,
        ]);
        expect(recovered.single.e2ee, CachedMessage.e2eeText);
        expect(
          await service.openText(
            _accountId,
            _chatId,
            recovered.single.sealedText!,
          ),
          'Synthetic missed message',
        );
        final recoveredState = await AppDatabase.loadE2eeSession(
          _accountId,
          _chatId,
        );
        final repeated = await service.inspectHistory(_accountId, _chatId, [
          message,
        ]);
        expect(repeated.single.e2ee, CachedMessage.e2eeText);
        expect(repeated.single.sealedText, recovered.single.sealedText);
        expect(
          (await AppDatabase.loadE2eeSession(_accountId, _chatId))?['state'],
          recoveredState?['state'],
        );
        final following = KometCrypto.sessionEncrypt(
          state: next.state,
          contentType: ContentType.text,
          plaintext: _bytes('Synthetic following message'),
        );
        final decrypted = await service.inspect(
          _incoming('synthetic-following', following.text, 3),
        );
        expect(decrypted.e2ee, CachedMessage.e2eeText);
        expect(
          await service.openText(_accountId, _chatId, decrypted.sealedText!),
          'Synthetic following message',
        );
      },
    );

    test(
      'concurrent history recovery reuses the first decrypted result',
      () async {
        final pair = _session();
        final encrypted = KometCrypto.sessionEncrypt(
          state: pair.sender,
          contentType: ContentType.text,
          plaintext: _bytes('Synthetic concurrent message'),
        );
        await saveSession(pair.receiver);
        final message = _incoming('synthetic-concurrent', encrypted.text, 1);
        await AppDatabase.saveMessages([message.toDbRow()]);

        final results = await Future.wait([
          service.inspectHistory(_accountId, _chatId, [message]),
          service.inspectHistory(_accountId, _chatId, [message]),
        ]);
        expect(results.map((batch) => batch.single.e2ee), [
          CachedMessage.e2eeText,
          CachedMessage.e2eeText,
        ]);
        expect(results.first.single.sealedText, isNotNull);
        expect(results.last.single.sealedText, results.first.single.sealedText);
        final stored = await AppDatabase.loadMessagesByIds(
          _accountId,
          _chatId,
          [message.id],
        );
        expect(stored.single['e2ee'], CachedMessage.e2eeText);
        expect(stored.single['text_sealed'], results.first.single.sealedText);
      },
    );

    for (final throughHistory in [false, true]) {
      test(
        'decrypts edited ciphertext with the same id through ${throughHistory ? 'history' : 'inspect'}',
        () async {
          final pair = _session();
          await saveSession(pair.receiver);
          final original = KometCrypto.sessionEncrypt(
            state: pair.sender,
            contentType: ContentType.text,
            plaintext: _bytes('Synthetic original message'),
          );
          final message = _incoming('synthetic-edited', original.text, 1);
          final first = await service.inspect(
            message,
            commit: (decrypted) =>
                AppDatabase.saveMessages([decrypted.toDbRow()]),
          );
          expect(first.e2ee, CachedMessage.e2eeText);

          final edited = KometCrypto.sessionEncrypt(
            state: original.state,
            contentType: ContentType.text,
            plaintext: _bytes('Synthetic edited message'),
          );
          final editedMessage = _incoming('synthetic-edited', edited.text, 2);
          final recovered = throughHistory
              ? (await service.inspectHistory(_accountId, _chatId, [
                  editedMessage,
                ])).single
              : await service.inspect(
                  editedMessage,
                  commit: (decrypted) =>
                      AppDatabase.saveMessages([decrypted.toDbRow()]),
                );
          expect(recovered.e2ee, CachedMessage.e2eeText);
          expect(
            await service.openText(_accountId, _chatId, recovered.sealedText!),
            'Synthetic edited message',
          );
          final following = KometCrypto.sessionEncrypt(
            state: edited.state,
            contentType: ContentType.text,
            plaintext: _bytes('Synthetic following edit'),
          );
          final next = await service.inspect(
            _incoming('synthetic-next-edit', following.text, 3),
          );
          expect(next.e2ee, CachedMessage.e2eeText);
          expect(
            await service.openText(_accountId, _chatId, next.sealedText!),
            'Synthetic following edit',
          );
        },
      );
    }

    test(
      'preserves cached legacy ciphertext that has a session-sized envelope',
      () async {
        final pair = _session();
        await saveSession(pair.receiver);
        final legacyKey = Uint8List.fromList(List.filled(32, 11));
        final plaintext = 'Synthetic legacy payload'.padRight(58, '.');
        final ciphertext = KometCrypto.encryptMessage(plaintext, legacyKey);
        expect(KometCrypto.classifyText(ciphertext), TextClass.legacy);
        final message = _incoming('synthetic-legacy', ciphertext, 1);
        await AppDatabase.saveMessages([message.toDbRow()]);
        await service.ensureLoaded(_accountId);
        final sessionBefore = await AppDatabase.loadE2eeSession(
          _accountId,
          _chatId,
        );

        final result = await service.inspectHistory(_accountId, _chatId, [
          message,
        ]);
        expect(result.single.e2ee, CachedMessage.e2eeNone);
        expect(result.single.sealedText, isNull);
        expect(
          KometCrypto.decryptMessage(result.single.text!, legacyKey),
          plaintext,
        );
        expect(
          (await AppDatabase.loadE2eeSession(_accountId, _chatId))?['state'],
          sessionBefore?['state'],
        );
        final stored = await AppDatabase.loadMessagesByIds(
          _accountId,
          _chatId,
          [message.id],
        );
        expect(stored.single['e2ee'], CachedMessage.e2eeNone);
      },
    );

    test('keeps cached ordinary messages and handshakes unchanged', () async {
      final pair = _session();
      await saveSession(pair.receiver);
      final messages = [
        _incoming('synthetic-ordinary', 'Synthetic ordinary history', 1),
        _incoming('synthetic-offer', pair.offer, 2),
        _incoming('synthetic-answer', pair.answer, 3),
      ];
      await AppDatabase.saveMessages(messages.map((m) => m.toDbRow()).toList());
      await service.ensureLoaded(_accountId);
      final revision = service.revision.value;
      final state = await AppDatabase.loadE2eeSession(_accountId, _chatId);

      final result = await service.inspectHistory(
        _accountId,
        _chatId,
        messages,
      );
      expect(result.map((m) => m.text), messages.map((m) => m.text));
      expect(result.every((m) => m.e2ee == CachedMessage.e2eeNone), isTrue);
      expect(service.phaseOf(_accountId, _chatId), E2eePhase.established);
      expect(service.info(_accountId, _chatId)?.verified, isTrue);
      expect(service.revision.value, revision);
      expect(
        (await AppDatabase.loadE2eeSession(_accountId, _chatId))?['state'],
        state?['state'],
      );
    });
  }, skip: !available);
}
