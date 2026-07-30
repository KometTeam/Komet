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

    test('a bare link is parsed as a max link once normalized', () {
      final link = MaxLink.parse(linkTarget('max.ru/somebot?start=abc123'));

      expect(link!.kind, MaxLinkKind.public);
      expect(link.startPayload, 'abc123');
    });
  });

  group('MaxLink start payload', () {
    test('parses a bot start link over http', () {
      final link = MaxLink.parse('http://max.ru/id100000000001bot?start=abc123');

      expect(link, isNotNull);
      expect(link!.kind, MaxLinkKind.public);
      expect(link.startPayload, 'abc123');
      expect(link.baseUrl, 'https://max.ru/id100000000001bot');
      expect(link.url, 'http://max.ru/id100000000001bot?start=abc123');
    });

    test('decodes the payload and ignores a trailing fragment', () {
      final link = MaxLink.parse(
        'https://www.max.ru/somebot?start=a%20b&ref=x#top',
      );

      expect(link!.startPayload, 'a b');
      expect(link.baseUrl, 'https://max.ru/somebot');
    });

    test('keeps the payload empty for links without one', () {
      expect(MaxLink.parse('https://max.ru/somebot')!.startPayload, isNull);
      expect(
        MaxLink.parse('https://max.ru/somebot?start=')!.startPayload,
        isNull,
      );
      expect(
        MaxLink.parse('https://max.ru/somebot?other=1')!.startPayload,
        isNull,
      );
    });

    test('leaves other link kinds untouched', () {
      final invite = MaxLink.parse('https://max.ru/join/AbCdEf?start=x');

      expect(invite!.kind, MaxLinkKind.invite);
      expect(invite.startPayload, isNull);
      expect(invite.baseUrl, invite.url);
    });

    test('still rejects non-max links', () {
      expect(MaxLink.parse('https://example.com/somebot?start=x'), isNull);
      expect(MaxLink.parse('https://max.ru/?start=x'), isNull);
    });
  });
}
