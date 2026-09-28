import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/complaints.dart';

void main() {
  test('channel complaint carries the chat id and no parentId', () {
    final payload = ComplaintsModule.complaintPayload(
      reasonId: 22,
      typeId: ComplaintsModule.channelTypeId,
      ids: const [-68562458441188],
    );
    expect(payload, {
      'reasonId': 22,
      'typeId': 2,
      'ids': [-68562458441188],
    });
    expect(payload.containsKey('parentId'), isFalse);
  });

  test('message complaint keeps the chat as parentId', () {
    final payload = ComplaintsModule.complaintPayload(
      reasonId: 3,
      typeId: 5,
      ids: const [116000000000000001],
      parentId: -68562458441188,
    );
    expect(payload, {
      'reasonId': 3,
      'typeId': 5,
      'ids': [116000000000000001],
      'parentId': -68562458441188,
    });
  });

  test('channel complaints use type 2', () {
    expect(ComplaintsModule.channelTypeId, 2);
  });
}
