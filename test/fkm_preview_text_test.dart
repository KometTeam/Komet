import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/push/fkm_controller.dart';

Map<String, dynamic> _forward(Map<String, dynamic> original) => {
  'id': 2,
  'sender': 303,
  'text': '',
  'link': {'type': 'FORWARD', 'chatId': 404, 'message': original},
};

void main() {
  test('a plain message shows its own text', () {
    expect(
      FkmController.previewText({'text': '  Synthetic text  '}),
      'Synthetic text',
    );
    expect(
      FkmController.previewText({
        'text': '',
        'attaches': [
          {'_type': 'PHOTO'},
        ],
      }),
      'Изображение',
    );
  });

  test('a forwarded message shows what was forwarded', () {
    expect(
      FkmController.previewText(_forward({'text': 'Synthetic forwarded'})),
      '↪ Synthetic forwarded',
    );
    expect(
      FkmController.previewText(
        _forward({
          'text': '',
          'attaches': [
            {'_type': 'AUDIO'},
          ],
        }),
      ),
      '↪ Голосовое сообщение',
    );
    expect(
      FkmController.previewText(_forward({'text': ''})),
      '↪ Пересланное сообщение',
    );
  });

  test('a reply keeps its own text, not the quoted one', () {
    expect(
      FkmController.previewText({
        'text': 'Synthetic answer',
        'link': {
          'type': 'REPLY',
          'message': {'text': 'Synthetic question'},
        },
      }),
      'Synthetic answer',
    );
  });

  test('a message with nothing to show falls back to the placeholder', () {
    expect(FkmController.previewText({'text': ''}), 'Новое сообщение');
  });
}
