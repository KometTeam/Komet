import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/video_request_headers.dart';

const _agent = 'SyntheticAgent/1.0 (Android 14)';

Map<String, String> _headers(String url, {String? agent = _agent}) =>
    videoRequestHeaders(Uri.parse(url), sessionUserAgent: agent);

void main() {
  test('ссылки okcdn получают User-Agent сессии', () {
    expect(_headers('https://vd1.okcdn.ru/?expires=1'), {'User-Agent': _agent});
  });

  test('ссылки vkuser.net получают User-Agent сессии', () {
    expect(_headers('https://cdn-1.vkuser.net/video.mp4?expires=1'), {
      'User-Agent': _agent,
    });
  });

  test('любая ссылка с srcAg привязана к клиенту', () {
    expect(_headers('https://media.example.org/v.mp4?srcAg=UNKNOWN_ANDROID'), {
      'User-Agent': _agent,
    });
  });

  test('посторонние хосты не получают User-Agent', () {
    expect(_headers('https://media.example.org/v.mp4'), isEmpty);
    expect(_headers('https://notvkuser.net/v.mp4'), isEmpty);
  });

  test('без User-Agent сессии заголовков нет', () {
    expect(_headers('https://cdn-1.vkuser.net/v.mp4', agent: null), isEmpty);
    expect(_headers('https://cdn-1.vkuser.net/v.mp4', agent: '  '), isEmpty);
  });

  test('агент iOS-устройства не уходит в CDN целиком', () {
    const iosAgent =
        'OKMessages/26.31.0 (18.6; iPhone15,2; 420dpi 420dpi 1080x2340)';
    expect(
      _headers(
        'https://maxvd665.okcdn.ru/?srcAg=UNKNOWN_ANDROID&expires=1',
        agent: iosAgent,
      ),
      {'User-Agent': 'OKMessages/26.31.0 (Android)'},
    );
  });

  test('агент с Android уходит без изменений', () {
    const androidAgent =
        'OKMessages/26.31.0 (Android 14; Samsung Galaxy S24 Ultra; '
        'xxhdpi 450dpi 1440x3120)';
    expect(cdnUserAgent(androidAgent), androidAgent);
  });

  test('агент без продукта заменяется на OKMessages', () {
    expect(
      cdnUserAgent('(iPhone; CPU OS 18_6 like Mac OS X)'),
      'OKMessages (Android)',
    );
  });
}
