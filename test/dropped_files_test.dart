import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/clipboard/pasted_attachment.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('komet_drop_test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<String> file(String name, int size) async {
    final path = p.join(dir.path, name);
    await File(path).writeAsBytes(List.filled(size, 7));
    return path;
  }

  test('dropped files keep their name, size and media kind', () async {
    final photo = await file('photo.JPG', 3);
    final clip = await file('clip.mp4', 5);
    final doc = await file('notes.pdf', 8);

    final items = await materializeDroppedFiles([photo, clip, doc]);

    expect(items.map((it) => it.name), ['photo.JPG', 'clip.mp4', 'notes.pdf']);
    expect(items.map((it) => it.size), [3, 5, 8]);
    expect(items.map((it) => it.kind), [
      PastedAttachmentKind.image,
      PastedAttachmentKind.video,
      PastedAttachmentKind.file,
    ]);
    expect(items.map((it) => it.isMedia), [true, true, false]);
  });

  test('folders and vanished paths are skipped', () async {
    final folder = await Directory(p.join(dir.path, 'album')).create();
    final kept = await file('kept.png', 1);

    final items = await materializeDroppedFiles([
      folder.path,
      p.join(dir.path, 'missing.png'),
      kept,
    ]);

    expect(items.map((it) => it.name), ['kept.png']);
  });
}
