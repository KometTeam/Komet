import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:komet_crypto/komet_crypto.dart';

import '../../backend/modules/messages.dart';
import '../storage/app_database.dart';
import '../storage/token_storage.dart';
import '../utils/logger.dart';

// #***! сквозное шифрование диалогов: identity-ключ, хендшейк сообщениями, рэтчет в C-ядре
enum E2eePhase { none, offered, pendingConsent, established, keyChanged }

// #***! перенесённая сессия ждёт DH-шага, иначе оба устройства дадут один ключ
class E2eeAwaitingPeer implements Exception {
  const E2eeAwaitingPeer();
}

const String kE2eeOfferPrefix =
    '🔐 Komet: запрос сквозного шифрования. Откройте этот чат в Komet, чтобы принять.';
const String kE2eeAnswerPrefix = '🔐 Komet: сквозное шифрование включено.';
const String kE2eeOfferDonePrefix = '🔐 Komet: запрос сквозного шифрования.';

@immutable
class E2eeSessionInfo {
  final E2eePhase phase;
  final int peerId;
  final Uint8List? peerPublic;
  final bool verified;
  final String? offerText;
  final String? offerMessageId;

  const E2eeSessionInfo({
    required this.phase,
    required this.peerId,
    this.peerPublic,
    this.verified = false,
    this.offerText,
    this.offerMessageId,
  });

  bool get needsAttention =>
      phase == E2eePhase.pendingConsent || phase == E2eePhase.keyChanged;

  // #***! keyChanged это живая сессия, выключить значит уронить чат в открытый текст
  bool get hasSession =>
      phase == E2eePhase.established || phase == E2eePhase.keyChanged;

  E2eeSessionInfo copyWith({
    E2eePhase? phase,
    int? peerId,
    Uint8List? peerPublic,
    bool? verified,
    String? offerText,
    bool clearOffer = false,
    String? offerMessageId,
  }) => E2eeSessionInfo(
    phase: phase ?? this.phase,
    peerId: peerId ?? this.peerId,
    peerPublic: peerPublic ?? this.peerPublic,
    verified: verified ?? this.verified,
    offerText: clearOffer ? null : (offerText ?? this.offerText),
    offerMessageId: offerMessageId ?? this.offerMessageId,
  );
}

class E2eeService {
  E2eeService._();

  static final E2eeService instance = E2eeService._();

  static const int _exportMemoryKib = 65536;
  static const int _exportPasses = 3;

  // #***! фазы по чатам для синхронных проверок, состояния рэтчета грузим лениво
  final ValueNotifier<int> revision = ValueNotifier(0);
  final Map<String, E2eeSessionInfo> _info = {};
  final Map<String, Uint8List> _states = {};
  final Map<String, Future<void>> _chains = {};
  final Set<int> _loaded = {};
  final Map<int, Uint8List> _identities = {};
  final Map<int, Uint8List> _localKeys = {};
  MessagesModule? _messages;

  bool get available => KometCrypto.isAvailable;

  void attach(MessagesModule messages) => _messages = messages;

  String _key(int accountId, int chatId) => '$accountId/$chatId';

  Future<void> ensureLoaded(int accountId) async {
    if (accountId == 0 || !_loaded.add(accountId)) return;
    try {
      final rows = await AppDatabase.loadE2eeSessions(accountId);
      for (final row in rows) {
        _info[_key(accountId, row['chat_id'] as int)] = _infoFromRow(row);
      }
      revision.value++;
    } catch (e) {
      _loaded.remove(accountId);
      logger.w('e2ee load: $e');
    }
  }

  E2eeSessionInfo? info(int accountId, int chatId) =>
      _info[_key(accountId, chatId)];

  E2eePhase phaseOf(int accountId, int chatId) =>
      info(accountId, chatId)?.phase ?? E2eePhase.none;

  bool isActive(int accountId, int chatId) =>
      info(accountId, chatId)?.hasSession ?? false;

  bool isOn(int accountId, int chatId) =>
      phaseOf(accountId, chatId) != E2eePhase.none;

  E2eeSessionInfo _infoFromRow(Map<String, dynamic> row) => E2eeSessionInfo(
    phase: E2eePhase.values.firstWhere(
      (phase) => phase.name == row['phase'],
      orElse: () => E2eePhase.none,
    ),
    peerId: row['peer_id'] as int,
    peerPublic: row['peer_public'] is Uint8List
        ? row['peer_public'] as Uint8List
        : null,
    verified: row['verified'] == 1,
    offerText: row['offer_text'] as String?,
    offerMessageId: row['offer_message_id'] as String?,
  );

  // #***! операции по одному чату строго по очереди, состояние рэтчета мутирует
  Future<T> _serial<T>(String key, Future<T> Function() body) {
    final previous = _chains[key] ?? Future<void>.value();
    final next = previous.then((_) => body());
    _chains[key] = next.then((_) {}, onError: (_) {});
    return next;
  }

  final Map<String, Future<Uint8List>> _secretsInFlight = {};

  // #***! схлопываем вывод, две гонки дадут два ключа и запечатанное не откроется
  Future<Uint8List> _secureBytes(String key, Uint8List Function() create) {
    final running = _secretsInFlight[key];
    if (running != null) return running;
    final future = _createSecret(key, create);
    _secretsInFlight[key] = future;
    return future.whenComplete(() => _secretsInFlight.remove(key));
  }

  Future<Uint8List> _createSecret(
    String key,
    Uint8List Function() create,
  ) async {
    final stored = await TokenStorage.readSecure(key);
    if (stored != null && stored.isNotEmpty) return base64Decode(stored);
    final created = create();
    await TokenStorage.writeSecure(key, base64Encode(created));
    return created;
  }

  // #***! отдаём копию, lock() затирает кэш и посреди операции
  Future<Uint8List> identity(int accountId) async {
    final cached = _identities[accountId];
    if (cached != null) return Uint8List.fromList(cached);
    final identity = await _secureBytes(
      'e2ee_identity_$accountId',
      () => KometCrypto.identityCreate(),
    );
    _identities[accountId] = identity;
    return Uint8List.fromList(identity);
  }

  Future<Uint8List> identityPublic(int accountId) async =>
      KometCrypto.identityPublicKey(await identity(accountId));

  Future<Uint8List> _localKey(int accountId) async {
    final cached = _localKeys[accountId];
    if (cached != null) return Uint8List.fromList(cached);
    final key = await _secureBytes(
      'e2ee_local_$accountId',
      () => KometCrypto.randomBytes(KometCryptoSizes.localKey),
    );
    _localKeys[accountId] = key;
    return Uint8List.fromList(key);
  }

  Uint8List _aad(String kind, int accountId, int chatId) =>
      Uint8List.fromList(utf8.encode('$kind/$accountId/$chatId'));

  Future<Uint8List> sealBytes(
    int accountId,
    int chatId,
    Uint8List plaintext,
  ) async => KometCrypto.localSeal(
    key: await _localKey(accountId),
    plaintext: plaintext,
    aad: _aad('text', accountId, chatId),
  );

  Future<Uint8List> sealText(int accountId, int chatId, String text) =>
      sealBytes(accountId, chatId, Uint8List.fromList(utf8.encode(text)));

  Future<Uint8List?> openBytes(
    int accountId,
    int chatId,
    Uint8List sealed,
  ) async {
    try {
      return KometCrypto.localOpen(
        key: await _localKey(accountId),
        blob: sealed,
        aad: _aad('text', accountId, chatId),
      );
    } catch (e) {
      logger.w('e2ee local open: $e');
      return null;
    }
  }

  Future<String?> openText(int accountId, int chatId, Uint8List sealed) async {
    final bytes = await openBytes(accountId, chatId, sealed);
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }

  Future<Uint8List?> _state(int accountId, int chatId) async {
    final key = _key(accountId, chatId);
    final cached = _states[key];
    if (cached != null) return Uint8List.fromList(cached);
    final row = await AppDatabase.loadE2eeSession(accountId, chatId);
    final sealed = row?['state'];
    if (sealed is! Uint8List) return null;
    try {
      final state = KometCrypto.localOpen(
        key: await _localKey(accountId),
        blob: sealed,
        aad: _aad('session', accountId, chatId),
      );
      _states[key] = state;
      return Uint8List.fromList(state);
    } catch (e) {
      logger.w('e2ee session open: $e');
      return null;
    }
  }

  Future<void> _persist(
    int accountId,
    int chatId,
    E2eeSessionInfo info, {
    required Uint8List? state,
  }) async {
    final key = _key(accountId, chatId);
    Uint8List? sealed;
    if (state != null) {
      sealed = KometCrypto.localSeal(
        key: await _localKey(accountId),
        plaintext: state,
        aad: _aad('session', accountId, chatId),
      );
    }
    await AppDatabase.saveE2eeSession({
      'account_id': accountId,
      'chat_id': chatId,
      'peer_id': info.peerId,
      'phase': info.phase.name,
      'state': sealed,
      'peer_public': info.peerPublic,
      'verified': info.verified ? 1 : 0,
      'offer_text': info.offerText,
      'offer_message_id': info.offerMessageId,
      'updated': DateTime.now().millisecondsSinceEpoch,
    });
    if (state != null) {
      _states[key] = state;
    } else {
      _states.remove(key);
    }
    final previous = _info[key];
    _info[key] = info;
    if (previous?.phase != info.phase ||
        previous?.verified != info.verified ||
        previous?.offerText != info.offerText) {
      revision.value++;
    }
  }

  // #***! сессию выбрасываем, личность собеседника и отметку проверки помним
  Future<void> _forget(int accountId, int chatId) async {
    final key = _key(accountId, chatId);
    final current = _info[key];
    final state = _states.remove(key);
    if (state != null) KometCrypto.wipe(state);
    if (current?.peerPublic == null) {
      await AppDatabase.deleteE2eeSession(accountId, chatId);
      _info.remove(key);
      revision.value++;
      return;
    }
    await _persist(
      accountId,
      chatId,
      E2eeSessionInfo(
        phase: E2eePhase.none,
        peerId: current!.peerId,
        peerPublic: current.peerPublic,
        verified: current.verified,
      ),
      state: null,
    );
  }

  bool _samePeer(E2eeSessionInfo? previous, Uint8List peerPublic) =>
      previous?.peerPublic != null &&
      listEquals(previous!.peerPublic, peerPublic);

  bool _carryVerified(E2eeSessionInfo? previous, Uint8List peerPublic) =>
      _samePeer(previous, peerPublic) && (previous?.verified ?? false);

  // #***! мы предлагаем шифрование: OFFER уходит обычным сообщением
  Future<bool> startOffer({
    required int accountId,
    required int chatId,
    required int peerId,
  }) => _serial(_key(accountId, chatId), () async {
    final messages = _messages;
    if (messages == null || !available) return false;
    await ensureLoaded(accountId);
    try {
      final offer = KometCrypto.sessionOffer(
        identity: await identity(accountId),
        chatId: chatId,
        myId: accountId,
        peerId: peerId,
      );
      final messageId = await messages.sendMessage(
        accountId,
        chatId,
        '$kE2eeOfferPrefix\n${offer.text}',
      );
      if (messageId.isEmpty) return false;
      final previous = info(accountId, chatId);
      await _persist(
        accountId,
        chatId,
        E2eeSessionInfo(
          phase: E2eePhase.offered,
          peerId: peerId,
          peerPublic: previous?.peerPublic,
          verified: previous?.verified ?? false,
          offerMessageId: messageId,
        ),
        state: offer.pending,
      );
      return true;
    } catch (e) {
      logger.w('e2ee offer: $e');
      return false;
    }
  });

  // #***! собеседник предложил, мы согласились: ANSWER и сессия установлена
  Future<bool> acceptOffer({required int accountId, required int chatId}) =>
      _serial(_key(accountId, chatId), () => _answer(accountId, chatId));

  Future<bool> _answer(int accountId, int chatId) async {
    final messages = _messages;
    final current = info(accountId, chatId);
    final offerText = current?.offerText;
    if (messages == null || current == null || offerText == null) return false;
    try {
      final hadSession =
          current.phase == E2eePhase.established ||
          current.phase == E2eePhase.keyChanged;
      final answer = KometCrypto.sessionAnswer(
        identity: await identity(accountId),
        chatId: chatId,
        myId: accountId,
        peerId: current.peerId,
        offerText: offerText,
        oldState: hadSession ? await _state(accountId, chatId) : null,
      );
      final messageId = await messages.sendMessage(
        accountId,
        chatId,
        '$kE2eeAnswerPrefix\n${answer.text}',
      );
      if (messageId.isEmpty) return false;
      final peek = KometCrypto.handshakePeek(offerText);
      await _persist(
        accountId,
        chatId,
        E2eeSessionInfo(
          phase: E2eePhase.established,
          peerId: current.peerId,
          peerPublic: peek.publicKey,
          verified: _carryVerified(current, peek.publicKey),
        ),
        state: answer.state,
      );
      return true;
    } catch (e) {
      logger.w('e2ee answer: $e');
      return false;
    }
  }

  Future<void> declineOffer({required int accountId, required int chatId}) =>
      _serial(_key(accountId, chatId), () async {
        final current = info(accountId, chatId);
        if (current == null) return;
        if (current.phase == E2eePhase.keyChanged) {
          await _persist(
            accountId,
            chatId,
            current.copyWith(phase: E2eePhase.established, clearOffer: true),
            state: await _state(accountId, chatId),
          );
          return;
        }
        await _forget(accountId, chatId);
      });

  Future<void> resetSession({required int accountId, required int chatId}) =>
      _serial(_key(accountId, chatId), () => _forget(accountId, chatId));

  Future<void> setVerified({
    required int accountId,
    required int chatId,
    required bool verified,
  }) => _serial(_key(accountId, chatId), () async {
    final current = info(accountId, chatId);
    if (current == null) return;
    await _persist(
      accountId,
      chatId,
      current.copyWith(verified: verified),
      state: await _state(accountId, chatId),
    );
  });

  // #***! в keyChanged ключ мог и не меняться, а разницу показать надо
  bool offerChangesPeer(int accountId, int chatId) {
    final current = info(accountId, chatId);
    final offer = current?.offerText;
    final known = current?.peerPublic;
    if (offer == null || known == null) return true;
    try {
      return !listEquals(KometCrypto.handshakePeek(offer).publicKey, known);
    } on KometCryptoException {
      return true;
    }
  }

  Future<String?> fingerprint(int accountId, int chatId) async {
    final current = info(accountId, chatId);
    final peerPublic = current?.peerPublic;
    if (current == null || peerPublic == null) return null;
    try {
      return KometCrypto.fingerprint(
        myId: accountId,
        myPublic: await identityPublic(accountId),
        peerId: current.peerId,
        peerPublic: peerPublic,
      );
    } catch (e) {
      logger.w('e2ee fingerprint: $e');
      return null;
    }
  }

  // #***! исходящее: рэтчет шагает, состояние сразу в базу
  Future<String?> encryptText(int accountId, int chatId, String text) =>
      encryptBytes(
        accountId,
        chatId,
        ContentType.text,
        Uint8List.fromList(utf8.encode(text)),
      );

  Future<String?> encryptBytes(
    int accountId,
    int chatId,
    ContentType contentType,
    Uint8List plaintext,
  ) => _serial(_key(accountId, chatId), () async {
    final current = info(accountId, chatId);
    if (current == null || !current.hasSession) return null;
    final state = await _state(accountId, chatId);
    if (state == null) return null;
    try {
      final result = KometCrypto.sessionEncrypt(
        state: state,
        contentType: contentType,
        plaintext: plaintext,
      );
      await _persist(accountId, chatId, current, state: result.state);
      return result.text;
    } on KometCryptoException catch (e) {
      logger.w('e2ee encrypt: ${e.status.name_}');
      if (e.status == CryptoStatus.awaitingPeer) {
        throw const E2eeAwaitingPeer();
      }
      return null;
    }
  });

  bool fitsTransport(int plaintextBytes) =>
      plaintextBytes <= KometCryptoSizes.sessionPlaintextMax;

  // #***! входящее: хендшейки двигают фазу, шифртекст расшифровывается один раз
  Future<CachedMessage> inspect(
    CachedMessage message, {
    Future<void> Function(CachedMessage message)? commit,
  }) async {
    final text = message.text;
    if (!available || text == null || text.isEmpty) return message;
    if (message.senderId == 0 || message.senderId == message.accountId) {
      return message;
    }
    await ensureLoaded(message.accountId);
    switch (KometCrypto.classifyText(text)) {
      case TextClass.offer:
        await _serial(
          _key(message.accountId, message.chatId),
          () => _onOffer(message, text),
        );
        return message;
      case TextClass.answer:
        await _serial(
          _key(message.accountId, message.chatId),
          () => _onAnswer(message, text),
        );
        return message;
      case TextClass.session:
        return _serial(
          _key(message.accountId, message.chatId),
          () => _decryptIncoming(message, text, commit),
        );
      case TextClass.legacy:
        // #***! каждый 32-й legacy похож на v2 по длине, решает тег а не длина
        if (isActive(message.accountId, message.chatId)) {
          return _serial(
            _key(message.accountId, message.chatId),
            () => _decryptIncoming(message, text, commit),
          );
        }
        return message;
      case TextClass.none:
        return message;
    }
  }

  Future<bool> _isDialog(int accountId, int chatId) async {
    final rows = await AppDatabase.loadChat(accountId, chatId);
    if (rows.isEmpty) return false;
    final type = rows.first['type']?.toString() ?? 'DIALOG';
    return type == 'DIALOG';
  }

  Future<void> _onOffer(CachedMessage message, String text) async {
    final accountId = message.accountId;
    final chatId = message.chatId;
    if (!await _isDialog(accountId, chatId)) return;
    final HandshakePeek peek;
    try {
      peek = KometCrypto.handshakePeek(text);
    } on KometCryptoException {
      return;
    }
    final current = info(accountId, chatId);
    final peerId = message.senderId;
    switch (current?.phase) {
      case E2eePhase.established:
        final samePeer = _samePeer(current, peek.publicKey);
        // #***! повтор старого OFFER выглядит так же, живую сессию только со спросом
        await _persist(
          accountId,
          chatId,
          current!.copyWith(
            phase: E2eePhase.keyChanged,
            peerId: peerId,
            offerText: text,
            verified: samePeer && current.verified,
          ),
          state: await _state(accountId, chatId),
        );
      case E2eePhase.offered:
        if (peerId < accountId) {
          await _persist(
            accountId,
            chatId,
            E2eeSessionInfo(
              phase: E2eePhase.pendingConsent,
              peerId: peerId,
              offerText: text,
            ),
            state: null,
          );
          await _answer(accountId, chatId);
        }
      case E2eePhase.keyChanged:
      case E2eePhase.pendingConsent:
      case E2eePhase.none:
      case null:
        await _persist(
          accountId,
          chatId,
          (current ?? E2eeSessionInfo(phase: E2eePhase.none, peerId: peerId))
              .copyWith(
                phase: current?.phase == E2eePhase.keyChanged
                    ? E2eePhase.keyChanged
                    : E2eePhase.pendingConsent,
                peerId: peerId,
                offerText: text,
                verified: _carryVerified(current, peek.publicKey),
              ),
          state: current?.phase == E2eePhase.keyChanged
              ? await _state(accountId, chatId)
              : null,
        );
    }
  }

  Future<void> _onAnswer(CachedMessage message, String text) async {
    final accountId = message.accountId;
    final chatId = message.chatId;
    final current = info(accountId, chatId);
    if (current == null || current.phase != E2eePhase.offered) return;
    if (current.peerId != message.senderId) return;
    final pending = await _state(accountId, chatId);
    if (pending == null) return;
    final peek = KometCrypto.handshakePeek(text);
    try {
      final state = KometCrypto.sessionAccept(
        identity: await identity(accountId),
        pending: pending,
        answerText: text,
        expectedPeer: current.peerPublic,
      );
      await _persist(
        accountId,
        chatId,
        E2eeSessionInfo(
          phase: E2eePhase.established,
          peerId: current.peerId,
          peerPublic: peek.publicKey,
          verified: _carryVerified(current, peek.publicKey),
          offerMessageId: current.offerMessageId,
        ),
        state: state,
      );
      final offerMessageId = current.offerMessageId;
      final messages = _messages;
      if (offerMessageId != null && messages != null) {
        unawaited(
          messages
              .editMessage(chatId, offerMessageId, text: kE2eeOfferDonePrefix)
              .catchError((_) => false),
        );
      }
    } on KometCryptoException catch (e) {
      logger.w('e2ee accept: ${e.status.name_}');
      // #***! ответил не тот, кого мы знали: спрашиваем пользователя, а не молча меняем пира
      if (e.status == CryptoStatus.badPeer) {
        await _persist(
          accountId,
          chatId,
          current.copyWith(
            phase: E2eePhase.keyChanged,
            verified: false,
            clearOffer: true,
          ),
          state: null,
        );
      }
    }
  }

  Future<CachedMessage> _decryptIncoming(
    CachedMessage message,
    String text,
    Future<void> Function(CachedMessage message)? commit,
  ) async {
    final accountId = message.accountId;
    final chatId = message.chatId;
    final current = info(accountId, chatId);
    if (current == null || !current.hasSession) {
      return message;
    }
    final state = await _state(accountId, chatId);
    if (state == null) return message;
    try {
      final result = KometCrypto.sessionDecrypt(state: state, text: text);
      final decrypted = switch (result.contentType) {
        ContentType.text => message.copyWith(
          sealedText: await sealBytes(accountId, chatId, result.plaintext),
          e2ee: CachedMessage.e2eeText,
        ),
        ContentType.file => message.copyWith(
          sealedText: await sealBytes(accountId, chatId, result.plaintext),
          e2ee: CachedMessage.e2eeFile,
        ),
        ContentType.control => message.copyWith(e2ee: CachedMessage.e2eeFailed),
      };
      // #***! текст на диск раньше состояния рэтчета, ключ сообщения уже потрачен
      if (commit != null) await commit(decrypted);
      await _persist(accountId, chatId, current, state: result.state);
      return decrypted;
    } on KometCryptoException catch (e) {
      switch (e.status) {
        case CryptoStatus.notEncrypted:
        case CryptoStatus.handshakeMessage:
          return message;
        default:
          logger.w('e2ee decrypt ${message.id}: ${e.status.name_}');
          return message.copyWith(e2ee: CachedMessage.e2eeFailed);
      }
    }
  }

  // #***! история: уже расшифрованное не трогаем, новое расшифровываем по порядку
  Future<List<CachedMessage>> inspectHistory(
    int accountId,
    int chatId,
    List<CachedMessage> messages,
  ) async {
    if (!available || messages.isEmpty) return messages;
    await ensureLoaded(accountId);
    if (!isOn(accountId, chatId)) return messages;
    final existing = <String, Map<String, dynamic>>{};
    for (final row in await AppDatabase.loadMessagesByIds(
      accountId,
      chatId,
      messages.map((m) => m.id).toList(),
    )) {
      existing[row['id'].toString()] = row;
    }
    final ordered = [...messages]..sort((a, b) => a.time.compareTo(b.time));
    final result = <String, CachedMessage>{};
    for (final message in ordered) {
      final row = existing[message.id];
      if (row != null && (row['e2ee'] as int? ?? 0) != CachedMessage.e2eeNone) {
        result[message.id] = message.copyWith(
          sealedText: row['text_sealed'] is Uint8List
              ? row['text_sealed'] as Uint8List
              : null,
          e2ee: row['e2ee'] as int,
        );
        continue;
      }
      if (row != null && message.senderId != accountId) {
        result[message.id] = message;
        continue;
      }
      result[message.id] = await inspect(
        message,
        commit: (decrypted) => AppDatabase.saveMessages([decrypted.toDbRow()]),
      );
    }
    return messages.map((m) => result[m.id] ?? m).toList();
  }

  // #***! новый identity-ключ: все сессии сбрасываются, собеседники увидят смену ключа
  Future<bool> rotateIdentity(int accountId) async {
    await ensureLoaded(accountId);
    final chats = <int>[];
    for (final key in _info.keys) {
      if (key.startsWith('$accountId/')) {
        chats.add(int.parse(key.split('/').last));
      }
    }
    for (final chatId in chats) {
      await _serial(_key(accountId, chatId), () async {
        final current = info(accountId, chatId);
        final state = _states.remove(_key(accountId, chatId));
        if (state != null) KometCrypto.wipe(state);
        if (current == null) return;
        await _persist(
          accountId,
          chatId,
          E2eeSessionInfo(
            phase: E2eePhase.none,
            peerId: current.peerId,
            peerPublic: current.peerPublic,
          ),
          state: null,
        );
      });
    }
    final previous = _identities.remove(accountId);
    if (previous != null) KometCrypto.wipe(previous);
    try {
      final identity = KometCrypto.identityCreate();
      await TokenStorage.writeSecure(
        'e2ee_identity_$accountId',
        base64Encode(identity),
      );
      _identities[accountId] = identity;
      revision.value++;
      return true;
    } on KometCryptoException catch (e) {
      logger.w('e2ee rotate identity: ${e.status.name_}');
      return false;
    }
  }

  // #***! ушли в фон или сменили аккаунт, секреты из памяти вон
  void lock() {
    for (final state in _states.values) {
      KometCrypto.wipe(state);
    }
    _states.clear();
    for (final identity in _identities.values) {
      KometCrypto.wipe(identity);
    }
    _identities.clear();
    for (final key in _localKeys.values) {
      KometCrypto.wipe(key);
    }
    _localKeys.clear();
  }

  void forgetAccount(int accountId) {
    lock();
    _info.removeWhere((key, _) => key.startsWith('$accountId/'));
    _loaded.remove(accountId);
    revision.value++;
  }

  // #***! без этого ключи и сессии переживают удаление аккаунта
  Future<void> eraseAccount(int accountId) async {
    forgetAccount(accountId);
    _identities.remove(accountId);
    _localKeys.remove(accountId);
    for (final key in ['e2ee_identity_$accountId', 'e2ee_local_$accountId']) {
      try {
        await TokenStorage.deleteSecure(key);
      } catch (e) {
        logger.w('e2ee erase $key: $e');
      }
    }
    try {
      for (final row in await AppDatabase.loadE2eeSessions(accountId)) {
        await AppDatabase.deleteE2eeSession(accountId, row['chat_id'] as int);
      }
    } catch (e) {
      logger.w('e2ee erase sessions: $e');
    }
  }

  // #***! перенос на другое устройство: identity и сессии одним паролем
  Future<Uint8List?> exportTransfer(int accountId, String password) async {
    await ensureLoaded(accountId);
    final items = <Uint8List>[await identity(accountId)];
    final exported = <int>[];
    for (final entry in _info.entries) {
      if (!entry.key.startsWith('$accountId/')) continue;
      if (!entry.value.hasSession) continue;
      final chatId = int.parse(entry.key.split('/').last);
      final state = await _state(accountId, chatId);
      if (state != null) {
        items.add(state);
        exported.add(chatId);
      }
    }
    final container = BytesBuilder(copy: false);
    container.add(_be32(items.length));
    for (final item in items) {
      container.add(_be32(item.length));
      container.add(item);
    }
    final Uint8List blob;
    final payload = container.toBytes();
    final secret = Uint8List.fromList(utf8.encode(password));
    final library = KometCrypto.libraryPath;
    try {
      blob = await Isolate.run(() {
        KometCrypto.libraryPath = library;
        return KometCrypto.exportSeal(
          password: secret,
          memoryKib: _exportMemoryKib,
          passes: _exportPasses,
          container: payload,
        );
      });
    } on KometCryptoException catch (e) {
      logger.w('e2ee export: ${e.status.name_}');
      return null;
    }
    // #***! источник отключаем сразу, две копии сессии шлют под одним ключом
    for (final chatId in exported) {
      await _serial(_key(accountId, chatId), () => _forget(accountId, chatId));
    }
    return blob;
  }

  Future<int?> importTransfer(
    int accountId,
    Uint8List blob,
    String password,
  ) async {
    final Uint8List container;
    final secret = Uint8List.fromList(utf8.encode(password));
    final library = KometCrypto.libraryPath;
    try {
      container = await Isolate.run(() {
        KometCrypto.libraryPath = library;
        return KometCrypto.exportOpen(password: secret, blob: blob);
      });
    } on KometCryptoException catch (e) {
      logger.w('e2ee import: ${e.status.name_}');
      return null;
    }
    final items = <Uint8List>[];
    var offset = 4;
    final count = _readBe32(container, 0);
    for (var index = 0; index < count && offset + 4 <= container.length; index++) {
      final length = _readBe32(container, offset);
      offset += 4;
      if (offset + length > container.length) return null;
      items.add(Uint8List.sublistView(container, offset, offset + length));
      offset += length;
    }
    if (items.isEmpty || items.first.length != KometCryptoSizes.identity) {
      return null;
    }
    lock();
    await TokenStorage.writeSecure(
      'e2ee_identity_$accountId',
      base64Encode(items.first),
    );
    await ensureLoaded(accountId);
    var imported = 0;
    for (final state in items.skip(1)) {
      if (state.length < 66) continue;
      final chatId = _readBe64(state, 2);
      final myId = _readBe64(state, 10);
      final peerId = _readBe64(state, 18);
      if (myId != accountId) continue;
      final peerPublic = Uint8List.fromList(
        Uint8List.sublistView(state, 34, 66),
      );
      await _persist(
        accountId,
        chatId,
        E2eeSessionInfo(
          phase: E2eePhase.established,
          peerId: peerId,
          peerPublic: peerPublic,
          verified: _carryVerified(info(accountId, chatId), peerPublic),
        ),
        state: Uint8List.fromList(state),
      );
      imported++;
    }
    return imported;
  }

  static Uint8List _be32(int value) => Uint8List(4)
    ..[0] = (value >> 24) & 0xff
    ..[1] = (value >> 16) & 0xff
    ..[2] = (value >> 8) & 0xff
    ..[3] = value & 0xff;

  static int _readBe32(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  static int _readBe64(Uint8List bytes, int offset) {
    var value = 0;
    for (var index = 0; index < 8; index++) {
      value = (value << 8) | bytes[offset + index];
    }
    return value;
  }
}
