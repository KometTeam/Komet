class Message {
  final String id;
  final String text;
  final int time;
  final int senderId;
  final String? status;
  final int? updateTime;
  final List<Map<String, dynamic>> attaches;
  final int? cid;
  final Map<String, dynamic>? reactionInfo;
  final Map<String, dynamic>? link;
  final List<Map<String, dynamic>> elements;
  final bool isDeleted;
  final String? originalText;

  Message({
    required this.id,
    required this.text,
    required this.time,
    required this.senderId,
    this.status,
    this.updateTime,
    this.attaches = const [],
    this.cid,
    this.reactionInfo,
    this.link,
    this.elements = const [],
    this.isDeleted = false,
    this.originalText,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    int senderId;
    if (json['sender'] is int) {
      senderId = json['sender'];
    } else {
      senderId = 0;
    }

    int time;
    if (json['time'] is int) {
      time = json['time'];
    } else {
      time = 0;
    }

    return Message(
      id:
          json['id']?.toString() ??
          'local_${DateTime.now().millisecondsSinceEpoch}',
      text: json['text'] ?? '',
      time: time,
      senderId: senderId,
      status: json['status'],
      updateTime: json['updateTime'],
      attaches:
          (json['attaches'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          const [],
      cid: json['cid'],
      reactionInfo: json['reactionInfo'],
      link: json['link'],
      elements:
          (json['elements'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          const [],
      isDeleted: json['isDeleted'] ?? false,
      originalText: json['originalText'] as String?,
    );
  }

  Message copyWith({
    String? id,
    String? text,
    int? time,
    int? senderId,
    String? status,
    int? updateTime,
    List<Map<String, dynamic>>? attaches,
    int? cid,
    Map<String, dynamic>? reactionInfo,
    Map<String, dynamic>? link,
    List<Map<String, dynamic>>? elements,
    bool? isDeleted,
    String? originalText,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      time: time ?? this.time,
      senderId: senderId ?? this.senderId,
      status: status ?? this.status,
      updateTime: updateTime ?? this.updateTime,
      attaches: attaches ?? this.attaches,
      cid: cid ?? this.cid,
      reactionInfo: reactionInfo ?? this.reactionInfo,
      link: link ?? this.link,
      elements: elements ?? this.elements,
      isDeleted: isDeleted ?? this.isDeleted,
      originalText: originalText ?? this.originalText,
    );
  }

  bool get isEdited => status == 'EDITED';
  bool get isReply => link != null && link!['type'] == 'REPLY';
  bool get isForwarded => link != null && link!['type'] == 'FORWARD';
  bool get hasFileAttach =>
      attaches.any((a) => (a['_type'] ?? a['type']) == 'FILE');

  bool canEdit(int currentUserId) {
    if (isDeleted) return false;
    if (senderId != currentUserId) return false;
    if (attaches.isNotEmpty) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final messageTime = time;
    final hoursSinceCreation = (now - messageTime) / (1000 * 60 * 60);

    return hoursSinceCreation <= 24;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'time': time,
      'sender': senderId,
      'status': status,
      'updateTime': updateTime,
      'cid': cid,
      'attaches': attaches,
      'link': link,
      'reactionInfo': reactionInfo,
      'elements': elements,
    };
  }
}
