import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/stories.dart';
import 'package:komet/core/protocol/opcode_map.dart';

void main() {
  test('story delete sends the story ids as a list', () {
    expect(StoriesModule.deletePayload(const [137908807]), {
      'storyIds': [137908807],
    });
  });

  test('several stories go in one request', () {
    expect(StoriesModule.deletePayload(const [1, 2, 3]), {
      'storyIds': [1, 2, 3],
    });
  });

  test('story delete uses opcode 218', () {
    expect(Opcode.storiesDelete, 218);
  });
}
