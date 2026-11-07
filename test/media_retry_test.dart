import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/screens/chats/chat/chat_controller.dart';
import 'package:komet/frontend/screens/chats/chat/chat_media_send_controller.dart';
import 'package:komet/frontend/screens/chats/chat/upload_status.dart';
import 'package:komet/models/attachment.dart';

const int _me = 101;
const int _chatId = 303;

CachedMessage _failed(
  List<MessageAttachment> attachments, {
  String status = 'error',
  int e2ee = CachedMessage.e2eeNone,
}) => CachedMessage(
  id: 'temp_1_1',
  accountId: _me,
  chatId: _chatId,
  senderId: _me,
  time: 1700000000000,
  status: status,
  attachments: attachments,
  e2ee: e2ee,
);

void main() {
  final chat = ChatController()
    ..myId = _me
    ..chatId = _chatId;
  final media = ChatMediaSendController(
    chatController: chat,
    showAttachmentPanel: ValueNotifier(false),
    uploadStatus: ValueNotifier(const UploadStatus()),
    bumpMessages: () {},
    scrollToBottom: () {},
    setLastSentId: (_) {},
    notify: (_) {},
    isMounted: () => true,
    encryptionEnabled: () => false,
    encryptOutgoing: (text, {notify = true}) async => text,
    confirmSend: () async => true,
    markHasScheduled: () {},
    takeReply: () => null,
  );

  test('media with its source on the device can be sent again', () {
    expect(
      media.canRetry(_failed([const PhotoAttachment(localPath: '/tmp/a.jpg')])),
      isTrue,
    );
    expect(
      media.canRetry(
        _failed([
          const VideoAttachment(videoType: 1, localPath: '/tmp/note.mp4'),
        ]),
      ),
      isTrue,
    );
    expect(
      media.canRetry(_failed([const AudioAttachment(localPath: '/tmp/v.ogg')])),
      isTrue,
    );
    expect(
      media.canRetry(
        _failed([const FileAttachment(localPath: '/tmp/doc.pdf')]),
      ),
      isTrue,
    );
  });

  test('a file already on the server is sent again by its id', () {
    expect(media.canRetry(_failed([const FileAttachment(fileId: 7)])), isTrue);
  });

  test('stickers, contacts and places are rebuilt from the attachment', () {
    expect(
      media.canRetry(_failed([const StickerAttachment(stickerId: '12')])),
      isTrue,
    );
    expect(
      media.canRetry(_failed([const ContactAttachment(contactId: 900301)])),
      isTrue,
    );
    expect(
      media.canRetry(
        _failed([const LocationAttachment(latitude: 55.7, longitude: 37.6)]),
      ),
      isTrue,
    );
  });

  test('nothing to send again is not offered', () {
    expect(media.canRetry(_failed([const AudioAttachment()])), isFalse);
    expect(media.canRetry(_failed([const FileAttachment()])), isFalse);
    expect(
      media.canRetry(
        _failed([
          const PhotoAttachment(localPath: '/tmp/a.jpg'),
          const PhotoAttachment(),
        ]),
      ),
      isFalse,
    );
    expect(media.canRetry(_failed(const [])), isFalse);
  });

  test('only failed unencrypted messages are offered', () {
    const photo = PhotoAttachment(localPath: '/tmp/a.jpg');
    expect(media.canRetry(_failed([photo], status: 'sending')), isFalse);
    expect(media.canRetry(_failed([photo], status: 'sent')), isFalse);
    expect(
      media.canRetry(_failed([photo], e2ee: CachedMessage.e2eeFile)),
      isFalse,
    );
  });
}
