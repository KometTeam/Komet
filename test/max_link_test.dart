import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/links/max_link.dart';
import 'package:komet/frontend/widgets/link_text.dart';

void main() {
  group('linkPattern', () {
    List<String> matches(String text) =>
        linkPattern.allMatches(text).map((m) => m.group(0)!).toList();

    test('picks up a bare max.ru link inside plain text', () {
      expect(
        matches('Ваша ссылка 👇\nmax.ru/id100000000001_bot?start=abc123\n'),
        ['max.ru/id100000000001_bot?start=abc123'],
      );
      expect(matches('зайди на max.ru и посмотри'), ['max.ru']);
    });

    test('still picks up schemed and www links', () {
      expect(matches('https://max.ru/somebot?start=x'), [
        'https://max.ru/somebot?start=x',
      ]);
      expect(matches('www.max.ru/somebot'), ['www.max.ru/somebot']);
    });

    test('does not match look-alike hosts or emails', () {
      expect(matches('evil.max.ru/phish'), isEmpty);
      expect(matches('max.ru.evil.com/phish'), isEmpty);
      expect(matches('bot@max.ru'), isEmpty);
      expect(matches('max.rules/somebot'), isEmpty);
    });

    test('linkTarget adds a scheme only when missing', () {
      expect(linkTarget('max.ru/somebot'), 'https://max.ru/somebot');
      expect(linkTarget('www.max.ru/somebot'), 'https://www.max.ru/somebot');
      expect(linkTarget('http://max.ru/somebot'), 'http://max.ru/somebot');
      expect(linkTarget('https://max.ru/somebot'), 'https://max.ru/somebot');
    });
  });

  group('MaxLink.parse — не наши ссылки', () {
    test('rejects other hosts and non-links', () {
      expect(MaxLink.parse('https://example.com/somebot'), isNull);
      expect(MaxLink.parse('evil.max.ru/phish'), isNull);
      expect(MaxLink.parse('mailto:bot@max.ru'), isNull);
      expect(MaxLink.parse(''), isNull);
    });

    test('rejects reserved site pages', () {
      expect(MaxLink.parse('https://max.ru/login'), isNull);
      expect(MaxLink.parse('https://max.ru/tos'), isNull);
    });
  });

  group('MaxLink.parse — контентные ссылки', () {
    test('bare host, http and www all normalize to the root link', () {
      expect(MaxLink.parse('max.ru'), isA<MaxRootLink>());
      expect(MaxLink.parse('http://max.ru/'), isA<MaxRootLink>());
      expect(MaxLink.parse('https://www.max.ru'), isA<MaxRootLink>());
      expect(MaxLink.parse('max://max.ru/'), isA<MaxRootLink>());
    });

    test('public link keeps the canonical https url', () {
      final link = MaxLink.parse('max.ru/somebot') as MaxContentLink;

      expect(link.kind, MaxContentKind.public);
      expect(link.url, 'https://max.ru/somebot');
      expect(link.baseUrl, 'https://max.ru/somebot');
      expect(link.startPayload, isNull);
      expect(link.messageId, isNull);
    });

    test('@nickname is a public link too', () {
      final link = MaxLink.parse('https://max.ru/@somebot') as MaxContentLink;

      expect(link.kind, MaxContentKind.public);
      expect(link.baseUrl, 'https://max.ru/somebot');
    });

    test('bot start payload is parsed and the base url drops it', () {
      final link =
          MaxLink.parse('http://max.ru/id100000000001_bot?start=a%20b')
              as MaxContentLink;

      expect(link.startPayload, 'a b');
      expect(link.url, 'https://max.ru/id100000000001_bot?start=a%20b');
      expect(link.baseUrl, 'https://max.ru/id100000000001_bot');
    });

    test('empty start payload is ignored', () {
      final link = MaxLink.parse('max.ru/somebot?start=') as MaxContentLink;
      expect(link.startPayload, isNull);
    });

    test('startapp opens a mini app and is cut at the first &', () {
      final link =
          MaxLink.parse('max.ru/somebot?startapp=deal%2F42&ref=x')
              as MaxWebAppLink;

      expect(link.startApp, 'deal/42');
    });

    test('message links carry the message id', () {
      final byName =
          MaxLink.parse('max.ru/somechannel/900000000000000001')
              as MaxContentLink;
      expect(byName.kind, MaxContentKind.public);
      expect(byName.messageId, 900000000000000001);
      expect(byName.baseUrl, 'https://max.ru/somechannel');

      final byId =
          MaxLink.parse('max.ru/c/424242/900000000000000001')
              as MaxContentLink;
      expect(byId.kind, MaxContentKind.content);
      expect(byId.messageId, 900000000000000001);
      expect(byId.baseUrl, 'https://max.ru/c/424242');
    });

    test('invite, call and sticker links keep their own types', () {
      expect(
        (MaxLink.parse('max.ru/join/AbCdEf') as MaxContentLink).kind,
        MaxContentKind.invite,
      );
      expect(MaxLink.parse('max.ru/joincall/AbCdEf'), isA<MaxCallLink>());
      expect(
        (MaxLink.parse('max.ru/stickerset/512-abc') as MaxStickerSetLink).path,
        'stickerset/512-abc',
      );
    });

    test('uid and cid open a contact and a chat', () {
      expect(
        (MaxLink.parse('max://max.ru/?uid=434343') as MaxContactIdLink)
            .userId,
        434343,
      );
      final chat = MaxLink.parse('max://max.ru/?cid=424242') as MaxChatIdLink;
      expect(chat.chatId, 424242);
      expect(chat.messageId, isNull);
    });
  });

  group('MaxLink.parse — внутренние маршруты', () {
    test('auth keeps the full url with its token', () {
      final link = MaxLink.parse('https://max.ru/:auth/tok3n') as MaxAuthLink;
      expect(link.url, 'https://max.ru/:auth/tok3n');
    });

    test('share and share-self-out are separate targets', () {
      final share =
          MaxLink.parse('https://max.ru/:share?text=%D0%BF%D1%80%D0%B8%D0%B2')
              as MaxShareTextLink;
      expect(share.text, 'прив');
      expect(
        MaxLink.parse('https://max.ru/:share-self-out'),
        isA<MaxShareSelfLink>(),
      );
    });

    test('folder needs an id, otherwise it stays a plain route', () {
      expect(
        (MaxLink.parse('max.ru/:folder?id=42') as MaxFolderLink).folderId,
        '42',
      );
      expect(MaxLink.parse('max.ru/:folder'), isA<MaxRouteLink>());
    });

    test('current is a no-op target', () {
      expect(MaxLink.parse('max.ru/:current'), isA<MaxCurrentLink>());
    });

    test('other routes keep their path and query params', () {
      final route =
          MaxLink.parse('max://max.ru/:profile?id=123&type=CHAT')
              as MaxRouteLink;

      expect(route.route, ':profile');
      expect(route.params, {'id': '123', 'type': 'CHAT'});

      final nested =
          MaxLink.parse('https://max.ru/:Settings/Appearance') as MaxRouteLink;
      expect(nested.route, ':settings/appearance');
    });
  });
}
