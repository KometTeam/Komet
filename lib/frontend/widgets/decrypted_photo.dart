import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/crypto/encrypted_photo_cache.dart';
import '../../core/storage/chat_encryption_store.dart';

class DecryptedPhoto extends StatefulWidget {
  final int accountId;
  final int chatId;
  final String cacheName;
  final int size;
  final EncryptedPhotoUrlLoader urlLoader;
  final Widget Function(EncryptedPhotoView? view) builder;

  const DecryptedPhoto({
    super.key,
    required this.accountId,
    required this.chatId,
    required this.cacheName,
    required this.size,
    required this.urlLoader,
    required this.builder,
  });

  @override
  State<DecryptedPhoto> createState() => _DecryptedPhotoState();
}

class _DecryptedPhotoState extends State<DecryptedPhoto> {
  @override
  void initState() {
    super.initState();
    _request();
    ChatEncryptionStore.instance.revision.addListener(_onEncryptionChanged);
  }

  @override
  void dispose() {
    ChatEncryptionStore.instance.revision.removeListener(_onEncryptionChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(DecryptedPhoto old) {
    super.didUpdateWidget(old);
    if (old.cacheName != widget.cacheName) _request();
  }

  void _onEncryptionChanged() => scheduleMicrotask(_request);

  void _request() {
    if (!mounted) return;
    EncryptedPhotoCache.instance.request(
      accountId: widget.accountId,
      chatId: widget.chatId,
      cacheName: widget.cacheName,
      urlLoader: widget.urlLoader,
      size: widget.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EncryptedPhotoView?>(
      valueListenable: EncryptedPhotoCache.instance.listenableFor(
        widget.cacheName,
      ),
      builder: (context, view, _) => widget.builder(view),
    );
  }
}
