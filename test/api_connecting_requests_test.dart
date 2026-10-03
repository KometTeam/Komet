import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/core/protocol/opcode_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Object?> _failureOf(Future<Object?> request) async {
  try {
    await request;
    return null;
  } catch (error) {
    return error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('без подключения запрос отклоняется сразу', () async {
    final api = Api();
    addTearDown(api.dispose);

    final failure = await _failureOf(
      api.sendRequest(Opcode.contactPhotos, const {}),
    );

    expect(failure, isA<StateError>());
    expect((failure as StateError).message, contains('CONTACT_PHOTOS'));
  });

  test('запрос во время подключения ждёт сессию, а не падает', () async {
    final api = Api();
    addTearDown(api.dispose);

    unawaited(api.connect());
    expect(api.state, SessionState.connecting);

    var settled = false;
    final failure = _failureOf(
      api.sendRequest(Opcode.contactPhotos, const {}),
    ).whenComplete(() => settled = true);

    await Future<void>.microtask(() {});
    expect(settled, isFalse);

    await api.disconnect();

    final error = await failure;
    expect(error, isA<StateError>());
    expect((error as StateError).message, isNot(contains('CONTACT_PHOTOS')));
  });
}
