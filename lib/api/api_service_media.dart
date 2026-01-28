part of 'api_service.dart';

extension ApiServiceMedia on ApiService {
  Future<void> sendVoiceMessage(
    int chatId, {
    required String localPath,
    int? senderId,
    int? cidOverride,
    int maxNotReadyRetries = 6,
  }) async {
    await waitUntilOnline();

    final int cid = cidOverride ?? DateTime.now().millisecondsSinceEpoch;

    _emitLocal({
      'ver': 11,
      'cmd': 1,
      'seq': -1,
      'opcode': 128,
      'payload': {
        'chatId': chatId,
        'message': {
          'id': 'local_$cid',
          'sender': senderId ?? 0,
          'time': DateTime.now().millisecondsSinceEpoch,
          'text': '',
          'type': 'USER',
          'cid': cid,
          'attaches': [
            {'_type': 'AUDIO', 'url': 'file://$localPath'},
          ],
        },
      },
    });

    final int seq82 = await _sendMessage(82, {'type': 2, 'count': 1});
    final resp82 = await messages.firstWhere((m) => m['seq'] == seq82);

    final infoList = resp82['payload']?['info'];
    if (infoList is! List || infoList.isEmpty) {
      throw Exception('Неверный ответ на opcode 82: отсутствует info');
    }

    final uploadInfo = infoList.first;
    final String uploadUrl = uploadInfo['url'];
    final int audioId = (uploadInfo['id'] as num).toInt();

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('file', localPath));
    final streamed = await request.send();
    final httpResp = await http.Response.fromStream(streamed);
    if (httpResp.statusCode != 200) {
      throw Exception(
        'Ошибка загрузки аудио: ${httpResp.statusCode} ${httpResp.body}',
      );
    }

    String? token;
    try {
      final decoded = jsonDecode(httpResp.body);
      if (decoded is Map) {
        token = decoded['token']?.toString();
      }
    } catch (_) {}

    if (token == null || token.isEmpty) {
      throw Exception('Не получен token после загрузки аудио');
    }

    Future<void> trySendWithToken() async {
      final payload = {
        'chatId': chatId,
        'message': {
          'isLive': false,
          'detectShare': false,
          'elements': [],
          'cid': cid,
          'attaches': [
            {'_type': 'AUDIO', 'token': token},
          ],
        },
        'notify': true,
      };
      clearChatsCache();

      final int seq64 = await _sendMessage(64, payload);
      final resp64 = await messages.firstWhere((m) => m['seq'] == seq64);
      final cmd = resp64['cmd'] as int?;
      if (cmd == 0x300 || cmd == 768) {
        final err = resp64['payload'];
        if (err is Map && err['error'] == 'attachment.not.ready') {
          throw err;
        }
        throw Exception(err?.toString() ?? 'Ошибка отправки аудио');
      }
    }

    int attempt = 0;
    while (true) {
      try {
        await trySendWithToken();
        return;
      } catch (e) {
        if (e is Map && e['error'] == 'attachment.not.ready') {
          if (attempt >= maxNotReadyRetries) {
            throw Exception('attachment.not.ready (max retries exceeded)');
          }
          final backoffMs = 250 * (attempt + 1);
          await Future.delayed(Duration(milliseconds: backoffMs));
          await _sendMessage(136, {'audioId': audioId});
          attempt += 1;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<Profile?> updateProfileText(
    String firstName,
    String lastName,
    String description,
  ) async {
    try {
      await waitUntilOnline();

      final Map<String, dynamic> payload = {
        "firstName": firstName,
        "lastName": lastName,
        "description": description,
      };

      final int seq = await _sendMessage(16, payload);
      _log(
        '➡️ SEND: opcode=16, payload=${truncatePayloadObjectForLog(payload)}',
      );

      final response = await messages.firstWhere(
        (msg) => msg['seq'] == seq && msg['opcode'] == 16,
      );

      final Map<String, dynamic>? respPayload =
          response['payload'] as Map<String, dynamic>?;

      if (respPayload == null) {
        throw Exception('Пустой ответ сервера на изменение профиля');
      }

      if (respPayload.containsKey('error')) {
        final humanMessage =
            respPayload['localizedMessage'] ??
            respPayload['message'] ??
            respPayload['title'] ??
            respPayload['error'];
        throw Exception(humanMessage.toString());
      }

      final profileJson = respPayload['profile'];
      if (profileJson is Map<String, dynamic>) {
        _lastChatsPayload ??= {
          'chats': <dynamic>[],
          'contacts': <dynamic>[],
          'profile': null,
          'presence': null,
          'config': null,
        };
        _lastChatsPayload!['profile'] = profileJson;

        return Profile.fromJson(profileJson);
      }
    } catch (e) {
      _log('❌ Ошибка при обновлении профиля через opcode 16: $e');
    }
    return null;
  }

  Future<Profile?> updateProfilePhoto(String firstName, String lastName) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      print("Запрашиваем URL для загрузки фото...");
      final int seq = await _sendMessage(80, {"count": 1});
      final response = await messages.firstWhere((msg) => msg['seq'] == seq);
      final String uploadUrl = response['payload']['url'];
      print("URL получен: $uploadUrl");

      print("Загружаем фото на сервер...");
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var streamedResponse = await request.send();
      var httpResponse = await http.Response.fromStream(streamedResponse);

      if (httpResponse.statusCode != 200) {
        throw Exception("Ошибка загрузки фото: ${httpResponse.body}");
      }

      final uploadResult = jsonDecode(httpResponse.body);
      final String photoToken = uploadResult['photos'].values.first['token'];
      print("Фото загружено, получен токен: $photoToken");

      print("Привязываем фото к профилю...");
      final payload = {
        "firstName": firstName,
        "lastName": lastName,
        "photoToken": photoToken,
        "avatarType": "USER_AVATAR",
      };
      final int seq16 = await _sendMessage(16, payload);
      print("Запрос на смену аватара отправлен.");

      final resp16 = await messages.firstWhere(
        (msg) => msg['seq'] == seq16 && msg['opcode'] == 16,
      );

      final Map<String, dynamic>? respPayload16 =
          resp16['payload'] as Map<String, dynamic>?;

      if (respPayload16 == null) {
        throw Exception('Пустой ответ сервера на смену аватара');
      }

      if (respPayload16.containsKey('error')) {
        final humanMessage =
            respPayload16['localizedMessage'] ??
            respPayload16['message'] ??
            respPayload16['title'] ??
            respPayload16['error'];
        throw Exception(humanMessage.toString());
      }

      final profileJson = respPayload16['profile'];
      if (profileJson is Map<String, dynamic>) {
        _lastChatsPayload ??= {
          'chats': <dynamic>[],
          'contacts': <dynamic>[],
          'profile': null,
          'presence': null,
          'config': null,
        };
        _lastChatsPayload!['profile'] = profileJson;

        final profile = Profile.fromJson(profileJson);
        await ProfileCacheService().syncWithServerProfile(profile);
        return profile;
      }
    } catch (e) {
      print("!!! Ошибка в процессе смены аватара: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> fetchPresetAvatars() async {
    await waitUntilOnline();

    final int seq = await _sendMessage(25, {});
    _log('➡️ SEND: opcode=25, payload={}');

    final resp = await messages.firstWhere(
      (msg) => msg['seq'] == seq && msg['opcode'] == 25,
    );

    final payload = resp['payload'] as Map<String, dynamic>?;
    return payload ?? <String, dynamic>{};
  }

  Future<Profile?> setPresetAvatar({
    required String firstName,
    required String lastName,
    required int photoId,
  }) async {
    try {
      await waitUntilOnline();

      final payload = {
        "firstName": firstName,
        "lastName": lastName,
        "photoId": photoId,
        "avatarType": "PRESET_AVATAR",
      };

      final int seq16 = await _sendMessage(16, payload);
      _log(
        '➡️ SEND: opcode=16 (PRESET_AVATAR), payload=${truncatePayloadObjectForLog(payload)}',
      );

      final resp16 = await messages.firstWhere(
        (msg) => msg['seq'] == seq16 && msg['opcode'] == 16,
      );

      final Map<String, dynamic>? respPayload16 =
          resp16['payload'] as Map<String, dynamic>?;

      if (respPayload16 == null) {
        throw Exception('Пустой ответ сервера на установку пресет‑аватара');
      }

      if (respPayload16.containsKey('error')) {
        final humanMessage =
            respPayload16['localizedMessage'] ??
            respPayload16['message'] ??
            respPayload16['title'] ??
            respPayload16['error'];
        throw Exception(humanMessage.toString());
      }

      final profileJson = respPayload16['profile'];
      if (profileJson is Map<String, dynamic>) {
        _lastChatsPayload ??= {
          'chats': <dynamic>[],
          'contacts': <dynamic>[],
          'profile': null,
          'presence': null,
          'config': null,
        };
        _lastChatsPayload!['profile'] = profileJson;

        return Profile.fromJson(profileJson);
      }
    } catch (e) {
      _log('❌ Ошибка при установке пресет‑аватара: $e');
    }
    return null;
  }

  Future<void> sendPhotoMessage(
    int chatId, {
    String? localPath,
    String? caption,
    int? cidOverride,
    int? senderId,
  }) async {
    try {
      XFile? image;
      if (localPath != null) {
        image = XFile(localPath);
      } else {
        final picker = ImagePicker();
        image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
      }

      await waitUntilOnline();

      final int seq80 = await _sendMessage(80, {"count": 1});
      final resp80 = await messages.firstWhere((m) => m['seq'] == seq80);
      final String uploadUrl = resp80['payload']['url'];

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var streamed = await request.send();
      var httpResp = await http.Response.fromStream(streamed);
      if (httpResp.statusCode != 200) {
        throw Exception(
          'Ошибка загрузки фото: ${httpResp.statusCode} ${httpResp.body}',
        );
      }
      final uploadJson = jsonDecode(httpResp.body) as Map<String, dynamic>;
      final Map photos = uploadJson['photos'] as Map;
      if (photos.isEmpty) throw Exception('Не получен токен фото');
      final String photoToken = (photos.values.first as Map)['token'];

      final int cid = cidOverride ?? DateTime.now().millisecondsSinceEpoch;
      final payload = {
        "chatId": chatId,
        "message": {
          "text": caption?.trim() ?? "",
          "cid": cid,
          "elements": [],
          "attaches": [
            {"_type": "PHOTO", "photoToken": photoToken},
          ],
        },
        "notify": true,
      };

      clearChatsCache();

      if (localPath != null) {
        _emitLocal({
          'ver': 11,
          'cmd': 1,
          'seq': -1,
          'opcode': 128,
          'payload': {
            'chatId': chatId,
            'message': {
              'id': 'local_$cid',
              'sender': senderId ?? 0,
              'time': DateTime.now().millisecondsSinceEpoch,
              'text': caption?.trim() ?? '',
              'type': 'USER',
              'cid': cid,
              'attaches': [
                {'_type': 'PHOTO', 'url': 'file://$localPath'},
              ],
            },
          },
        });
      }

      _sendMessage(64, payload);
    } catch (e) {
      print('Ошибка отправки фото-сообщения: $e');
    }
  }

  Future<void> sendPhotoMessages(
    int chatId, {
    required List<String> localPaths,
    String? caption,
    int? senderId,
  }) async {
    if (localPaths.isEmpty) return;
    try {
      await waitUntilOnline();

      final int cid = DateTime.now().millisecondsSinceEpoch;
      _emitLocal({
        'ver': 11,
        'cmd': 1,
        'seq': -1,
        'opcode': 128,
        'payload': {
          'chatId': chatId,
          'message': {
            'id': 'local_$cid',
            'sender': senderId ?? 0,
            'time': DateTime.now().millisecondsSinceEpoch,
            'text': caption?.trim() ?? '',
            'type': 'USER',
            'cid': cid,
            'attaches': [
              for (final p in localPaths)
                {'_type': 'PHOTO', 'url': 'file://$p'},
            ],
          },
        },
      });

      final List<Map<String, String>> photoTokens = [];
      for (final path in localPaths) {
        final int seq80 = await _sendMessage(80, {"count": 1});
        final resp80 = await messages.firstWhere((m) => m['seq'] == seq80);
        final String uploadUrl = resp80['payload']['url'];

        var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        request.files.add(await http.MultipartFile.fromPath('file', path));
        var streamed = await request.send();
        var httpResp = await http.Response.fromStream(streamed);
        if (httpResp.statusCode != 200) {
          throw Exception(
            'Ошибка загрузки фото: ${httpResp.statusCode} ${httpResp.body}',
          );
        }
        final uploadJson = jsonDecode(httpResp.body) as Map<String, dynamic>;
        final Map photos = uploadJson['photos'] as Map;
        if (photos.isEmpty) throw Exception('Не получен токен фото');
        final String photoToken = (photos.values.first as Map)['token'];
        photoTokens.add({"token": photoToken});
      }

      final payload = {
        "chatId": chatId,
        "message": {
          "text": caption?.trim() ?? "",
          "cid": cid,
          "elements": [],
          "attaches": [
            for (final t in photoTokens)
              {"_type": "PHOTO", "photoToken": t["token"]},
          ],
        },
        "notify": true,
      };

      clearChatsCache();

      final queueItem = QueueItem(
        id: 'photo_$cid',
        type: QueueItemType.sendMessage,
        opcode: 64,
        payload: payload,
        createdAt: DateTime.now(),
        persistent: true,
        chatId: chatId,
        cid: cid,
      );

      unawaited(
        _sendMessage(64, payload)
            .then((_) {
              _queueService.removeFromQueue(queueItem.id);
            })
            .catchError((e) {
              print('Ошибка отправки фото: $e');
              _queueService.addToQueue(queueItem);
            }),
      );
    } catch (e) {
      print('Ошибка отправки фото-сообщений: $e');
    }
  }

  Future<void> sendFileMessage(
    int chatId, {
    String? caption,
    int? senderId,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        print("Выбор файла отменен");
        return;
      }

      final String filePath = result.files.single.path!;
      final String fileName = result.files.single.name;
      final int fileSize = result.files.single.size;

      await waitUntilOnline();

      final int cid = DateTime.now().millisecondsSinceEpoch;
      _emitLocal({
        'ver': 11,
        'cmd': 1,
        'seq': -1,
        'opcode': 128,
        'payload': {
          'chatId': chatId,
          'message': {
            'id': 'local_$cid',
            'sender': senderId ?? 0,
            'time': DateTime.now().millisecondsSinceEpoch,
            'text': caption?.trim() ?? '',
            'type': 'USER',
            'cid': cid,
            'attaches': [
              {
                '_type': 'FILE',
                'name': fileName,
                'size': fileSize,
                'url': 'file://$filePath',
              },
            ],
          },
        },
      });

      final int seq87 = await _sendMessage(87, {"count": 1});
      final resp87 = await messages.firstWhere((m) => m['seq'] == seq87);

      if (resp87['payload'] == null ||
          resp87['payload']['info'] == null ||
          (resp87['payload']['info'] as List).isEmpty) {
        throw Exception('Неверный ответ на Opcode 87: отсутствует "info"');
      }

      final uploadInfo = (resp87['payload']['info'] as List).first;
      final String uploadUrl = uploadInfo['url'];
      final int fileId = uploadInfo['fileId'];
      final String token = uploadInfo['token'];

      print('Получен fileId: $fileId, token: $token и URL: $uploadUrl');

      Timer? heartbeatTimer;
      heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _sendMessage(65, {"chatId": chatId, "type": "FILE"});
        print('Heartbeat отправлен для загрузки файла');
      });

      try {
        var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
        var streamed = await request.send();
        var httpResp = await http.Response.fromStream(streamed);
        if (httpResp.statusCode != 200) {
          throw Exception(
            'Ошибка загрузки файла: ${httpResp.statusCode} ${httpResp.body}',
          );
        }

        print('Файл успешно загружен на сервер. Ожидаем подтверждение...');

        final uploadCompleteMsg = await messages
            .timeout(const Duration(seconds: 30))
            .firstWhere(
              (msg) =>
                  msg['opcode'] == 136 && msg['payload']['fileId'] == fileId,
            );

        print(
          'Получено подтверждение загрузки файла: ${uploadCompleteMsg['payload']}',
        );

        heartbeatTimer.cancel();

        final payload = {
          "chatId": chatId,
          "message": {
            "text": caption?.trim() ?? "",
            "cid": cid,
            "elements": [],
            "attaches": [
              {"_type": "FILE", "fileId": fileId},
            ],
          },
          "notify": true,
        };

        clearChatsCache();

        final queueItem = QueueItem(
          id: 'file_$cid',
          type: QueueItemType.sendMessage,
          opcode: 64,
          payload: payload,
          createdAt: DateTime.now(),
          persistent: true,
          chatId: chatId,
          cid: cid,
        );

        unawaited(
          _sendMessage(64, payload)
              .then((_) {
                _queueService.removeFromQueue(queueItem.id);
              })
              .catchError((e) {
                print('Ошибка отправки файла: $e');
                _queueService.addToQueue(queueItem);
              }),
        );
        print('Сообщение о файле (Opcode 64) отправлено.');
      } finally {
        heartbeatTimer.cancel();
      }
    } catch (e) {
      print('Ошибка отправки файла: $e');
    }
  }

  Future<void> sendContactMessage(
    int chatId, {
    required int contactId,
    int? senderId,
  }) async {
    try {
      await waitUntilOnline();

      final int cid = DateTime.now().millisecondsSinceEpoch;

      _emitLocal({
        'ver': 11,
        'cmd': 1,
        'seq': -1,
        'opcode': 128,
        'payload': {
          'chatId': chatId,
          'message': {
            'id': 'local_$cid',
            'sender': senderId ?? 0,
            'time': DateTime.now().millisecondsSinceEpoch,
            'text': '',
            'type': 'USER',
            'cid': cid,
            'attaches': [
              {'_type': 'CONTACT', 'contactId': contactId},
            ],
          },
        },
      });

      final payload = {
        "chatId": chatId,
        "message": {
          "text": "",
          "cid": cid,
          "elements": [],
          "attaches": [
            {"_type": "CONTACT", "contactId": contactId},
          ],
        },
        "notify": true,
      };

      final queueItem = QueueItem(
        id: 'contact_$cid',
        type: QueueItemType.sendMessage,
        opcode: 64,
        payload: payload,
        createdAt: DateTime.now(),
        persistent: true,
        chatId: chatId,
        cid: cid,
      );

      unawaited(
        _sendMessage(64, payload)
            .then((_) {
              _queueService.removeFromQueue(queueItem.id);
            })
            .catchError((e) {
              print('Ошибка отправки контакта: $e');
              _queueService.addToQueue(queueItem);
            }),
      );
    } catch (e) {
      print('Ошибка отправки контакта: $e');
    }
  }

  Future<String> getVideoUrl(int videoId, int chatId, String messageId) async {
    await waitUntilOnline();

    final payload = {
      "videoId": videoId,
      "chatId": chatId,
      "messageId": int.tryParse(messageId) ?? 0,
    };

    final int seq = await _sendMessage(83, payload);
    print('Запрашиваем URL для videoId: $videoId (seq: $seq)');

    try {
      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq && msg['opcode'] == 83)
          .timeout(const Duration(seconds: 15));

      if (response['cmd'] == 3) {
        throw Exception(
          'Ошибка получения URL видео: ${response['payload']?['message']}',
        );
      }

      final videoPayload = response['payload'] as Map<String, dynamic>?;
      if (videoPayload == null) {
        throw Exception('Получен пустой payload для видео');
      }

      String? videoUrl =
          videoPayload['MP4_720'] as String? ??
          videoPayload['MP4_480'] as String? ??
          videoPayload['MP4_1080'] as String? ??
          videoPayload['MP4_360'] as String?;

      if (videoUrl == null) {
        final mp4Key = videoPayload.keys.firstWhere(
          (k) => k.startsWith('MP4_'),
          orElse: () => '',
        );
        if (mp4Key.isNotEmpty) {
          videoUrl = videoPayload[mp4Key] as String?;
        }
      }

      if (videoUrl != null) {
        print('URL для videoId: $videoId успешно получен.');
        return videoUrl;
      } else {
        throw Exception('Не найден ни один MP4 URL в ответе');
      }
    } on TimeoutException {
      print('Таймаут ожидания URL для videoId: $videoId');
      throw Exception('Сервер не ответил на запрос видео вовремя');
    } catch (e) {
      print('Ошибка в getVideoUrl: $e');
      rethrow;
    }
  }
}
