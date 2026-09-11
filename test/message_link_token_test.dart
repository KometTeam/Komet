import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/links/max_link.dart';
import 'package:komet/core/links/message_link_token.dart';

void main() {
  final syntheticId = BigInt.parse('0102030405060708', radix: 16).toString();
  const syntheticToken = 'AQIDBAUGBwg';

  group('MessageLinkToken', () {
    test('encodes the id as eight big-endian bytes in base64url', () {
      expect(MessageLinkToken.encode(syntheticId), syntheticToken);
      expect(MessageLinkToken.encode('1'), 'AAAAAAAAAAE');
    });

    test('decodes a token back to the same id', () {
      expect(MessageLinkToken.decode(syntheticToken), syntheticId);
      expect(MessageLinkToken.decode('AAAAAAAAAAE'), '1');
    });

    test('refuses ids and tokens it cannot represent', () {
      expect(MessageLinkToken.encode('temp_1'), isNull);
      expect(MessageLinkToken.encode('0'), isNull);
      expect(MessageLinkToken.decode('AQIDBAUGBw'), isNull);
      expect(MessageLinkToken.decode('AQIDBAUGBw!'), isNull);
    });

    test('builds a link through the public name when there is one', () {
      expect(
        MessageLinkToken.messageUrl(
          chatId: -424242,
          messageId: syntheticId,
          publicLink: 'https://max.ru/somechannel/',
        ),
        'https://max.ru/somechannel/$syntheticToken',
      );
      expect(
        MessageLinkToken.messageUrl(chatId: -424242, messageId: syntheticId),
        'https://max.ru/c/-424242/$syntheticToken',
      );
    });
  });

  group('MaxLink.parse — ссылки на сообщения с токеном', () {
    test('a public post link resolves through name and token', () {
      final link =
          MaxLink.parse('https://max.ru/somechannel/$syntheticToken')
              as MaxContentLink;

      expect(link.kind, MaxContentKind.public);
      expect(link.messageId, int.parse(syntheticId));
      expect(link.baseUrl, 'https://max.ru/somechannel');
      expect(link.lookup, 'somechannel/$syntheticToken');
    });

    test('a chat post link resolves through the chat id', () {
      final link =
          MaxLink.parse('max.ru/c/-424242/$syntheticToken') as MaxContentLink;

      expect(link.kind, MaxContentKind.content);
      expect(link.messageId, int.parse(syntheticId));
      expect(link.baseUrl, 'https://max.ru/c/-424242');
      expect(link.lookup, '/c/-424242/$syntheticToken');
    });

    test('links without a message keep resolving by their url', () {
      final link = MaxLink.parse('max.ru/somechannel') as MaxContentLink;

      expect(link.lookup, 'https://max.ru/somechannel');
    });
  });
}
