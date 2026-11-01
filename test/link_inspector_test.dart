import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/links/link_inspector.dart';
import 'package:komet/core/links/punycode.dart';

List<LinkWarningKind> _kinds(LinkInspection inspection) => [
  for (final warning in inspection.warnings) warning.kind,
];

String _flaggedText(LinkInspection inspection) {
  final indices = inspection.flagged.toList()..sort();
  return String.fromCharCodes([
    for (final i in indices) inspection.address.codeUnitAt(i),
  ]);
}

void main() {
  group('punycode', () {
    test('decodes the RFC 3492 Russian sample', () {
      expect(
        decodePunycodeLabel('xn--b1abfaaepdrnnbgefbadotcwatmq2g4l'),
        'почемужеонинеговорятпорусски',
      );
    });

    test('decodes a whole host and keeps ASCII labels', () {
      expect(decodePunycodeHost('xn--d1abbgf6aiiy.xn--p1ai'), 'президент.рф');
      expect(decodePunycodeHost('www.example.com'), 'www.example.com');
    });

    test('rejects garbage', () {
      expect(decodePunycodeLabel('xn--'), isNull);
      expect(decodePunycodeLabel('xn--abж'), isNull);
    });
  });

  group('linkWithScheme', () {
    test('adds https only where the scheme is missing', () {
      expect(linkWithScheme('example.test/a'), 'https://example.test/a');
      expect(linkWithScheme(' example.test '), 'https://example.test');
      expect(
        linkWithScheme('example.test:8080/a'),
        'https://example.test:8080/a',
      );
      expect(linkWithScheme('//example.test'), 'https://example.test');
      expect(linkWithScheme('http://example.test'), 'http://example.test');
      expect(
        linkWithScheme('mailto:someone@example.test'),
        'mailto:someone@example.test',
      );
      expect(linkWithScheme('tel:+70000000000'), 'tel:+70000000000');
      expect(linkWithScheme('tel:80000000000'), 'tel:80000000000');
      expect(linkWithScheme('geo:55.75,37.61'), 'geo:55.75,37.61');
      expect(linkWithScheme('sms:900'), 'sms:900');
      expect(linkWithScheme('192.0.2.10:8080'), 'https://192.0.2.10:8080');
    });
  });

  group('inspectLink', () {
    test('a bare domain is inspected as a site', () {
      final inspection = inspectLink('burm\u0430ld\u0430.test');
      expect(inspection.host, 'burm\u0430ld\u0430.test');
      expect(_kinds(inspection), [LinkWarningKind.mixedScripts]);
    });

    test('an ordinary link is clean', () {
      final inspection = inspectLink('https://www.example.com/path?q=1');
      expect(inspection.suspicious, isFalse);
      expect(inspection.host, 'www.example.com');
      expect(
        inspection.address.substring(inspection.hostStart, inspection.hostEnd),
        'www.example.com',
      );
    });

    test('a whole-Cyrillic site under a Cyrillic zone is clean', () {
      expect(inspectLink('https://пример.рф/').suspicious, isFalse);
      expect(inspectLink('https://яндекс.example').suspicious, isFalse);
    });

    test('Latin with accents is not a mix', () {
      expect(inspectLink('https://café.example').suspicious, isFalse);
    });

    test('one Cyrillic letter among Latin is flagged', () {
      final inspection = inspectLink('https://exаmple.test/a');
      expect(_kinds(inspection), [LinkWarningKind.mixedScripts]);
      final warning = inspection.warnings.single;
      expect(warning.letters, [(letter: 'а', script: LinkScript.cyrillic)]);
      expect(_flaggedText(inspection), 'а');
    });

    test('the minority script is the one highlighted', () {
      final inspection = inspectLink('https://приmер.test');
      final warning = inspection.warnings.single;
      expect(warning.kind, LinkWarningKind.mixedScripts);
      expect(warning.letters.single.script, LinkScript.latin);
      expect(_flaggedText(inspection), 'm');
    });

    test('a Cyrillic label that only looks Latin is flagged', () {
      final inspection = inspectLink('https://раураӏ.com');
      expect(_kinds(inspection), [LinkWarningKind.lookalikeScript]);
      expect(_flaggedText(inspection), 'раураӏ');
    });

    test('punycode alone is shown decoded, not flagged', () {
      final inspection = inspectLink('https://xn--d1abbgf6aiiy.xn--p1ai/');
      expect(inspection.host, 'президент.рф');
      expect(inspection.address, 'https://президент.рф/');
      expect(inspection.suspicious, isFalse);
    });

    test('a forgery hidden in punycode is still caught', () {
      final inspection = inspectLink('http://xn--burmld-6nfc.test');
      expect(inspection.host, 'burm\u0430ld\u0430.test');
      expect(_kinds(inspection), [LinkWarningKind.mixedScripts]);
    });

    test('user info before @ hides the real site', () {
      final inspection = inspectLink('https://bank.example@login.test/form');
      expect(_kinds(inspection), [LinkWarningKind.userInfo]);
      expect(inspection.host, 'login.test');
      expect(inspection.warnings.single.value, 'login.test');
      expect(_flaggedText(inspection), 'bank.example@');
    });

    test('invisible characters are shown and flagged', () {
      final inspection = inspectLink('https://exa​mple.test/');
      expect(_kinds(inspection), [LinkWarningKind.invisibleCharacters]);
      expect(inspection.address, contains('[U+200B]'));
      expect(_flaggedText(inspection), '[U+200B]');
    });

    test('a literal bidi override in the path is flagged', () {
      final inspection = inspectLink('https://example.test/\u202Efdp.exe');
      expect(_kinds(inspection), [LinkWarningKind.invisibleCharacters]);
      expect(inspection.address, 'https://example.test/[U+202E]fdp.exe');
    });

    test('encoded control characters stay encoded and are not flagged', () {
      const url = 'https://example.test/send?text=Hello%0AWorld%E2%80%AE';
      final inspection = inspectLink(url);
      expect(inspection.suspicious, isFalse);
      expect(inspection.address, url);
    });

    test('percent-encoded paths are shown decoded', () {
      final inspection = inspectLink(
        'https://example.test/wiki/%D0%9F%D1%80%D0%B8%D0%BC%D0%B5%D1%80',
      );
      expect(inspection.suspicious, isFalse);
      expect(inspection.address, 'https://example.test/wiki/Пример');
    });

    test('IP hosts are flagged', () {
      expect(_kinds(inspectLink('http://192.0.2.10/login')), [
        LinkWarningKind.ipAddress,
      ]);
      expect(_kinds(inspectLink('http://[2001:db8::1]/')), [
        LinkWarningKind.ipAddress,
      ]);
    });

    test('unusual schemes are flagged, mail and phone are not', () {
      expect(_kinds(inspectLink('intent://scan/#Intent;end')), [
        LinkWarningKind.unusualScheme,
      ]);
      expect(_kinds(inspectLink('javascript:void(0)')), [
        LinkWarningKind.unusualScheme,
      ]);
      expect(inspectLink('mailto:someone@example.test').suspicious, isFalse);
      expect(inspectLink('tel:+70000000000').suspicious, isFalse);
      expect(inspectLink('geo:55.75,37.61').suspicious, isFalse);
      expect(_kinds(inspectLink('sms:900')), [LinkWarningKind.unusualScheme]);
    });

    test('link text naming another site is a mismatch', () {
      final inspection = inspectLink(
        'https://login.test/form',
        shownText: 'https://bank.example',
      );
      expect(_kinds(inspection), [LinkWarningKind.textMismatch]);
      expect(inspection.warnings.single.value, 'bank.example');
    });

    test('link text matching the site or its subdomain is fine', () {
      for (final shown in [
        'example.test',
        'www.example.test/other',
        'Example.Test',
        'Click here',
        'docs v1.2',
      ]) {
        expect(
          inspectLink(
            'https://login.example.test/path',
            shownText: shown,
          ).suspicious,
          isFalse,
          reason: shown,
        );
      }
    });
  });
}
