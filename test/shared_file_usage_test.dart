import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/share/shared_file_usage.dart';

void main() {
  test('waits for every concurrent upload using a shared file', () async {
    final usage = SharedFileUsage();
    final first = Completer<void>();
    final second = Completer<void>();
    final firstUpload = usage.use(['/synthetic/photo'], () => first.future);
    final secondUpload = usage.use(['/synthetic/photo'], () => second.future);
    var released = false;
    final cleanup = usage
        .waitUntilUnused(['/synthetic/photo'])
        .then((_) => released = true);

    first.complete();
    await firstUpload;
    expect(released, isFalse);
    second.complete();
    await secondUpload;
    await cleanup;
    expect(released, isTrue);
  });

  test('protects uploads started after the composer has closed', () async {
    final usage = SharedFileUsage();
    final readyToUpload = Completer<void>();
    final uploaded = Completer<void>();
    late Future<void> upload;
    final preparing = usage.use(['/synthetic/video'], () async {
      await readyToUpload.future;
      upload = usage.use(['/synthetic/video'], () => uploaded.future);
    });
    var released = false;
    final cleanup = usage
        .waitUntilUnused(['/synthetic/video'])
        .then((_) => released = true);

    readyToUpload.complete();
    await preparing;
    expect(released, isFalse);
    uploaded.complete();
    await upload;
    await cleanup;
    expect(released, isTrue);
  });

  test('releases failed readers and deduplicates repeated paths', () async {
    final usage = SharedFileUsage();
    final failed = Completer<void>();
    final upload = usage.use([
      '/synthetic/document',
      '/synthetic/document',
    ], () => failed.future);
    final result = expectLater(upload, throwsStateError);
    final cleanup = usage.waitUntilUnused(['/synthetic/document']);

    failed.completeError(StateError('Synthetic upload failure'));
    await result;
    await cleanup;
    await usage.waitUntilUnused(['/synthetic/document']);
  });

  test('does not block cleanup on files from another share', () async {
    final usage = SharedFileUsage();
    final uploaded = Completer<void>();
    final upload = usage.use(['/synthetic/other'], () => uploaded.future);

    await usage.waitUntilUnused(['/synthetic/current']);
    uploaded.complete();
    await upload;
  });
}
