import 'dart:async';

class SharedFileUsage {
  static final instance = SharedFileUsage();

  final Map<String, Set<Future<void>>> _readers = {};

  Future<T> use<T>(
    Iterable<String> filePaths,
    Future<T> Function() operation,
  ) async {
    final paths = filePaths.toSet();
    final released = Completer<void>();
    for (final path in paths) {
      (_readers[path] ??= {}).add(released.future);
    }
    try {
      return await operation();
    } finally {
      for (final path in paths) {
        final readers = _readers[path];
        readers?.remove(released.future);
        if (readers?.isEmpty ?? false) _readers.remove(path);
      }
      released.complete();
    }
  }

  Future<void> waitUntilUnused(Iterable<String> filePaths) async {
    final paths = filePaths.toSet();
    while (true) {
      final readers = {for (final path in paths) ...?_readers[path]};
      if (readers.isEmpty) return;
      await Future.wait(readers);
    }
  }
}
