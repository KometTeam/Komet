import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/crypto/message_decryption_cache.dart';
import '../../core/crypto/e2ee_service.dart';
import '../../core/storage/chat_encryption_store.dart';

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
    ChatEncryptionStore.instance.revision.addListener(_onEncryptionChanged);
    E2eeService.instance.revision.addListener(_onEncryptionChanged);
  }

  void _onEncryptionChanged() {
    scheduleMicrotask(() {
      if (mounted) _request();
    });
  }

  @override
  void dispose() {
    ChatEncryptionStore.instance.revision.removeListener(_onEncryptionChanged);
    E2eeService.instance.revision.removeListener(_onEncryptionChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(DecryptedContent old) {
    super.didUpdateWidget(old);
    if (old.accountId != widget.accountId ||
        old.chatId != widget.chatId ||
        old.messageId != widget.messageId ||
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
        accountId: widget.accountId,
        chatId: widget.chatId,
      ),
      builder: (context, decryption, _) => widget.builder(decryption),
    );
  }
}
