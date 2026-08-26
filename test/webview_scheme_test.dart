import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/links/max_link.dart';
import 'package:komet/core/utils/link_opener.dart';

void main() {
  group('leavesWebView', () {
    test('keeps page navigation inside the web view', () {
      for (final scheme in [
        'http',
        'https',
        'HTTPS',
        'about',
        'data',
        'blob',
      ]) {
        expect(leavesWebView(scheme), isFalse, reason: scheme);
      }
    });

    test('hands app schemes over to the app', () {
      for (final scheme in ['max', 'MAX', 'komet', 'tel', 'mailto', 'intent']) {
        expect(leavesWebView(scheme), isTrue, reason: scheme);
      }
    });

    test('treats a missing scheme as in-page', () {
      expect(leavesWebView(null), isFalse);
      expect(leavesWebView(''), isFalse);
    });
  });

  test('a max deep link from a web view resolves to in-app content', () {
    expect(MaxLink.parse('max://max.ru/somechannel'), isA<MaxContentLink>());
    expect(MaxLink.isMaxLink('max://max.ru/?cid=424242'), isTrue);
  });
}
