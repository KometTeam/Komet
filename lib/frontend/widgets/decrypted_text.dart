import 'package:flutter/material.dart';

import '../../core/crypto/message_decryption_cache.dart';

class DecryptedContent extends StatefulWidget {
  final int accountId;
  final int chatId;
  final String messageId;
  final String cipherText;
  final Widget Function(MessageDecryption? decryption) builder;

  const DecryptedContent({
    super.key,
    required this.accountId,
    required this.chatId,
    required this.messageId,
    required this.cipherText,
    required this.builder,
  });

  @override
  State<DecryptedContent> createState() => _DecryptedContentState();
}

class _DecryptedContentState extends State<DecryptedContent> {
  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(DecryptedContent old) {
    super.didUpdateWidget(old);
    if (old.messageId != widget.messageId ||
        old.cipherText != widget.cipherText) {
      _request();
    }
  }

  void _request() {
    MessageDecryptionCache.instance.request(
      accountId: widget.accountId,
      chatId: widget.chatId,
      messageId: widget.messageId,
      cipherText: widget.cipherText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MessageDecryption?>(
      valueListenable: MessageDecryptionCache.instance.listenableFor(
        widget.messageId,
      ),
      builder: (context, decryption, _) => widget.builder(decryption),
    );
  }
}
