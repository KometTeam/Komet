import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/contacts.dart';

class _PhotosApi extends Api {
  _PhotosApi(this.response);

  final Map<dynamic, dynamic>? response;

  @override
  Future<Map<dynamic, dynamic>?> sendRequestMap(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
  }) async => response;
}

void main() {
  test('photo ids come back aligned with urls', () async {
    final api = _PhotosApi({
      'total': 3,
      'urls': <dynamic>['https://example.test/a', 'https://example.test/b'],
      'ids': <dynamic>[111, 222],
    });

    final photos = await ContactsModule.fetchPhotos(api, 501);

    expect(photos.urls, ['https://example.test/a', 'https://example.test/b']);
    expect(photos.ids, [111, 222]);
    expect(photos.idAt(1), 222);
    expect(photos.idAt(5), isNull);
    expect(photos.total, 3);
  });

  test('misaligned ids are dropped instead of shifting photos', () async {
    final api = _PhotosApi({
      'total': 2,
      'urls': <dynamic>['https://example.test/a', 'https://example.test/b'],
      'ids': <dynamic>[111],
    });

    final photos = await ContactsModule.fetchPhotos(api, 502);

    expect(photos.urls.length, 2);
    expect(photos.ids, isEmpty);
    expect(photos.idAt(0), isNull);
  });

  test('a response without ids still lists photos', () async {
    final api = _PhotosApi({
      'total': 1,
      'urls': <dynamic>['https://example.test/a'],
    });

    final photos = await ContactsModule.fetchPhotos(api, 503);

    expect(photos.urls.length, 1);
    expect(photos.ids, isEmpty);
  });
}
