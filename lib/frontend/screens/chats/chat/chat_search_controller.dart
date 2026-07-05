import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/utils/logger.dart';
import '../../../../main.dart';
import 'message_search_result.dart';

class ChatSearchController {
  ChatSearchController({required this.chatId, required this.isMounted}) {
    searchController.addListener(_onTextChanged);
  }

  final int chatId;
  final bool Function() isMounted;

  final TextEditingController searchController = TextEditingController();
  final ValueNotifier<bool> searchMode = ValueNotifier(false);
  final ValueNotifier<List<MessageSearchResult>> results = ValueNotifier(
    const [],
  );
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<bool> performed = ValueNotifier(false);
  Timer? _debounce;
  int _seq = 0;

  void _onTextChanged() {
    final query = searchController.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      _seq++;
      results.value = const [];
      loading.value = false;
      performed.value = false;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      runSearch(query);
    });
  }

  void submit(String query) {
    _debounce?.cancel();
    runSearch(query);
  }

  Future<void> runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final seq = ++_seq;
    loading.value = true;
    List<Map<String, dynamic>> raw;
    try {
      raw = await messagesModule.searchMessages(chatId, trimmed);
    } catch (e) {
      logger.e('Search error: $e');
      raw = const [];
    }
    if (!isMounted() || seq != _seq) return;
    final mapped = raw
        .map(MessageSearchResult.fromRaw)
        .whereType<MessageSearchResult>()
        .toList();
    results.value = mapped;
    loading.value = false;
    performed.value = true;
  }

  void reset() {
    _debounce?.cancel();
    _seq++;
    searchMode.value = false;
    searchController.clear();
    results.value = const [];
    loading.value = false;
    performed.value = false;
  }

  void dispose() {
    _debounce?.cancel();
    searchController.removeListener(_onTextChanged);
    searchController.dispose();
    searchMode.dispose();
    results.dispose();
    loading.dispose();
    performed.dispose();
  }
}
