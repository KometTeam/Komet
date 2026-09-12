import 'dart:convert';

import 'package:flutter/widgets.dart';

// #***! Expando привязывает провайдер к сообщению, base64 декодируется один раз а не на каждый билд
final Expando<ImageProvider> _providers = Expando<ImageProvider>('preview');

// #***! размытая превьюшка из data-uri
ImageProvider? dataUriImage(Object owner, String? data) {
  if (data == null || !data.startsWith('data:')) return null;
  final cached = _providers[owner];
  if (cached != null) return cached;
  final comma = data.indexOf(',');
  if (comma < 0) return null;
  try {
    final provider = MemoryImage(base64Decode(data.substring(comma + 1)));
    _providers[owner] = provider;
    return provider;
  } catch (_) {
    return null;
  }
}
