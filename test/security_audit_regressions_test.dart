import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komet/core/crypto/message_decryption_cache.dart';
import 'package:komet/core/storage/per_chat_json_store.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/core/crypto/noise_png.dart';
import 'package:komet/core/plugins/plugin_network_policy.dart';
import 'package:komet/core/plugins/plugin_storage.dart';
import 'package:komet/frontend/screens/webapp/web_app_origin_policy.dart';

class _GuardedApi extends Api {
  int dispatched = 0;
  Future<void>? gate;
  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
    void Function()? beforeSend,
  }) async {
    await gate;
    beforeSend?.call();
    dispatched++;
    return Packet(cmd: CmdType.ok, payload: const {});
  }
}

class _SyntheticSettings extends PerChatJsonStore<bool> {
  _SyntheticSettings()
    : super(
        prefsKey: 'synthetic_chat_settings',
        fromJson: (v) => v == true ? true : null,
        toJson: (v) => v,
      );
  bool enabled(int accountId, int chatId) => read(accountId, chatId) == true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('concurrent settings consumers await the same load', () async {
    SharedPreferences.setMockInitialValues({
      'synthetic_chat_settings': '{"101/201":true}',
    });
    final settings = _SyntheticSettings();
    final first = settings.load();
    final second = settings.load();
    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    expect(settings.enabled(101, 201), isTrue);
  });
  test('every media dispatch and upload URL honors the final guard', () async {
    final api = _GuardedApi();
    final sender = MessagesModule(api);
    void reject() => throw StateError('synthetic account change');
    for (final action in <Future<Object?> Function()>[
      () => sender.sendFileMessage(201, 301, beforeSend: reject),
      () => sender.sendPhotoMessage(201, ['synthetic'], beforeSend: reject),
      () => sender.sendVideoMessage(201, 'synthetic', beforeSend: reject),
      () => sender.sendAudioMessage(
        201,
        'synthetic',
        duration: 1,
        wave: Uint8List(1),
        beforeSend: reject,
      ),
      () => sender.sendVideoNoteMessage(
        201,
        'synthetic',
        duration: 1,
        beforeSend: reject,
      ),
      () => sender.sendStickerMessage(201, 301, beforeSend: reject),
      () => sender.sendContactMessage(201, 301, beforeSend: reject),
      () => sender.sendLocationMessage(201, 1, 1, beforeSend: reject),
      () => sender.sendPollMessage(201, 'Synthetic', [
        'A',
        'B',
      ], beforeSend: reject),
      () => sender.requestUploadUrl(beforeSend: reject),
      () => sender.requestPhotoUploadUrl(beforeSend: reject),
      () => sender.requestVideoUploadUrl(beforeSend: reject),
      () => sender.requestAudioUploadUrl(beforeSend: reject),
      () => sender.requestVideoNoteUploadUrl(beforeSend: reject),
    ]) {
      await expectLater(action(), throwsStateError);
    }
    expect(api.dispatched, 0);
  });
  test('rejects oversized RGB dimensions before inflating', () {
    final png = Uint8List(33)..setAll(0, [137, 80, 78, 71, 13, 10, 26, 10]);
    final data = ByteData.sublistView(png)..setUint32(8, 13);
    png.setAll(12, 'IHDR'.codeUnits);
    data.setUint32(16, 16384);
    data.setUint32(20, 16384);
    png[24] = 8;
    png[25] = 2;
    expect(unwrapNoisePng(png), isNull);
  });
  test('re-decrypts edits and separates accounts and chats', () async {
    final cache = MessageDecryptionCache.forTesting(
      (a, c, id, text) async => MessageDecryption.decrypted('$a/$c/$text'),
    );
    Future<MessageDecryption?> resolve(int a, int c, String text) =>
        cache.resolve(
          accountId: a,
          chatId: c,
          messageId: 'synthetic',
          cipherText: text,
        );
    expect((await resolve(101, 201, 'first'))?.plaintext, '101/201/first');
    expect((await resolve(101, 201, 'edit'))?.plaintext, '101/201/edit');
    expect((await resolve(102, 201, 'first'))?.plaintext, '102/201/first');
    expect((await resolve(101, 202, 'first'))?.plaintext, '101/202/first');
  });
  test('clear notifies listeners and rejects late decryption', () async {
    final pending = Completer<MessageDecryption?>();
    final cache = MessageDecryptionCache.forTesting(
      (a, c, id, text) => pending.future,
    );
    final listener = cache.listenableFor(
      'synthetic',
      accountId: 101,
      chatId: 201,
    );
    cache.seed(
      'synthetic',
      'local',
      accountId: 101,
      chatId: 201,
      cipherText: 'old',
    );
    expect(listener.value?.plaintext, 'local');
    var changed = 0;
    listener.addListener(() => changed++);
    cache.clear();
    expect(listener.value, isNull);
    expect(changed, 1);
    final job = cache.resolve(
      accountId: 101,
      chatId: 201,
      messageId: 'synthetic',
      cipherText: 'new',
    );
    cache.clear();
    pending.complete(const MessageDecryption.decrypted('stale'));
    expect(await job, isNull);
    expect(listener.value, isNull);
  });
  test('an empty edit clears the old plaintext', () async {
    final cache = MessageDecryptionCache.forTesting(
      (a, c, id, text) async => MessageDecryption.decrypted(text),
    );
    await cache.resolve(
      accountId: 101,
      chatId: 201,
      messageId: 'synthetic',
      cipherText: 'old',
    );
    expect(
      await cache.resolve(
        accountId: 101,
        chatId: 201,
        messageId: 'synthetic',
        cipherText: '',
      ),
      isNull,
    );
    expect(
      cache.listenableFor('synthetic', accountId: 101, chatId: 201).value,
      isNull,
    );
  });
  test('an older edit cannot overwrite the latest decryption', () async {
    final old = Completer<MessageDecryption?>(),
        fresh = Completer<MessageDecryption?>();
    final cache = MessageDecryptionCache.forTesting(
      (a, c, id, text) => text == 'old' ? old.future : fresh.future,
    );
    final a = cache.resolve(
      accountId: 101,
      chatId: 201,
      messageId: 'synthetic',
      cipherText: 'old',
    );
    final b = cache.resolve(
      accountId: 101,
      chatId: 201,
      messageId: 'synthetic',
      cipherText: 'fresh',
    );
    fresh.complete(const MessageDecryption.decrypted('fresh result'));
    expect((await b)?.plaintext, 'fresh result');
    old.complete(const MessageDecryption.decrypted('stale result'));
    await a;
    expect(
      cache
          .listenableFor('synthetic', accountId: 101, chatId: 201)
          .value
          ?.plaintext,
      'fresh result',
    );
  });
  test('plugin storage serializes mutations across instances', () async {
    SharedPreferences.setMockInitialValues({});
    final a = PluginStorage('synthetic.plugin'),
        b = PluginStorage('synthetic.plugin');
    await Future.wait([a.set('a', 1), b.set('b', 2), a.set('nullable', null)]);
    expect(await a.get('a'), 1);
    expect(await b.get('b'), 2);
    await b.remove('nullable');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('plugin_storage_v1_synthetic.plugin'),
      isNot(contains('nullable')),
    );
    await Future.wait([a.clear(), b.set('after', 3)]);
    expect(await a.get('a'), isNull);
    expect(await a.get('after'), 3);
  });
  test('a failed storage mutation does not block following writes', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PluginStorage('synthetic.plugin');
    await expectLater(
      storage.set('too-large', 'я' * 40000),
      throwsFormatException,
    );
    await storage.set('small', 1);
    expect(await storage.get('small'), 1);
  });
  test('plugin DNS policy rejects private, mixed and mapped addresses', () {
    for (final ips in [
      ['127.0.0.1'],
      ['10.1.2.3'],
      ['192.168.1.2'],
      ['::1'],
      ['fc00::1'],
      ['::ffff:127.0.0.1'],
      ['::ffff:192.168.1.1'],
      ['100.64.0.1'],
      ['93.184.216.34', '10.1.2.3'],
      <String>[],
    ]) {
      expect(
        () => PluginNetworkPolicy.validateAddresses(
          ips.map(InternetAddress.new).toList(),
        ),
        throwsFormatException,
        reason: '$ips',
      );
    }
    expect(
      () => PluginNetworkPolicy.validateAddresses([
        InternetAddress('93.184.216.34'),
      ]),
      returnsNormally,
    );
  });
  test(
    'a host resolving to loopback is rejected before a socket opens',
    () async {
      final original = HttpOverrides.current;
      HttpOverrides.global = null;
      var lookups = 0;
      final client = PluginNetworkPolicy.createClient(
        lookup: (host) async {
          lookups++;
          return [InternetAddress('127.0.0.1')];
        },
      );
      try {
        await expectLater(
          client.getUrl(Uri.parse('https://synthetic.example.invalid/')),
          throwsFormatException,
        );
        expect(lookups, 1);
      } finally {
        client.close(force: true);
        HttpOverrides.global = original;
      }
    },
  );
  test(
    'socket connects to the validated IP rather than resolving host again',
    () async {
      final original = HttpOverrides.current;
      HttpOverrides.global = null;
      final addresses = <Object>[];
      try {
        await IOOverrides.runZoned(
          () async {
            final client = PluginNetworkPolicy.createClient(
              lookup: (host) async => [InternetAddress('93.184.216.34')],
            );
            try {
              await expectLater(
                client.getUrl(Uri.parse('https://synthetic.example.invalid/')),
                throwsA(isA<SocketException>()),
              );
            } finally {
              client.close(force: true);
            }
          },
          socketStartConnect: (host, port, {sourceAddress, sourcePort = 0}) {
            addresses.add(host as Object);
            throw const SocketException('synthetic connection');
          },
        );
        expect(addresses, hasLength(1));
        expect(addresses.single, isA<InternetAddress>());
        expect((addresses.single as InternetAddress).address, '93.184.216.34');
      } finally {
        HttpOverrides.global = original;
      }
    },
  );
  test('mini-app bridge refuses plain http origins', () {
    for (final url in [
      'http://mini.example.invalid/start',
      'http://127.0.0.1:8080/',
      'ftp://mini.example.invalid/',
    ]) {
      expect(() => WebAppOriginPolicy(url), throwsFormatException);
    }
  });

  test('mini-app origin requires exact host, scheme, port and main frame', () {
    final policy = WebAppOriginPolicy('https://mini.example.invalid/start');
    expect(
      policy.accepts(Uri.parse('https://mini.example.invalid/next')),
      isTrue,
    );
    for (final url in [
      'https://mini.example.invalid.evil.invalid/',
      'http://mini.example.invalid/',
      'https://mini.example.invalid:8443/',
      'about:blank',
    ]) {
      expect(policy.accepts(Uri.parse(url)), isFalse);
    }
    expect(
      policy.accepts(
        Uri.parse('https://mini.example.invalid/'),
        isMainFrame: false,
      ),
      isFalse,
    );
    expect(
      RegExp(
        policy.patterns.single,
      ).hasMatch('https://mini.example.invalid.evil.invalid'),
      isFalse,
    );
  });
}
